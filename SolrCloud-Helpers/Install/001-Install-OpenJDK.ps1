function Extract-JRE
{
	param(
        [string] $jdkZip,
        [string] $workingFolder,
		[string] $jreFolderName = "JRE"
    )
    
    $jreFolderPath = "$workingFolder\$jreFolderName"

    if(!(Test-Path $jreFolderPath))
    {
        Write-Host "Expanding archive for $jdkZip to get $jreFolderName"

        Expand-Archive $jdkZip "$workingFolder\tmp"

        $jreFolder = Get-ChildItem -Path "$workingFolder\tmp" -Directory | select -ExpandProperty FullName

        Move-Item $jreFolder $jreFolderPath
        Remove-Item "$workingFolder\tmp" -Recurse
    }
    else
    {
        Write-Host "No need to expanding archive for $jdkZip - Folder $jreFolderName exists"
    }

    return $jreFolderPath
}

function Set-JavaHomeEnvironment
{
    param(
        [string]$jrePath,
        [string]$environmentVariable = "JAVA_HOME",
        [bool]$overwriteEnvironmentVariable = $false
    )

    $val = [Environment]::GetEnvironmentVariable($environmentVariable, [EnvironmentVariableTarget]::Machine)

    if([string]::IsNullOrWhiteSpace($val) -or $overwriteEnvironmentVariable)
    {
        [Environment]::SetEnvironmentVariable($environmentVariable, $jrePath, [EnvironmentVariableTarget]::Machine)
		$env:JAVA_HOME = $jrePath
        Write-Host "Updated $environmentVariable to `"$jrePath`" - YOU MUST REFRESH OTHER CMD/POWERSHELL WINDOWS"
    }
    else
    {
        Write-Host "Not updating $environmentVariable - existing value `"$val`""
    }

	# JRE needs to be in the path too!
	$path = [Environment]::GetEnvironmentVariable("PATH",[EnvironmentVariableTarget]::Machine)
	if(-not $path.Contains($jrePath) )
	{
		$jreBinPath = Join-Path $jrePath "bin"
		$path = "$path;$jreBinPath"
		[Environment]::SetEnvironmentVariable("PATH", $path, [EnvironmentVariableTarget]::Machine)

		$env:Path = $env:Path + ";" + $jreBinPath

		Write-Host "Updated path to `"$path`""
	}
	else
	{
	Write-Host "Not updating path - existing value `"$path`""
	}

	# do we need to "refresh" this? Maybe not - and maybe remove other refresh?
}

<#
 .Synopsis
  Downloads and installs the specified version of OpenJDK

 .Description
  Downloads the OpenJDK build specified by the release parameter provided, unzips it to the folder specified for the target
  and makes sure that the path / JAVA_HOME environment variables are update for the downloaded JDK.

 .Parameter targetFolder
  The absolute path to a folder to install the specified JRE into. A child folder with the specified name will be created
  under it to contain the files. If it doesn't exist it will be created.

 .Parameter javaRelease
  The full download url for the zip file containing the OpenJDK build.

 .Parameter jreFolderName
  The folder name to create under the target folder, to hold the JRE files.
#>
function Install-OpenJDK
{
	# Releases come form
	# https://github.com/ojdkbuild/ojdkbuild/releases/1.8.0.212-1
	param(
		[string]$targetFolder = "C:\SolrCloud",
		[string]$javaRelease = "https://github.com/ojdkbuild/ojdkbuild/releases/download/java-1.8.0-openjdk-1.8.0.222-2.b10/java-1.8.0-openjdk-jre-1.8.0.222-2.b10.ojdkbuild.windows.x86_64.zip",
		[string]$jreFolderName = "JRE"
	)

	Verify-Elevated "To create Java's environment variable, please run this script elevated."
	Ensure-FolderExists $targetFolder

	$downloadedZipFile = "$targetFolder\jre.zip"

	Download-IfRequired "OpenJDK" $javaRelease $downloadedZipFile $false
	$jreFolder = Extract-JRE -jdkZip $downloadedZipFile -workingFolder $targetFolder -jreFolderName $jreFolderName
	Set-JavaHomeEnvironment $jreFolder
}

Export-ModuleMember -Function Install-OpenJDK