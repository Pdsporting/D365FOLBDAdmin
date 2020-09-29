function Connect-ServiceFabricAutomatic {
    <#
   .SYNOPSIS
  todo not working yet

  .DESCRIPTION
   Connect-ServiceFabricAutomatic

  .EXAMPLE
  Connect-ServiceFabricAutomatic

  .EXAMPLE
  Connect-ServiceFabricAutomatic

  .PARAMETER Config
  optional custom object generated from Get-D365LBDConfig 
  #>
    param
    (
        [Parameter(Mandatory = $false)]
        [psobject]$Config
    )
    try {
        if (Get-Command Connect-ServiceFabricCluster -ErrorAction Stop) {
        }
        else {
            Write-PSFMessage -Level Error Message "Error: Service Fabric Powershell module not installed" 
        }
    }
    catch {
        Stop-PSFFunction -Message "Error: Service Fabric Powershell module not installed" -EnableException $true -Cmdlet $PSCmdlet
    }
    if (!$Config) {
        $Config = Get-D365LBDConfig
    }  
    $SFServiceCert = Get-ChildItem "Cert:\localmachine\my" | Where-Object { $_.Thumbprint -eq $config.SFServerCertificate } 

    if (!$SFServiceCert) {
        Stop-PSFFunction -Message "Error: Can't Find SFServerCertificate $($config.SFServerCertificate)" -EnableException $true -Cmdlet $PSCmdlet
    }
    else {
        Write-PSFMessage -Level Verbose -Message "$SFServiceCert"
    }
    $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $config.SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
        
    if (!$connection) {
        Connect-ServiceFabricCluster
    }
    $connection
}
