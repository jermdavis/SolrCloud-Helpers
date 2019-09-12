$ErrorActionPreference = "Stop"

$targetFolder = "$([Environment]::GetFolderPath("Desktop"))\SolrCloud"

Install-Module "7Zip4Powershell"
Import-Module ".\Solr-Scripting-Helpers" -DisableNameChecking

Install-OpenJDK -targetFolder $targetFolder

Write-Host "You should refresh other PowerShell/CMD windows now..."