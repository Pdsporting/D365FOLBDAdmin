function Connect-ServiceFabricAutomatic {
    <#
   .SYNOPSIS
  Looks inside the agent share extracts the version from the zip by using the custom module name.
  Puts an xml in root for easy idenitification.

  .DESCRIPTION
   Connect-ServiceFabricAutomatic

  .EXAMPLE
  Connect-ServiceFabricAutomatic

  .EXAMPLE
  Connect-ServiceFabricAutomatic

  .PARAMETER AgentShare

  optional string 
  The location of the Agent Share

  .PARAMETER CustomModuleName
  optional string 
  The name of the custom module you will be using to capture the version number.

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
        if (!$Config){
            $Config = Get-D365LBDConfig
        }
        
    }

     
}