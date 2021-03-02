param(
    [parameter(Mandatory=$true)]
    [string] $AzureDevopsOrganization,
    [parameter(Mandatory=$true)]
    [string] $AzureDevopsPersonalAccessToken,
    [string] $AgentImage = 'containerdemos.azurecr.io/pipeline-agent:ubuntu-18.04',
    [string] $AgentPool = 'Linux',
    [switch] $Interactive
)

if ($null -eq (Get-Command -name docker )) {
    Write-Output "Docker command not found!"
    exit 1
}

if ($Interactive.IsPresent) {
    docker run -it --rm -e AZP_URL=$AzureDevopsOrganization -e AZP_TOKEN=$AzureDevopsPersonalAccessToken -e AZP_POOL=$AgentPool $AgentImage
}
else {
    docker run --rm -e AZP_URL=$AzureDevopsOrganization -e AZP_TOKEN=$AzureDevopsPersonalAccessToken -e AZP_POOL=$AgentPool $AgentImage
}


