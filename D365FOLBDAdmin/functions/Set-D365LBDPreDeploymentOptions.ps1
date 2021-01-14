function Set-D365LBDPreDeploymentOptions {
    <#
   .SYNOPSIS
  Uses switches to set different deployment options
  .DESCRIPTION

  .EXAMPLE
  Set-D365LBDPreDeploymentOptions -RemoveMR

  .EXAMPLE

  #>
    [alias("Set-D365PreDeploymentOptions")]
    param
    (
        [Parameter(ParameterSetName = 'AgentShare')]
        [Alias('AgentShare')]
        [string]$AgentShareLocation,
        [string]$CustomModuleName,
        [Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name',
            ParameterSetName = 'NoConfig')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ParameterSetName = 'Config',
            ValueFromPipeline = $True)]
        [psobject]$Config,
        [switch]$RemoveMR,
        [switch]$MaintenanceModeOn,
        [switch]$MaintenanceModeOff

    )
    BEGIN {
    }
    PROCESS {
        if (!$Config -and !$AgentShareLocation) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly
           
        }
        if ($Config) {
            $agentsharelocation = $Config.AgentShareLocation
            $AXDatabaseServer = $Config.AXDatabaseServer
            $AXDatabaseName = $Config.AXDatabaseName
        }
        if ($RemoveMR) {
            $JsonLocation = Get-ChildItem $AgentShareLocation\wp\*\StandaloneSetup-*\SetupModules.json | Sort-Object { $_.CreationTime }  | Select-Object -First 1 
            $JsonLocationRoot =  Get-ChildItem $AgentShareLocation\wp\*\StandaloneSetup-*\
            copy-item $JsonLocation.fullName -Destination $AgentShareLocation\OriginalSetupModules.json
            $json = Get-Content $JsonLocation.FullName -Raw | ConvertFrom-Json
            $json.components = $json.components | Where-Object { $_.name -ne 'financialreporting' }
            $json | ConvertTo-Json -Depth 100 | Out-File $JsonLocationRoot\Setupmodules.json -Force -Verbose
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
        if ($MaintenanceModeOn){
            $SQLQuery = "update SQLSYSTEMVARIABLES SET VALUE = 1 Where PARM = 'CONFIGURATIONMODE'"
            $Sqlresults = invoke-sql -datasource $AXDatabaseServer -database $AXDatabaseName -sqlcommand $SQLQuery
            foreach ($AXSFServer in $config.AXSFServerNames){
                Restart-Computer -ComputerName $AXSFServer -Force
            }

        }
        if ($MaintenanceModeOff){
            $SQLQuery = "update SQLSYSTEMVARIABLES SET VALUE = 0 Where PARM = 'CONFIGURATIONMODE'"
            $Sqlresults = invoke-sql -datasource $AXDatabaseServer -database $AXDatabaseName -sqlcommand $SQLQuery
            foreach ($AXSFServer in $config.AXSFServerNames){
                Restart-Computer -ComputerName $AXSFServer -Force
            }
        }
    }
    END {
    }
}
