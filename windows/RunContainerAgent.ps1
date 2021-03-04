Param(
    [string] $AzureDevOpsOrg="https://dev.azure.com/drobny",
    [string] $PersonalAccessToken=$ENV:ADOPAT,
    [Parameter(Mandatory=$true)]
    [string] $AgentName,
    [string] $PoolName = 'Container',
    [string] $ImageName = 'containerdemos.azurecr.io/pipeline-agent:windows',
    [switch] $Interactive,
    [switch] $RunOnce,
    [hashtable] $VolumeMount
)

# Docker Installed?
 if ($null -eq (Get-Command Docker))
 {
     Throw "Docker for Windows is not installed!"
 }
 # Volumne Mounting
 [string[]] $volumes = @()
  if ($null -ne $VolumeMount) {
    foreach($entry in $VolumeMount.GetEnumerator()) {
        $volumes += "-v $($entry.Key):$($entry.Value)"
    }
 }
 # Interactive Mode
 if ($Interactive.IsPresent) {
    [string[]] $argList = @( `
    "run", "-it", "--rm", "--name $AgentName", `
    "-e VSTS_AGENT_INPUT_URL=$AzureDevOpsOrg", `
    "-e VSTS_AGENT_INPUT_AUTH=pat", `
    "-e VSTS_AGENT_INPUT_TOKEN=$PersonalAccessToken", `
    "-e VSTS_AGENT_INPUT_POOL=$PoolName", `
    "-e VSTS_AGENT_INPUT_AGENT=$AgentName")
    if ($RunOnce.IsPresent) {
        $argList += "-e RUN_ONCE=True"
    }
    if ($volumes.Count -ne 0) {
        $argList += $volumes
    }
    $argList += @($ImageName, `
    "PowerShell")
    Start-Process docker -ArgumentList $argList 
 }
 else {
    [string[]] $argList = @( `
    "run", "-d", "--rm", "--name $AgentName", `
    "-e VSTS_AGENT_INPUT_URL=$AzureDevOpsOrg", `
    "-e VSTS_AGENT_INPUT_AUTH=pat", `
    "-e VSTS_AGENT_INPUT_TOKEN=$PersonalAccessToken", `
    "-e VSTS_AGENT_INPUT_POOL=$PoolName", `
    "-e VSTS_AGENT_INPUT_AGENT=$AgentName")
    if ($RunOnce.IsPresent) {
        $argList += "-e RUN_ONCE=True"
    }
    if ($volumes.Count -ne 0) {
        $argList += $volumes
    }
    $argList += $ImageName
    Start-Process docker -ArgumentList $argList -NoNewWindow
}

