function Make-SslCertificate
{
    param(
        [string]$workingFolder,
        [string[]]$hostNames,
        [string]$certFriendlyName,
        [string]$certPassword
    )

    Write-Host "Looking for certificate $certFriendlyName"
    $cert = Get-ChildItem -Path Cert:\LocalMachine\Root | where { $_.FriendlyName -eq $certFriendlyName }

    if( $cert -eq $null )
    {
        $cert = New-SelfSignedCertificate -Subject $certFriendlyName -FriendlyName $certFriendlyName -DnsName $hostNames -CertStoreLocation "cert:\LocalMachine\My" -NotAfter (Get-Date).AddYears(10)
        Write-Host "Created certificate $($cert.Thumbprint)"

        Move-Item "cert:\LocalMachine\my\$($cert.Thumbprint)" "cert:\LocalMachine\Root"
        Write-Host "Moved cert to trusted store"

        $cert = Get-Item "cert:\LocalMachine\Root\$($cert.Thumbprint)"
    }
    else
    {
        Write-Host "Found certificate $($cert.Thumbprint)"
    }

    $certStore = "$workingFolder\solr.keystore.pfx"
    $certPwd = ConvertTo-SecureString -String $certPassword -Force -AsPlainText
    $cert | Export-PfxCertificate -FilePath $certStore -Password $certpwd | Out-Null
    Write-Host "Exported Cert to $certStore"
    
    return $certStore
}

<#
 .Synopsis
  Generates a self-signed SSL certificate which can be used by a SolrCloud cluster to enable HTTPS access.

 .Description
  Uses PowerShell's certificate generation features to make a certificate including the defined set of SANs,
  and then configuires the certificate to be trusted, and exports it to a PFX file including the private key
  for use with Solr.

 .Parameter targetFolder
  The folder to export the certificate's PFX file to.

  .Parameter solrHostNames
  An array of strings which are used as the Subject Alternative Names in the certificate file.

  .Parameter solrCertPassword
  The password to use when exporting the certificate to a PFX file.
#>
function Generate-SolrCertificate
{
	param(
		[string]$targetFolder = "C:\SolrCloud",
		[string[]]$solrHostNames = @("solr"),
		[string]$solrCertPassword = "secret"
	)

	Verify-Elevated "This script must be elevated to configure certificate trust"
	Ensure-FolderExists $targetFolder

	return Make-SslCertificate $targetFolder $solrHostNames "Solr SSL Certificate" $solrCertPassword
}

Export-ModuleMember -Function Generate-SolrCertificate