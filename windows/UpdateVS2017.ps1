Param(
    [Parameter()]
    [ValidateSet('Community','Professional','Enterprise')]
    [string] $SKU = "Enterprise",
    [switch] $Reboot = $false
)

[hashtable] $skuList = @{
    "Community" = "vs_community.exe";
    "Professional" = "vs_professional.exe";
    "Enterprise" = "vs_enterprise.exe"
}

function Get-Bootstapper
{
    Param(
        [Parameter()]
        [ValidateSet('Community','Professional','Enterprise')]
        [string] $SKU = "Enterprise"
    )

    # Create Temporary directory
    [string] $bootstapperPath = Join-Path -Path $ENV:Temp -ChildPath "VS_Bootstapper"
    New-Item -Path $bootstapperPath -ItemType Directory -Force | Out-Null

    # Download Boostrapper
    [string] $bootstrapperUri = "https://aka.ms/vs/15/release/{0}" -f $skuList[$SKU]
    $bootstapperPath = Join-Path -Path $bootstapperPath -ChildPath $skuList[$SKU]
    Invoke-WebRequest -UseBasicParsing -Uri $bootstrapperUri -OutFile $bootstapperPath
    return $bootstapperPath
}

function Get-InstallPath
{
    Param(
        [Parameter()]
        [ValidateSet('Community','Professional','Enterprise')]
        [string] $SKU = "Enterprise"
    )

    # Based on SKU get default Path
    [string] $defaultPath = "C:\Program Files (x86)\Microsoft Visual Studio\2017\{0}" -f $SKU
    if (Test-Path -Path $defaultPath)
    {
        return $defaultPath
    }
    else 
    {
        return $null
    }
}

$starttime = [datetime]::Now
Write-Output "Starting Unattended Update of Visual Studio 2017 ($SKU)"

[string] $InstallPath = Get-InstallPath -SKU $SKU
if ([string]::IsNullOrEmpty($InstallPath))
{
    Write-Output "$InstallPath not found! Exiting."
    Exit
}

Write-Output "Downloading Visual Studio 2017 ($SKU) Bootstrapper"
[string] $bootstrapper = Get-Bootstapper -SKU $SKU

Write-Output "Updating Visual Studio 2017 ($SKU)"
Write-Output "Start-Time: $starttime"
Write-Output "Reboot Allowed: $Reboot"

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
    Write-Output "Update Successfully completed. Elapsed Time $($endtime - $starttime)"
}
else 
{
    if ($errors.Count -eq 0)
    {
        Write-Output "Updated finished. Elapsed Time $($endtime - $starttime)"
        Write-Output "Exit Code = $($proc.ExitCode)"
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
        Write-Output "Update failed. "
        Write-Output "Please Check:"
        Write-Output $errors
    }
}
 
