function Get-D365LBDOrchestratorLastRunBookDetails {
    <#
    .SYNOPSIS
 

   #>
    [CmdletBinding()]
    [alias("Get-D365OrchestratorLastRunBookDetails")]
    param ([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name',
            ParameterSetName = 'NoConfig')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ParameterSetName = 'Config',
            ValueFromPipeline = $True)]
        [psobject]$Config,
        [Parameter(ParameterSetName = 'Orch')]
        $OrchdatabaseServer,
        [Parameter(ParameterSetName = 'Orch')]
        $OrchdatabaseName
    )
    BEGIN {
    } 
    PROCESS {
        if (!$Config) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly
        }
        if ($Config)
        {
            $OrchdatabaseServer = $Config.OrchdatabaseServer
            $OrchdatabaseName = $OrchdatabaseName.OrchDatabase
        }
       
       
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
        $Query = "Select RBT.[Order], CASE WHEN RBT.State = 0 THEN 'Not Started' WHEN RBT.State = 1 THEN 'In Progress' WHEN RBT.State THEN 'Failed' WHEN RBT.State = 4 THEN 'Cancelled' END AS TaskStatus,
        RBT.Name, RBT.Description, RBT.RunbookTaskId, RBT.TaskDefinitionName, RBT.State, RBT.Retries, RBT.StartDateTime, RBT.EndDateTime, 
        DI.ID as EnvironmentID, DI.Name as EnvironmentName, DI.ActiveJobID, DI.State as EnvironmentState, DI.Status as EnvironmentStatus, 
        OJ.JobID, OJ.CommandID, OJ.State, OJ.Exception, OJ.QueuedDateTime, OJ.QueuedDateTime, OJ.ScheduledDateTime, OJ.LastProcessedDateTime FROM 
        DeploymentInstance DI JOIN
        OrchestratorJob OJ ON OJ.DeplomentInstanceID = DI.ID JOIN
        RunBookTask RBT ON RBT.JobID = OJ.JobID WHERE 
        OJ.JobID = (select Top 1 JobID from RunBookTask ORDER BY StartDateTime DESC
        "

        try {
            $Sqlresults = invoke-sql -datasource $OrchdatabaseServer -database $OrchDatabase -sqlcommand $Query
            
            $Sqlresults
        }
        catch {}
    }
    END {
    }
}