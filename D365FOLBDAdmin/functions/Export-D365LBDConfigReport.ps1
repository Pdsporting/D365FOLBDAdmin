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
            HelpMessage = 'D365FO Local Business Data Server Name')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ValueFromPipeline = $True)]
        [psobject]$Config,
        [switch]$Detailed,
        [string]$ExportLocation, ##mandatory should end in html
        [string]$CustomModuleName
    )
    ##Gather Information from the Dynamics 365 Orchestrator Server Config
    BEGIN {
    } 
    PROCESS {
        if (!$Config) {
            if ($CustomModuleName) {
                $Config = Get-D365LBDConfig -ComputerName $ComputerName -CustomModuleName $CustomModuleName
            }
            else {
                $Config = Get-D365LBDConfig -ComputerName $ComputerName
            }
        }


        $html = "<html> <body>"
        $html += "<h1>$($Config.LCSEnvironmentName) </h1>"
        if ($CustomModuleName) {
            $html += "<p><b>Custom Code $CustomModuleName Version:</b></p> $($Config.CustomModuleVersion)"
        }
        $html += "<p><b>AX Kernel Version:</b></p> $($Config.AOSKernelVersion)"
        $html += "<p><b>Environment ID:</b></p> <a href=""$($config.LCSEnvironmentURL)""> $($config.LCSEnvironmentID)</a> "
        if ($Config.AXDatabaseRestoreDate) {
            $html += "<p><b>Database Refresh/Restore Date:</b></p> $($Config.AXDatabaseRestoreDate)  "
            $html += "<p><b>Database Refresh/Restore file:</b></p> $($Config.AXDatabaseBackupFileUsedForRestore) "
        }
        
        $html += "<p><b>Total Apps in Healthy State:</b></p> <a href=""$($config.SFExplorerURL)""> $($Config.NumberOfAppsinServiceFabric) </a> "

        $CountofAXServerNames = $Config.AXSFServerNames.Count
        $html += "<p><b>Amount of AX SF Servers:</b></p> $($CountofAXServerNames) </p>"
        if ($Detailed) {
            $html += "<b><p>AX SF Servers: </b></p> <ul>"
            foreach ($axsfserver in $Config.AXSFServerNames) {
                $html += "<li>$axsfserver</li>"
            }
            $html += "</ul>"
        }
        $html += "<p><b>Number of Orchestrator Servers: </b> $($Config.OrchestratorServerNames.Count)</p>"
        if ($Detailed) {
            $html += "<p><b>Orchestrator Servers:</b></p> <ul>"
            foreach ($AXOrchServerName in $Config.OrchestratorServerNames) {
                $html += "<li>$AXOrchServerName</li>"
            }
            $html += "</ul>"
        }
        $html += "<p><b>AX Database Connection Endpoint:</b></p> $($Config.AXDatabaseServer)"
        $html += "<p><b>AX database is $($Config.DatabaseClusteredStatus)</p>"
        $DBCount = $Config.DatabaseClusterServerNames.Count

        if ($DBCount -gt 1) {
            $html += "<p><b>Number of Database servers:</b> $($Config.DatabaseClusterServerNames.Count)</p>"
            if ($Detailed) {
                $html += "<p><b>Database server(s):</b></p> <ul>"
                foreach ($AXDBServerName in $($Config.DatabaseClusterServerNames)) {
                    $html += "<li>$AXDBServerName</li>"
                }
                $html += "</ul>"
            }
        }
           
        $html += "<p><b>Local Agent Version: $($Config.OrchServiceLocalAgentVersionNumber)</p>"

        if ($Detailed) {
            $html += "<p><b>SF Client Thumbprint:</b></p><p> $($Config.SFClientCertificate)</p>"
        }
        $html += "<p><b>SF Client Cert Expires After:</b></p><p> $($Config.SFClientCertificateExpiresAfter)</p>"

        if ($Detailed) {
            $html += "<p><b>SF Server Thumbprint:</b></p><p> $($Config.SFServerCertificate)</p>"
        }
        $html += "<p><b>SF Server Cert Expires After:</b></p><p> $($Config.SFServerCertificateExpiresAfter)</p>"

        if ($Detailed) {
            $html += "<p><b>Data Encryption Thumbprint:</b></p><p> $($Config.DataEncryptionCertificate)</p>"
        }
        $html += "<p><b>Data Encryption Cert Expires After:</b></p><p> $($Config.DataEncryptionCertificateExpiresAfter)</p>"

        if ($Detailed) {
            $html += "<p><b>Data Signing Thumbprint:</b></p><p> $($Config.DataSigningCertificate)</p>"
        }
        $html += "<p><b>Data Signing Cert Expires After:</b></p><p> $($Config.DataSigningCertificateExpiresAfter)</p>"

        if ($Detailed) {
            $html += "<p><b>Session Authentication Thumbprint:</b></p><p> $($Config.SessionAuthenticationCertificate)</p>"
        }
        $html += "<p><b>Session Authentication Cert Expires After:</b></p><p> $($Config.SessionAuthenticationCertificateExpiresAfter)</p>"

        if ($Detailed) {
            $html += "<p><b>Shared Access SMB Thumbprint:</b></p><p> $($Config.SharedAccessSMBCertificate)</p>"
        }
        $html += "<p><b>Shared Access SMB Cert Expires After:</b></p><p> $($Config.SharedAccessSMBCertificateExpiresAfter)</p>"

        if ($Config.DataEnciphermentCertificateExpiresAfter) {
            if ($Detailed) {
                $html += "<p><b>Data Encipherment Thumbprint:</b></p><p> $($Config.DataEnciphermentCertificate)</p>"
            }
            $html += "<p><b>Data Encipherment Cert Expires After:</b></p><p> $($Config.DataEnciphermentCertificateExpiresAfter)</p>"
        }
        else {
            Write-PSFMessage -Level Warning -Message "DataEncipherment likely not configured in xml"
        }

        if ($Detailed) {
            $html += "<p><b>Financial Reporting (MR) Thumbprint:</b></p><p> $($Config.FinancialReportingCertificate)</p>"
        }
        $html += "<p><b>Financial Reporting (MR) Cert Expires After:</b></p><p> $($Config.FinancialReportingCertificateExpiresAfter)</p>"

        if ($Detailed) {
            $html += "<p><b>Reporting SSRS Thumbprint:</b></p><p> $($Config.ReportingSSRSCertificate)</p>"
        }
        $html += "<p><b>Reporting SSRS Cert Expires After:</b></p><p> $($Config.ReportingSSRSCertificateExpiresAfter)</p>"
       

        if ($Config.DatabaseEncryptionCertificateExpiresAfter) {
            if ($Detailed) {
                $html += "<p><b>Database Encryption Thumbprint:</b></p><p> $($Config.DatabaseEncryptionCertificate)</p>"
            }
            $html += "<p><b>Database Encryption Cert Expires After:</b></p><p> $($Config.DatabaseEncryptionCertificateExpiresAfter)</p>"
        }
        else {
            Write-PSFMessage -Level Warning -Message "DataEncipherment likely not configured in xml"
        }
        if ($Detailed) {
            $html += "<p><b>Local Agent Thumbprint:</b></p><p> $($Config.LocalAgentCertificate)</p>"
        }
        $html += "<p><b>Local Agent Cert Expires After:</b></p><p> $($Config.LocalAgentCertificateExpiresAfter)</p>"
        $html += "</body></html>"
        $html |  Out-File "$ExportLocation"  -Verbose
  
    }
    END {}
}