##Get Primary and Secondary
function Get-D365OrchestrationNodes {
    $config = Get-D365LBDConfig
    try {
        $connection = Connect-ServiceFabricCluster -connectionEndpoint $config.SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $Config.SFServerCertificate -ServerCertThumbprint $Config.SFServerCertificate | Out-Null
    }
    catch {
        Stop-PSFFunction -Message "Can't Connect to Service Fabric $_" -EnableException $true -Cmdlet $PSCmdlet -ErrorAction Stop
    }
    $PartitionId = $(Get-ServiceFabricServiceHealth -ServiceName 'fabric:/LocalAgent/OrchestrationService').PartitionHealthStates.PartitionId
    Get-ServiceFabricReplica -PartitionId "$PartitionId"
}