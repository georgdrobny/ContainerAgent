Param(
    [Parameter()]    
    [string] $LayoutPath = 'C:\VS2017Install'
)

[hashtable] $skuList = @{
    "Community" = "vs_community.exe";
    "Professional" = "vs_professional.exe";
    "Enterprise" = "vs_enterprise.exe"
}

function Get-Bootstapper
{
    Param(
        [string] $BootstapperPath
    )

    if ([string]::Empty -eq $BootstapperPath)
    {
        Throw "Invalid Path!"
    }

    # Check SKU List to find the bootstrapper
    foreach ($boot in $skuList.Values)
    {
        $bootstrapper = Join-Path $BootstapperPath $boot
        if (Test-Path -Path $bootstrapper)
        {
            return $bootstrapper
        }
    }

    Throw "No valid Bootstrapper found!"
}

$starttime = [datetime]::Now
Write-Output "Starting Unattended Install of Visual Studio 2017"

[string] $bootstrapper = Get-Bootstapper -BootstapperPath $LayoutPath

Start-Process -Wait -FilePath $bootstrapper -ArgumentList `
'--quiet', '--wait', '--noweb', `
'--add Microsoft.VisualStudio.Workload.CoreEditor', `
'--add Microsoft.VisualStudio.Workload.Azure', `
'--add Microsoft.VisualStudio.Workload.Data', `
'--add Microsoft.VisualStudio.Workload.ManagedDesktop', `
'--add Microsoft.VisualStudio.Workload.NetCoreTools', `
'--add Microsoft.VisualStudio.Workload.NetWeb', `
'--add Microsoft.VisualStudio.Workload.Node', `
'--add Microsoft.VisualStudio.Component.TestTools.CodedUITest', `
'--add Microsoft.Net.ComponentGroup.4.6.2.DeveloperTools', `
'--add Microsoft.Net.ComponentGroup.4.7.DeveloperTools', `
'--add Microsoft.Net.ComponentGroup.4.7.1.DeveloperTools', `
'--add Microsoft.Net.ComponentGroup.4.7.2.DeveloperTools', `
'--includeRecommended', `
'--remove Microsoft.VisualStudio.Component.Windows10SDK.10240', `
'--remove Microsoft.VisualStudio.Component.Windows10SDK.10586', `
'--remove Microsoft.VisualStudio.Component.Windows10SDK.14393', `
'--remove Microsoft.VisualStudio.Component.Windows81SDK'

[int] $result = $LASTEXITCODE

$endtime = [datetime]::Now

$errors = Get-ChildItem $env:Temp\*dd_setup_*errors*.log | Where-Object { ($_.CreationTime -ge [datetime]::Today) -and  ($_.Length -gt 0) }
if ($errors.Count -eq 0)
{
    Write-Output "Installation Successfully completed. Elapsed Time $($endtime - $starttime)"
    if ($result -eq 3010)
    {
        Write-Output "Reboot required."
    }
}
else 
{
   Write-Output "Installation failed. Elapsed Time $($endtime - $starttime)"
   Write-Output "Please Check:"
   Write-Output $errors
}
