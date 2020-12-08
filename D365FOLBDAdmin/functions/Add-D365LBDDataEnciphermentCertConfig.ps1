function Add-D365LBDDataEnciphermentCertConfig {
    <#
    .SYNOPSIS
   Adds the Encipherment Cert into the D365 Servers for the configuration of the local business data environment.
   .DESCRIPTION
    Adds the Encipherment Cert into the D365 Servers for the configuration of the local business data environment.
    Will be grabbed by the Get-D365LBDConfig after this command is ran.
   .EXAMPLE
   Add-D365LBDDataEnciphermentCertConfig -Thumbprint "1243asd234213"
   Will get config from the local machine.
    .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER Thumbprint
   String 
    The thumbprint of the DataEncipherment certificate.
    .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module
   #>
    [alias("Add-D365DataEnciphermentCertConfig")]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name',
            ParameterSetName = 'NoConfig')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(Mandatory = $True)]
        [string]$Thumbprint,
        [Parameter(ParameterSetName = 'Config',
            ValueFromPipeline = $True)]
        [psobject]$Config
  
    )
    ##Gather Information from the Dynamics 365 Orchestrator Server Config
    BEGIN {
    }
    PROCESS {
        if (!$Config) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly
        }

        foreach ($server in $Config.AllAppServerList) {
            $Thumbprint | Out-file \\$server\c$\ProgramData\SF\DataEnciphermentCert.txt
        }
    }
    END {
      
    }
}