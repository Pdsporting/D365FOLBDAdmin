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
            $html += "<p><b>Database Refresh/Restore Date:</b></p> $($Config.AXDatabaseRestoreDate) "
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
        $html += "<p><b>AX database is $($Config.DatabaseClusteredStatus)</b></p>"
        $DBCount = $Config.DatabaseClusterServerNames.Count

        if ($DBCount -gt 1) {
            $html += "<p><b>Number of Database servers:</b></p> $($Config.DatabaseClusterServerNames.Count)"
            if ($Detailed) {
                $html += "<p><b>Database server(s):</b></p> <ul>"
                foreach ($AXDBServerName in $($Config.DatabaseClusterServerNames)) {
                    $html += "<li>$AXDBServerName</li>"
                }
                $html += "</ul>"
            }
        }
           
        $html += "<p><b>Local Agent Version:</b></p> $($Config.OrchServiceLocalAgentVersionNumber)</p>"


        $html += '<table style="width:100%"><tr><th>Certificate</th>'
        if ($Detailed) {
            $html += '<th>Thumbprint</th>'
        }
        $html += '<th>Expiration Day</th></tr>'

        $html += '<tr><td>SF Client</td> '
        if ($Detailed) {
            $html += "<td> $($Config.SFClientCertificate)</td>"
        }
        $html += "<td> $($Config.SFClientCertificateExpiresAfter)</td></tr>"

        $html += '<tr><td>SF Server</td> '
        if ($Detailed) {
            $html += "<td>$($Config.SFServerCertificate)</td>"
        }
        $html += "<td> $($Config.SFServerCertificateExpiresAfter)</td></tr>"

        $html += '<tr><td>Data Encryption</td> '
        if ($Detailed) {
            $html += "<td> $($Config.DataEncryptionCertificate)</td>"
        }
        $html += "<td> $($Config.DataEncryptionCertificateExpiresAfter)</td></tr>"

        $html += '<tr><td>Data Signing</td> '
        if ($Detailed) {
            $html += "<td>$($Config.DataSigningCertificate)</td>"
        }
        $html += "<td>$($Config.DataSigningCertificateExpiresAfter)</td></tr>"

        $html += '<tr><td>Session Authentication</td> '
        if ($Detailed) {
            $html += "<td>$($Config.SessionAuthenticationCertificate)</td>"
        }
        $html += "<td>$($Config.SessionAuthenticationCertificateExpiresAfter)</td></tr>"

        $html += '<tr><td>Shared Access</td> '
        if ($Detailed) {
            $html += "<td>$($Config.SharedAccessSMBCertificate)</td>"
        }
        $html += "<td>$($Config.SharedAccessSMBCertificateExpiresAfter)</td></tr>"


        if ($Config.DataEnciphermentCertificateExpiresAfter) {
            $html += '<tr><td>Data Encipherment</td> '
            if ($Detailed) {
                $html += "<td>$($Config.DataEnciphermentCertificate)</td>"
            }
            $html += "<td>$($Config.DataEnciphermentCertificateExpiresAfter)</td></tr>"
        }
        else {
            Write-PSFMessage -Level Warning -Message "DataEncipherment likely not configured in xml"
        }

        $html += '<tr><td>Financial Reporting (MR)</td> '
        if ($Detailed) {
            $html += "<td>$($Config.FinancialReportingCertificate)</td>"
        }
        $html += "<td>$($Config.FinancialReportingCertificateExpiresAfter)</td></tr>"

        $html += '<tr><td>Reporting SSRS </td> '
        if ($Detailed) {
            $html += "<td>$($Config.ReportingSSRSCertificate)</td>"
        }
        $html += "<td>$($Config.ReportingSSRSCertificateExpiresAfter)</td></tr>"
       

        if ($Config.DatabaseEncryptionCertificateExpiresAfter) {
            $html += '<tr><td>Database Encryption </td> '
            if ($Detailed) {
                $html += "<td>$($Config.DatabaseEncryptionCertificate)</td>"
            }
            $html += "<td>$($Config.DatabaseEncryptionCertificateExpiresAfter)</td></tr>"
        }
        else {
            Write-PSFMessage -Level Warning -Message "DataEncipherment likely not configured in xml"
        }

        $html += '<tr><td>Local Agent</td> '
        if ($Detailed) {
            $html += "<td>$($Config.LocalAgentCertificate)</td>"
        }
        $html += "<td>$($Config.LocalAgentCertificateExpiresAfter)</td></tr>"
        $html += "</table>"
       
        $html += "</body></html>"
        $html |  Out-File "$ExportLocation"  -Verbose
  
    }
    END {}
}