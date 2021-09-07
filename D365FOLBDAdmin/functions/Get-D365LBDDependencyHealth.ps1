function Get-D365LBDDependencyHealth {
    <#
    .SYNOPSIS
   Checks and validates the dependencies configured in the AdditionalEnvironmentDetails.xml 
   .DESCRIPTION
    Checks and validates the dependencies configured in the AdditionalEnvironmentDetails.xml This can check web addresses, services running, processes open, and databases being accessible.
    This is recommended to be ran from the environment itself as some dependencies are better ran from the required environment.
   .EXAMPLE
    Get-D365LBDDependencyHealth
   Checks and validates the dependencies configured in the AdditionalEnvironmentDetails.xml on the local server's environment
   .EXAMPLE
   Get-D365LBDDependencyHealth -config $Config 
   Checks and validates the dependencies configured in the AdditionalEnvironmentDetails.xml on the defined configuration's environment
   .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module
   .PARAMETER CustomModuleName
   optional string 
   The name of the custom module you will be using to capture the version number
   .PARAMETER WebsiteChecksOnly
   switch
   If you want to only check the website dependencies
   .PARAMETER SendAlertIfIssue
    switch
   If you want to only to send alerts when there is a found issue with a dependency
   .PARAMETER SMTPServer
   string
   Email smtp server to email the alerts if issue (that switch must be on as well)
   .PARAMETER MSTeamsURI
   string
   MSTeams URI smtp server to email the alerts if issue (that switch must be on as well)
   #>
    [alias("Get-D365DependencyHealth")]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name',
            ParameterSetName = 'NoConfig')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ParameterSetName = 'Config',
            ValueFromPipeline = $True)]
        [psobject]$Config,
        [string]$CustomModuleName,
        [switch]$WebsiteChecksOnly,
        [switch]$SendAlertIfIssue,
        [string]$SMTPServer,
        [string]$MSTeamsURI
    )
    ##Gather Information from the Dynamics 365 Orchestrator Server Config
    BEGIN {
    } 
    PROCESS {
        if (!$Config -or $Config.OrchestratorServerNames.Count -eq 0) {
            if ($CustomModuleName) {
                $Config = Get-D365LBDConfig -ComputerName $ComputerName -CustomModuleName $CustomModuleName -highlevelonly
            }
            else {
                $Config = Get-D365LBDConfig -ComputerName $ComputerName -highlevelonly
            }
        }
        $AgentShareLocation = $config.AgentShareLocation 
        $OutputList = @()
        $EnvironmentAdditionalConfig = get-childitem  "$AgentShareLocation\scripts\D365FOLBDAdmin\AdditionalEnvironmentDetails.xml"
        if (!$EnvironmentAdditionalConfig) {
            Stop-PSFFunction -Message "Error: AdditionalEnvironmentDetails.xml not configured at $AgentShareLocation\scripts\D365FOLBDAdmin" -EnableException $true -FunctionName $_
        }
        [xml]$EnvironmentAdditionalConfigXML = get-content $EnvironmentAdditionalConfig.FullName

        ##checking WebURLS
        $EnvironmentAdditionalConfigXML.D365LBDEnvironment.Dependencies.CustomWebURLDependencies.CustomWebURL | ForEach-Object -Process { 
            $Note = $_.Note
            if ($_.Type.'#text'.Trim() -eq 'Basic') {
                ##Basic WebURL Start
                $results = Invoke-WebRequest -Uri $_.uri -UseBasicParsing
                if ($results.statusCode -eq 200 -or $results.statusCode -eq 203 -or $results.statusCode -eq 204 ) {
                    $Output = New-Object -TypeName PSObject -Property `
                    @{'Source'      = $env:COMPUTERNAME ;
                        'Name'      = $_.uri ;
                        'State'     = "Operational";
                        'ExtraInfo' = $results.Statuscode
                        'Group'     = 'Web Service/Page Web Basic'
                    }
                    $OutputList += $Output
                }
                else {
                    $Output += New-Object -TypeName PSObject -Property `
                    @{'Source'      = $env:COMPUTERNAME ;
                        'Name'      = $_.uri ;
                        'State'     = "Down";
                        'ExtraInfo' = $results.Statuscode
                        'Group'     = 'Web Service/Page Web Basic'
                    }
                }
            }
            else {
                ##Advanced Weburl start
                $childnodes = $($_.AdvancedCustomSuccessResponse | Select-Object childnodes).childnodes
                $properties = $childnodes | Get-Member -MemberType Property
                $propertiestocheck = $properties.Name
                [int]$countofproperties = $propertiestocheck.count
                $results = Invoke-RestMethod -Uri $_.uri -UseBasicParsing
                if ($countofproperties -eq 0 -or $countofproperties -eq 1 ) {
                    ##only one or 0 child items start
                    $diff = Compare-Object $results -DifferenceObject $($childnodes.'#text'.Trim())
                    if ($diff) {
                        Write-PSFMessage -message "Found differences $diff" -Level VeryVerbose
                        $Output = New-Object -TypeName PSObject -Property `
                        @{'Source'      = $env:COMPUTERNAME ;
                            'Name'      = $_.uri ;
                            'State'     = "Down";
                            'ExtraInfo' = $Note
                            'Group'     = 'Web Service/Page Web Advanced'
                        }
                        $OutputList += $Output
                    }
                    else {
                        ##no differences found so success
                        $Output = New-Object -TypeName PSObject -Property `
                        @{'Source'      = $env:COMPUTERNAME ;
                            'Name'      = $_.uri ;
                            'State'     = "Operational";
                            'ExtraInfo' = $Note
                            'Group'     = 'Web Service/Page Web Advanced'
                        }
                        $OutputList += $Output
                    }  ##only one or 0 child items end
                }##multiple items to check start 
                else {
                    foreach ($property in $propertiestocheck) {
                        $diff = compare-object $results.data.$property -DifferenceObject $childnodes.$property.trim()
                        if ($diff) {
                            Write-PSFMessage -message "Found differences $diff" -Level VeryVerbose
                            $Output = New-Object -TypeName PSObject -Property `
                            @{'Source'      = $env:COMPUTERNAME ;
                                'Name'      = $_.uri ;
                                'State'     = "Down";
                                'ExtraInfo' = $results.Statuscode
                                'Group'     = 'Web Service/Page Web Advanced'
                            }
                            $OutputList += $Output
                        }
                        else {
                            $Output = New-Object -TypeName PSObject -Property `
                            @{'Source'      = $env:COMPUTERNAME ;
                                'Name'      = $_.uri ;
                                'State'     = "Operational";
                                'ExtraInfo' = $results.Statuscode;
                                'Group'     = 'Web Service/Page Web Advanced'
                            }
                            $OutputList += $Output
                        }
                    }
                } 
            } ## Advanced Weburl End
        }##End of All Custom WebURL
        if ($WebsiteChecksOnly) {
            Write-PSFMessage -Level VeryVerbose -Message "Only Checking Websites"
        }
        else {
            Write-PSFMessage -Level VeryVerbose -Message "Checking for server dependencies"
            $servicestovalidate = $EnvironmentAdditionalConfigXML.D365LBDEnvironment.Dependencies.ServerDependencies.Dependency | Where-Object { $_.Type.'#text'.Trim() -eq "service" }
            foreach ($servicetovalidate in $servicestovalidate) {
                ##Services Start
                if ($servicestovalidate.locationType.'#text'.Trim() -eq 'AXSF') {
                    foreach ($AXSfServerName in $Config.AXSFServerNames) {
                        $servicetovalidateName = $servicetovalidate.Name
                        $results = Invoke-Command -ComputerName $AXSfServerName -ScriptBlock { Get-service $Using:servicetovalidateName } 
                        if ($results.Status -eq "Running") {
                            $results | ForEach-Object -Process { `
                                    $Output = New-Object -TypeName PSObject -Property `
                                @{'Source'      = $AXSfServerName ;
                                    'Name'      = "$servicetovalidateName"; 
                                    'State'     = "Operational";
                                    'ExtraInfo' = $_.StartType;
                                    'Group'     = 'AXSFService'
                                }
                                $OutputList += $Output
                            }
                        } ##Operational start
                        else {
                            $results | ForEach-Object -Process { `
                                    $Output = New-Object -TypeName PSObject -Property `
                                @{'Source'      = $AXSfServerName ;
                                    'Name'      = "$servicetovalidateName"; 
                                    'State'     = "Down";
                                    'ExtraInfo' = $_.StartType;
                                    'Group'     = 'AXSFService'
                                }
                                $OutputList += $Output
                            }
                        }##Failure end
                    }
                }
                if ($servicestovalidate.locationType.'#text'.Trim() -eq 'SSRS') {
                    foreach ($SSRSClusterServerName in $Config.SSRSClusterServerNames) {
                        $results = Invoke-Command -ComputerName $SSRSClusterServerName -ScriptBlock { Get-service $Using:servicetovalidateName } 
                        if ($results.Status -eq "Running") {
                            $results | ForEach-Object -Process { `
                                    $Output = New-Object -TypeName PSObject -Property `
                                @{'Source'      = $SSRSClusterServerName ;
                                    'Name'      = "$servicetovalidateName"; 
                                    'State'     = "Operational";
                                    'ExtraInfo' = $_.StartType;
                                    'Group'     = 'SSRSService'
                                }
                                $OutputList += $Output
                            }
                        } ##Operational start
                        else {
                            $results | ForEach-Object -Process { `
                                    $Output = New-Object -TypeName PSObject -Property `
                                @{'Source'      = $SSRSClusterServerName ;
                                    'Name'      = "$servicetovalidateName"; 
                                    'State'     = "Down";
                                    'ExtraInfo' = $_.StartType;
                                    'Group'     = 'SSRSService'
                                }
                                $OutputList += $Output
                            }
                        }##Failure end
                    }
                }
                if ($servicestovalidate.locationType.'#text'.Trim() -eq 'SQLDB') {
                    foreach ($DatabaseClusterServerName in $config.DatabaseClusterServerNames) {
                        $results = Invoke-Command -ComputerName $DatabaseClusterServerName -ScriptBlock { Get-service $Using:servicetovalidateName } 
                        if ($results.Status -eq "Running") {
                            $results | ForEach-Object -Process { `
                                    $Output = New-Object -TypeName PSObject -Property `
                                @{'Source'      = $DatabaseClusterServerName ;
                                    'Name'      = "$servicetovalidateName"; 
                                    'State'     = "Operational";
                                    'ExtraInfo' = $_.StartType;
                                    'Group'     = 'SQLDBService'
                                }
                                $OutputList += $Output
                            }
                        } ##Operational start
                        else {
                            $results | ForEach-Object -Process { `
                                    $Output = New-Object -TypeName PSObject -Property `
                                @{'Source'      = $DatabaseClusterServerName ;
                                    'Name'      = "$servicetovalidateName"; 
                                    'State'     = "Down";
                                    'ExtraInfo' = $_.StartType;
                                    'Group'     = 'SQLDBService'
                                }
                                $OutputList += $Output
                            }
                        }##Failure end
                    }
                }
                if ($servicestovalidate.locationType.'#text'.Trim() -eq 'ManagementReporter') {
                    foreach ($ManagementReporterServer in $ManagementReporterServers) {
                        $results = Invoke-Command -ComputerName $ManagementReporterServer -ScriptBlock { Get-service $Using:servicetovalidateName } 
                        if ($results.Status -eq "Running") {
                            $results | ForEach-Object -Process { `
                                    $Output = New-Object -TypeName PSObject -Property `
                                @{'Source'      = $ManagementReporterServer ;
                                    'Name'      = "$servicetovalidateName"; 
                                    'State'     = "Operational";
                                    'ExtraInfo' = $_.StartType;
                                    'Group'     = 'ManagementReporterService'
                                }
                                $OutputList += $Output
                            }
                        } ##Operational start
                        else {
                            $results | ForEach-Object -Process { `
                                    $Output = New-Object -TypeName PSObject -Property `
                                @{'Source'      = $ManagementReporterServer ;
                                    'Name'      = "$servicetovalidateName"; 
                                    'State'     = "Down";
                                    'ExtraInfo' = $_.StartType;
                                    'Group'     = 'ManagementReporterService'
                                }
                                $OutputList += $Output
                            }
                        }##Failure end
                    }
                }
                if ($servicestovalidate.locationType.'#text'.Trim() -eq 'All') {
                    foreach ($AppServer in $Config.AllAppServerList) {
                        $results = Invoke-Command -ComputerName $AppServer -ScriptBlock { Get-service $Using:servicetovalidateName } 
                        if ($results.Status -eq "Running") {
                            $results | ForEach-Object -Process { `
                                    $Output = New-Object -TypeName PSObject -Property `
                                @{'Source'      = $AppServer ;
                                    'Name'      = "$servicetovalidateName"; 
                                    'State'     = "Operational";
                                    'ExtraInfo' = $_.StartType;
                                    'Group'     = 'AllServersService'
                                }
                                $OutputList += $Output
                            }
                        } ##Operational start
                        else {
                            $results | ForEach-Object -Process { `
                                    $Output = New-Object -TypeName PSObject -Property `
                                @{'Source'      = $AppServer ;
                                    'Name'      = "$servicetovalidateName"; 
                                    'State'     = "Down";
                                    'ExtraInfo' = $_.StartType;
                                    'Group'     = 'AllServersService'
                                }
                                $OutputList += $Output
                            }
                        }##Failure end
                    }
                }
            }##Services End

            $processestovalidate = $EnvironmentAdditionalConfigXML.D365LBDEnvironment.Dependencies.ServerDependencies.Dependency | Where-Object { $_.Type.'#text'.Trim() -eq "process" }
            ##Process
            foreach ($processtovalidate in $processestovalidate) {
                $ProcessName = $processtovalidate.name
                if ($processtovalidate.locationType.'#text'.Trim() -eq 'AXSF') {
                    foreach ($AXSfServerName in $Config.AXSFServerNames) {
                        $results = Invoke-Command -ComputerName $AXSfServerName -ScriptBlock { Get-process | where-object { $_.Name -eq $Using:ProcessName } | Select-Object -First 1 } 
                        if ($results) {
                            $Output = New-Object -TypeName PSObject -Property `
                            @{'Source'      = $AXSfServerName ;
                                'Name'      = "$ProcessName"; 
                                'State'     = "Operational";
                                'ExtraInfo' = $_.StartType;
                                'Group'     = 'AXServerProcess'
                            }
                        }
                        else {
                            $Output = New-Object -TypeName PSObject -Property `
                            @{'Source'      = $AXSfServerName ;
                                'Name'      = "$ProcessName"; 
                                'State'     = "Down";
                                'ExtraInfo' = $_.StartType;
                                'Group'     = 'AXServerProcess'
                            }
                        }
                        $OutputList += $Output
                    }
                }
            
                if ($processtovalidate.locationType.'#text'.Trim() -eq 'SSRS') {
                    foreach ($SSRSClusterServerName in $Config.SSRSClusterServerNames) {
                        $results = Invoke-Command -ComputerName $SSRSClusterServerName -ScriptBlock { Get-process | where-object { $_.Name -eq $Using:ProcessName }  | Select-Object -First 1 } 
                        if ($results) {
                            $Output = New-Object -TypeName PSObject -Property `
                            @{'Source'      = $SSRSClusterServerName ;
                                'Name'      = "$ProcessName"; 
                                'State'     = "Operational";
                                'ExtraInfo' = $_.StartType;
                                'Group'     = 'SSRSServerProcess'
                            }
                        }
                        else {
                            $Output = New-Object -TypeName PSObject -Property `
                            @{'Source'      = $SSRSClusterServerName ;
                                'Name'      = "$ProcessName"; 
                                'State'     = "Down";
                                'ExtraInfo' = $_.StartType;
                                'Group'     = '$SSRSServerProcess'
                            }
                        }
                        $OutputList += $Output
                    }
                }
                if ($processtovalidate.locationType.'#text'.Trim() -eq 'SQLDB') {
                    foreach ($DatabaseClusterServerName in $config.DatabaseClusterServerNames) {
                        $results = Invoke-Command -ComputerName $DatabaseClusterServerName -ScriptBlock { Get-process | where-object { $_.Name -eq $Using:ProcessName } | Select-Object -First 1 } 
                        if ($results) {
                            $Output = New-Object -TypeName PSObject -Property `
                            @{'Source'      = $DatabaseClusterServerName ;
                                'Name'      = "$ProcessName"; 
                                'State'     = "Operational";
                                'ExtraInfo' = $_.StartType;
                                'Group'     = 'DatabaseClusterServerProcess'
                            }
                        }
                        else {
                            $Output = New-Object -TypeName PSObject -Property `
                            @{'Source'      = $DatabaseClusterServerName ;
                                'Name'      = "$ProcessName"; 
                                'State'     = "Down";
                                'ExtraInfo' = $_.StartType;
                                'Group'     = 'DatabaseClusterServerProcess'
                            }
                        }
                        $OutputList += $Output
                    }
                }
            
                if ($processtovalidate.locationType.'#text'.Trim() -eq 'ManagementReporter') {
                    foreach ($ManagementReporterServer in $ManagementReporterServers) {
                        $results = Invoke-Command -ComputerName $ManagementReporterServer -ScriptBlock { Get-process | where-object { $_.Name -eq $Using:ProcessName } | Select-Object -First 1 } 
                        if ($results) {
                            $Output = New-Object -TypeName PSObject -Property `
                            @{'Source'      = $ManagementReporterServer ;
                                'Name'      = "$ProcessName"; 
                                'State'     = "Operational";
                                'ExtraInfo' = $_.StartType;
                                'Group'     = 'ManagementReporterProcess'
                            }
                        }
                        else {
                            $Output = New-Object -TypeName PSObject -Property `
                            @{'Source'      = $ManagementReporterServer ;
                                'Name'      = "$ProcessName"; 
                                'State'     = "Down";
                                'ExtraInfo' = $_.StartType;
                                'Group'     = 'ManagementReporterProcess'
                            }
                        }
                        $OutputList += $Output
                    } 
                }
                if ($processtovalidate.locationType.'#text'.Trim() -eq 'All') {
                    foreach ($AppServer in $Config.AllAppServerList) {
                        $results = Invoke-Command -ComputerName $AppServer -ScriptBlock { Get-process | where-object { $_.Name -eq $Using:ProcessName }  | Select-Object -First 1 } 
                        if ($results) {
                            $Output = New-Object -TypeName PSObject -Property `
                            @{'Source'      = $AppServer ;
                                'Name'      = "$ProcessName"; 
                                'State'     = "Operational";
                                'ExtraInfo' = $_.StartType;
                                'Group'     = 'AllProcess'
                            }
                        }
                        else {
                            $Output = New-Object -TypeName PSObject -Property `
                            @{'Source'      = $AppServer ;
                                'Name'      = "$ProcessName"; 
                                'State'     = "Down";
                                'ExtraInfo' = $_.StartType;
                                'Group'     = 'AllProcess'
                            }
                        }
                        $OutputList += $Output
                    }
                }
            }
            ##Database
        }
        $FoundIssue = $false
        foreach ($scanneditem in $Output) {
            if ($scanneditem.State -eq "Down") {
                Write-PSFMessage -Message "Found an item down: $Scanneditem" -Level VeryVerbose
                $FoundIssue = $True
                if ($SendAlertIfIssue) {
                    $EnvironmentOwnerEmail = $EnvironmentAdditionalConfigXML.D365LBDEnvironment.EnvironmentAdditionalConfig.EnvironmentOwnerEmail
                    if ($SMTPServer) {
                        Write-PSFMessage -Level VeryVerbose -Message "Sending email to $EnvironmentOwnerEmail using $SMTPServer"
                        Send-MailMessage -to "$EnvironmentOwnerEmail" -Body "$scanneditem is down for $($Config.LCSEnvironmentName) " -Verbose -SmtpServer "$SMTPServer" -Subject "D365 Found issue with $($Config.LCSEnvironmentName)"
                    }
                    else {
                        Write-PSFMessage -Level VeryVerbose -Message "WARNING: Configure SMTP Server to send emails"

                    }
                    if ($MSTeamsURI) {
                        Send-D365LBDUpdateMSTeams -messageType "StatusReport" -MSTeamsURI "$MSTeamsURI"
                    }
                    else {
                        $MSTEAMSURLS = $EnvironmentAdditionalConfigXML.D365LBDEnvironment.Communication.Webhooks.Webhook | Where-Object { $_.type.'#text'.trim() -eq "MSTEAMS" } | select ChannelWebHookURL
                        foreach ($MSTEAMSURL in $MSTEAMSURLS) {
                            Send-D365LBDUpdateMSTeams -messageType "StatusReport" -MSTeamsURI "htts://fakemicrosoft.office.com/webhookb2/98984684987156465-4654/incominginwebhook/ea5s6d4sa6" -config $Config
                        }
                    }
                }
            }
        }
        [PSCustomObject] $OutputList
    }
    END {
        if ($SFModuleSession) {
            Remove-PSSession -Session $SFModuleSession  
        }
    }
}
