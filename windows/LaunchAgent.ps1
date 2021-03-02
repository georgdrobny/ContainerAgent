<#
    Launch the Azure Pipeline Agent
    This script assumes the agent configuration is set trough Environment Variables

    VSTS_AGENT_INPUT_URL=https://dev.azure.com/<org>
    VSTS_AGENT_INPUT_AUTH=<negotiate>|<pat>|<integrated>|<alt>
    VSTS_AGENT_INPUT_TOKEN=<tokenforPAT>
    VSTS_AGENT_INPUT_POOL=<poolname>
    VSTS_AGENT_INPUT_AGENT=<agentname> 
#>
[CmdletBinding()]
Param()

if ([string]::IsNullOrEmpty($ENV:VSTS_AGENT_INPUT_URL)) {
    Write-Error "Missing Azure DevOps URL!"
    exit 1
}

if ([string]::IsNullOrEmpty($ENV:VSTS_AGENT_INPUT_TOKEN)) {
    Write-Error "Missing Azure DevOps Token!"
    exit 1
}

[string] $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $ENV:VSTS_AGENT_INPUT_TOKEN)))
[hashtable] $AuthHeader = @{ Authorization = "Basic $base64AuthInfo" }
[string] $Uri = "$ENV:VSTS_AGENT_INPUT_URL/_apis/distributedtask/packages/agent?platform=win-x64"

Write-Host "Determining matching Azure Pipelines agent..." -ForegroundColor Cyan
$rsp = Invoke-WebRequest -uri $Uri -UseBasicParsing -Headers $AuthHeader
if ($rsp.StatusCode -ne 200) {
    Write-Error "Could not determine a matching Azure Pipelines agent - check that account '$ENV:VSTS_AGENT_INPUT_URL' is correct and the token is valid for that account"
    exit 1
}

[PSCustomObject] $agentList = ConvertFrom-Json $rsp.content;
[string] $agentPackage = $agentList.value[0].filename
$ProgressPreference = 'SilentlyContinue'

Write-Host "Downloading and installing Azure Pipelines agent..." -ForegroundColor Cyan
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -UseBasicParsing -Uri $agentList.value[0].downloadUrl -OutFile $agentPackage
Unblock-File $agentPackage
Expand-Archive -Path $agentPackage -DestinationPath .\
Remove-Item -Path $agentPackage -Force

try
{
    Write-Host "Configuring Azure Pipelines agent..." -ForegroundColor Cyan
    .\config.cmd --unattended --replace --acceptTeeEula 

    Write-Host "Running Azure Pipelines agent..." -ForegroundColor Cyan
    .\run.cmd
}
finally
{
    Write-Host "Cleanup. Removing Azure Pipelines agent..." -ForegroundColor Cyan
    .\config.cmd remove --unattended 
}