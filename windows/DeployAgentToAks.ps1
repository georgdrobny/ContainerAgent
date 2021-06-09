[CmdLetBinding()]
param(
    [string] $AzureDevopsOrganization,
    [string] $AzureDevopsPersonalAccessToken,
    [string] $DeploymentFile = '.\pipelineagent_BuildTools.yml',
    [string] $RepoTag = 'windows'
)

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

if ($null -eq (Get-Command -name kubectl )) {
    Write-Output "Kubectl command not found!"
    exit 1
}

if (!(Test-Path -Path $DeploymentFile)) {
    Write-Output "$DeploymentFile not found!"
    exit 1
}

if (![string]::IsNullOrEmpty($AzureDevopsOrganization) -and ![string]::IsNullOrEmpty($AzureDevopsPersonalAccessToken)) {
    New-Secret -Name "azdevops" -Url $AzureDevopsOrganization -Token $AzureDevopsPersonalAccessToken
}

if ($RepoTag -ne 'windows') {
    (Get-Content $DeploymentFile) -replace ":windows", ":$RepoTag" | kubectl apply -f -
}
else {
    kubectl apply -f $DeploymentFile    
}

