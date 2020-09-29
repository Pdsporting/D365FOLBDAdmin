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
        [psobject]$Config,
        [string]$SFServerCertificate,
        [string]$SFConnectionEndpoint

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
    if ((!$Config) -and (!$SFServerCertificate) -and (!$SFConnectionEndpoint)) {
        Write-PSFMessage -Message "No paramters selected will try and get config" -Level Verbose
        $Config = Get-D365LBDConfig
        $SFConnectionEndpoint = $config.SFConnectionEndpoint
        $SFServerCertificate = $config.SFServerCertificate
    }  
    $SFServiceCert = Get-ChildItem "Cert:\localmachine\my" | Where-Object { $_.Thumbprint -eq $SFServerCertificate } 

    if (!$SFServiceCert) {
        $SFServiceCert = Get-ChildItem "Cert:CurrentUser\my" | Where-Object { $_.Thumbprint -eq $SFServerCertificate } 
        if ($SFServiceCert) {
            $CurrentUser = 'true'
        }
    }

    if (!$SFServiceCert) {
        Stop-PSFFunction -Message "Error: Can't Find SFServerCertificate $SFServerCertificate" -EnableException $true -Cmdlet $PSCmdlet
    }
    else {
        Write-PSFMessage -Level Verbose -Message "$SFServiceCert"
    }

    $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $SFServerCertificate -ServerCertThumbprint $SFServerCertificate -StoreLocation LocalMachine -StoreName My
    if ($CurrentUser -eq 'true') {
        Write-PSFMessage -Message "Using Current User Certificate Store" -Level Verbose
        $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $SFServerCertificate -ServerCertThumbprint $SFServerCertificate -StoreLocation CurrentUser -StoreName My
    }
    
    if (!$connection) {
        $connection = Connect-ServiceFabricCluster
    }
    $connection
}
