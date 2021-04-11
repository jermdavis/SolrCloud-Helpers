function Extract-Solr
{
    param(
        [string] $solrArchive,
        [string] $workingFolder,
        [string] $solrFolderName
    )

    $solrDirectory = "$workingFolder\$solrFolderName"

    if(!(Test-Path $solrDirectory))
    {
        Write-Host "Extracting $solrArchive to $solrDirectory"

        Expand-Archive $solrArchive $workingFolder

        $createdFolder = $workingFolder | Get-ChildItem -Filter "solr-*" | select -ExpandProperty FullName

        Rename-Item $createdFolder $solrFolderName -Force
    }
    else
    {
        Write-Host "No need to extract Solr - it already exists"
    }

    return $solrDirectory
}

function Create-SolrConfig
{
    param(
        [string]$solrFolder,
        [string]$certFile,
        [string]$certPassword,
        [string]$solrHost,
        [string]$solrPort,
        [string]$zkConnectionString
    )

    # write config changes
    if(!(Test-Path -Path "$solrFolder\bin\solr.in.cmd.old"))
    {
        Write-Host "Rewriting solr config for instance $solrInstance"
 
        $cfg = Get-Content "$solrFolder\bin\solr.in.cmd"
        Rename-Item "$solrFolder\bin\solr.in.cmd" "$solrFolder\bin\solr.in.cmd.old"
        $newCfg = $cfg | % { $_ -replace "REM set SOLR_SSL_KEY_STORE=etc/solr-ssl.keystore\.(p12|jks)", "set SOLR_SSL_KEY_STORE=$certFile" }
        $newCfg = $newCfg | % { $_ -replace "REM set SOLR_SSL_KEY_STORE_PASSWORD=secret", "set SOLR_SSL_KEY_STORE_PASSWORD=$certPassword" }
        $newCfg = $newCfg | % { $_ -replace "REM set SOLR_SSL_TRUST_STORE=etc/solr-ssl.keystore\.(p12|jks)", "set SOLR_SSL_TRUST_STORE=$certFile" }
        $newCfg = $newCfg | % { $_ -replace "REM set SOLR_SSL_TRUST_STORE_PASSWORD=secret", "set SOLR_SSL_TRUST_STORE_PASSWORD=$certPassword" }
        $newCfg = $newCfg | % { $_ -replace "REM set SOLR_HOST=192.168.1.1", "set SOLR_HOST=$solrHost" }
        $newCfg = $newCfg | % { $_ -replace "REM set SOLR_PORT=8983", "set SOLR_PORT=$solrPort" }
        

        $newCfg = $newCfg | % { $_ -replace "REM set ZK_HOST=", "set ZK_HOST=$zkConnectionString" }
        $newCfg | Set-Content "$solrFolder\bin\solr.in.cmd"
    }
    else
    {
        Write-Host "No need to rewrite Solr config - already modified"
    }
}

function Configure-SolrService
{
    param(
        [string]$nssmFolder,
        [string]$solrFolder,
        [string]$solrServiceName
    )

    $svc = Get-Service "$solrServiceName" -ErrorAction SilentlyContinue
    if(!($svc))
    {
        Write-Host "Installing Solr service $solrServiceName"

        $nssmCommand = "$nssmFolder\nssm.exe"
        $solrCommand = "$solrFolder\bin\solr.cmd"

        & $nssmCommand install $solrServiceName $solrCommand "-f -c"
    }
    else
    {
        Write-Host "Solr service $solrServiceName already exists."
    }
}

<#
 .Synopsis
  Sets up a node in a SolrCloud cluster, based on the supplied parameters.

 .Description
  Dowloads the specified Solr archive, extracts it and applies configuration. Will optionally install it as a service.

 .Parameter targetFolder
  The absolute path to a folder to install Solr into. A child folder with the specified name will be created
  under it to contain the files. If it doesn't exist it will be created.

 .Parameter solrPackage
  The full download url for the archive file containing the Solr build.

 .Parameter solrFolderName
  The target folder (to be created underneath the targetFolder) to put the Solr files into.

 .Parameter certificateFile
  The path to a PFX file containing the SSL certificate to be used with the Solr instance.

 .Parameter certificatePassword
  The password for accessing the private keys of the certificate file.

 .Parameter solrHostname
  The host name for this instance of Solr

 .Parameter solrClientPort
  The port for this instance of Solr to respond to the UI / API

 .Parameter zkEnsembleConnectionString
  The connection string for the Zookeeper ensemble to be used by SolrCloud

 .Parameter installService
  Boolean flag to determine whether the Zookeeper executable should be configured as a windows service using NSSM.
#>
function Install-SolrInstance
{
	param(
		[string]$targetFolder = "C:\SolrCloud",
		[string]$solrPackage = "https://archive.apache.org/dist/lucene/solr/7.2.1/solr-7.2.1.zip",

		[string]$solrFolderName = "SOLR",

		[string]$certificateFile = "folder\solr.keystore.pfx",
		[string]$certificatePassword = "secret",

		[string]$solrHostname = "solr",
		[int]$solrClientPort = 9999,
		[string]$zkEnsembleConnectionString = "localhost:9911,localhost:9922,localhost:9933",

		[bool]$installService = $false
	)

	Verify-Elevated "You must run this script elevated to install the Solr service"
	Ensure-FolderExists $targetFolder

	$downloadedZipFile = "$targetFolder\solr.zip"

	Download-IfRequired "Solr" $solrPackage $downloadedZipFile
	$solrFolder = Extract-Solr $downloadedZipFile $targetFolder $solrFolderName

	Create-SolrConfig $solrFolder $certificateFile $certificatePassword $solrHostname $solrClientPort $zkEnsembleConnectionString

	if($installService)
	{
		Configure-SolrService "$targetFolder\NSSM" $solrFolder "Solr-$solrClientPort"
	}
}

<#
 .Synopsis
  Attempts to update the host file with the specified data

 .Description
  Checks whether the specified line already exists in the hosts file, and if not
  adds it to the end of the file.

 .Parameter hostFileName
  The full path to the host file to be updated

 .Parameter linesToAdd
  The line to add if required.
#>
function Add-HostEntries
{
	param(
		[string]$hostFileName = "c:\windows\system32\drivers\etc\hosts",
		[string[]]$linesToAdd
	)
    
    $hostFile = [System.Io.File]::ReadAllText($hostFileName)
    
	$text = ""
	foreach($lineToAdd in $linesToAdd)
	{
		if( -not ($hostFile -like "*$lineToAdd*") )
		{
			$text = "$text`r`n$lineToAdd"
		}
	}
	if($text.Length -gt 0)
	{
		Write-Host "Updating host file at `"$hostFileName`""
		$text | Add-Content $hostFileName 
	}
	else
	{
		Write-Host "No changes required to host file."
	}
}

<#
 .Synopsis
  A shortcut to start a Solr instance that has been installed as a service by Install-SolrInstance

 .Description
  Tells the Windows service API to start the Solr service, based on the naming conventions used when Install-SolrInstance.
  Behaviour is optional - if $installService is false, does nothing.

 .Parameter solrClientPort
  The port that the Solr Admin UI / API is exposed at.

 .Parameter installService
  A boolean flag to indicate if the Zookeeper instance was set up as a Windows service. If false, this call does nothing.
#>
function Start-SolrInstance
{
	param(
		[int]$solrClientPort = 9999,
		[bool]$installService = $false
	)

	if($installService)
	{
		$serviceName = "Solr-$solrClientPort" 
		Write-Host "Starting Solr service $serviceName"
		Start-Service $serviceName
	}
}

<#
 .Synopsis
  Polls a Solr URL, and blocks until it responds correctly.

 .Description
  Makes a web reqest to the Solr URL specified by the supplied host and port, assuming that it is exposed under HTTPS.
  Blocks until this returns a valid response.

 .Parameter solrHost
  The host name of the Solr URL/API

 .Parameter solrPort
  The port number of the Solr URL/API
#>
function Wait-ForSolrToStart
{
    param(
        [string]$solrHost,
        [int]$solrPort
    )

	Write-Host "Waiting for Solr to start on https://$($solrHost):$solrPort"
    $done = $false
    while(!$done)
    {
        try
        {
            Invoke-WebRequest "https://$($solrHost):$($solrPort)/solr" -UseBasicParsing | Out-Null
            $done = $true
        }
        catch
        {
        }
    }
	Write-Host "Solr is up..."
}

<#
 .Synopsis
  Generates an array of host names which can be used to build the SANs of a certificate for Solr

 .Description
  Returns the array worked out from the set of hosts declared in the config for this Solr cluster.

 .Parameter data
  The raw Solr config data for the cluster. An array-of-dictionaries where each dictionary
  has to have a "Host" key that specifies the appropriate host name.
#>
function Make-SolrHostList
{
	param(
		$data
	)

	$hostList = @()

	foreach($instance in $data)
	{
		$hostList += $instance.Host
	}

	return $hostList
}

<#
 .Synopsis
  Builds the appropriate host file entry for a test (single machine) Solr cluster.

 .Description
  Takes the raw config data for a Solr cluster, and uses it to generate a line for
  a host file mapping the assorted solr host names to an IP.

 .Parameter ip
  The ip address of the machine running the Solr instances.

 .Parameter data
  The raw Solr config data for the cluster. An array-of-dictionaries where each dictionary
  has to have a "Host" key that specifies the appropriate host name.
#>
function Make-SolrHostEntry
{
	param(
		[string] $ip,
		$data
	)

	$result = "$ip"

	foreach($instance in $data)
	{
		$result = $result + "`t" + $instance.Host
	}

	return $result
}

Export-ModuleMember -Function Install-SolrInstance
Export-ModuleMember -Function Add-HostEntries
Export-ModuleMember -Function Start-SolrInstance
Export-ModuleMember -Function Wait-ForSolrToStart
Export-ModuleMember -Function Make-SolrHostList
Export-ModuleMember -Function Make-SolrHostEntry
