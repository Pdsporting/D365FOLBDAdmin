function Import-D365Certificates {
    <#
   .SYNOPSIS
  Looks inside the agent share extracts the version from the zip by using the custom module name. Puts an xml in root for easy idenitification
  .DESCRIPTION
   Exports 
  .EXAMPLE
  Export-D365FOLBDAssetModuleVersio

  .EXAMPLE
   Export-D365FOLBDAssetModuleVersion

  .PARAMETER AgentShare
  optional string 
   The location of the Agent Share
  .PARAMETER CustomModuleName
  optional string 
  The name of the custom module you will be using to capture the version number

  #>
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$CertThumbprint,
        [Parameter(Mandatory = $true)]
        [string]$CertFolder
    )
    ##Import
    $certs = get-childitem "$CertFolder"
    foreach ($cert in $certs) {
        Import-PfxCertificate $cert.FullName -CertStoreLocation "Cert:\localmachine\my" -Exportable
    }
}