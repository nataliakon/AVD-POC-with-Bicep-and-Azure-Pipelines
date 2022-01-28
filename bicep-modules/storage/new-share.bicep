param fileshareName string
param storageAccount string 


@allowed([
  'Cool'
  'Hot'
  'Premium'
  'TransactionOptimized'
])
@description('Access tier for specific share. GpV2 account can choose between TransactionOptimized (default), Hot, and Cool. FileStorage account can choose Premium.')
param accessTier string

@allowed([
  'NFS'
  'SMB'
])
@description('The authentication protocol that is used for the file share. Can only be specified when creating a share.')
param enabledProtocols string

@description('The maximum size of the share, in gigabytes. Must be greater than 0, and less than or equal to 5TB (5120). For Large File Shares, the maximum size is 102400.')
param shareQuota string

var lowFileShareName = toLower(fileshareName)


resource fileshare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-06-01' = {
  name: '${storageAccount}/default/${lowFileShareName}'
  properties: {
    accessTier: accessTier
    enabledProtocols: enabledProtocols
    shareQuota: int(shareQuota)
  }
}
