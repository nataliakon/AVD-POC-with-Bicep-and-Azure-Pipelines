param (
    [string]$HostPoolName,
    [string]$ResourceGroupName
)

$ErrorActionPreference = "Stop"
## Get current number of session hosts deployed and return to pipeline
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
        # Set the ADO variable
        $currentSessionHosts=0
        Write-Host "Setting the ADO variable currentSessionHosts to 0 "
		Write-Host "$currentSessionHosts"
        Write-Host "##vso[task.setvariable variable=currentSessionHosts]$currentSessionHosts"
		return
    }
    
    else {
    Write-Host "HostPool info: $($HostPool | Format-List -Force | Out-String)"
	Write-Host "Number of session hosts in the HostPool: $($SessionHosts.Count)"
    Write-Host "Setting the ADO variable currentSessionHosts to $($SessionHosts.Count)"
    $currentSessionHosts=$SessionHosts.Count
    Write-Host "##vso[task.setvariable variable=currentSessionHosts]$currentSessionHosts"
    }


    ## Get image version
    