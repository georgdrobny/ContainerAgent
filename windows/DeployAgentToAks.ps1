[CmdLetBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $AzureDevopsOrganization,
    [Parameter(Mandatory=$true)]
    [string] $AzureDevopsPersonalAccessToken,
    [string] $DeploymentFile = '.\pipelineagent_BuildTools.yml',
    [string] $RepoTag = 'windows',
    [string] $PoolName = 'Container'
)

Function Get-PoolId
{
    Param (
        [string] $AzureDevopsOrganization,
        [string] $AzureDevopsPersonalAccessToken,
        [string] $PoolName
    )

    [string] $Uri = "$AzureDevopsOrganization/_apis/distributedtask/pools?poolname=$PoolName"
    [string] $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "",$AzureDevopsPersonalAccessToken)))
    [hashtable] $AuthHeader = 
    @{ 
        Authorization = "Basic $base64AuthInfo"
    }
    $response = Invoke-RestMethod -Headers $AuthHeader -Uri $Uri
    if (($null -ne $response) -and ($response.count -eq 1))
    {
        return $response.value[0].id
    }
    else {
       return $null
    }
}

Function New-Secret {
    Param ([string] $Name='azdevops', [string] $Url, [string] $Token)

    $devops = kubectl get secret $Name
    if (![string]::IsNullOrEmpty($devops)) {
        $azpUrl = kubectl get secret $Name -o jsonpath='{.data.azp_url}'
        $azpToken = kubectl get secret $Name -o jsonpath='{.data.azp_token}'
        if ($azpUrl -eq $Url -and $azpToken -eq $Token) { return }
        # value are different, delete and re-create secret
        Write-Verbose "Deleting secret '$Name'"
        kubectl delete secret $Name
    }
    Write-Verbose "Creating secret '$Name'"
    kubectl create secret generic $Name `
        --from-literal=azp_url=$Url `
        --from-literal=azp_token=$Token
}

#############################################################
# MAIN Entry Point
#############################################################

# Get PoolId
[string] $poolId = Get-PoolId -AzureDevopsOrganization $AzureDevopsOrganization -AzureDevopsPersonalAccessToken $AzureDevopsPersonalAccessToken -PoolName $PoolName
if ($null -eq $poolId) {
    Write-Output "Pool '$PoolName' not found at '$AzureDevopsOrganization'!"
    exit 1
}
# Check if kubectl is installed
if ($null -eq (Get-Command -name kubectl )) {
    Write-Output "Kubectl command not found!"
    exit 1
}
# Test for Deployment Manifest
if (!(Test-Path -Path $DeploymentFile)) {
    Write-Output "$DeploymentFile not found!"
    exit 1
}
# Create Secret in Kubernetes
if (![string]::IsNullOrEmpty($AzureDevopsOrganization) -and ![string]::IsNullOrEmpty($AzureDevopsPersonalAccessToken)) {
    New-Secret -Name "azdevops" -Url $AzureDevopsOrganization -Token $AzureDevopsPersonalAccessToken
}

(Get-Content $DeploymentFile) -replace ":windows", ":$RepoTag" -replace "<poolId>",$poolId | kubectl apply -f -

