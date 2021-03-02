[CmdLetBinding()]
Param(
    # [Parameter(Mandatory=$true)]
    [string] $AgentDownloadUri = "https://vstsagentpackage.azureedge.net/agent/2.166.4/vsts-agent-win-x64-2.166.4.zip",
    # [Parameter(Mandatory=$true)]
    [string] $WorkingDir = "C:\Temp\BuildAgentImage",
    # [Parameter(Mandatory=$true)]
    [string] $SourceDir = $PWD,
    [Parameter()]
    [string] $BaseImage = "mcr.microsoft.com/dotnet/framework/sdk:4.8",
    [Parameter()]
    [string] $AgentImage = "containerdemos.azurecr.io/pipeline-agent-win",
    [Parameter()]
    [switch] $PushImage,
    [Parameter()]
    [switch] $Clean
)

# region Functions

Function Remove-QuotesFromPath([string] $Path)
{
    $Path = $Path.Replace('"','')
    $Path = $Path.Replace("'","")
    return $Path
}
Function ValidateParameters()
{
    [System.IO.FileInfo] $agentInfo = $null
    [string] $agentNamePattern = "(?<name>vsts-agent-win-x64-)(?<version>\d+.\d{1,3}.\d+)"
    [string] $agentVersion = $null

    # Docker Installed?
    if ($null -eq (Get-Command Docker))
    {
        Throw "Docker for Windows is not installed!"
    }
    # Test Dockerfile exists
    $script:DockerFile = Join-Path $SourceDir -ChildPath "Dockerfile"
    if (!(Test-Path -Path $DockerFile))
    {
        Throw "Dockerfile $DockerFile does not exist!"
    }
    # Test Launcherfile exists
    $script:AgentLauncher = Join-Path $SourceDir -ChildPath "LaunchAgent.ps1"
    if (!(Test-Path -Path $AgentLauncher))
    {
        Throw "Agent Launcher $AgentLauncher does not exist!"
    }
    # Test Agent Path exists
    $AgentPathZip = Remove-QuotesFromPath($AgentPathZip)
    if (!(Test-Path -Path $AgentPathZip))
    {
        Throw "Agent Zip '$AgentPathZip' does not exist!"
    }
    # Zip File?
    $agentInfo = Get-Item -Path $AgentPathZip
    if (!($agentInfo.Extension.ToLower() -ne "zip"))
    {
        Throw "File '$AgentPathZip' ist not a .ZIP File!"
    }
    # Correct Naming Syntax
    if (!($agentInfo.Name -match $agentNamePattern))
    {
        Throw "Filename of '$AgentPathZip' invalid! Expected format '$agentNameFormat'"
    }
    # Extract Version Number from Agent
    $agentVersion = $Matches["version"]
    return $agentVersion
}
Function CreateOrCleanWorkingDirectory([string] $WorkingDir, [switch] $Clean)
{
    # Create / Clean Working Directory
    $WorkingDir = Remove-QuotesFromPath($WorkingDir)
    if ((Test-Path -Path $WorkingDir) -and ($Clean.IsPresent))
    {
        #Cleanup
        Remove-Item -Path "$WorkingDir\*" -Recurse -Force | Out-Null
    }
    if (!(Test-Path -Path $WorkingDir))
    {
        #Create     
        New-Item -Path $WorkingDir -ItemType Directory | Out-Null
    }
}
#endregion

#region Main Script

# Clean Working Directory
CreateOrCleanWorkingDirectory $WorkingDir $Clean

# Download Agent Binaries
[uri] $downloadUri = $AgentDownloadUri
[string] $AgentPathZip = Join-Path $WorkingDir $downloadUri.Segments[-1]
if (((Test-Path $AgentPathZip) -and ($Clean.IsPresent)) -or (!(Test-Path $AgentPathZip)))
{
    Invoke-WebRequest -UseBasicParsing -Uri $AgentDownloadUri -OutFile $AgentPathZip
    Unblock-File $AgentPathZip
}

# Validate Input Parameters 
[string] $DockerFile = [string]::Empty
[string] $AgentLauncher = [string]::Empty
[string] $agentVersion = ValidateParameters

# Unzip Agent Binaries
Write-Output "Expanding $AgentPathZip..."
Expand-Archive -Path "$AgentPathZip" -DestinationPath $(Join-Path $WorkingDir "Agent") -Force

# Copy needed files to working Directory
$DockerFile = Copy-Item -Path $DockerFile -Destination $WorkingDir -PassThru
Copy-Item $AgentLauncher -Destination $WorkingDir | Out-Null

# Build Agent Base Image

try {
    Push-Location $WorkingDir
    Write-Output "Building $($AgentImage):$($agentVersion) Image from $BaseImage..."
    Docker build --build-arg BASE=$BaseImage -t "$($AgentImage):$($agentVersion)" -t "$($AgentImage):latest" -f $DockerFile . 
    if ($PushImage.IsPresent)
    {
        Write-Output "Pushing Image $($AgentImage):$($agentVersion)"
        Docker push "$($AgentImage):$($agentVersion)"
        Docker push "$($AgentImage):latest"
    }
}
finally {
    Pop-Location
}

Write-Output "Done building image $($AgentImage):$($agentVersion)"
#endregion
