function Get-D365LBDCertsFromConfig {
<#
    .SYNOPSIS
    Grabs the certificatedetails from the config for easier export/analysis
    .DESCRIPTION
    Grabs the certificatedetails from the config for easier export/analysis
    .EXAMPLE
    Get-D365CertDetails
    
    .EXAMPLE
    Get-D365CertDetails 
    
    .PARAMETER Config
    optional psobject
    The configuration of D365 from the command Get-D365LBDConfig
    If ignored will use local host.
    
    .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module

       #>
    [alias("Get-D365CertsFromConfig")]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name',
            ParameterSetName = 'NoConfig')]
        [string]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ParameterSetName = 'Config',
            ValueFromPipeline = $True)]
        [psobject]$Config,
        [switch]$OnlyAdminCerts    
    )
    ##Gather Information from the Dynamics 365 Orchestrator Server Config
    BEGIN {
    }
    PROCESS {
     
        $allCerts = $Config.PSObject.Properties | Where-Object { $_.name -like '*Cert*' -and $_.name -notlike '*ExpiresAfter*' } | Select-Object Name, value
    
        $admincerts = $allCerts | Where-Object { $_.name -eq "SFServerCertificate" -or $_.name -eq "SFClientCertificate" }
    
        if ($OnlyAdminCerts) {   
            $admincerts
        }
        else {
            $allcerts
        }
    }
    END {  
    }
}