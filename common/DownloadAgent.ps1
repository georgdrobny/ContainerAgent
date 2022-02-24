[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $AzureDevopsOrganization,
    [Parameter(Mandatory=$true)]
    [string] $AzureDevopsPersonalAccessToken,
    [Parameter(Mandatory=$true)]
    [string] $DestinationDirectory
)

enum Platform { 
    Unknown
    Linux
    MacOS
    Windows
}

[string] $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $AzureDevopsPersonalAccessToken)))
[hashtable] $AuthHeader = @{ Authorization = "Basic $base64AuthInfo" }
[string] $Uri = [string]::Empty
[Platform] $Platform = [Platform]::Unknown

if ($IsLinux) { $Platform = [Platform]::Linux }
elseif ($IsMacOS) { $Platform = [Platform]::MacOS }
elseif ($IsWindows) { $Platform = [Platform]::Windows }

switch ($Platform) {
    Linux { $Uri = "$AzureDevopsOrganization/_apis/distributedtask/packages/agent?platform=linux-x64" }
    MacOS { $Uri = "$AzureDevopsOrganization/_apis/distributedtask/packages/agent?platform=osx-x64" }
    Windows { $Uri = "$AzureDevopsOrganization/_apis/distributedtask/packages/agent?platform=win-x64" }
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
[string] $agentPackage = Join-Path $DestinationDirectory $agentList.value[0].filename
[string] $agentVersion =  "{0}.{1}.{2}" -f $agentList.value[0].version.major, $agentList.value[0].version.minor, $agentList.value[0].version.patch

if (!(Test-Path $DestinationDirectory -ErrorAction SilentlyContinue)) {
    new-Item -ItemType Directory -Path $DestinationDirectory | Out-Null
}

$ProgressPreference = 'SilentlyContinue'

Write-Host "Downloading Azure Pipelines agent for $Platform Version $AgentVersion ..." -ForegroundColor Cyan
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -UseBasicParsing -Uri $agentList.value[0].downloadUrl -OutFile $agentPackage
if ($IsMacOS -or $IsWindows) { Unblock-File $agentPackage }
Write-Host "Finshed Downloading Azure Pipelines agent" -ForegroundColor Green
Return $agentPackage
