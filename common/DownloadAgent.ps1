#Requires -Version 7

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $AzureDevopsOrganization,
    [Parameter(Mandatory=$true)]
    [string] $AzureDevopsPersonalAccessToken,
    [Parameter(Mandatory=$true)]
    [string] $DestinationDirectory,
    [string] $CustomAgentLocation
)

enum Platform { 
    Unknown
    Linux
    Osx
    Win
}

Function Get-LatestAgent
{
    Param(
        [string] $AzureDevopsOrganization,
        [string] $AzureDevopsPersonalAccessToken,
        [Platform] $Platform
    )

    [string] $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $AzureDevopsPersonalAccessToken)))
    [hashtable] $AuthHeader = @{ Authorization = "Basic $base64AuthInfo" }
    [string] $Uri = [string]::Empty
    
    switch ($Platform) {
        Linux { $Uri = "$AzureDevopsOrganization/_apis/distributedtask/packages/agent?platform=linux-x64" }
        Osx { $Uri = "$AzureDevopsOrganization/_apis/distributedtask/packages/agent?platform=osx-x64" }
        Win { $Uri = "$AzureDevopsOrganization/_apis/distributedtask/packages/agent?platform=win-x64" }
        Default {
            Write-Error "Invalid Platform, exiting!"
            exit 1
        }    
    }
    
    Write-Host "Determining matching Azure Pipelines agent..." -ForegroundColor Cyan
    $rsp = Invoke-WebRequest -uri $Uri -UseBasicParsing -Headers $AuthHeader
    if ($rsp.StatusCode -ne 200) {
        Write-Error "Could not determine a matching Azure Pipelines agent - check that account 'AzureDevopsOrganization' is correct and the token is valid for that account"
        exit 2
    }

    [PSCustomObject] $agentList = ConvertFrom-Json $rsp.content;

    return [pscustomobject]@{
        "filename" = $agentList.value[0].filename
        "version" = "{0}.{1}.{2}" -f $agentList.value[0].version.major, $agentList.value[0].version.minor, $agentList.value[0].version.patch
        "downloadUrl" = $agentList.value[0].downloadUrl
    }
}

Function Get-CustomAgent
{
    Param(
        [string] $CustomAgentLocation,
        [Platform] $Platform
    )

    $loc = $CustomAgentLocation -as [uri]
    if ($loc -eq $Null) {
        Write-Error "Invalid custom agent location $CustomAgentLocation! exiting!"
        exit 3
    }
    if ($loc.Segments[-1] -notmatch "^vsts-agent-(?<platform>\w+)-(?<arch>\w+)-(?<version>\d+.\d+.\d+)") {
        Write-Error "Invalid custom agent location $CustomAgentLocation! exiting!"
        exit 3
    }
    if ($matches["platform"] -ne $Platform) {
        Write-Error "Invalid custom agent platform $CustomAgentLocation! exiting!"
        exit 3
    }

    return [pscustomobject]@{
        "filename" = $loc.Segments[-1]
        "version" = $matches["version"]
        "downloadUrl" = $CustomAgentLocation
    }
}

[Platform] $Platform = [Platform]::Unknown
if ($IsLinux) { $Platform = [Platform]::Linux }
elseif ($IsMacOS) { $Platform = [Platform]::Osx }
elseif ($IsWindows) { $Platform = [Platform]::Win }

[pscustomobject] $agent = $Null
if (([string]::IsNullOrEmpty($CustomAgentLocation)) -or ($CustomAgentLocation.Trim().Length -eq 0)) {
    $agent = Get-LatestAgent $AzureDevopsOrganization $AzureDevopsPersonalAccessToken $Platform
}
else {
    $agent = Get-CustomAgent $CustomAgentLocation $Platform
}

[string] $agentPackage = Join-Path $DestinationDirectory $agent.filename
if (!(Test-Path $DestinationDirectory -ErrorAction SilentlyContinue)) {
    new-Item -ItemType Directory -Path $DestinationDirectory | Out-Null
}

$ProgressPreference = 'SilentlyContinue'
Write-Host "Downloading Azure Pipelines agent for $Platform Version $($agent.version) ..." -ForegroundColor Cyan
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -UseBasicParsing -Uri $agent.downloadUrl -OutFile $agentPackage
if ($IsMacOS -or $IsWindows) { Unblock-File $agentPackage }
Write-Host "Finshed Downloading Azure Pipelines agent" -ForegroundColor Green
Return $agentPackage
