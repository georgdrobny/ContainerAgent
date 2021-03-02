param(
    [string] $AzureDevopsOrganization,
    [string] $AzureDevopsPersonalAccessToken,
    [string] $DeploymentFile = '.\aks-agent.yml'

)

if ($null -eq (Get-Command -name kubectl )) {
    Write-Output "Kubectl command not found!"
    exit 1
}

if (!(Test-Path -Path $DeploymentFile)) {
    Write-Output "$DeploymentFile not found!"
    exit 1
}

if (![string]::IsNullOrEmpty($AzureDevopsOrganization)) {
    kubectl create secret generic azdevops `
        --from-literal=azp_url=$AzureDevopsOrganization `
        --from-literal=azp_token=$AzureDevopsPersonalAccessToken
}

kubectl apply -f $DeploymentFile