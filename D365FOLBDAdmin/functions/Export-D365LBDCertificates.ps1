function Export-D365LBDCertificates {
    <# TODO: Need to rethink approach doesnt work smoothly
   .SYNOPSIS

  .DESCRIPTION
   Exports 

  .EXAMPLE
  Export-D365LBDCertificates

  .EXAMPLE
  Export-D365LBDCertificates -exportlocation "C:/certs" -username Stefan -certthumbprint 'A5234656'

  .PARAMETER ExportLocation
  optional string 
  The location where the certificates will export to.

  .PARAMETER Username
  optional string 
  The username this will be protected to

  #>
    [alias("Export-D365Certificates")]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$CertThumbprint,
        [Parameter(Mandatory = $true)]
        [string]$ExportLocation,
        [string]$Username,
        [string]$CertPassword
    )
    BEGIN {
    }
    PROCESS {
   
        ##Export
        if (Test-Path -Path $ExportLocation -IsValid) {
        }
        else {
            mkdir $ExportLocation
        }
        if (!$Username) {
            $Username = whoami
        }
        try {
            Write-PSFMessage -Message "Trying to pull  $CertThumbprint from LocalMachine My " -Level Verbose
            if ($CertPassword){
                $CertSecurePass = ConvertTo-SecureString -String $using:CertPassword -AsPlainText -Force
                Get-ChildItem "Cert:\localmachine\my" | Where-Object { $_.Thumbprint -eq $CertThumbprint } | ForEach-Object -Process { Export-PfxCertificate -Cert $_ -FilePath $("$ExportLocation\" + $_.FriendlyName + ".pfx") -Password $CertSecurePass }
            }else{
                Get-ChildItem "Cert:\localmachine\my" | Where-Object { $_.Thumbprint -eq $CertThumbprint } | ForEach-Object -Process { Export-PfxCertificate -Cert $_ -FilePath $("$ExportLocation\" + $_.FriendlyName + ".pfx") -ProtectTo "$Username" }
            }
            
        }
        catch {
            try {
                Write-PSFMessage -Message "Trying to pull $CertThumbprint from CurrentUser My " -Level Verbose
                if ($CertPassword){
                    $CertSecurePass = ConvertTo-SecureString -String $using:CertPassword -AsPlainText -Force
                    Get-ChildItem "Cert:\CurrentUser\my" | Where-Object { $_.Thumbprint -eq $CertThumbprint } | ForEach-Object -Process { Export-PfxCertificate -Cert $_ -FilePath $("$ExportLocation\" + $_.FriendlyName + ".pfx") -Password $CertSecurePass }
                }
                else{
                    Get-ChildItem "Cert:\CurrentUser\my" | Where-Object { $_.Thumbprint -eq $CertThumbprint } | ForEach-Object -Process { Export-PfxCertificate -Cert $_ -FilePath $("$ExportLocation\" + $_.FriendlyName + ".pfx") -ProtectTo "$Username" }
                }
            }
            catch {
                Write-PSFMessage -Level Verbose "Can't Export Certificate"
                $_ 
            }
        }
    }
    END {
    }
} 