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
        [psobject]$Config,
        [switch]$Detailed,
        [string]$ExportLocation,##mandatory
        [string]$CustomModuleName
    )
    ##Gather Information from the Dynamics 365 Orchestrator Server Config
    BEGIN {
    } 
    PROCESS {
        if (!$Config) {
            if ($CustomModuleName){
                $Config = Get-D365LBDConfig -ComputerName $ComputerName -CustomModuleName $CustomModuleName
            }
            else{
            $Config = Get-D365LBDConfig -ComputerName $ComputerName
        }
        }
        $html = "<html> <body>"
        $html += "<h1>$($Config.LCSEnvironmentName) </h1>"
        $html += "<p><b>Custom Code Version:</b></p> $($Config.CustomModuleVersion)"
        $html += "<p><b>AX Kernel Version:</b></p> $($Config.AOSKernelVersion) "
        $html += "<p><b>Environment ID:</b></p> $($config.LCSEnvironmentID)"
        $CountofAXServerNames = $Config.AXSFServerNames.Count
        $html += "<p><b>Amount of AX SF Servers:</b></p> $($CountofAXServerNames) </p>"
        if ($Detailed){
            $html += "<b><p>AX SF Servers: </b></p> <ul>"
            foreach($axsfserver in $Config.AXSFServerNames)
            {
                $html += "<li>$axsfserver</li>"
            }
            $html += "</ul>"
        }
        $html += "<p><b>Number of Orchestrator Servers: </b> $($Config.OrchestratorServerNames.Count)</p>"
        if ($Detailed){
            $html += "<p><b>Orchestrator Servers:</b></p> <ul>"
            foreach($AXOrchServerName in $Config.OrchestratorServerNames)
            {
                $html += "<li>$AXOrchServerName</li>"
            }
            $html += "</ul>"
        }
        $html += "<p><b>AX database is $($Config.DatabaseClusteredStatus)</p>"
        $html += "<p><b>Number of Database servers:</b> $($Config.DatabaseClusterServerNames.Count)</p>"
        $html += "<p><b>Database server(s):</b></p> <ul>"
            foreach($AXDBServerName in $($Config.DatabaseClusterServerNames))
            {
                $html += "<li>$AXDBServerName</li>"
            }
            $html += "</ul>"
        $html += "<p><b>Local Agent Version: $($Config.OrchServiceLocalAgentVersionNumber)</p>"
        $html += "<p><b>SF Client Cert Expires After:</b></p><p> $($Config.SFClientCertificateExpiresAfter)</p>"
        $html += "<p><b>SF Client Cert Expires After:</b></p><p> $($Config.SFServerCertificateExpiresAfter)</p>"
        $html += "<p><b>SF Client Cert Expires After:</b></p><p> $($Config.DataEncryptionCertificateExpiresAfter)</p>"
        $html += "<p><b>SF Client Cert Expires After:</b></p><p> $($Config.DataSigningCertificateExpiresAfter)</p>"
        $html += "<p><b>SF Client Cert Expires After:</b></p><p> $($Config.SessionAuthenticationCertificateExpiresAfter)</p>"
        $html += "<p><b>SF Client Cert Expires After:</b></p><p> $($Config.SharedAccessSMBCertificateExpiresAfter)</p>"
        $html += "<p><b>SF Client Cert Expires After:</b></p><p> $($Config.DataEnciphermentCertificateExpiresAfter)</p>"
        $html += "<p><b>SF Client Cert Expires After:</b></p><p> $($Config.FinancialReportingCertificateExpiresAfter)</p>"
        $html += "<p><b>SF Client Cert Expires After:</b></p><p> $($Config.ReportingSSRSCertificateExpiresAfter)</p>"
        $html += "<p><b>SF Client Cert Expires After:</b></p><p> $($Config.DatabaseEncryptionCertificateExpiresAfter)</p>"
        $html += "<p><b>SF Client Cert Expires After:</b></p><p> $($Config.LocalAgentCertificateExpiresAfter)</p>"
        $html += "</body></html>"
        $html |  Out-File "$ExportLocation"   
  
    }
    END {}
}