[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $AzureDevopsOrganization,
    [Parameter(Mandatory=$true)]
    [string] $AzureDevopsPersonalAccessToken,
    [Parameter(Mandatory=$true)]
    [string] $DestinationDirectory
)

[string] $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $AzureDevopsPersonalAccessToken)))
[hashtable] $AuthHeader = @{ Authorization = "Basic $base64AuthInfo" }
[string] $Uri = "$AzureDevopsOrganization/_apis/distributedtask/packages/agent?platform=win-x64"

Write-Host "Determining matching Azure Pipelines agent..." -ForegroundColor Cyan
$rsp = Invoke-WebRequest -uri $Uri -UseBasicParsing -Headers $AuthHeader
if ($rsp.StatusCode -ne 200) {
    Write-Error "Could not determine a matching Azure Pipelines agent - check that account 'AzureDevopsOrganization' is correct and the token is valid for that account"
    exit 1
}

[PSCustomObject] $agentList = ConvertFrom-Json $rsp.content;
[string] $agentPackage = Join-Path $DestinationDirectory $agentList.value[0].filename
[string] $agentVersion =  $agentList.value[0].filename

if ($agentVersion -match "vsts-agent-win-x64-(\d+.\d+.\d+)") {
    $agentVersion = $matches[1]
}

if (!(Test-Path $DestinationDirectory -ErrorAction SilentlyContinue)) {
    new-Item -ItemType Directory -Path $DestinationDirectory | Out-Null
}

$ProgressPreference = 'SilentlyContinue'

Write-Host "Downloading Azure Pipelines agent $AgentVersion ..." -ForegroundColor Cyan
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -UseBasicParsing -Uri $agentList.value[0].downloadUrl -OutFile $agentPackage
Unblock-File $agentPackage
Write-Host "Finshed Downloading Azure Pipelines agent" -ForegroundColor Green
Return $agentPackage
