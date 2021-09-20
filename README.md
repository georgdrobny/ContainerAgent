# Container Agent
Tools for creating a "containerized" Azure Pipelines agent for Azure DevOps Services / Azure DevOps Server 
The tools available in this repository are designed to build a container image for **Windows** or **Linux**.
## Windows
For Windows you can create a Container Image based on:

* Image with Visual Studio 2017/2019 preinstalled 
* Any publically available image like
    * [microsoft/dotnet](https://hub.docker.com/r/microsoft/dotnet/) 
    * [microsoft/dotnet-framework-sdk](https://hub.docker.com/_/microsoft-dotnet-framework-sdk/)

>  [microsoft/dotnet-framework-sdk](https://hub.docker.com/_/microsoft-dotnet-framework-sdk/) has the following components in the image:
>* .NET Framework Runtime
>* Visual Studio Build Tools
>* Visual Studio Test Agent
>* NuGET CLI
>* .NET Framwework Targeting Packs
>* ASP.NET Web Targets 

### Create an Azure Pipelines Agent Image with Visual Studio pre-installed
>The [microsoft/dotnet-framework-sdk](https://hub.docker.com/_/microsoft-dotnet-framework-sdk/) has **Visual Studio Build Tools** already pre-installed. If that's sufficient for you see **Create an Azure Pipelines Agent Image** below.

If you need to have Visual Studio in your Azure Pipelines agent image, you can build a Azure Pipelines container image with Visual Studio 2019/2017 Enterprise/Professional installed in the image.

To build the image, a YAML pipeline is included in this repo. See [build-VSImage.yml](build-VSImage.yml)
The pipeline can build either a **Visual Studio 2017 or 2019** image. You can choose between **Professional and Entreprise** Edition. Which Visual Studio components are installed in the base base is defined in the dockerfiles provided in this repo. You can customize it for your needs. 
* [VS2017 Enterprise Dockerfile](windows/VS2017Container/Dockerfile.Enterprise) 
* [VS2017 Professional Dockerfile](windows/VS2017Container/Dockerfile.Professional) 
* [VS2019 Enterprise Dockerfile](windows/VS2019Container/Dockerfile.Enterprise) 
* [VS2019 Professional Dockerfile](windows/VS2019Container/Dockerfile.Professional) 

The dockerfiles provided with this repo will create a ready to use Azure Pipelines Agent container image with Visual Studio pre-installed. The agent binaries will always be downloaded then the agent container instance starts.

### Create an Azure Pipelines Agent Image
You can create an agent image with a specific version of the  Azure Pipelines Agent or without any agent. If you dont provide a specific version of the Azure Pipeline Agent, the default behaviour is the container will try to download the latest version of the agent based on the configured Azure DevOps Organization / Collection.

#### **Step 1 - Download Azure Pipelines Agent Binaries (Optional)**
If you need to pre-install a specific version of the agent into the container image you need to donload the necassary version of the agent binaries first.

You can find the releases for the Azure Pipelines Agent [here](https://github.com/Microsoft/vsts-agent/releases)
In the example below we can use Powershell the download the agent binaries.

```Invoke-WebRequest https://vstsagentpackage.azureedge.net/agent/2.184.2/vsts-agent-win-x64-2.184.2.zip -Outfile C:\Agent\vsts-agent-win-x64-2.184.2.zip```

For your convenience you can download the supported Azure Pipelines Agent for your Azure DevOps Organization / Collection with the provided PowerShell script. 
>[DownloadAgent.ps1](windows/DownloadAgent.ps1)

See the following example on how to use the script. (You need to change to **.\windows** directory first)

```$package = .\DownloadAgent.ps1 -AzureDevOpsOrganization https://dev.azure.com/<org> -AzureDevOpsPersonalAccessToken <pat> -DestinationDirectory C:\Agent```

The script will download the agent and store the package zip in the destitnation folder. the script will return the full path to the downloaded package file and you can store it in a PowerShell variable for later use.

#### **Step 2 - Build Azure Pipelines Agent Image**
You can build the Azure Pipelines Agent image based on the binaries you downloaded in Step 1 and a base image like **Visual Studio** or [microsoft/dotnet-framework-sdk](https://hub.docker.com/_/microsoft-dotnet-framework-sdk/) using the provided script
>[BuildAgentImage.ps1](windows/BuildAgentImage.ps1)

See the following examples on how to use the script. (You need to change to **.\windows** directory first)

**Requires Docker for Windows on you local machine!**

- Example 1: Build a new Azure Pipelines Agent container image based on the default base image without agent binaries pre-installed. 

   ```.\BuildAgentImage.ps1 -BuildImage```

   This creates a new container image named **pipeline-agent:windows** on your local machine. The resulting image is based on the default [microsoft/dotnet-framework-sdk](https://hub.docker.com/_/microsoft-dotnet-framework-sdk/) image.

- Example 2: Build a new Azure Pipelines Agent container with a specific Azure Pipelines Agent version pre-installed. (See **Step1** on how to donwload a specific Azure Pipelines Agent version)

   ```.\BuildAgentImage.ps1 -AgentPackage C:\Agent\vsts-agent-win-x64-2.184.2.zip -BuildImage ```

   This creates a new container image named **pipeline-agent:windows-2.184.2** on your local machine. The  resulting image is based on the default [microsoft/dotnet-framework-sdk](https://hub.docker.com/_/microsoft-dotnet-framework-sdk/) image.

> Instead of building the images locally you can use the provided YAML pipeline [build-AgentImage-Windows.yml](build-AgentImage-Windows.yml) to automatically build and publish your Azure Pipelines Agent image.

### Running instances of the Azure Pipelines Container Agent in Docker

You can run any number of instances to any Azure DevOps Organization / Collection by using the provided script
>[RunContainerAgent.ps1](windows/RunContainerAgent.ps1)

See the following examples on how to use the script. (You need to change to **.\windows** directory first)

- Example 1: Run an Azure Pipelines Agent container instance against an Azure DevOps organization

    ```.\RunContainerAgent.ps1 -AzureDevOpsOrg 'https://dev.azure.com/<org>' -PersonalAccessToken <pat> -AgentName 'Agent1' -ImageName pipeline-agent:windows```

    This command creates a container instance of an Azure Pipelines Agent locally. The instance will register itself at **https://dev.azure.com/org** in an agent pool named **Container** with the Agent Name of **Agent1** It will run continously.

- Example 2: Run an Azure Pipelines Agent container instance against an Azure DevOps Server Collection

    ```.\RunContainerAgent.ps1  -AzureDevOpsOrg 'https://tfs.drobny.net/DefaultCollection' -PersonalAccessToken <pat> -AgentName 'Agent1' -PoolName Default -ImageName pipeline-agent:windows-2.184.2```

    This This command creates a container instance of an Azure Pipelines Agent locally. The instance will register itself at **https://tfs.drobny.net/DefaultCollection** in an agent pool named **Default** with the Agent Name of **Agent1**. It will run continously.
>NOTE: The personal access token provided needs to have permission to register an agent. The agent pool (Default:**Container**) needs to exist before running the container instance.
### Running instances of the Azure Pipelines Container Agent in Kubernetes
You can run the Azure Pipelines Container Agent in any Kubernetes Cluster (Bare Metal, AKS, Rancher, OKD) by using the provided script.
>[DeployAgentToAks.ps1](windows/DeployAgentToAks.ps1)
The script is using **kubectl** to deploy an Azure Pipelines Agent to Kubernetes. 

>NOTE: To run an instance of the Windows Azure Pipelines Container Agent you need to have an mixed mode Kuberetes Cluster with **Windows Worker Nodes** (NodePool) running. The machines in the node pool need to run **Windows Server 2019** or later.  

See the following examples on how to use the script. (You need to change to **.\windows** directory first)

- Example 1: Deploy an Azure Pipelines Agent to a Kuberntetes Cluster

   ```.\DeployAgentToAks.ps1 -AzureDevOpsOrganization 'https://dev.azure.com/<org>' -AzureDevOpsPersonalAccessToken <pat> -DeploymentFile .\pipelineagent_BuildTools.yml```

   This command deploys an Auzure Pipelines Agent tp the default Kubernetes cluster context. The script creates a Kubernetes Secret named **azdevops** which contains the URL to the Azure DevOps Organization / Collection and the personal access tolen. The provided deployment manifest [pipelineagent_BuildTools.yml](windows/pipelineagent_BuildTools.yml) contains a sample deployment as a Stateful Set with 1 replica and a container image stored in an Azure Container Registry. The Azure Pipelines pool is **Container**.

   The pods are registered with a **RunOnce** flag (defined in the deployment manifest) which will terminate the agent instance after running one job. The Kubernetes scheduler will restart the pod after it terminates to get a fresh instance of the container.

#### Autoscaling Azure Pipelines Container Agent with KEDA
If you run your Azure Pipelines Container in Kubernetes, you scale the number of Agents dynamically based on the number of requests waiting in associated Pool/Queue by using [KEDA](https://keda.sh/).

Deploy KEDA to your Kuberntes Cluster based on your preferred Method. 

- Example Deploying KEDA with a manifest

    ```kubectl apply -f https://github.com/kedacore/keda/releases/download/v2.4.0/keda-2.4.0.yaml```

- Example running Azure Pipelines Container Agent with Autoscaling
    [pipelineagent_BuildTools_Autoscale.yml](windows/pipelineagent_BuildTools_Autoscale.yml)
You need to run [DeployAgentToAks.ps1](windows/DeployAgentToAks.ps1) to deploy the agent to Kubernetes Cluster. The script automatically gets the Pool-ID from the Poolname and then replaces it in the deployment manifest and run the deployment. 
 