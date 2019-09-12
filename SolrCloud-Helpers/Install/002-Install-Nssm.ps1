function Extract-Nssm
{
    param(
        [string] $nssmZip,
        [string] $workingFolder,
        [string] $nssmFolderName
    )

    $nssmDirectory = "$workingFolder\$nssmFolderName"

    if(!(Test-Path $nssmDirectory))
    {
        Write-Host "Extracting $nssmZip to $nssmDirectory"

        Expand-Archive $nssmZip $workingFolder

        $expandedFolder = $workingFolder | Get-ChildItem -Filter "nssm-*" | select -ExpandProperty FullName

        $win64Folder = "$expandedFolder\Win64"
        Move-Item $win64Folder $nssmDirectory
        Remove-Item $expandedFolder -Recurse
    }
    else
    {
        Write-Host "No need to extract nssm - it already exists"
    }
}

<#
 .Synopsis
  Downloads and installs the specified version of NSSM, to allow the creation of Windows Services

 .Description
  Downloads the specified NSSM release zip, and extracts it to the specified folder under the target path given,
  leaving it ready to install services.

 .Parameter targetFolder
  The absolute path to a folder to install the specified JRE into. A child folder with the specified name will be created
  under it to contain the files. If it doesn't exist it will be created.

 .Parameter nssmPackage
  The full download url for the zip file containing the NSSM build.

 .Parameter nssmFolder
  The folder name to create under the target folder, to hold the NSSM files.
#>
function Install-NSSM
{
	param(
		[string]$targetFolder = "C:\SolrCloud",
		[string]$nssmPackage = "https://nssm.cc/release/nssm-2.24.zip",
		[string]$nssmFolder = "NSSM"
	)

	$downloadedZipFile = "$targetFolder\nssm.zip"

	Ensure-FolderExists $targetFolder

	Download-IfRequired "NSSM" $nssmPackage $downloadedZipFile -useBitsTransfer $false
	Extract-Nssm $downloadedZipFile $targetFolder $nssmFolder
}

Export-ModuleMember -Function Install-NSSM