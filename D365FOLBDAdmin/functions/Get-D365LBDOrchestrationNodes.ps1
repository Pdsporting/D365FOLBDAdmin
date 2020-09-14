##Get Primary and Secondary
function Get-D365LBDOrchestrationNodes {
    [alias("Get-D365OrchestrationNodes")]
    $config = Get-D365LBDConfig
    try {
        $connection = Connect-ServiceFabricCluster -connectionEndpoint $config.SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $Config.SFServerCertificate -ServerCertThumbprint $Config.SFServerCertificate | Out-Null
    }
    catch {
        Stop-PSFFunction -Message "Can't Connect to Service Fabric $_" -EnableException $true -Cmdlet $PSCmdlet -ErrorAction Stop
    }
    $PartitionId = $(Get-ServiceFabricServiceHealth -ServiceName 'fabric:/LocalAgent/OrchestrationService').PartitionHealthStates.PartitionId
    $nodes = Get-ServiceFabricReplica -PartitionId "$PartitionId"
    $primary = $nodes | Where-Object { $_.ReplicaRole -eq "Primary" }
    $secondary = $nodes | Where-Object { $_.ReplicaType -eq "ActiveSecondary" }
    New-Object -TypeName PSObject -Property `
    @{'PrimaryNodeName'                              = $primary.NodeName;
        'SecondaryNodeName'                          = $secondary.NodeName;
        'PrimaryReplicaStatus'                       = $primary.Properties[2].value; 
        'SecondaryReplicaStatus'                     = $secondary.Message;
        'PrimaryLastInBuildStatusLevelDisplayName'   = $primary.LevelDisplayName;
        'SecondaryLastInBuildStatusLevelDisplayName' = $secondary.TimeCreated;
        'PrimaryHealthState'                         = $primary.UserId;
        'SecondaryHealthState'                       = $secondary.LogName;
        'PartitionId'                                = $PartitionId;
    }
}