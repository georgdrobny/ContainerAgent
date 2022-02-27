[CmdLetBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [string] $WorkingDir,
    [Parameter()]
    [string] $SourceDir = $PWD,
    [Parameter()]
    [string] $AgentPackage,
    [Parameter(ParameterSetName = 'Container')]
    [string] $AgentRepository = "pipeline-agent",
    [Parameter(ParameterSetName = 'Container')]
    [string] $Tag = 'ubuntu-20.04',
    [Parameter(ParameterSetName = 'Container')]
    [string] $DockerFile = 'dockerfile-ubuntu-2004',
    [Parameter(ParameterSetName = 'Container')]
    [switch] $BuildImage,
    [Parameter()]
    [switch] $Clean
)

#region Functions

Function ValidateParameters()
{
    # Docker Installed?
    if (($BuildImage.IsPresent) -and ($null -eq (Get-Command docker)))
    {
        Throw "Docker for Linux is not installed!"
    }
    # Test Dockerfile exists
    $script:DockerFilePath = Join-Path $SourceDir -ChildPath $DockerFile
    if (!(Test-Path -Path $DockerFilePath))
    {
        Throw "Dockerfile $DockerFilePath does not exist!"
    }
    # Test Launcherfile exists
    $script:AgentLauncher = Join-Path $SourceDir -ChildPath "start.sh"
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
    if ((Test-Path -Path $WorkingDir) -and ($Clean))
    {
        #Cleanup
        Write-Host "Cleaning $WorkingDir..."
        Remove-Item -Path "$WorkingDir" -Recurse -Force | Out-Null
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
[string] $DockerFilePath = [string]::Empty
[string] $AgentLauncher = [string]::Empty
ValidateParameters

# Copy needed files to working Directory
$DockerFilePath = Copy-Item -Path $DockerFilePath -Destination $WorkingDir -PassThru
Copy-Item $AgentLauncher -Destination $WorkingDir | Out-Null

# Extract AgentPackge if specified to working Directory
if (!([string]::IsNullOrEmpty($AgentPackage)) -and ($AgentPackage -ne 'none')) {
    Write-Host "Expanding $AgentPackage..."
    tar -xz -f $AgentPackage -C $WorkingDir
    if ($AgentPackage -match "vsts-agent-linux-x64-(\d+.\d+.\d+)") {
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
        docker build --build-arg BASE=$BaseImage -t $t -f $DockerFilePath . 
    }
    finally {
        Pop-Location
    }
}

Write-Host "Done building image $AgentImage"
return $Tag
#endregion
