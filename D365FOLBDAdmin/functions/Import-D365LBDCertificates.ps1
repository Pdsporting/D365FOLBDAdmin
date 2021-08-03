function Import-D365LBDCertificates {
    <# TODO: Need to rethink approach doesnt work smoothly
   .SYNOPSIS
  Looks inside the agent share extracts the version from the zip by using the custom module name. Puts an xml in root for easy idenitification
  .DESCRIPTION
   Exports 
  .EXAMPLE
  Import-D365Certificates

  .EXAMPLE
   Import-D365Certificates


  #>
    [alias("Import-D365Certificates")]
    [CmdletBinding()]
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
            if ($Exportable) {
                Import-PfxCertificate $cert.FullName -CertStoreLocation "Cert:\localmachine\my" -Exportable 
            }
            else {
                Import-PfxCertificate $cert.FullName -CertStoreLocation "Cert:\localmachine\my"
            }
        }
        END {
        }
    }
}