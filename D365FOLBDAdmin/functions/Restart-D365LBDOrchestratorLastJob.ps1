function Restart-D365LBDOrchestratorLastJob {
     <#
   .SYNOPSIS
  Restarts the state of the orchestratorjob and runbooktaskid tables last executed jobs
  .DESCRIPTION
  Restarts the state of the orchestratorjob and runbooktaskid tables last executed jobs by changing the values in the orchestrator database.
  .EXAMPLE
  $config = get-d365Config
   Restart-D365LBDOrchestratorLastJob -config $config
  .EXAMPLE
   Restart-D365LBDOrchestratorLastJob -OrchDatabaseServer 'DBSERVER01' -OrchDatabaseName 'OrchDatabaseServer'
  .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER OrchDatabaseServer
    string
    The name of the orchestrator database server can be defined with OrchDatabaseName to restart without a config
   .PARAMETER OrchDatabaseName
   string 
   The name of the orchestrator database (usually OrchestratorData) can be defined with OrchDatabaseServer to restart without a config
  #>
    [CmdletBinding()]
    [alias("Restart-D365OrchestratorLastJob")]
    param ([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name',
            ParameterSetName = 'NoConfig')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ParameterSetName = 'Config',
            ValueFromPipeline = $True)]
        [psobject]$Config,
        [Parameter(ParameterSetName = 'Directly')]
        [string]$OrchDatabaseServer,
        [string]$OrchDatabaseName
    )
    BEGIN {
    } 
    PROCESS {
        if (!$Config -and !$OrchDatabaseServer) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly
        }
        else {
            if (!$config) {
                if ($OrchDatabaseName) {
                    Write-PSFMessage -Message "No DatabaseName specified trying OrchestratorData" -Level VeryVerbose
                    $OrchDatabaseName = 'OrchestratorData'
                }
            }
            else {
                ##Using Config
                Write-PSFMessage -Message "Using Config for execution" -Level Verbose
                $OrchDatabaseName = $Config.OrchDatabaseName
                $OrchDatabaseServer = $Config.OrchDatabaseServer
            }
        }

        if ($null -eq $OrchDatabaseServer) {
            Stop-PSFFunction -Message "Error: Can't Find OrchDatabaseServer. Stopping. Suggest running the command using the parameter set directly" -EnableException $true -Cmdlet $PSCmdlet
        }
  
        $OrchJobQuery = 'select top 1 JobId,State from OrchestratorJob order by ScheduledDateTime desc'
        $RunBookQuery = 'select top 1 RunbookTaskId, State from RunBookTask order by StartDateTime desc'
   
        function Invoke-SQL {
            param(
                [string] $dataSource = ".\SQLEXPRESS",
                [string] $database = "MasterData",
                [string] $sqlCommand = $(throw "Please specify a query.")
            )

            $connectionString = "Data Source=$dataSource; " +
            "Integrated Security=SSPI; " +
            "Initial Catalog=$database"

            $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
            $command = new-object system.data.sqlclient.sqlcommand($sqlCommand, $connection)
            $connection.Open()
    
            $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
            $dataset = New-Object System.Data.DataSet

            $adapter.Fill($dataSet) | Out-Null
            $connection.Close()
            $dataSet.Tables
        }
        $OrchJobQueryResults = Invoke-SQL -dataSource $OrchDatabaseServer -database $OrchDatabaseName -sqlCommand $OrchJobQuery
        $RunBookQueryResults = Invoke-SQL -dataSource $OrchDatabaseServer -database $OrchDatabaseName -sqlCommand $RunBookQuery 

        $LastOrchJobId = $($OrchJobQueryResults | select JobId).JobId
        $LastOrchState = $($OrchJobQueryResults | select state).State

        $LastRunbookTaskId = $($RunBookQueryResults | select RunbookTaskId).RunbookTaskId
        $LastRunbookState = $($RunBookQueryResults | select state).State

        if ($LastOrchState -eq 2 -or $LastOrchState -eq 1) {
            Write-PSFMessage -Level VeryVerbose -Message "Can't run OrchJob is already in running on completed successfully state"
        }
        else {
            $RestartQuery1 = "Update OrchestratorJob set State = 1 where JobId = '$LastOrchJobId'"
            $RestartQuery2 = "Update RunBookTask set State = 1, Retries = 1 where RunbookTaskId = '$LastRunbookTaskId'"
            Write-PSFMessage -Level VeryVerbose -Message "$RestartQuery1 Running on $OrchDatabaseServer against $OrchDatabaseName"
            Invoke-SQL -dataSource $OrchDatabaseServer -database $OrchDatabaseName -sqlCommand $RestartQuery1 
            Write-PSFMessage -Level VeryVerbose -Message "$RestartQuery2 Running on $OrchDatabaseServer against $OrchDatabaseName"
            Invoke-SQL -dataSource $OrchDatabaseServer -database $OrchDatabaseName -sqlCommand $RestartQuery2 
        }

        if (!$Config) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly
        }
        [int]$count = 0
        Write-PSFMessage -Message "Trying to connect to service fabric to find primary and secondary orchestration servers" -Level VeryVerbose
        while (!$connection) {
            do {
                $OrchestratorServerName = $Config.OrchestratorServerNames | Select-Object -First 1 -Skip $count
                Write-PSFMessage -Message "Verbose: Reaching out to $OrchestratorServerName to try and connect to the service fabric" -Level Verbose
                $SFModuleSession = New-PSSession -ComputerName $OrchestratorServerName
                if (!$module) {
                    $module = Import-Module -Name ServiceFabric -PSSession $SFModuleSession 
                }
                $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $config.SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
                if (!$connection) {
                    $trialEndpoint = "https://$OrchestratorServerName" + ":198000"
                    $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $trialEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
                }
                $count = $count + 1
                if (!$connection) {
                    Write-PSFMessage -Message "Count of servers tried $count" -Level Verbose
                }
            } until ($connection -or ($count -eq $($Config.OrchestratorServerName).Count))
            if (($count -eq $($Config.OrchestratorServerName).Count) -and (!$connection)) {
                Write-PSFMessage -Level VeryVerbose -Message "Error: Can't connect to Service Fabric"
            }
        }
        if ($connection) {
            Write-PSFMessage -Level VeryVerbose -Message "Connected to Service Fabric"
            $PartitionId = $(Get-ServiceFabricServiceHealth -ServiceName 'fabric:/LocalAgent/OrchestrationService').PartitionHealthStates | Select-Object PartitionId
            [string]$PartitionIdString = $PartitionId 
            $PartitionIdString = $PartitionIdString.Trim("@{PartitionId=")
            $PartitionIdString = $PartitionIdString.Substring(0, $PartitionIdString.Length - 1)
       
            $nodes = Get-ServiceFabricReplica -PartitionId "$PartitionIdString"
            $primary = $nodes | Where-Object { $_.ReplicaRole -eq "Primary" -or $_.ReplicaType -eq "Primary" }
            $secondary = $nodes | Where-Object { $_.ReplicaRole -eq "ActiveSecondary" -or $_.ReplicaType -eq "ActiveSecondary" }
            New-Object -TypeName PSObject -Property `
            @{'PrimaryNodeName'                = $primary.NodeName;
                'SecondaryNodeName'            = $secondary.NodeName;
                'PrimaryReplicaStatus'         = $primary.ReplicaStatus; 
                'SecondaryReplicaStatus'       = $secondary.ReplicaStatus;
                'PrimaryLastinBuildDuration'   = $primary.LastinBuildDuration;
                'SecondaryLastinBuildDuration' = $secondary.LastinBuildDuration;
                'PrimaryHealthState'           = $primary.HealthState;
                'SecondaryHealthState'         = $secondary.HealthState;
                'PartitionId'                  = $PartitionIdString;
            }
        }
    }
    END {
    }
}