function Export-D365LBDConfigReport {
    <#
    .SYNOPSIS
   
   .DESCRIPTION

   .EXAMPLE
    Export-D365LBDConfigReport

   .EXAMPLE
   Export-D365LBDConfigReport -computername 'AXSFServer01'
  
   .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module


   #>
    [alias("Export-D365ConfigReport")]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name',
            ParameterSetName = 'NoConfig')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ParameterSetName='Config',
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
        $Config.LCSEnvironmentName
        $config.LCSEnvironmentID
        $Config.AXServerNames.Count
        $Config.OrchestratorServerNames.Count
        $Config.DatabaseClusteredStatus
        $Config.DatabaseClusterServerNames.Count
        $Config.AOSKernelVersion
        $Config.CustomModuleVersion
        $Config.OrchServiceLocalAgentVersionNumber
        $Config.SFClientCertificateExpiresAfter
        $Config.SFServerCertificateExpiresAfter              
        $Config.DataEncryptionCertificateExpiresAfter       
        $Config.DataSigningCertificateExpiresAfter          
        $Config.SessionAuthenticationCertificateExpiresAfter 
        $Config.SharedAccessSMBCertificateExpiresAfter       
        $Config.LocalAgentCertificateExpiresAfter            
        $Config.DataEnciphermentCertificateExpiresAfter      
        $Config.FinancialReportingCertificateExpiresAfter   
        $Config.ReportingSSRSCertificateExpiresAfter         
        $Config.DatabaseEncryptionCertificateExpiresAfter    
    }
    END {}
}