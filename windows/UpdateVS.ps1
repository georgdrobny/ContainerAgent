[CmdLetBinding()]
Param(
    [switch] $Reboot = $false
)

[hashtable] $skuList = @{
    "Community" = "vs_community.exe";
    "Professional" = "vs_professional.exe";
    "Enterprise" = "vs_enterprise.exe"
}

#region Internal Functions
function Get-Bootstapper {
    Param(
        $setupInstance
    )
    
    # Create Temporary directory
    [string] $bootstapperPath = Join-Path -Path $ENV:Temp -ChildPath "VS_Bootstapper"
    New-Item -Path $bootstapperPath -ItemType Directory -Force | Out-Null

    # Download Boostrapper
    [string] $SKU = ($setupInstance.Product.Id -split "\.")[-1]
    [string] $bootstrapperUri = "https://aka.ms/vs/{0}/release/{1}" -f $setupInstance.InstallationVersion.Major, $skuList[$SKU]
    $bootstapperPath = Join-Path -Path $bootstapperPath -ChildPath $skuList[$SKU]
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -UseBasicParsing -Uri $bootstrapperUri -OutFile $bootstapperPath
    return $bootstapperPath
}
function Install-VisualStudio {
    Param(
        $setupInstance,
        [string] $bootstrapper
    )

    $starttime = [datetime]::Now

    Write-Host "Updating $($setupInstance.DisplayName)"
    Write-Host "Start-Time: $starttime"
    Write-Host "Reboot Allowed: $Reboot"
    
    [System.Diagnostics.Process] $proc = [System.Diagnostics.Process]::Start($bootstrapper, "--update --quiet --wait")
    $proc.WaitForExit();
    
    # If reboot is allowed call the update without --norestart
    if ($Reboot)
    {
        $proc = [System.Diagnostics.Process]::Start($bootstrapper, "update --installPath ""$InstallPath"" --quiet --wait")
    }
    else
    {
        $proc = [System.Diagnostics.Process]::Start($bootstrapper, "update --installPath ""$InstallPath"" --quiet --wait --norestart")
    }
    $proc.WaitForExit();
    
    $endtime = [datetime]::Now
    
    $errors = Get-ChildItem $env:Temp\*dd_setup_*errors*.log | Where-Object { ($_.CreationTime -ge $starttime) -and  ($_.Length -gt 0) }
    if (($proc.ExitCode -eq 0) -and ($errors.Count -eq 0))
    {
        Write-Host "Update of '$($setupInstance.DisplayName)' successfully completed. Elapsed Time $($endtime - $starttime)" -ForegroundColor Green
    }
    else 
    {
        if ($errors.Count -eq 0)
        {
            Write-Host "Update of '$($setupInstance.DisplayName)' finished. Elapsed Time $($endtime - $starttime)" -ForegroundColor Green
            Write-Host "Exit Code = $($proc.ExitCode)" -ForegroundColor Yellow
            if ($proc.ExitCode -eq 3010)
            {
                $result = Read-Host -Prompt "A restart is required. Do you want to restart now? Y(es), (No) [Y]"
                if ([string]::IsNullOrEmpty($result) -or ($result -eq "Y" ))
                {
                    Restart-Computer -Force
                }
            }
        }
        else 
        {
            Write-Host "Update failed. " -ForegroundColor Red
            Write-Host "Please Check:" -ForegroundColor Red
            Write-Host $errors -ForegroundColor Red
            exit 2
        }
    }
}
#endregion

####################################################################
# MAIN ENTRY POINT
####################################################################

# Check if VS Setup Powershell Module is installed.
if ($null -eq (Get-Module -Name VSSetup -ListAvailable)) {
    Write-Host "Installing Powershell Module 'VSSetup' into the user sope" -ForegroundColor Yellow
    Install-Module -Name VSSetup -Scope CurrentUser
}
# Determining Visual Studio Installation
$setupInstances = Get-VSSetupInstance 
if (($null -eq $setupInstances) -or ($setupInstances.Count -eq 0)) {
    Write-Host "No Version of Visual Studio is installed!" -ForegroundColor Red
    exit 1
}
# Update Visual Studio 
foreach($setupInstance in $setupInstances) {
    Write-Host "Starting Unattended Update of '$($setupInstance.DisplayName)'" -ForegroundColor Green 
    [string] $InstallPath = $setupInstance.InstallationPath
    Write-Host "Downloading $($setupInstance.DisplayName) Setup Bootstrapper"
    [string] $bootstrapper = Get-Bootstapper -setupInstance $setupInstance
    Install-VisualStudio -setupInstance $setupInstance -bootstrapper $bootstrapper
}




 
