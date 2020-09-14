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
    {
        try {
            if (Get-Command Connect-ServiceFabric -ErrorAction Stop) {
            }
            else {
                Write-PSFMessage -Level Error Message "Error: Service Fabric Powershell module not installed" 
            }
        }
        catch {
            Write-PSFMessage -Level Error Message "Error: Service Fabric Powershell module not installed" 
        }
        if (!$Config) {
            $Config = Get-D365LBDConfig
        }  
        Connect-ServiceFabricCluster -ConnectionEndpoint $config.SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate
    }
}