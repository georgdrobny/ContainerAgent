<#
    Launch the Azure Pipeline Agent
    This script assumes the agent configuration is set trough Environment Variables

    VSTS_AGENT_INPUT_URL=https://dev.azure.com/<org>
    VSTS_AGENT_INPUT_AUTH=<negotiate>|<pat>|<integrated>|<alt>
    VSTS_AGENT_INPUT_TOKEN=<tokenforPAT>
    VSTS_AGENT_INPUT_POOL=<poolname>
    VSTS_AGENT_INPUT_AGENT=<agentname> 
    RUN_ONCE=<bool>

    NOTE: If the agent is already preinstalled in the image, the script will not download the agent
    If the file config.cmd exists the script assumes that the agent is preinstalled.
#>
[CmdletBinding()]
Param()

# Workaround for Bug in NerdCtl where the path is wrongly set on Windows
if ($env:PATH -eq "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin") {
    Write-Host "Correcting Path (workaround)" -ForegroundColor Yellow
    $Env:PATH = "C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin;C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0\;C:\Windows\System32\OpenSSH\;C:\Program Files\dotnet\;C:\Users\ContainerAdministrator\AppData\Local\Microsoft\WindowsApps;C:\Users\ContainerAdministrator\.dotnet\tools;C:\Program Files\NuGet;C:\Program Files (x86)\Microsoft Visual Studio\2022\TestAgent\Common7\IDE\CommonExtensions\Microsoft\TestWindow;C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\amd64;C:\Program Files (x86)\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools;C:\Program Files (x86)\Microsoft SDKs\ClickOnce\SignTool;"
}

if ([string]::IsNullOrEmpty($ENV:VSTS_AGENT_INPUT_URL)) {
    Write-Error "Missing Azure DevOps URL!"
    exit 1
}

if ([string]::IsNullOrEmpty($ENV:VSTS_AGENT_INPUT_TOKEN)) {
    Write-Error "Missing Azure DevOps Token!"
    exit 1
}

[bool] $skipDownload = $false
if (Test-Path .\config.cmd) {
    Write-Host "Agent is pre-installed, skipping download..." -ForegroundColor Yellow
    $skipDownload = $true
}

[string] $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $ENV:VSTS_AGENT_INPUT_TOKEN)))
[hashtable] $AuthHeader = @{ Authorization = "Basic $base64AuthInfo" }
[string] $Uri = "$ENV:VSTS_AGENT_INPUT_URL/_apis/distributedtask/packages/agent?platform=win-x64"

if (!$skipDownload) {
    Write-Host "Determining matching Azure Pipelines agent..." -ForegroundColor Cyan
    [int] $retry = 0
    while ($true) {
        try {
            $rsp = Invoke-WebRequest -uri $Uri -UseBasicParsing -Headers $AuthHeader
            if ($rsp.StatusCode -ne 200) {
                Write-Error "Could not determine a matching Azure Pipelines agent - check that account '$ENV:VSTS_AGENT_INPUT_URL' is correct and the token is valid for that account"
                exit 1
            }
            break
        } 
        catch {
            Write-Host "Failed to determine a matching Azure Pipelines agent! Retrying..."
            $retry++
            if ($retry -ge 3) {
                Write-Error "Could not determine a matching Azure Pipelines agent - check that account '$ENV:VSTS_AGENT_INPUT_URL' is correct and the token is valid for that account"
                exit 1
            }
            Start-Sleep -Seconds 5
        }
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
}

try
{
    Write-Host "Configuring Azure Pipelines agent..." -ForegroundColor Cyan
    .\config.cmd --unattended --replace --acceptTeeEula 

    # if you just want to run one job, pass --once flag to the .\run.cmd
    # like .\run.cmd --once, the agent will run one job and then terminate
    # If the agent terminates after --once it will also de-register the agent from the pool.
    if (([string]::IsNullOrEmpty($ENV:RUN_ONCE)) -or ($ENV:RUN_ONCE -eq $False)) {
        Write-Host "Running Azure Pipelines agent..." -ForegroundColor Cyan
        .\run.cmd
    }
    else {
        Write-Host "Running Azure Pipelines agent once..." -ForegroundColor Cyan
        .\run.cmd --once
    }
}
finally
{
    Write-Host "Cleanup. Removing Azure Pipelines agent..." -ForegroundColor Cyan
    .\config.cmd remove --unattended 
}