[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $AzureDevopsOrganization,
    [Parameter(Mandatory=$true)]
    [string] $AzureDevopsPersonalAccessToken,
    [Parameter(Mandatory=$false)]
    [string] $PoolName='Default'
)

[string] $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $AzureDevopsPersonalAccessToken)))
[hashtable] $AuthHeader = @{ Authorization = "Basic $base64AuthInfo" }
[string] $Uri = "{0}/_apis/distributedtask/pools?api-version=6.0" -f $AzureDevopsOrganization

Write-Host "Determining PoolId for Pool with Name $PoolName" -ForegroundColor Cyan
$rsp = Invoke-WebRequest -uri $Uri -UseBasicParsing -Headers $AuthHeader
if ($rsp.StatusCode -ne 200) {
    Write-Error "Could not determine PoolId - check that account 'AzureDevopsOrganization' is correct and the token is valid for that account"
    exit 1
}

[PSCustomObject] $poolList = ConvertFrom-Json $rsp.content;
foreach($pool in $poolList.value) {
    if ($pool.name -eq $PoolName) {
        # check if it a non-hosted pool and no legacy pool and not a scaleset pool
        if ((!$pool.isHosted) -and ($pool.poolType -eq "automation") -and ($pool.options -ne "elasticPool")) {
            return $pool.id
        }
    }
}

Write-Error "Could not determine PoolId from $PoolName - Pool is either a hosted or elastic pool!"
return 0
