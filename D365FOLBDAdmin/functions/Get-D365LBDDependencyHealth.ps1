function Get-D365LBDDependencyHealth {
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
        [string]$SMTPServer
    )
    ##Gather Information from the Dynamics 365 Orchestrator Server Config
    BEGIN {
    } 
    PROCESS {
        if (!$Config) {
            if ($CustomModuleName) {
                $Config = Get-D365LBDConfig -ComputerName $ComputerName -CustomModuleName $CustomModuleName -highlevelonly
            }
            else {
                $Config = Get-D365LBDConfig -ComputerName $ComputerName -highlevelonly
            }
        }
        $AgentShareLocation = $config.AgentShareLocation 
        $EnvironmentAdditionalConfig = get-childitem  "$AgentShareLocation\scripts\D365FOLBDAdmin\AdditionalEnvironmentDetails.xml"
        [xml]$EnvironmentAdditionalConfigXML = get-content $EnvironmentAdditionalConfig.FullName
        $OutputList = @()

        ##checking WebURLS
        $EnvironmentAdditionalConfigXML.D365LBDEnvironment.Dependencies.CustomWebURLDependencies.CustomWebURL | ForEach-Object -Process { 
            $Note = $_.Note
            if ($_.Type.'#text'.Trim() -eq 'Basic') {
                ##Basic WebURL Start
                $results = Invoke-WebRequest -Uri $_.uri -UseBasicParsing
                if ($results.statusCode -eq 200 -or $results.statusCode -eq 203 -or $results.statusCode -eq 204 ) {
                    $Output = New-Object -TypeName PSObject -Property `
                    @{'Source'           = $env:COMPUTERNAME ;
                        'DependencyType' = "Web Service/Page";
                        'Name'           = $_.uri ;
                        'State'          = "Operational";
                        'ExtraInfo'      = $results.Statuscode
                    }
                    $OutputList += $Output
                }
                else {
                    $Output += New-Object -TypeName PSObject -Property `
                    @{'Source'           = $env:COMPUTERNAME ;
                        'DependencyType' = "Web Service/Page";
                        'Name'           = $_.uri ;
                        'State'          = "Down";
                        'ExtraInfo'      = $results.Statuscode
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
                        @{'Source'           = $env:COMPUTERNAME ;
                            'DependencyType' = "Web Service/Page";
                            'Name'           = $_.uri ;
                            'State'          = "Down";
                            'ExtraInfo'      = $Note
                        }
                        $OutputList += $Output
                    }
                    else {
                        ##no differences found so success
                        $Output = New-Object -TypeName PSObject -Property `
                        @{'Source'           = $env:COMPUTERNAME ;
                            'DependencyType' = "Web Service/Page";
                            'Name'           = $_.uri ;
                            'State'          = "Operational";
                            'ExtraInfo'      = $Note
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
                            @{'Source'           = $env:COMPUTERNAME ;
                                'DependencyType' = "Web Service/Page";
                                'Name'           = $_.uri ;
                                'State'          = "Down";
                                'ExtraInfo'      = $results.Statuscode
                            }
                            $OutputList += $Output
                        }
                        else {
                            $Output = New-Object -TypeName PSObject -Property `
                            @{'Source'           = $env:COMPUTERNAME ;
                                'DependencyType' = "Web Service/Page";
                                'Name'           = $_.uri ;
                                'State'          = "Operational";
                                'ExtraInfo'      = $results.Statuscode;
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
                        $servicetovalidateName =  $servicetovalidate.Name
                        $results = Invoke-Command -ComputerName $AXSfServerName -ScriptBlock { Get-service $Using:servicetovalidateName } | ForEach-Object -Process { `
                                if ($results.Status -eq "Running") {
                                $results | ForEach-Object -Process { `
                                        $Output = New-Object -TypeName PSObject -Property `
                                    @{'Source'           = $env:COMPUTERNAME ;
                                        'DependencyType' = "Service";
                                        'Name'           = "$Using:servicetovalidateName"; 
                                        'State'          = "Operational";
                                        'ExtraInfo'      = $_.StartType;
                                    }
                                    $OutputList += $Output
                                }
                            } ##Operational start
                            else {
                                $results | ForEach-Object -Process { `
                                        $Output = New-Object -TypeName PSObject -Property `
                                    @{'Source'           = $env:COMPUTERNAME ;
                                        'DependencyType' = "Service";
                                        'Name'           = "$Using:servicetovalidateName"; 
                                        'State'          = "Down";
                                        'ExtraInfo'      = $_.StartType;
                                    }
                                    $OutputList += $Output
                                }
                            }##Failure end
                        }
                    }
                }
                if ($servicestovalidate.locationType.'#text'.Trim() -eq 'SSRS') {
                    foreach ($SSRSClusterServerName in $Config.SSRSClusterServerNames) {
                        $results = Invoke-Command -ComputerName $SSRSClusterServerName -ScriptBlock { Get-service $Using:servicetovalidateName } | ForEach-Object -Process { `
                                if ($results.Status -eq "Running") {
                                $results | ForEach-Object -Process { `
                                        $Output = New-Object -TypeName PSObject -Property `
                                    @{'Source'           = $env:COMPUTERNAME ;
                                        'DependencyType' = "Service";
                                        'Name'           = "$Using:servicetovalidateName"; 
                                        'State'          = "Operational";
                                        'ExtraInfo'      = $_.StartType;
                                    }
                                    $OutputList += $Output
                                }
                            } ##Operational start
                            else {
                                $results | ForEach-Object -Process { `
                                        $Output = New-Object -TypeName PSObject -Property `
                                    @{'Source'           = $env:COMPUTERNAME ;
                                        'DependencyType' = "Service";
                                        'Name'           = "$Using:servicetovalidateName"; 
                                        'State'          = "Down";
                                        'ExtraInfo'      = $_.StartType;
                                    }
                                    $OutputList += $Output
                                }
                            }##Failure end
                        }
                    }
                }
                if ($servicestovalidate.locationType.'#text'.Trim() -eq 'SQLDB') {
                    foreach ($DatabaseClusterServerName in $config.DatabaseClusterServerNames) {
                        $results = Invoke-Command -ComputerName $DatabaseClusterServerName -ScriptBlock { Get-service $Using:servicetovalidateName} | ForEach-Object -Process { `
                                if ($results.Status -eq "Running") {
                                $results | ForEach-Object -Process { `
                                        $Output = New-Object -TypeName PSObject -Property `
                                    @{'Source'           = $env:COMPUTERNAME ;
                                        'DependencyType' = "Service";
                                        'Name'           = "$Using:servicetovalidateName"; 
                                        'State'          = "Operational";
                                        'ExtraInfo'      = $_.StartType;
                                    }
                                    $OutputList += $Output
                                }
                            } ##Operational start
                            else {
                                $results | ForEach-Object -Process { `
                                        $Output = New-Object -TypeName PSObject -Property `
                                    @{'Source'           = $env:COMPUTERNAME ;
                                        'DependencyType' = "Service";
                                        'Name'           = "$Using:servicetovalidateName"; 
                                        'State'          = "Down";
                                        'ExtraInfo'      = $_.StartType;
                                    }
                                    $OutputList += $Output
                                }
                            }##Failure end
                        }
                    }
                }
                if ($servicestovalidate.locationType.'#text'.Trim() -eq 'ManagementReporter') {
                    foreach ($ManagementReporterServer in $ManagementReporterServers) {
                        $results = Invoke-Command -ComputerName $ManagementReporterServer -ScriptBlock { Get-service $Using:servicetovalidateName } | ForEach-Object -Process { `
                                if ($results.Status -eq "Running") {
                                $results | ForEach-Object -Process { `
                                        $Output = New-Object -TypeName PSObject -Property `
                                    @{'Source'           = $env:COMPUTERNAME ;
                                        'DependencyType' = "Service";
                                        'Name'           = "$Using:servicetovalidateName"; 
                                        'State'          = "Operational";
                                        'ExtraInfo'      = $_.StartType;
                                    }
                                    $OutputList += $Output
                                }
                            } ##Operational start
                            else {
                                $results | ForEach-Object -Process { `
                                        $Output = New-Object -TypeName PSObject -Property `
                                    @{'Source'           = $env:COMPUTERNAME ;
                                        'DependencyType' = "Service";
                                        'Name'           = "$Using:servicetovalidateName"; 
                                        'State'          = "Down";
                                        'ExtraInfo'      = $_.StartType;
                                    }
                                    $OutputList += $Output
                                }
                            }##Failure end
                        }
                    }
                }
                if ($servicestovalidate.locationType.'#text'.Trim() -eq 'All') {
                    foreach ($AppServer in $Config.AllAppServerList) {
                        $results = Invoke-Command -ComputerName $AppServer -ScriptBlock { Get-service $Using:servicetovalidateName } 
                        if ($results.Status -eq "Running") {
                            $results | ForEach-Object -Process { `
                                    $Output = New-Object -TypeName PSObject -Property `
                                @{'Source'           = $env:COMPUTERNAME ;
                                    'DependencyType' = "Service";
                                    'Name'           = "$Using:servicetovalidateName"; 
                                    'State'          = "Operational";
                                    'ExtraInfo'      = $_.StartType;
                                }
                                $OutputList += $Output
                            }
                        } ##Operational start
                        else {
                            $results | ForEach-Object -Process { `
                                    $Output = New-Object -TypeName PSObject -Property `
                                @{'Source'           = $env:COMPUTERNAME ;
                                    'DependencyType' = "Service";
                                    'Name'           = "$Using:servicetovalidateName"; 
                                    'State'          = "Down";
                                    'ExtraInfo'      = $_.StartType;
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
                        Invoke-Command -ComputerName $AXSfServerName -ScriptBlock { Get-process -name $Using:ProcessName | Select-Object -First 1 } | ForEach-Object -Process { `
                        }
                    }
                }
                if ($processtovalidate.locationType.'#text'.Trim() -eq 'SSRS') {
                    foreach ($SSRSClusterServerName in $Config.SSRSClusterServerNames) {
                        Invoke-Command -ComputerName $SSRSClusterServerName -ScriptBlock { Get-process -name $Using:ProcessName  | Select-Object -First 1 } | ForEach-Object -Process { `
                        }
                    }
                }
                if ($processtovalidate.locationType.'#text'.Trim() -eq 'SQLDB') {
                    foreach ($DatabaseClusterServerName in $config.DatabaseClusterServerNames) {
                        Invoke-Command -ComputerName $DatabaseClusterServerName -ScriptBlock { Get-process -name $Using:ProcessName  | Select-Object -First 1 } | ForEach-Object -Process { `
                        }
                    }
                }
                if ($processtovalidate.locationType.'#text'.Trim() -eq 'ManagementReporter') {
                    foreach ($ManagementReporterServer in $ManagementReporterServers) {
                        Invoke-Command -ComputerName $ManagementReporterServer -ScriptBlock { Get-process -name $Using:ProcessName | Select-Object -First 1 } | ForEach-Object -Process { `
                        }
                    }
                }
                if ($processtovalidate.locationType.'#text'.Trim() -eq 'All') {
                    foreach ($AppServer in $Config.AllAppServerList) {
                        Invoke-Command -ComputerName $AppServer -ScriptBlock { Get-process -name $Using:ProcessName  | Select-Object -First 1 } | ForEach-Object -Process { `
                        }
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
                    Send-MailMessage -to "$EnvironmentOwnerEmail" -Body "$output" -Verbose -SmtpServer "$SMTPServer" 
                }
            }
        }

        [PSCustomObject] $OutputList
    }

    END {}
}
