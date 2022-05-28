function Start-D365LBDDeploymentSleep {
    [alias("Start-D365DeploymentSleep")]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(Mandatory = $true,
        ValueFromPipeline = $True)][psobject]$Config,
        [int]$TimeOutMinutes = 400
    )
    BEGIN {
    }
    PROCESS {
        $Runtime = 0
        $count = 0
        Write-PSFMessage -Level VeryVerbose -Message "Recommend always use an exported valid config not a live config"

        if (!$connection) {
            do {
                $OrchestratorServerName = $config.OrchestratorServerNames | Select-Object -First 1 -Skip $count
                Write-PSFMessage -Message "Verbose: Reaching out to $OrchestratorServerName to try and connect to the service fabric" -Level Verbose
                $SFModuleSession = New-PSSession -ComputerName $OrchestratorServerName
                if (!$module) {
                    $module = Import-Module -Name ServiceFabric -PSSession $SFModuleSession 
                }
                $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $config.SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
                if ($connection) {
                    Write-PSFMessage -Message "Connected to Service Fabric Via: Connect-ServiceFabricCluster -ConnectionEndpoint $config.ConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $ServerCertificate -ServerCertThumbprint $ServerCertificate -StoreLocation LocalMachine -StoreName My"
                }
                if (!$connection) {
                    $trialEndpoint = "https://$OrchestratorServerName" + ":198000"
                    $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $trialEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
                    if ($connection) {
                        Write-PSFMessage -Message "Connected to Service Fabric Via: Connect-ServiceFabricCluster -ConnectionEndpoint $trialEndpoint -X509Credential -FindType FindByThumbprint -FindValue $ServerCertificate -ServerCertThumbprint $ServerCertificate -StoreLocation LocalMachine -StoreName My"
                    }
                }
                if (!$connection) {
                    $connection = Connect-ServiceFabricCluster
                    if ($connection) {
                        Write-PSFMessage -Message "Connected to Service Fabric Via: Connect-ServiceFabricCluster"
                    }
                }
                $count = $count + 1
                if (!$connection) {
                    Write-PSFMessage -Message "Count of servers tried $count" -Level Verbose
                }
            } until ($connection -or ($count -eq $($config.OrchestratorServerNames).Count) -or ($($config.OrchestratorServerNames).Count) -eq 0)
        }

        do { 
            Start-Sleep -Seconds 60
            Write-PSFMessage -Level VeryVerbose -Message "Waiting for StandaloneSetup to start Runtime: $Runtime" 
            $logs = Get-D365LBDOrchestrationLogs -Config $config -NumberofEvents 2
            if (Compare-Object $logs -DifferenceObject $logscurrent) {
                foreach ($log in $logs) {
                    if ($logscurrent.Eventdetails -contains $log.Eventdetails) {}else {
                        Write-PSFMessage -Level VeryVerbose -Message "$log"
                    }
                }
            } 
            $Runtime = $Runtime + 1
            $logscurrent = $logs
            $count = 0
            if (!$logs) {
                do {
                    $OrchestratorServerName = $config.OrchestratorServerNames | Select-Object -First 1 -Skip $count
                    Write-PSFMessage -Message "Verbose: Reaching out to $OrchestratorServerName to try and connect to the service fabric" -Level Verbose
                    $SFModuleSession = New-PSSession -ComputerName $OrchestratorServerName
                    if (!$module) {
                        $module = Import-Module -Name ServiceFabric -PSSession $SFModuleSession 
                    }
                    $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $config.SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
                    if ($connection) {
                        Write-PSFMessage -Message "Connected to Service Fabric Via: Connect-ServiceFabricCluster -ConnectionEndpoint $config.ConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $ServerCertificate -ServerCertThumbprint $ServerCertificate -StoreLocation LocalMachine -StoreName My"
                    }
                    if (!$connection) {
                        $trialEndpoint = "https://$OrchestratorServerName" + ":198000"
                        $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $trialEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
                        if ($connection) {
                            Write-PSFMessage -Message "Connected to Service Fabric Via: Connect-ServiceFabricCluster -ConnectionEndpoint $trialEndpoint -X509Credential -FindType FindByThumbprint -FindValue $ServerCertificate -ServerCertThumbprint $ServerCertificate -StoreLocation LocalMachine -StoreName My"
                        }
                    }
                    if (!$connection) {
                        $connection = Connect-ServiceFabricCluster
                        if ($connection) {
                            Write-PSFMessage -Message "Connected to Service Fabric Via: Connect-ServiceFabricCluster"
                        }
                    }
                    $count = $count + 1
                    if (!$connection) {
                        Write-PSFMessage -Message "Count of servers tried $count" -Level Verbose
                    }
                } until ($connection -or ($count -eq $($config.OrchestratorServerNames).Count) -or ($($config.OrchestratorServerNames).Count) -eq 0)

            }

            $atStandaloneSetupexecution = $logs | Where-Object { $_.eventmessage -like "*StandaloneSetup*" }

        }
        until($atStandaloneSetupexecution -or $Runtime -gt $TimeOutMinutes) 

        if ($Runtime -gt $TimeOutMinutes) {
            Stop-PSFFunction -Message "Error: Failed did not complete within $TimeOutMinutes minutes"  -EnableException $true -Cmdlet $PSCmdlet
        }
        $logscurrent = Get-D365LBDOrchestrationLogs -Config $config -NumberofEvents 2
        do {
            Start-Sleep -Seconds 60
            $Runtime = $Runtime + 1
            Write-PSFMessage -Message "Waiting for AXSF to be created. Runtime: $Runtime"  -Level VeryVerbose
            $apps = $(get-servicefabricclusterhealth | Select-Object ApplicationHealthStates).ApplicationHealthStates
            Write-PSFMessage -Level VeryVerbose -Message "Apps Current status $apps" 
          
            $AXSF = $apps | Where-Object { $_.ApplicationName -eq 'fabric:/AXSF' }
            if ($AXSF) {
                Write-PSFMessage -message "Found AXSF Running" -Level veryVerbose
            }

            $logs = Get-D365LBDOrchestrationLogs -Config $config -NumberofEvents 2
            if (Compare-Object $logs -DifferenceObject $logscurrent) {
                foreach ($log in $logs) {
                    if ($logscurrent.Eventdetails -contains $log.Eventdetails) {}else {
                        Write-PSFMessage -Level VeryVerbose -Message "$log"
                    }
                }
            }
                $logscurrent = $logs
                $FoundError = $logs | Where-Object { $_.EventMessage -like "status of job*Error" }
                if ($FoundError) {
                    $Deployment = "Failure"
                }

            }until ($AXSF -or $Deployment -eq 'Failure')

            do {
                $DBeventscurrent = Get-D365DBEvents -Config $config -NumberofEvents 5
                Start-Sleep -Seconds 120
                $Runtime = $Runtime + 2
                $logs = Get-D365LBDOrchestrationLogs -Config $config -NumberofEvents 2
                $FoundSuccess = $logs | Where-Object { $_.EventMessage -like "status of job*Success" }
                $FoundError = $logs | Where-Object { $_.EventMessage -like "status of job*Error" }
                $logs = Get-D365LBDOrchestrationLogs -Config $config -NumberofEvents 2
                if (Compare-Object $logs -DifferenceObject $logscurrent) {
                    foreach ($log in $logs) {
                        if ($logscurrent.Eventdetails -contains $log.Eventdetails) {}else {
                            Write-PSFMessage -Level VeryVerbose -Message "$log"
                        }
                    }
                }
                $logscurrent = $logs
                if ($FoundSuccess) {
                    $Deployment = "Success"
                }
                if ($FoundError) {
                    $Deployment = "Failure"
                }
                $DBevents = Get-D365DBEvents -Config $config -NumberofEvents 5
                if (Compare-Object $DBevents -DifferenceObject $DBeventscurrent) {
                    foreach ($event in $DBevents) {
                        if ((($event.message -contains "Table synchronization failed.") -or ($event.message -contains "Database Synchronize Succeeded.") -or ($event.message -contains "Database Synchronize Failed.")) -and $SyncStatusFound -eq $false) {
                            if (($event.message -contains "Table synchronization failed.") -or ($event.message -contains "Database Synchronize Failed.")) {
                                Write-PSFMessage -Message "Found a DB Sync failure $event" -Level Verbose
                                $DBSyncStatus = "Failed"
                                $DBSyncTimeStamp = $event.TimeCreated
                            }
                            if ($event.message -contains "Database Synchronize Succeeded.") {
                                Write-PSFMessage -Message "Found a DB Sync Success $event" -Level Verbose
                                $DBSyncStatus = "Succeeded"
                                $DBSyncTimeStamp = $event.TimeCreated
                            }
                            $SyncStatusFound = $true
                        }
                        if ($DBeventscurrent -contains $event) {}else {
                            Write-PSFMessage -Level VeryVerbose -Message "DBSyncLog $Event"
                        }
                    }
                }
                if ($DBSyncStatus) {
                    Write-PSFMessage -Level VeryVerbose -Message "Found Database Sync Status: $DBSyncStatus" 
                    foreach ($event in $DBevents) {
                        Write-PSFMessage -Level VeryVerbose -Message "$event"  
                    }
                }
                $DBeventscurrent = $DBevents
            }
            until($Deployment -eq "Success" -or $Deployment -eq "Failure")

            Write-Verbose "$Deployment" -Verbose
            if ($Deployment -eq "Failure") {
                Stop-PSFFunction -Message "Error: The Deployment failed. Stopping" -EnableException $true -Cmdlet $PSCmdlet
            }

        }
        END {
        }
    }