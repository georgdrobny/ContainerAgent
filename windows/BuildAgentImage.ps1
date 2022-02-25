[CmdLetBinding()]
Param(
    [Parameter()]
    [string] $WorkingDir = "C:\Temp\BuildAgentImage",
    [Parameter()]
    [string] $SourceDir = $PWD,
    [Parameter()]
    [string] $AgentPackage,
    [Parameter(ParameterSetName = 'Container')]
    [string] $BaseImage = "mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-ltsc2019",
    [Parameter(ParameterSetName = 'Container')]
    [string] $AgentRepository = "pipeline-agent",
    [Parameter(ParameterSetName = 'Container')]
    [string] $Tag = 'windows',
    [Parameter(ParameterSetName = 'Container')]
    [switch] $BuildImage,
    [Parameter()]
    [switch] $Clean
)

#region Functions

Function Remove-QuotesFromPath([string] $Path)
{
    $Path = $Path.Replace('"','')
    $Path = $Path.Replace("'","")
    return $Path
}
Function ValidateParameters()
{
    # Docker Installed?
    if (($BuildImage.IsPresent) -and ($null -eq (Get-Command Docker)))
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
    # Test if AgentPackage was specified and if it exists
    if (!([string]::IsNullOrEmpty($AgentPackage)) -and ($AgentPackage -ne 'none')) {
        if (!(Test-Path $AgentPackage)) {
            Throw "Agent Package $AgentPackage does not exist!"
        }
    }
}
Function CreateOrCleanWorkingDirectory([string] $WorkingDir, [bool] $Clean)
{
    # Create / Clean Working Directory
    $WorkingDir = Remove-QuotesFromPath($WorkingDir)
    if ((Test-Path -Path $WorkingDir) -and ($Clean))
    {
        #Cleanup
        Write-Host "Cleaning $WorkingDir..."
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
CreateOrCleanWorkingDirectory $WorkingDir $Clean.IsPresent

# Validate Input Parameters 
[string] $DockerFile = [string]::Empty
[string] $AgentLauncher = [string]::Empty
ValidateParameters

# Copy needed files to working Directory
$DockerFile = Copy-Item -Path $DockerFile -Destination $WorkingDir -PassThru
Copy-Item $AgentLauncher -Destination $WorkingDir | Out-Null

# Extract AgentPackge if specified to working Directory
if (!([string]::IsNullOrEmpty($AgentPackage)) -and ($AgentPackage -ne 'none')) {
    Write-Host "Expanding $AgentPackage..."
    Expand-Archive -Path $AgentPackage -DestinationPath $WorkingDir
    if ($AgentPackage -match "vsts-agent-win-x64-(\d+.\d+.\d+)") {
        $agentVersion = $matches[1]
        $Tag = "{0}-{1}" -f $Tag, $agentVersion
    }
    Write-Host "Done Expanding"
}

# Build Agent Base Image
if ($BuildImage.IsPresent) {
    try {
        Push-Location $WorkingDir
        [string] $t = "{0}:{1}" -f $AgentRepository, $Tag
        Write-Host "Building $t Image from $BaseImage..."
        Docker build --build-arg BASE=$BaseImage -t $t -f $DockerFile . | Out-Null
    }
    finally {
        Pop-Location
    }
}

Write-Host "Done building image $AgentImage"
return $Tag
#endregion
