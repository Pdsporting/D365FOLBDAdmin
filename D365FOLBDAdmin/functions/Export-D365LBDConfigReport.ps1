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
        Write-PSFMessage -Level VeryVerbose -Message "Running Environment Health Check"
        $Health = Get-D365LBDEnvironmentHealth -config $config
        $HealthGroups = $($Health.Group | Select-Object -unique)
        Write-PSFMessage -Level VeryVerbose -Message "Running Dependency Health Check"
        $DependencyCheck = Get-D365LBDDependencyHealth -Config $config
        $DependencyGroups = $($DependencyCheck.Group | Select-Object -unique)
        $HealthText = "<p class=""Success""><b>D365 Health looks great</b></p>"
        if ($Health.Status -contains "Down") {
            $HealthText = "<p class=""issue""><b>D365 Health issues:</b></p>"
            $healthissues = $Health | Where-Object { $_.Status -eq "Down" }
        }
        $html = "<html> <body>"
        $html += "<h1><a href = ""$($Config.ClientURL)"">$($Config.LCSEnvironmentName)</a> </h1>"
        if ($CustomModuleName) {
            $html += "<p><b>Custom Code $CustomModuleName Version:</b></p> $($Config.CustomModuleVersion)"
        }
        $html += "<p><b>AX Kernel Version:</b></p> $($Config.AOSKernelVersion)"
        $html += "<p><b>LCS Project and Environment ID:</b></p> $($config.LCSProjectID)  -  <a href=""$($config.LCSEnvironmentURL)""> $($config.LCSEnvironmentID)</a> "
      
        if ($Config.AXDatabaseRestoreDate) {
            $html += "<p><b>Database Refresh/Restore Date:</b></p> $($Config.AXDatabaseRestoreDate) "
            if ($Detailed) {
                $html += "<p><b>Database Refresh/Restore file:</b></p> $($Config.AXDatabaseBackupFileUsedForRestore) "
            }
        }
        
        $html += "<p><b>Number of  Apps in Healthy State:</b></p> <a href=""$($config.SFExplorerURL)""> $($Config.NumberOfAppsinServiceFabric) </a> "
        $html += "$HealthText"
        if ($healthissues) {
            foreach ($healthissue in $healthissues) {
                $html += "<p><b>Check:</b> $($healthissue.Name) <b>Source:</b> $($healthissue.Source) <b>Details:</b> $($healthissue.Details) <b>Additional Info:</b> $($healthissue.ExtraInfo) </p>"
            }
        }
        $html += "<b><p>Health Check Groups: </b></p> <ul>"
        foreach ($HealthGroup in $HealthGroups) {
            $html += "<li>$HealthGroup</li>"
        }
        $html += "</ul>"

        if ($DependencyCheck.Count -gt 0) {
            $DependencyCheckText = "<p class=""Success""><b>D365 Environment Dependencies Health looks great.</b></p>"
            if ($DependencyCheck.Status -contains "Down") {
                $DependencyCheckText = "<p class=""issue""><b>D365 Health issues:</b></p>"
                $DependencyCheckissues = $DependencyCheck | Where-Object { $_.Status -eq "Down" }
            }
            $html += "$DependencyCheckText"
            if ($DependencyCheckissues) {
                foreach ($DependencyCheckissue in $DependencyCheckissues) {
                    $html += "<p><b>Check:</b> $($DependencyCheckissue.Name) <b>Source:</b> $($DependencyCheckissue.Source) <b>Details:</b> $($DependencyCheckissue.Details)  <b>Additional Info:</b> $($DependencyCheckissue.ExtraInfo) </p></p> "
                }
            }
            $html += "<b><p>Dependency Groups: </b></p> <ul>"
            foreach ($DependencyGroup in $DependencyGroups) {
                $html += "<li>$DependencyGroup</li>"
            }
            $html += "</ul>"
 
        }
        $html += "<p><b>Orchestrator Job State:</b> $($Config.OrchestratorJobState)  <b>Last Ran Orchestrator Job ID:</b> $($Config.LastOrchJobId) </p>"
        $html += "<p><b>Run Book Task State:</b> $($Config.OrchestratorJobRunBookState)  <b>Last Ran Run Book Task ID:</b> $($Config.LastRunbookTaskId) </p>"
       

        $CountofAXServerNames = $Config.AXSFServerNames.Count
        $html += "<p><b>Number of AX SF Servers:</b></p> $($CountofAXServerNames)"
        if ($Detailed) {
            $html += "<b><p>AX SF Servers: </b></p> <ul>"
            foreach ($axsfserver in $Config.AXSFServerNames) {
                $html += "<li>$axsfserver</li>"
            }
            $html += "</ul>"
        }
        $html += "<p><b>Number of Orchestrator Servers: </b> </p>$($Config.OrchestratorServerNames.Count)</p>"
        if ($Detailed) {
            $html += "<p><b>Orchestrator Servers:</b></p> <ul>"
            foreach ($AXOrchServerName in $Config.OrchestratorServerNames) {
                $html += "<li>$AXOrchServerName</li>"
            }
            $html += "</ul>"
        }
        if ($Detailed) {  
            $html += "<p><b>AX Database Connection Endpoint:</b></p> $($Config.AXDatabaseServer)"
        }

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

        $html += "<p><b>Number of SSRS Report Servers: </b> </p>$($Config.SSRSClusterServerNames.Count)</p>"
        if ($Detailed) {
            $html += "<p><b>SSRS Servers:</b></p> <ul>"
            foreach ($SSRSClusterServerName in $Config.SSRSClusterServerNames) {
                $html += "<li>$SSRSClusterServerName</li>"
            }
            $html += "</ul>"
        }

        if ($Config.ComponentsinSetupModule -contains "financialreporting") {  
            $html += "<p><b>Number of Management Reporter Servers: </b> </p>$($Config.ManagementReporterServers.Count)</p>"
            if ($Detailed) {
                $html += "<p><b>Management Reporter Servers:</b></p> <ul>"
                foreach ($ManagementReporterServer in $Config.ManagementReporterServers) {
                    $html += "<li>$ManagementReporterServer</li>"
                }
                $html += "</ul>"
            }
        }
           
        $html += "<p><b>Local Agent Version:</b></p> $($Config.OrchServiceLocalAgentVersionNumber)</p>"

        $html += '<table style="width:100%" class="Thumbprints"><tr><th>Certificate</th>'
        if ($Detailed) {
            $html += '<th>Thumbprint</th>'
        }
        $html += '<th>Expiration Date</th></tr>'

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
       
        if ($Config.DatabaseEncryptionCertificates) {
            foreach ($DatabaseEncryptionCertificate in $Config.DatabaseEncryptionCertificates) {

                $html += '<tr><td>Database Connection Configured Encryption </td> '
                if ($Detailed) {
                    $html += "<td>$($DatabaseEncryptionCertificate)</td>"
                }
                if ($Config.DatabaseEncryptionCertificateExpiresAfter) {
                    $html += "<td>$($Config.DatabaseEncryptionCertificateExpiresAfter)</td></tr>"
                }
                else {
                    $html += "<td>Can't get Expiration (Permissions on SQL OS level)</td></tr>"
                }
            }
        }
        else {
            Write-PSFMessage -Level Warning -Message "Database Encryption not configured in xml or access issues to Database server"
        }

        $html += '<tr><td>Local Agent</td> '
        if ($Detailed) {
            $html += "<td>$($Config.LocalAgentCertificate)</td>"
        }
        $html += "<td>$($Config.LocalAgentCertificateExpiresAfter)</td></tr>"
        $html += "</table>"

        if ($Detailed) {
            $guids = Get-D365LBDAXSFGUIDS -Config $Config
            $html += "<p></p><table style=""width:100%"" class=""GUIDS"">  <tr>    <th>Server</th>    <th>GUID</th>    <th>Endpoint</th>  </tr>"
            
            foreach ($guid in $guids) {
                $html += "<tr><td>$($guid.Source)</td><td>$($guid.Details)</td><td><a href=""$($guid.ExtraInfo)"">$($guid.ExtraInfo)</a></td></tr>"
            }
            $html += "</table>"
        }
        
        $html += "</body></html>"
        $html |  Out-File "$ExportLocation"  -Verbose
  
    }
    END {}
}