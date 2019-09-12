function Setup-ZooKeeperForSsl
{
    param(
        [string]$solrFolder,
        [string]$zkConnectionString
    )

    Write-Host "Configuring ZooKeeper for SSL"

	#
	# Make sure local java env variable was updated before calling this
	# It will fail if it can't find Java - and it appears to need the path environment set
	# rather than the JAVA_HOME that the rest of Solr requires.
	#
    $zkCliTool = "$solrFolder\server\scripts\cloud-scripts\zkCli.bat"
    & $zkCliTool -zkhost $zkConnectionString -cmd clusterprop -name urlScheme -val https
}

<#
 .Synopsis
  Performs the configuration of a Zookeeper ensemble to use SSL when talking to Solr.

 .Description
  Sends the "clusterprop" command required to configure the Zookeeper nodes for the use of SSL
  when speaking to Solr. Makes use of Solr's config tools to do this, as they do this which much
  less hassle than Zookeeper's tools...

 .Parameter targetFolder
  The folder that was used as the parent for the Solr / Zookeeper folders

 .Parameter solrFolderName
  The name of the Solr folder under the targetFolder

 .Parameter zkConnection
  The Zookeeper connection string for this ensemble.
#>
function Configure-ZooKeeperForSsl
{
	param(
		[string]$targetFolder = "C:\SolrCloud",
		[string]$solrFolderName = "SOLR",
		[string]$zkConnection = "localhost:2971"
	)

	Setup-ZooKeeperForSsl "$targetFolder\$solrFolderName" $zkConnection
}

Export-ModuleMember -Function Configure-ZooKeeperForSsl