param(
    [string] $AzureDevopsOrganization,
    [string] $AzureDevopsPersonalAccessToken,
    [string] $DeploymentFile = '.\pipelineagent_BuildTools.yml'
)

if ($null -eq (Get-Command -name kubectl )) {
    Write-Output "Kubectl command not found!"
    exit 1
}

if (!(Test-Path -Path $DeploymentFile)) {
    Write-Output "$DeploymentFile not found!"
    exit 1
}

if (![string]::IsNullOrEmpty($AzureDevopsOrganization) -and ![string]::IsNullOrEmpty($AzureDevopsPersonalAccessToken)) {
    kubectl create secret generic azdevops `
        --from-literal=azp_url=$AzureDevopsOrganization `
        --from-literal=azp_token=$AzureDevopsPersonalAccessToken
}

kubectl apply -f $DeploymentFile