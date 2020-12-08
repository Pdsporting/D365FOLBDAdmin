function Export-D365LBDConfigReport {
    <#
    .SYNOPSIS
   Grabs the configuration of the local business data environment
   .DESCRIPTION
   Grabs the configuration of the local business data environment through logic using the Service Fabric Cluster XML,
   AXSF.Package.Current.xml and OrchestrationServicePkg.Package.Current.xml
   .EXAMPLE
   Get-D365LBDConfig
   Will get config from the local machine.
   .EXAMPLE
    Get-D365LBDConfig -ComputerName "LBDServerName" -verbose
   Will get the Dynamics 365 Config from the LBD server
   .PARAMETER ComputerName
   optional string 
   The name of the Local Business Data Computer.
   If ignored will use local host.
   .PARAMETER ConfigImportFromFile
   optional string 
   The name of the config file to import (if you are choosing to import rather than pull dynamically)
   .PARAMETER ConfigExportToFile
   optional string 
   The name of the config file to export 
   .PARAMETER CustomModuleName
   optional string 
   The name of the custom module you will be using to caputre the version number

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