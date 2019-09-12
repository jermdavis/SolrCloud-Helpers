function Extract-ZooKeeper
{
    param(
        [string] $zkArchive,
        [string] $workingFolder,
        [string] $zkFolderName
    )

    $zkDirectory = "$workingFolder\$zkFolderName"

    if(!(Test-Path $zkDirectory))
    {
        Write-Host "Extracting $zkArchive to $zkDirectory"

        Expand-TarGz $zkArchive $workingFolder -BufferSize $(1024*1024)

        $createdFolder = $workingFolder | Get-ChildItem -Filter "zookeeper*" | select -ExpandProperty FullName

        Rename-Item $createdFolder $zkFolderName
    }
    else
    {
        Write-Host "No need to extract ZooKeeper - it already exists"
    }

    return $zkDirectory
}

function Create-ZooKeeperInstanceId
{
    param(
        [string]$zkFolder,
        [int]$zkInstance
    )

    $dataFolder = "$zkFolder\data"
    $myIdFile = "$dataFolder\myid"

    if(!(Test-Path $myIdFile))
    {
        Write-Host "Creating instance id file for instance #$zkInstance"

        New-Item $dataFolder -ItemType Directory | Out-Null
        $zkInstance | Out-File -FilePath $myIdFile -Encoding ascii
    }
    else
    {
        Write-Host "Instance id file exists."
    }
}

function Create-ZooKeeperConfig
{
    param(
        [string]$zkFolder,
        [int]$zkPort,
        [string[]]$ensemble,
        [int]$zkInitLimit = 5,
        [int]$zkSyncLimit = 2
    )

    $zkDataFolder = "$zkFolder\data"
    $cfgFile = "$zkFolder\conf\zoo.cfg"

	$singleInstance = ($ensemble.Length -eq 1)

    if(!(Test-Path $cfgFile))
    {
        Write-Host "Writing ZooKeeper config"

		if(-not $singleInstance)
		{
			"initLimit=$zkInitLimit" | Out-File -FilePath $cfgFile -Encoding ascii
			"syncLimit=$zkSyncLimit" | Out-File -FilePath $cfgFile -Encoding ascii -Append
		}

        "dataDir=$zkDataFolder".Replace("\", "\\") | Out-File -FilePath $cfgFile -Encoding ascii -Append
        "clientPort=$zkPort" | Out-File -FilePath $cfgFile -Encoding ascii -Append
    
		if(-not $singleInstance)
		{
			for($i=0; $i -lt $ensemble.Length; $i++)
			{
				"server.$($i+1)=$($ensemble[$i])" | Out-File -FilePath $cfgFile -Encoding ascii -Append
			}
		}
    }
    else
    {
        Write-Host "ZooKeeper config file exists"
    }
}

function Configure-ZooKeeperService
{
    param(
        [string]$nssmFolder,
        [string]$zkFolder,
        [string]$zkServiceName
    )

    $svc = Get-Service "$zkServiceName" -ErrorAction SilentlyContinue
    if(!($svc))
    {
        Write-Host "Installing ZooKeeper service $zkServiceName"

        $nssmCommand = "$nssmFolder\nssm.exe"
        $zkCommand = "$zkFolder\bin\zkServer.cmd"

        & $nssmCommand install $zkServiceName $zkCommand
    }
    else
    {
        Write-Host "ZooKeeper service $zkServiceName already exists."
    }
}

<#
 .Synopsis
  Goes through the process of installing a Zookeeper instance. Downloads, extracts and configures the specified version.

 .Description
  Orchistrates the process of downloading, extracting and configuiring an instance of Zookeeper based on the parameters
  passed in. Since Zookeeper is packaged as a .tar.gz file this depends on helpers that wrap the 7ZipForPowershell module.

 .Parameter targetFolder
  The absolute path to a folder to install Zookeeper into. A child folder with the specified name will be created
  under it to contain the files. If it doesn't exist it will be created.

 .Parameter zkPackage
  The full download url for the archive file containing the Zookeeper build.

 .Parameter zkFolder
  The target folder (to be created underneath the targetFolder) to put the Zookeeper files into.

 .Parameter zkInstanceId
  The integer instance number for this Zookeeper node. Must be unique in the current cluster.

 .Parameter zkClientPort
  The port that other software will connect to this Zookeeper node via. Must be available for use on the
  current machine (and open via appropriate firewalls if cross-machine comms are required)

 .Parameter zkEnsemble
  An array of internal connection data for this ensemble of ZooKeeper nodes. Each node in the ensemble gets an entry in
  the array - and each entry is a string in the format "hostname:port:port". The ports are the private ports for Zookeeper's
  internal use.

 .Parameter installService
  Boolean flag to determine whether the Zookeeper executable should be configured as a windows service using NSSM.
#>
function Install-ZooKeeperInstance
{
	param(
		[string]$targetFolder = "C:\SolrCloud",
		[string]$zkPackage = "https://mirrors.ukfast.co.uk/sites/ftp.apache.org/zookeeper/zookeeper-3.4.14/zookeeper-3.4.14.tar.gz",
		[string]$zkFolder = "ZK",
		[int]$zkInstanceId = 1,
		[int]$zkClientPort = 2971,
		[string[]]$zkEnsemble = @("localhost:2981:2991", "localhost:2982:2992", "localhost:2983:2993"),
		[bool]$installService = $false
	)

	Verify-Elevated "You must run this script elevated in order to install the ZooKeeper service"
	Ensure-FolderExists $targetFolder

	$downloadedTarFile = "$targetFolder\zk.tar.gz"

	Download-IfRequired "ZooKeeper" $zkPackage $downloadedTarFile
	$zkDirectory = Extract-ZooKeeper $downloadedTarFile $targetFolder $zkFolder

	Create-ZooKeeperInstanceId $zkDirectory $zkInstanceId
	Create-ZooKeeperConfig $zkDirectory $zkClientPort $zkEnsemble

	if($installService)
	{
		Configure-ZooKeeperService "$targetFolder\NSSM" $zkDirectory "ZooKeeper-$zkInstanceId"
	}
}

<#
 .Synopsis
  A shortcut to start a Zookeeper instance that has been installed as a service by Install-ZooKeeperInstance

 .Description
  Tells the Windows service API to start the Zookeeper service, based on the naming conventions used when Install-ZooKeeperInstance.
  Behaviour is optional - if $installService is false, does nothing.


 .Parameter zkInstanceId
  The instance number for the Zookeeper node to start. An integer, used to format the correct service name based on the patterns
  used by Install-ZooKeeperInstance

 .Parameter installService
  A boolean flag to indicate if the Zookeeper instance was set up as a Windows service. If false, this call does nothing.
#>
function Start-ZooKeeperInstance
{
	param(
		[int]$zkInstanceId = 1,
		[bool]$installService = $false
	)

	if($installService)
	{
		$serviceName = "ZooKeeper-$zkInstanceId"
		Write-Host "Starting ZooKeeper service $serviceName"
		Start-Service $serviceName
	}
}

<#
 .Synopsis
  Once called, will block until an instance of Zookeeper is up and running.

 .Description
  Uses Zookeeper's comms protocol to connect and ask if the process is running ok. Will keep polling (blocking the script 
  from continuing) until a positive response is received.

 .Parameter zkHost
  The host name to connect to for the Zookeeper instance to poll.

 .Parameter zkPort
  The client (public) port for the Zookeeper instance to poll.
#>
function Wait-ForZooKeeperInstance
{
    param(
        [string]$zkHost,
        [int]$zkPort
    )

    Write-Host "Waiting for ZooKeeper at $($zkHost):$zkPort"

    $client = New-Object System.Net.Sockets.TcpClient

    $sawError = $false
    $isUp = $false
    while($isUp -ne $true)
    {
        try
        {
            $client.Connect($zkHost, $zkPort)
            $ns = [System.Net.Sockets.NetworkStream]$client.GetStream()
        
            $sendBytes = [System.Text.Encoding]::ASCII.GetBytes("ruok")
            $ns.Write($sendBytes, 0, $sendBytes.Length)

            $buffer = New-Object 'byte[]' 10
            $bytesRead = $ns.Read($buffer, 0, 10)

            $receivedBytes = New-Object 'byte[]' $bytesRead
            [System.Array]::Copy($buffer, $receivedBytes, $bytesRead)

            $result= [System.Text.Encoding]::ASCII.GetString($receivedBytes)
            
            if( $result -eq "imok" )
            {
                $isUp = $true
                if( $sawError -eq $true )
                {
                    Write-Host
                }
            }

            $ns.Dispose()
        }
        catch
        {
            $sawError = $true
            Write-Host "." -NoNewline
        }
    }

    $client.Dispose()

    Write-Host "ZooKeeper is up"
}

<#
 .Synopsis
  Transforms the raw Zookeeper config array data structure into the ensemble connection string used in
  the zoo.cfg file's ensemble description data.

 .Description
  Takes the array-of-dictionary config data defined by the example scripts that describes the setup of a
  Zookeeper ensemble and concatenates the relevant data to generate the connection string required
  for Zookeeper's config file data.

 .Parameter zkData
  The raw config data, as per the example scripts for this project. An array of dictionaries. Each node in
  the ensemble gets one dictionary, which needs to contain "Host" and "EnsemblePorts" keys.
#>
function Make-ZooKeeperEnsemble
{
    param(
        $zkData
    )

    $result = @()

    foreach($entry in $zkData)
    {
        $result += $entry.Host + ":" + $entry.EnsemblePorts
    }

    return $result;
}

<#
 .Synopsis
  Transforms the raw Zookeeper config array data structure into the connection string used by Solr
  to talk to the ensemble.

 .Description
  Takes the array-of-dictionary config data defined by the example scripts that describes the setup of a
  Zookeeper ensemble and concatenates the relevant data to generate the connection string required
  for Solr's config file data.

 .Parameter zkData
  The raw config data, as per the example scripts for this project. An array of dictionaries. Each node in
  the ensemble gets one dictionary, which needs to contain "Host" and "ClientPort" keys.
#>
function Make-ZooKeeperConnection
{
    param(
        $zkData
    )

    $result = [string]::Empty

    foreach($entry in $zkData)
    {
        if($result) {
            $result = $result + ","
        }

        $result = $result + $entry.Host + ":" + $entry.ClientPort
    }

    return $result;
}

Export-ModuleMember -Function Make-ZooKeeperEnsemble
Export-ModuleMember -Function Make-ZooKeeperConnection
Export-ModuleMember -Function Install-ZooKeeperInstance
Export-ModuleMember -Function Start-ZooKeeperInstance
Export-ModuleMember -Function Wait-ForZooKeeperInstance