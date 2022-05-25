function Start-D365LBDDeploymentSleep {
    [alias("Start-D365DeploymentSleep")]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(Mandatory = $true)][string]$CustomModuleName,
        [int]$TimeOutMinutes = 400
    )
    BEGIN {
    }
    PROCESS {

        Write-PSFMessage -Level VeryVerbose -Message "Recommend always use an exported valid config not a live config"
        $logs = Get-D365LBDOrchestrationLogs -Config $config -NumberofEvents 5

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
            Write-Verbose "Waiting for StandaloneSetup to start" -Verbose
            $logs = Get-D365LBDOrchestrationLogs -Config $config -NumberofEvents 2
            foreach ($log in $logs) {
                Write-Verbose $log -Verbose
            }
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
        until($atStandaloneSetupexecution -or $timeout -gt $TimeOutMinutes) 

        if ($timeout -gt $TimeOutMinutes){
            Stop-PSFFunction -Message "Error: Failed did not complete within $TimeOutMinutes minutes"  -EnableException $true -Cmdlet $PSCmdlet

        }

        do {
            Start-Sleep -Seconds 60
            Write-verbose "Waiting for AXSF to be created" -verbose
            $apps = $(get-servicefabricclusterhealth | Select-Object ApplicationHealthStates).ApplicationHealthStates
            Write-Verbose "Apps Current status $apps" -Verbose
            $AXSF = $apps | Where-Object { $_.ApplicationName -eq 'fabric:/AXSF' }
            if ($AXSF) {
                Write-Verbose "Found AXSF Running" -Verbose
            }

            $logs = Get-D365LBDOrchestrationLogs -Config $config -NumberofEvents 2
            Write-Verbose "Last 2 Orch Logs" -Verbose
            foreach ($log in $logs) {
                Write-Verbose "$log" -Verbose
            }
            $FoundError = $logs | Where-Object { $_.EventMessage -like "status of job*Error" }
            if ($FoundError) {
                $Deployment = "Failure"
            }

        }until ($AXSF -or $Deployment -eq 'Failure')

        do {
            Start-Sleep -Seconds 120
            $logs = Get-D365LBDOrchestrationLogs -Config $config -NumberofEvents 2
            $FoundSuccess = $logs | Where-Object { $_.EventMessage -like "status of job*Success" }
            $FoundError = $logs | Where-Object { $_.EventMessage -like "status of job*Error" }
            Write-Verbose "Last 2 Orch Logs" -Verbose
            foreach ($log in $logs) {
                Write-Verbose "$log" -Verbose
            }
            if ($FoundSuccess) {
                $Deployment = "Success"
            }
            if ($FoundError) {
                $Deployment = "Failure"
            }
            $DBevents = Get-D365DBEvents -Config $config -NumberofEvents 5
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
            }
            if ($DBSyncStatus) {
                Write-Verbose "FOUND DB SYNC STATUS $DBSyncStatus" -Verbose
                foreach ($event in $DBevents) {
                    Write-Verbose " $event" -Verbose
                }
            }

        }
        until($Deployment -eq "Success" -or $Deployment -eq "Failure")

        Write-Verbose "$Deployment" -Verbose
    }
    END {
    }
}