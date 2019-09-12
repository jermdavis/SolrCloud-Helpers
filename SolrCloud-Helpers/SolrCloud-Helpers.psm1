# Pattern for module from https://stackoverflow.com/a/44512990/847953

#Get public and private function definition files.
$SolrProcess  = @( Get-ChildItem -Path $PSScriptRoot\Install\*.ps1 -ErrorAction SilentlyContinue )
$Extras = @( Get-ChildItem -Path $PSScriptRoot\Extras\*.ps1 -ErrorAction SilentlyContinue )

#Dot source the files
foreach($import in @($SolrProcess + $Extras))
{
    try
    {
        . $import.fullname
    }
    catch
    {
        Write-Error -Message "Failed to import file $($import.fullname): $_"
    }
}