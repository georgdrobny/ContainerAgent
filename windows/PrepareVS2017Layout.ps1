Param(
    [Parameter()]
    [ValidateSet('Community','Professional','Enterprise')]
    [string] $SKU = "Enterprise",
    [Parameter()]
    [string] $Language = "en-US",
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
        [Parameter()]
        [ValidateSet('Community','Professional','Enterprise')]
        [string] $SKU = "Enterprise",
        [string] $BootstapperPath
    )

    if ([string]::Empty -eq $BootstapperPath)
    {
        Throw "Invalid Path!"
    }

    # Download Boostrapper
    [string] $bootstrapperUri = "https://aka.ms/vs/15/release/{0}" -f $skuList[$SKU]
    $BootstapperPath = Join-Path -Path $bootstapperPath -ChildPath $skuList[$SKU]
    Invoke-WebRequest -UseBasicParsing -Uri $bootstrapperUri -OutFile $BootstapperPath
    return $BootstapperPath
}

[datetime] $start = [datetime]::Now
Write-Output "Creating Visual Studio 2017 ($SKU) Offline Layout on $LayoutPath"

if (!(Test-Path -Path $LayoutPath))
{
    Write-Output "Creating $LayoutPath"
    New-Item -Path $LayoutPath -ItemType Directory -Force | Out-Null
}

Write-Output "Downloading Visual Studio 2017 ($SKU) Bootstrapper"
[string] $bootstrapper = Get-Bootstapper -SKU $SKU -BootstapperPath $LayoutPath

Start-Process -Wait -FilePath $bootstrapper -ArgumentList `
"--layout $LayoutPath", 
"--lang $Language", `
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
'--includeRecommended'

[int] $result = $LASTEXITCODE

$end = [datetime]::Now
Write-Output "Finished, Elapsed $($end - $start)"

switch ($result) {
    3010
        { Write-Output "Reboot Required." }
    0 
        { Write-Output "Success." } 
    Default 
        { Write-Output "Error, ExitCode: $result" }
}

