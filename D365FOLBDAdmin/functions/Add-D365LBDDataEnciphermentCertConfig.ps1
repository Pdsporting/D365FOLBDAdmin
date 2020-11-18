function Add-D365LBDDataEnciphermentCertConfig {
    <#
    .SYNOPSIS
   Adds the Encipherment Cert into the D365 Servers for the configuration of the local business data environment
   .DESCRIPTION
    Adds the Encipherment Cert into the D365 Servers for the configuration of the local business data environment
   .EXAMPLE
   Add-D365LBDDataEnciphermentCertConfig -Thumbprint "1243asd234213"
   Will get config from the local machine.
   .PARAMETER Thumbrint
   required string 
    the thumbprint of the DataEncipherment certificate
   #>
    [alias("Add-D365DataEnciphermentCertConfig")]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [string]$Thumbprint,
        [psobject]$Config
  
    )
    ##Gather Information from the Dynamics 365 Orchestrator Server Config
    BEGIN {
    }
    PROCESS {
        if (!$Config) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName 
        }

        foreach ($server in $Config.AllAppServerList) {
            $Thumbprint | Out-file \\$server\c$\ProgramData\SF\DataEnciphermentCert.txt
        }
    }
    END {
      
    }
}