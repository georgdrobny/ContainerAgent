[CmdLetBinding()]
Param(
    [Parameter()]
    [string] $WorkingDir = "C:\Temp\BuildAgentImage",
    [Parameter()]
    [string] $SourceDir = $PWD,
    [Parameter()]
    [string] $BaseImage = "mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-ltsc2019",
    [Parameter()]
    [string] $AgentImage = "containerdemos.azurecr.io/pipeline-agent:windows",
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

# Validate Input Parameters 
[string] $DockerFile = [string]::Empty
[string] $AgentLauncher = [string]::Empty
ValidateParameters

# Copy needed files to working Directory
$DockerFile = Copy-Item -Path $DockerFile -Destination $WorkingDir -PassThru
Copy-Item $AgentLauncher -Destination $WorkingDir | Out-Null

# Build Agent Base Image
try {
    Push-Location $WorkingDir
    Write-Output "Building $AgentImage Image from $BaseImage..."
    Docker build --build-arg BASE=$BaseImage -t $AgentImage -f $DockerFile . 
    if ($PushImage.IsPresent)
    {
        Write-Output "Pushing Image $($AgentImage)"
        Docker push $AgentImage
    }
}
finally {
    Pop-Location
}

Write-Output "Done building image $AgentImage"
#endregion
