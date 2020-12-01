function Import-D365LBDCertificates {
 <#
   .SYNOPSIS
  Looks inside the agent share extracts the version from the zip by using the custom module name. Puts an xml in root for easy idenitification
  .DESCRIPTION
   Exports 
  .EXAMPLE
  Import-D365Certificates

  .EXAMPLE
   Import-D365Certificates

  .PARAMETER AgentShare
  optional string 
   The location of the Agent Share
  .PARAMETER CustomModuleName
  optional string 
  The name of the custom module you will be using to capture the version number

  #>
  [alias("Import-D365Certificates")]
    param
    (
        [Parameter(Mandatory = $false)]
        [string]$CertThumbprint,
        [Parameter(Mandatory = $false)]
        [string]$CertFolder,
        [switch]$Exportable
    )
    BEGIN {
    }
    PROCESS {
    ##Import do to.. bythumbprint
    $certs = get-childitem "$CertFolder"
    foreach ($cert in $certs) {
        if ($Exportable){
            Import-PfxCertificate $cert.FullName -CertStoreLocation "Cert:\localmachine\my" -Exportable 
        }
        else {
            Import-PfxCertificate $cert.FullName -CertStoreLocation "Cert:\localmachine\my"
        }
    }
    END {
    }
}