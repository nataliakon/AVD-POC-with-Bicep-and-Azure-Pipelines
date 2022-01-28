
param workspaceName string
param workspaceLocation string
param appGroupName string

var appGroupResourceID = resourceId('Microsoft.DesktopVirtualization/applicationGroups/',appGroupName)


/* Call on the workspace to get the list of existing Application groups. */

resource existingworkspace 'Microsoft.DesktopVirtualization/workspaces@2021-09-03-preview' existing = {
  name: workspaceName
}

/* Update the workspace */

module workspace 'update-workspace.bicep' = {
  name: 'Update-AVD-Workspace-${workspaceName}'
  params: {
    workspaceLocation: workspaceLocation
    workspaceName: workspaceName
    tags: existingworkspace.tags
    workspaceFriendlyName: existingworkspace.properties.friendlyName
    workspaceDescription: existingworkspace.properties.description
    existingApplicationGroupReferences: existingworkspace.properties.applicationGroupReferences
    newApplicationGroupReference: appGroupResourceID
 }
}
