param (
    [string]$HostPoolName,
    [string]$ResourceGroupName
)

$ErrorActionPreference = "Stop"
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

	Write-Host 'Get all session hosts'
	$SessionHosts = @(Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName)
	if (!$SessionHosts) {
		Write-Host "There are no session hosts in the Hostpool '$HostPoolName'. Ensure that hostpool has session hosts"
		Write-Host 'End'
		return
    }
    
    else {
    Write-Host "HostPool info: $($HostPool | Format-List -Force | Out-String)"
	Write-Host "Number of session hosts in the HostPool: $($SessionHosts.Count)"
    }
    Write-Host "Setting the currently deployed session hosts to 'Drain' mode"
    foreach ($SessionHost in $SessionHosts) {
        $SessionHostName = $SessionHost.Name.Split('/')[-1].ToLower()
        Write-Host "Setting drain mode on the session host $SessionHostName in the HostPool $HostPoolName"
        Update-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $ResourceGroupName -Name $SessionHostName -AllowNewSession:$false
    }
