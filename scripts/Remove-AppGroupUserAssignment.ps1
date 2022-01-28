[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $ResourceGroupName,
    # Application Group Name in the Resource Group
    [Parameter()]
    [Alias("Name")]
    [string]
    $AvdAppGroupName,
    # Azure AD Group Name
    [Parameter()]
    [string]
    $AzureADGroupName
)

$ErrorActionPreference = "Stop"

#Desktop Virtualization User
$RoleDefinitionId = "1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63"


$group = Get-AzADGroup -DisplayName $AzureADGroupName

if (!$group) {
    Write-Error "Group $AzureAdGroupName not found"
    throw
}

$appGroup = Get-AzResource -Name $AvdAppGroupName -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.DesktopVirtualization/applicationgroups"
#will throw error if resource does not exist

$existingAssignment = Get-AzRoleAssignment -Scope $appGroup.ResourceId -ObjectId $group.Id -RoleDefinitionId $RoleDefinitionId -ErrorAction SilentlyContinue

if (!$existingAssignment) {
    Write-Host "Role Assignment does not exist"
    return
}

Write-Host "Removing assignment for group $AzureADGroupName"

Remove-AzRoleAssignment -Scope $appGroup.ResourceId -ObjectId $group.Id -RoleDefinitionId $RoleDefinitionId
