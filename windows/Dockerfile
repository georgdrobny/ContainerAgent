ARG BASE
FROM ${BASE}

ENV VSTS_AGENT_INPUT_URL=https://dev.azure.com
ENV VSTS_AGENT_INPUT_AUTH=pat
ENV VSTS_AGENT_INPUT_POOL=default
ENV VSTS_AGENT_INPUT_AGENT=$COMPUTERNAME 
ENV VSTS_AGENT_INPUT_TOKEN="tokenvalue"
ENV RUN_ONCE=false
ENV AZP_AGENT_DOWNGRADE_DISABLED=true

RUN powershell -Command $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi

WORKDIR /Agent
COPY . /Agent
CMD C:\Windows\System32\WindowsPowershell\V1.0\powershell.exe -File C:\Agent\LaunchAgent.ps1
