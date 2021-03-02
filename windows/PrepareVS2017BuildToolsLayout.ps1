Param(
    [Parameter()]    
    [string] $LayoutPath = 'C:\VS2017BuildToolsInstall'
)

[hashtable] $skuList = @{
    "Community" = "vs_community.exe";
    "Professional" = "vs_professional.exe";
    "Enterprise" = "vs_enterprise.exe";
    "BuildTools" = "vs_buildtools.exe"
}

[string] $SKU = "BuildTools"

function Get-Bootstapper
{
    Param(
        [Parameter()]
        [ValidateSet('Community','Professional','Enterprise', 'BuildTools')]
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

[datetime] $start = [datetime]::Now
Write-Output "Creating Visual Studio 2017 Build Tools Offline Layout on $LayoutPath"
Write-Output "Start-Time: $starttime"

Write-Output "Downloading Visual Studio 2017 ($SKU) Bootstrapper"
[string] $bootstrapper = Get-Bootstapper -SKU $SKU

Write-Output "Building Offline Layout for Visual Studio 2017 ($SKU)"
Start-Process -Wait -FilePath $bootstrapper -ArgumentList `
"--layout $LayoutPath", 
'--lang en-US', `
'--all'

$end = [datetime]::Now
Write-Output "Finished, Elapsed $($end - $start)"