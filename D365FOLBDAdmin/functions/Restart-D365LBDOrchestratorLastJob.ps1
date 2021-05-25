function Restart-D365LBDOrchestratorLastJob {
    <#
    .SYNOPSIS
Restarts the state of the orchestratorjob and runbooktaskid tables last executed jobs
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
        [psobject]$Config
    )
    BEGIN {
    } 
    PROCESS {
        if (!$Config) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly
        }
        $OrchDatabaseServer = $Config.OrchDatabaseServer 
        $OrchDatabaseName = $Config.OrchDatabaseName 

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
            Invoke-SQL -dataSource $OrchDatabaseServer -database $OrchDatabaseName -sqlCommand $RestartQuery1 
            Invoke-SQL -dataSource $OrchDatabaseServer -database $OrchDatabaseName -sqlCommand $RestartQuery2 

        }

    }
    END {
    }
}