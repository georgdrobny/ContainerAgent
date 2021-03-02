# Container Agent
Tools for creating a "containerized" Build/Release agent for Azure DevOps / Azure DevOps Server 

## Windows
On Windows you can create a Container Image based on:

* Base Image with Visual Studio 2017 preinstalled (See Instructions below)
* Any publically available image like
    * [microsoft/dotnet](https://hub.docker.com/r/microsoft/dotnet/) 
    * [microsoft/dotnet-framework-sdk](https://hub.docker.com/r/microsoft/dotnet-framework/)

> If you do not need Visual Studio 2017 in your base image you can skip the next task.
>
> If you want to install Visual Studio 2017 Build Tools into a container image see [here](https://docs.microsoft.com/en-us/visualstudio/install/build-tools-container?view=vs-2017) 

### Prepare a Visual Studio 2017 Base Image
[See also](https://docs.microsoft.com/en-us/visualstudio/install/install-vs-inconsistent-quality-network)

#### Step 1 - Create a local install cache

You must have an internet connection to complete this step. To create a local layout, open a PowerShell console and run the provided script like below:

```PrepareVS2017Layout.ps1 -SKU 'SKU' -Language 'Lang' -LayoutPath 'Path'```

* SKU = 'Community', 'Professional', 'Enterprise' (Default: **'Enterprise'**)
* Language = See list of locales below on this page (Default: **'en-US'**)
* LayoutPath = Path to the Layout Folder (Default: **'C:\VS2017Install'**)

>If you run the script without any parameters it will use the default as listed above.

Example Usage:

```.\PrepareVS2017Layout.ps1 -SKU Enterprise -Language 'de-DE' -LayoutPath C:\VS2017Layout```

If you want to install a language other than English, pass a locale from the list below on this page. Use this [list of the components and workloads available](https://docs.microsoft.com/en-us/visualstudio/install/workload-and-component-ids?view=vs-2017) to further customize your installation cache as necessary.

>[IMPORTANT]
>A complete Visual Studio 2017 layout requires at least 35 GB of disk space and can take some time to download. See [Use command-line parameters to install Visual Studio 2017](https://docs.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2017) for information on how to create a layout with only the components you want to install.

##### List of language locales

| **Language-locale** | **Language** |
| ----------------------- | --------------- |
| cs-CZ | Czech |
| de-DE | German |
| en-US | English |
| es-ES | Spanish |
| fr-FR | French |
| it-IT | Italian |
| ja-JP | Japanese |
| ko-KR | Korean |
| pl-PL | Polish |
| pt-BR | Portuguese - Brazil |
| ru-RU | Russian |
| tr-TR | Turkish |
| zh-CN | Chinese - Simplified |
| zh-TW | Chinese - Traditional |

#### Step 2 - Install Visual Studio from the local cache into a Container
>When you run from a local install cache, setup uses the local versions of each of these files. But if you select components during installation that aren't in the cache, we attempt to download them from the internet.

To ensure that you only install the files you've downloaded, use the same command-line options that you used to create the layout cache. You can use the provided script

```InstallVS2017Layout.ps1 -LayoutPath 'Path'```

* LayoutPath = Path to the Layout Folder (Default: **'C:\VS2017Install'**)

>For convenience you can copy the script into the offline layout folder.

- Launch a new container with the local cache mounted as a volume

   ```docker run -it -v C:/VS2017Install/:C:/VS2017Install microsoft/dotnet-framework:4.7.2-sdk PowerShell```
- In the container PowerShell prompt run the following command:

   ```C:\VS2017Install\InstallVS2017Layout.ps1 -LayoutPath C:\VS2017Install```

> This can take up to 20 minutes depending on your infrastructure.

> If you get an error that a signature is invalid, you must install updated certificates. Open the Certificates folder in your offline cache. Double-click each of the certificate files, and then click through the Certificate Manager wizard. If asked for a password, leave it blank.

- Once the setup is finished, exit from the container by entering `exit` in the PowerShell console.
- Commit the image by runnig `docker commit <containerid> -t tfs/visualstudio:15.7.4 -t tfs/visualstudio:latest`

> 15.7.4 is an example for a specific version tag. You can also use 'latest' as a tag.

> This will take a **lot of time** as the file system changes would need to be commited. Depending on your infrastructure it can be round 20-30 minutes.
> I'm currently working on a Dockerfile automate this process!

After you created the Visual Studio 2017 Base Image you can process with next step.

### Create a Build/Release Agent Image

#### Step 1 - Download Agent Binaries 
You can find the releases for the agent [here](https://github.com/Microsoft/vsts-agent/releases)
In the example below we can use Powershell the download the agent binaries.

```Invoke-WebRequest https://vstsagentpackage.azureedge.net/agent/2.134.2/vsts-agent-win-x64-2.134.2.zip -Outfile C:\Agent\vsts-agent-win-x64-2.134.2.zip```

#### Step 2 - Build Agent Image
You can build the agent image based on the binaries you downloaded in Step 1 and and a base image like **Visual Studio 2017**, [microsoft/dotnet](https://hub.docker.com/r/microsoft/dotnet/) or [microsoft/dotnet-framework-sdk(https://hub.docker.com/r/microsoft/dotnet-framework/) using the provided script
>BuildAgentImage.ps1

See the following example on how to use the script.

- Build a new container image (default image name is tfs/buildagent:AgentVersion)

   ```.\BuildAgentImage.ps1 -AgentPathZip C:\Agent\vsts-agent-win-x64-2.134.2.zip -WorkingDir C:\Temp -Dockerfile .\Dockerfile  ```

   This creates a new container image named **tfs/buildagent:2.134.2** and also applies the **latest** tag. The resulting image is based on the default Visual Studio 2017 Image **tfs/visualstudio2017:latest** created in the previous task.

### Running an instance of the Container Agent

You can any number of instances to any *VSTS Account / TFS Instance* by using the provided script
>RunContainerAgent.ps1

- The example below runs an agent instance against a *TFS Instance* using *username/password* passed in as `[pscredential]`

    ```$cred = Get-Crendential | .\RunContainerAgent.ps1 -TFSUrl 'http://mytfs.com:8080/tfs' -AgentName 'Agent1'```

- The example below runs an agent instance against a *VSTS Instance* using *PersonalAccessToken* 

    ```.\RunContainerAgent.ps1 -TFSUrl 'https://myvsts.visualstudio.com' -PersonalAccessToken <token> -AgentName 'Agent1'```
