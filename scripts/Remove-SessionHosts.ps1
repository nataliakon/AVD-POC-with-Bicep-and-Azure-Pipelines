param (
    [string]$HostPoolName,
    [string]$ResourceGroupName
)


function Wait-ForJobs {
    param ([array]$Jobs = @())

    Write-Host "Wait for $($Jobs.Count) jobs"
    $StartTime = Get-Date
    while ($true) {
        if ((Get-Date).Subtract($StartTime).TotalSeconds -ge $StatusCheckTimeOut) {
            throw "Status check timed out. Taking more than $StatusCheckTimeOut seconds"
        }
        Write-Host "[Check jobs status] Total: $($Jobs.Count), $(($Jobs | Group-Object State | ForEach-Object { "$($_.Name): $($_.Count)" }) -join ', ')"
        if (!($Jobs | Where-Object { $_.State -eq 'Running' })) {
            break
        }
        Start-Sleep -Seconds 30
    }

    $IncompleteJobs = @($Jobs | Where-Object { $_.State -ne 'Completed' })
    if ($IncompleteJobs) {
        throw "$($IncompleteJobs.Count) jobs did not complete successfully: $($IncompleteJobs | Format-List -Force | Out-String)"
    }
}

function Update-SessionHostToAllowNewSession {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $SessionHost
    )
    Begin { }
    Process {
        if (!$SessionHost.AllowNewSession) {
            $SessionHostName = $SessionHost.Name.Split('/')[-1].ToLower()
            Write-Host "Update session host '$($SessionHostName)' to allow new sessions"
            if ($PSCmdlet.ShouldProcess($SessionHostName, 'Update session host to allow new sessions')) {
                Update-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -Name $SessionHostName -AllowNewSession:$true | Write-Verbose
            }
        }
    }
    End { }
}

#Setting the Log-off Message

[string]$LogOffMessageTitle = "Warning. Maintenance."
[string]$LogOffMessageBody = "Please save your work and log off."
[int]$LimitSecondsToForceLogOffUser = 10
[int]$StatusCheckTimeOut = 60 * 60 # 1 hr
[int]$SessionHostStatusCheckSleepSecs = 30
[string[]]$DesiredRunningStates = @('Available', 'NeedsAssistance')
# Object that contains all session host objects, VM instance objects except the ones that are under maintenance
$VMs = @{ }
# Note: time diff can be '#' or '#:#', so it is appended with ':0' in case its just '#' and so the result will have at least 2 items (hrs and min)
$TimeDifference = "0:00"
[string[]]$TimeDiffHrsMin = "$($TimeDifference):0".Split(':')
$CurrentDateTime = (Get-Date).ToUniversalTime().AddHours($TimeDiffHrsMin[0]).AddMinutes($TimeDiffHrsMin[1])

# Now that we have all the info about the session hosts & their usage, figure how many session hosts to start/stop depending on in/off peak hours and the demand
	$Ops = @{
		nVMsToStart   = 0
		nVMsToStop    = 0
	}

	try {
		Write-Host "Get Hostpool info of '$HostPoolName' in resource group '$ResourceGroupName'"
		$HostPool = Get-AzWvdHostPool -Name $HostPoolName -ResourceGroupName $ResourceGroupName
		if (!$HostPool) {
			throw $HostPool
		}
	}
	catch {
		throw [System.Exception]::new("Failed to get Hostpool info of '$HostPoolName' in resource group '$ResourceGroupName'. Ensure that you have entered the correct values", $PSItem.Exception)
	}

	Write-Host 'Get all session hosts in the Drain mode'
	$SessionHosts = @(Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName | Where-Object {$_.AllowNewSession -eq $false})
	if (!$SessionHosts) {
		Write-Host "There are no session hosts in the Hostpool '$HostPoolName'. Ensure that hostpool has session hosts"
		Write-Host 'End'
		return
    }
    
    else {
    Write-Host "HostPool info: $($HostPool | Format-List -Force | Out-String)"
	Write-Host "Number of drained session hosts in the HostPool: $($SessionHosts.Count)"
    }

    #Updating number of VMs to be stopped/started with number of hosts
    $Ops.nVMsToStop=$SessionHosts.Count
    $Ops.nVMsToStart=$SessionHosts.Count

	Write-Host 'Get number of user sessions in Hostpool'
    [int]$nUserSessions = @(Get-AzWvdUserSession -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName).Count
    Write-Host "'Number of users currently logged on: ' $nUserSessions"

    # Popoluate all session hosts objects
	foreach ($SessionHost in $SessionHosts) {
		$SessionHostName = $SessionHost.Name.Split('/')[-1].ToLower()
		$VMs.Add($SessionHostName.Split('.')[0], @{ 'SessionHostName' = $SessionHostName; 'SessionHost' = $SessionHost; 'Instance' = $null})
    }

    Write-Host 'Get all VMs, check session host status and get usage info'
	foreach ($VMInstance in (Get-AzVM -Status)) {
		if (!$VMs.ContainsKey($VMInstance.Name.ToLower())) {
			# This VM is not a WVD session host
			continue
		}
		$VMName = $VMInstance.Name.ToLower()
		if ($VMInstance.Tags.Keys -contains $MaintenanceTagName) {
			Write-Host "VM '$VMName' is in maintenance and will be ignored"
			$VMs.Remove($VMName)
			continue
		}

		$VM = $VMs[$VMName]
		$SessionHost = $VM.SessionHost
		if ($VM.Instance) {
			throw "More than 1 VM found in Azure with same session host name '$($VM.SessionHostName)' (This is not supported): $($VMInstance | Format-List -Force | Out-String)$($VM.Instance | Format-List -Force | Out-String)"
		}

		$VM.Instance = $VMInstance

		Write-Host "Session host: '$($VM.SessionHostName)', power state: '$($VMInstance.PowerState)', status: '$($SessionHost.Status)', update state: '$($SessionHost.UpdateState)', sessions: $($SessionHost.Session), allow new session: $($SessionHost.AllowNewSession)"

		if ($VMInstance.PowerState -eq 'VM running') {
			if ($SessionHost.Status -notin $DesiredRunningStates) {
				Write-Host 'VM is in running state but session host is not (this could be because the VM was just started and has not connected to broker yet)'
			}

			++$nRunningVMs
			$nUserSessionsFromAllRunningVMs += $SessionHost.Session
		}
		else {
			if ($SessionHost.Status -in $DesiredRunningStates) {
				Write-Host "VM is not in running state but session host is (this could be because the VM was just stopped and broker doesn't know that yet)"
			}
		}
	}

    
    # '0' then begin drain and log off
    
	if (!$Ops.nVMsToStop) {
		Write-Host 'No need to start/stop any session hosts'
		Write-Host 'End'
		return
	}

	# Object that contains names of session hosts that will be stopped
	$StopSessionHostFullNames = @{ }
    
	# Array that contains jobs of stopping the session hosts
	[array]$StopVMjobs = @()
	[array]$VMsToStopAfterLogOffTimeOut = @()

    Write-Host 'Find session hosts that are running, sort them by number of user sessions'
    
	foreach ($VM in ($VMs.Values | Where-Object { $_.Instance.PowerState -eq 'VM running' } | Sort-Object { $_.SessionHost.Session })) {
		if (!$Ops.nVMsToStop) {
			# Done with stopping session hosts that needed to be
			break
		}
		$SessionHost = $VM.SessionHost
		$SessionHostName = $VM.SessionHostName
		
		if ($SessionHost.Session -and !$LimitSecondsToForceLogOffUser) {
			Write-Host -Warn "Session host '$SessionHostName' has $($SessionHost.Session) sessions but limit seconds to force log off user is set to 0, so will not stop any more session hosts (https://aka.ms/wvdscale#how-the-scaling-tool-works)"
			# Note: why break ? Because the list this loop iterates through is sorted by number of sessions, if it hits this, the rest of items in the loop will also hit this
			break
		}

		if ($SessionHost.AllowNewSession) {
			Write-Host "Session host '$SessionHostName' has '$($SessionHost.Session)' sessions. Set it to disallow new sessions"
			#if ($PSCmdlet.ShouldProcess($SessionHostName, 'Set session host to disallow new sessions')) {
				try {
					$VM.SessionHost = $SessionHost = Update-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -Name $SessionHostName -AllowNewSession:$false
				}
				catch {
					throw [System.Exception]::new("Failed to set it to disallow new sessions on session host: '$SessionHostName'", $PSItem.Exception)
				}

				if ($SessionHost.Session -and !$LimitSecondsToForceLogOffUser) {
					Write-Host "Session host '$SessionHostName' has $($SessionHost.Session) sessions but limit seconds to force log off user is set to 0, so will not stop any more session hosts (https://aka.ms/wvdscale#how-the-scaling-tool-works)"
					Update-SessionHostToAllowNewSession -SessionHost $SessionHost
					continue
				}
			#}
		}

		if ($SessionHost.Session) {
			[array]$VM.UserSessions = @()
			Write-Host "Get all user sessions from session host '$SessionHostName'"
			try {
				$VM.UserSessions = @(Get-AzWvdUserSession -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -SessionHostName $SessionHostName)
			}
			catch {
				throw [System.Exception]::new("Failed to retrieve user sessions of session host: '$SessionHostName'", $PSItem.Exception)
			}

			Write-Host "Send log off message to active user sessions on session host: '$SessionHostName'"
			foreach ($Session in $VM.UserSessions) {
				if ($Session.SessionState -ne "Active") {
					continue
				}
				$SessionID = $Session.Name.Split('/')[-1]
				try {
					Write-Host "Send a log off message to user: '$($Session.ActiveDirectoryUserName)', session ID: $SessionID"
					#if ($PSCmdlet.ShouldProcess($Session.ActiveDirectoryUserName, 'Send a log off message to user')) {
						# //todo what if user logged off by this time
						Send-AzWvdUserSessionMessage -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -SessionHostName $SessionHostName -UserSessionId $SessionID -MessageTitle $LogOffMessageTitle -MessageBody "$LogOffMessageBody You will be logged off in $LimitSecondsToForceLogOffUser seconds"
					#}
				}
				catch {
					throw [System.Exception]::new("Failed to send a log off message to user: '$($Session.ActiveDirectoryUserName)', session ID: $SessionID", $PSItem.Exception)
				}
			}
			$VMsToStopAfterLogOffTimeOut += $VM
		}
		else {
			Write-Host "Stop session host '$SessionHostName' as a background job"
			#if ($PSCmdlet.ShouldProcess($SessionHostName, 'Stop session host as a background job')) {
				$StopSessionHostFullNames.Add($SessionHost.Name, $null)
				$StopVMjobs += ($VM.Instance | Stop-AzVM -Force -AsJob)
			#}
		}

		--$Ops.nVMsToStop
		if ($Ops.nVMsToStop -lt 0) {
			$Ops.nVMsToStop = 0
		}
	}

	if ($VMsToStopAfterLogOffTimeOut) {
		Write-Host "Wait $LimitSecondsToForceLogOffUser seconds for users to log off"
		#if ($PSCmdlet.ShouldProcess("for $LimitSecondsToForceLogOffUser seconds", 'Wait for users to log off')) {
			Start-Sleep -Seconds $LimitSecondsToForceLogOffUser
		#}

		Write-Host "Force log off users and stop remaining $($VMsToStopAfterLogOffTimeOut.Count) session hosts"
		foreach ($VM in $VMsToStopAfterLogOffTimeOut) {
			$SessionHostName = $VM.SessionHostName

			Write-Host "Force log off $($VM.UserSessions.Count) users on session host: '$SessionHostName'"
			foreach ($Session in $VM.UserSessions) {
				$SessionID = $Session.Name.Split('/')[-1]
				try {
					Write-Host "Force log off user: '$($Session.ActiveDirectoryUserName)', session ID: $SessionID"
					#if ($PSCmdlet.ShouldProcess($Session.Id, 'Force log off user with session ID')) {
						# //todo what if user logged off by this time
						Remove-AzWvdUserSession -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -SessionHostName $SessionHostName -Id $SessionID -Force
					#}
				}
				catch {
					throw [System.Exception]::new("Failed to force log off user: '$($Session.ActiveDirectoryUserName)', session ID: $SessionID", $PSItem.Exception)
				}
			}
			
			Write-Host "Stop session host '$SessionHostName' as a background job"
			#if ($PSCmdlet.ShouldProcess($SessionHostName, 'Stop session host as a background job')) {
				$StopSessionHostFullNames.Add($VM.SessionHost.Name, $null)
				$StopVMjobs += ($VM.Instance | Stop-AzVM -Force -AsJob)
			#}
		}
	}

	# Check if there were enough number of session hosts to stop
	if ($Ops.nVMsToStop) {
		Write-Host "Still need to stop $($Ops.nVMsToStop) VMs"
	}

	# Wait for those jobs to stop the session hosts
	Wait-ForJobs $StopVMjobs

	Write-Host 'All jobs completed'
	Write-Host 'End'
	#return

	# //todo if not going to poll for status here, then no need to keep track of the list of session hosts that were stopped
	Write-Host "Wait for $($StopSessionHostFullNames.Count) session hosts to be unavailable"
	[array]$SessionHostsToCheck = @()
	$StartTime = Get-Date
	while ($true) {
		if ((Get-Date).Subtract($StartTime).TotalSeconds -ge $StatusCheckTimeOut) {
			throw "Status check timed out. Taking more than $StatusCheckTimeOut seconds"
		}
		$SessionHostsToCheck = @(Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName | Where-Object { $StopSessionHostFullNames.ContainsKey($_.Name) })
		Write-Host "[Check session hosts status] Total: $($SessionHostsToCheck.Count), $(($SessionHostsToCheck | Group-Object Status | ForEach-Object { "$($_.Name): $($_.Count)" }) -join ', ')"
		if (!($SessionHostsToCheck | Where-Object { $_.Status -in $DesiredRunningStates })) {
			break
		}
		Start-Sleep -Seconds $SessionHostStatusCheckSleepSecs
	}

	# Make sure session hosts are allowing new user sessions & update them to allow if not
 #  $SessionHostsToCheck | Update-SessionHostToAllowNewSession
    
    # Start the removal from the host pool
    $SessionHosts = @(Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName | Where-Object {$_.AllowNewSession -eq $false})
	if (!$SessionHosts) {
		Write-Host "There are no session hosts in the Hostpool '$HostPoolName'. Ensure that hostpool has session hosts"
		Write-Host 'End'
		return
    }
    foreach ($SessionHost in $SessionHosts) {
        $SessionHostName = $SessionHost.Name.Split('/')[-1].ToLower()
        Write-Host "Removing the registration of the Host: '$SessionHostName'"
        Remove-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -Name $SessionHostName
    }