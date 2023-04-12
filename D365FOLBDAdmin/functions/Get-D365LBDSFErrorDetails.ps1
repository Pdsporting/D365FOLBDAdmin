function Get-D365LBDSFErrorDetails {
    <#
    .SYNOPSIS
    
   .DESCRIPTION
 
   .EXAMPLE
    Get-D365LBDSFErrorDetails -ComputerName "LBDServerName" -verbose
   
    .EXAMPLE 
    $config = get-d365Config
    Get-D365LBDSFErrorDetails -config $Config 
   
   .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module
   #>
    [alias("Get-D365SFErrorDetails")]
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
        [int]$Timeout = 600
    )
    ##Gather Information from the Dynamics 365 Orchestrator Server Config
    BEGIN {
    } 
    PROCESS {
        if (!$Config -or $Config.OrchestratorServerNames.Count -eq 0) {
            Write-PSFMessage -Level VeryVerbose -Message "Config not defined or Config is invalid. Trying to Get new config using $ComputerName"
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly
        }
        [int]$count = 0
        while (!$connection) {
            do {
                $OrchestratorServerName = $Config.OrchestratorServerNames | Select-Object -First 1 -Skip $count
                Write-PSFMessage -Message "Verbose: Reaching out to $OrchestratorServerName to try and connect to the service fabric" -Level Verbose
                $SFModuleSession = New-PSSession -ComputerName $OrchestratorServerName
                if (!$module) {
                    $module = Import-Module -Name ServiceFabric -PSSession $SFModuleSession 
                }
                Write-PSFMessage -Message "-ConnectionEndpoint $($config.SFConnectionEndpoint) -X509Credential -FindType FindByThumbprint -FindValue $($config.SFServerCertificate) -ServerCertThumbprint $($config.SFServerCertificate) -StoreLocation LocalMachine -StoreName My" -Level Verbose
                $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $config.SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
                if (!$connection) {
                    $trialEndpoint = "https://$OrchestratorServerName" + ":198000"
                    $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $trialEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
                }
                $count = $count + 1
                if (!$connection) {
                    Write-PSFMessage -Message "Count of servers tried $count" -Level Verbose
                }
            } until ($connection -or ($count -eq $($Config.OrchestratorServerNames).Count) -or ($($Config.OrchestratorServerNames).Count) -eq 0)
            if (($count -eq $($Config.OrchestratorServerNames).Count) -and (!$connection)) {
                Stop-PSFFunction -Message "Error: Can't connect to Service Fabric"
            }
        }
        $TotalApplications = (Get-ServiceFabricApplication).Count
        $HealthyApps = (Get-ServiceFabricApplication | Where-Object { $_.HealthState -eq "OK" }).Count
        if ($TotalApplications -eq $HealthyApps) {
            Write-PSFMessage -Message "All deployed applications are healthy $TotalApplications / $HealthyApps " -Level Verbose
        }
        else {
            $NotHealthyApps = Get-ServiceFabricApplication | Where-Object { $_.HealthState -ne "OK" }
            foreach ($NotHealthyApp in $NotHealthyApps) {
                Write-PSFMessage -Level VeryVerbose -Message "$NotHealthyApp.ApplicationName"
                $AppHealth = Get-ServiceFabricApplicationHealth -ApplicationName $NotHealthyApp.ApplicationName
                $AppUnHealthEvents = $AppHealth.UnhealthyEvaluations
                foreach ($AppUnHealthEvent in $AppUnHealthEvents) {
                    $AppUnHealthEvent
                }
                $ServiceswithIssues = Get-ServiceFabricService -ApplicationName $NotHealthyApp.ApplicationName
                foreach ($ServiceswithIssue in $ServiceswithIssues) {
                    $ServicePartition = Get-ServiceFabricPartition -ServiceName $ServiceswithIssue.ServiceName
                    $ServiceReplicaList = Get-ServiceFabricReplica -PartitionId $ServicePartition.PartitionId
                    foreach ($ServiceReplica in $ServiceReplicaList) {
                        $HealthEvents = Get-ServiceFabricReplicaHealth -partitionid $ServiceReplica.PartitionId -ReplicaOrInstanceId $ServiceReplica[0].id
                        $unhealthyevents = $HealthEvents.UnhealthyEvaluations
                        foreach ($unhealthyevent in $unhealthyevents) {
                            $unhealthyevent
                        }
                    }
                }
            }
        }
        
    }
    END {}
}