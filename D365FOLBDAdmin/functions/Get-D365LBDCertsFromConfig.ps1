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
    
    
       #>
    [alias("Get-D365CertsFromConfig")]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name')]
        [string]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(Mandatory = $false)][psobject]$Config,
        [switch]$OnlyAdminCerts    
    )
    ##Gather Information from the Dynamics 365 Orchestrator Server Config
    BEGIN {
    }
    PROCESS {
     
        $allCerts = $Config.PSObject.Properties | Where-Object { $_.name -like '*Cert*' } | Select-Object Name, value
    
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