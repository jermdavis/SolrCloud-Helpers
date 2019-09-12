##
## Shared helper methods
##

#
# Verify elevated
# https://superuser.com/questions/749243/detect-if-powershell-is-running-as-administrator
#
function Verify-Elevated
{
    param(
        [string]$message = "This script must be run elevated."
    )
    $elevated = [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")
    if($elevated -eq $false)
    {
        throw $message
    }
}

function Ensure-FolderExists
{
    param(
        [string]$folder
    )

    if(!(Test-Path $folder)){
        Write-Host "Creating folder $folder"
        New-Item $folder -ItemType Directory | Out-Null
    }
    else
    {
        Write-Host "Folder $folder exists"
    }
}

#
# Note, for Github:
# https://powershell.org/forums/topic/bits-transfer-with-github/
#
function Download-IfRequired
{
    param(
        [string]$toolName,
        [string]$downloadUrl,
        [string]$outputFile,
        [bool]$useBitsTransfer = $true
    )

    if(!(Test-Path -Path $outputFile))
    {
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 + [Net.SecurityProtocolType]::Tls11 + [Net.SecurityProtocolType]::Tls1

        Write-Host "Downloading $toolName..."
        if($useBitsTransfer)
        {
            Start-BitsTransfer -Source $downloadUrl -Destination $outputFile
        }
        else
        {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $outputFile
        }
    }
    else
    {
        Write-Host "No need to download $toolName - already present..."
    }
}