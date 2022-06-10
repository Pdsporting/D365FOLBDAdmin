function Start-D365LBDDeploymentSleep {
        <#
    .SYNOPSIS
Watches the deployment of a D365 LBD package
   .DESCRIPTION
Watches the deployment of a D365 LBD package. Recommend to use with exported config
   .EXAMPLE
   $config = Get-D365Config -ConfigImportFromFile "C:\environment\environment.xml"
Start-D365LBDDeploymentSleep -config $config 
   .EXAMPLE

   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module
    
   #>
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
            $logscurrent = Get-D365LBDOrchestrationLogs -Config $config -NumberofEvents 4
            Start-Sleep -Seconds 60
            Write-PSFMessage -Level VeryVerbose -Message "Waiting for StandaloneSetup to start Runtime: $Runtime" 
            $logs = Get-D365LBDOrchestrationLogs -Config $config -NumberofEvents 4
            if (Compare-Object $logs -DifferenceObject $logscurrent -Property Eventdetails) {
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
                    $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $config.SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My -KeepAliveIntervalInSec 400
                    if ($connection) {
                        Write-PSFMessage -Message "Connected to Service Fabric Via: Connect-ServiceFabricCluster -ConnectionEndpoint $config.ConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $ServerCertificate -ServerCertThumbprint $ServerCertificate -StoreLocation LocalMachine -StoreName My"
                    }
                    if (!$connection) {
                        $trialEndpoint = "https://$OrchestratorServerName" + ":198000"
                        $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $trialEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My -KeepAliveIntervalInSec 400
                        if ($connection) {
                            Write-PSFMessage -Message "Connected to Service Fabric Via: Connect-ServiceFabricCluster -ConnectionEndpoint $trialEndpoint -X509Credential -FindType FindByThumbprint -FindValue $ServerCertificate -ServerCertThumbprint $ServerCertificate -StoreLocation LocalMachine -StoreName My"
                        }
                    }
                    if (!$connection) {
                        $connection = Connect-ServiceFabricCluster -KeepAliveIntervalInSec 400
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
            return "Failed"
            Stop-PSFFunction -Message "Error: Failed did not complete within $TimeOutMinutes minutes"  -EnableException $true -Cmdlet $PSCmdlet
        }
        $logscurrent = Get-D365LBDOrchestrationLogs -Config $config -NumberofEvents 4
        do {
            Start-Sleep -Seconds 60
            $Runtime = $Runtime + 1
            Write-PSFMessage -Message "Waiting for AXSF to be created. Runtime: $Runtime"  -Level VeryVerbose
            $apps = $(get-servicefabricclusterhealth | Select-Object ApplicationHealthStates).ApplicationHealthStates
            Write-PSFMessage -Level VeryVerbose -Message "Apps Current status $apps" 
            if (!$apps){
                Write-PSFMessage -Level VeryVerbose -Message "Lost connection reconnecting to SF"
                do {
                    $OrchestratorServerName = $Config.OrchestratorServerNames | Select-Object -First 1 -Skip $count
                    Write-PSFMessage -Message "Verbose: Reaching out to $OrchestratorServerName to try and connect to the service fabric" -Level Verbose
                    $SFModuleSession = New-PSSession -ComputerName $OrchestratorServerName
                    if (!$module) {
                        $module = Import-Module -Name ServiceFabric -PSSession $SFModuleSession 
                        Import-PSSession -Session $SFModuleSession
                    }
                    $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $config.SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My  -KeepAliveIntervalInSec 400
                    if (!$connection) {
                        $trialEndpoint = "https://$OrchestratorServerName" + ":198000"
                        $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $trialEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My -KeepAliveIntervalInSec 400
                        if ($connection) {
                            Write-PSFMessage -Message "Connected to Service Fabric Via: Connect-ServiceFabricCluster -ConnectionEndpoint $trialEndpoint -X509Credential -FindType FindByThumbprint -FindValue $ServerCertificate -ServerCertThumbprint $ServerCertificate -StoreLocation LocalMachine -StoreName My"
                        }
                    }
                    if (!$connection) {
                        $connection = Connect-ServiceFabricCluster -KeepAliveIntervalInSec 400
                        if ($connection) {
                            Write-PSFMessage -Message "Connected to Service Fabric Via: Connect-ServiceFabricCluster"
                        }
                    }
                    $count = $count + 1
                    if (!$connection) {
                        Write-PSFMessage -Message "Count of servers tried $count" -Level Verbose
                    }
                }  until ($connection -or ($count -eq $($Config.OrchestratorServerNames).Count) -or ($($Config.OrchestratorServerNames).Count) -eq 0)
            }
          
            $AXSF = $apps | Where-Object { $_.ApplicationName -eq 'fabric:/AXSF' }
            if ($AXSF) {
                Write-PSFMessage -message "Found AXSF Running" -Level veryVerbose
            }

            $logs = Get-D365LBDOrchestrationLogs -Config $config -NumberofEvents 4
            if (Compare-Object $logs -DifferenceObject $logscurrent -Property Eventdetails) {
                foreach ($log in $logs) {
                    if ($logscurrent.Eventdetails -contains $log.Eventdetails) {}else {
                        if ($log.EventMessage -like "Execution of custom powershell script*"){
                            Write-PSFMessage -Level VeryVerbose -Message "$log"
                            $time = $(get-date).AddMinutes(-15)
                            $customscriptlogs = get-childitem  "$($config.AgentShareLocation)\scripts\logs" | Where-Object {$_.CreationTime -gt $time}
                            foreach ($customscriptlog in $customscriptlogs){
                                Write-PSFMessage -Level VeryVerbose -Message "BEGIN Log: $($CustomscriptLog.Name)"
                                $customlogcontent = Get-Content $customscriptlog.FullName
                                Write-PSFMessage -Level VeryVerbose -Message "$customlogcontent"
                                Write-PSFMessage -Level VeryVerbose -Message "END Log: $($CustomscriptLog.Name)"

                            }
                        }
                        Write-PSFMessage -Level VeryVerbose -Message "$log"
                    }
                }
            }
            $logscurrent = $logs
            $FoundError = $logs | Where-Object { $_.EventMessage -like "status of job*Error" }
            if ($FoundError) {
                $Deployment = "Failure"
            }

        }until ($AXSF -or $Deployment -eq 'Failure' -or $Runtime -gt $TimeOutMinutes)
        if ($Runtime -gt $TimeOutMinutes -or $Deployment -eq 'Failure') {
            return "Failed"
            Stop-PSFFunction -Message "Error: The Deployment failed. Stopping" -EnableException $true -Cmdlet $PSCmdlet
        }

        do {
            $DBeventscurrent = Get-D365DBEvents -Config $config -NumberofEvents 5
            Start-Sleep -Seconds 120
            $Runtime = $Runtime + 2
            $logs = Get-D365LBDOrchestrationLogs -Config $config -NumberofEvents 4
            $FoundSuccess = $logs | Where-Object { $_.EventMessage -like "status of job*Success" }
            $FoundError = $logs | Where-Object { $_.EventMessage -like "status of job*Error" }
            $logs = Get-D365LBDOrchestrationLogs -Config $config -NumberofEvents 4
            if (Compare-Object $logs -DifferenceObject $logscurrent -Property Eventdetails) {
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
            if ($FoundRecentDBSync -eq "Yes"){
                $DBevents = Get-D365DBEvents -OnlyThisDBServer $newconfig.DBSyncServerWithLatestLog -NumberofEvents 5
            }else{
            $DBevents = Get-D365DBEvents -Config $config -NumberofEvents 5
        }
            if (Compare-Object $DBevents -DifferenceObject $DBeventscurrent -Property EventMessage ) {
                $RightNow = Get-Date
                $15MinsAgo = $RightNow.AddMinutes(-15)
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
                    if ($event.TimeCreated -gt $15MinsAgo){
                        $FoundRecentDBSync = "Yes"
                        if (!$newconfig){
                            Write-PSFMessage -Level VeryVerbose -Message "Found a recent Database event getting a fresh config"
                            $newconfig = get-d365config -ComputerName $config.SourceAXSFServer -highlevelonly
                        }
                    }
                    else{
                        $FoundRecentDBSync = "nos"
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
            return "Failed"
            Stop-PSFFunction -Message "Error: The Deployment failed. Stopping" -EnableException $true -Cmdlet $PSCmdlet
        }
        else{
            Write-PSFMessage -Level VeryVerbose -Message "Deployment status = Success"
            return "Success"
        }

    }
    END {
    }
}