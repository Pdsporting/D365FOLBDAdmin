function Import-D365LBDDBCertificate {
    <# 
   .SYNOPSIS
  Imports PFX File into all Application Servers Trusted Root
  .DESCRIPTION
 Imports PFX File into all Application Servers Trusted Root. Created to import database certificates
  .EXAMPLE
   Import-D365Certificates -pfxLocation "C:\Certs\FakeThumbprint.pfx" -CertPassword 'StrongFakePass123' -Config $Config
  .EXAMPLE
   $Certs = New-D365MSSQLSelfCert -config $Config -CertPass 'StrongFakePass123'
   foreach ($cert in $Certs){
    Import-D365Certificates -pfxLocation $cert.FullName -CertPassword 'StrongFakePass123' -Config $Config -DeletePFXAfter
   }
  #>
    [alias("Import-D365DBCertificate")]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$PFXLocation,
        [Parameter(Mandatory = $true)]
        [string]$CertPassword,
        [Parameter(ValueFromPipeline = $True)]
        [psobject]$Config,
        [switch]$DeletePFXAfter
    )
    BEGIN {
    }
    PROCESS {
        if (!$Config -or $Config.OrchestratorServerNames.Count -eq 0) {
            Write-PSFMessage -Level VeryVerbose -Message "Config not defined or Config is invalid. Trying to Get new config using $ComputerName"
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly
        }

        $CertFile = Get-ChildItem $PFXLocation
        foreach ($Server in $Config.AllAppServerList | Select ComputerName) {
            $ServerName = $Server.ComputerName
            Write-PSFMessage -Level Verbose -Message "Trying to import into $ServerName"
            if (!(test-path -PathType Container "\\$ServerName\c$\certs")) {
                mkdir "\\$ServerName\c$\certs"
            }
            Copy-Item $PFXLocation -Destination \\$ServerName\c$\certs\$($CertFile.Name)

            Invoke-Command -ScriptBlock {
                $LocalFile = Get-ChildItem "C:\Certs\$($using:CertFile.Name)"
                $CertSecurePass = ConvertTo-SecureString -String $using:CertPassword -AsPlainText -Force
                try {
                    Import-PfxCertificate -FilePath $LocalFile.FullName -Password $CertSecurePass -CertStoreLocation Cert:\LocalMachine\Root
                    Write-Verbose "Imported Certificate into $env:ComputerName" -Verbose
                }
                catch {
                    Write-Warning -Message "Could not import into $env:ComputerName"
                    Write-Warning -Message "$_"
                }
                finally {
                    if ($using:DeletePFXAfter) {
                        Get-ChildItem $LocalFile.FullName | Remove-Item -Force
                    }
                    
                }
            } -ComputerName $ServerName
        }
    }
    END {
    }
}