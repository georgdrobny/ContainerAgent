Param(
    [Parameter()]    
    [string] $LayoutPath = 'C:\VS2017BuildToolsInstall'
)

$bootstrapper = Join-Path -Path $LayoutPath -ChildPath vs_buildtools.exe
if (!(Test-Path $bootstrapper))
{
    Write-Error "Bootstrapper $bootstrapper does not exist!"
    return 1
}

$starttime = [datetime]::Now
Write-Output "Starting Unattended Install of Visual Studio 2017 BuildTools"


Start-Process -Wait -FilePath $bootstrapper -ArgumentList `
'--passive', '--wait', '--noweb', `
'--all', `
'--remove Microsoft.VisualStudio.Component.Windows10SDK.10240', `
'--remove Microsoft.VisualStudio.Component.Windows10SDK.10586', `
'--remove Microsoft.VisualStudio.Component.Windows10SDK.14393', `
'--remove Microsoft.VisualStudio.Component.Windows81SDK' `

$endtime = [datetime]::Now

$errors = Get-ChildItem $env:Temp\*dd_setup_*errors*.log | Where-Object { ($_.CreationTime -ge [datetime]::Today) -and  ($_.Length -gt 0) }
if ($errors.Count -eq 0)
{
    Write-Output "Installation Successfully completed. Elapsed Time $($endtime - $starttime)"
}
else 
{
   Write-Output "Installation failed. Elapsed Time $($endtime - $starttime)"
   Write-Output "Please Check:"
   Write-Output $errors
}
