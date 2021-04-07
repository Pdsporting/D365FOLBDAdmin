##Get Primary and Secondary
function Get-D365LBDOrchestrationNodes {
    <#
    .SYNOPSIS
  
   .DESCRIPTION
   
   .EXAMPLE
   Get-D365LBDOrchestrationNodes
  
   .EXAMPLE
    Get-D365LBDOrchestrationNodes -ComputerName "LBDServerName" -verbose
   
   .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module

   #>
    [alias("Get-D365OrchestrationNodes")]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name',
            ParameterSetName = 'NoConfig')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [string]$Thumbprint,
        [Parameter(ParameterSetName = 'Config',
            ValueFromPipeline = $True)]
        [psobject]$Config)
    BEGIN {
    }
    PROCESS {

        if (!$Config) {
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
                Stop-PSFFunction -Message "Error: Can't connect to Service Fabric"
            }
        }
        $PartitionId = $(Get-ServiceFabricServiceHealth -ServiceName 'fabric:/LocalAgent/OrchestrationService').PartitionHealthStates | Select-Object PartitionId
        [string]$PartitionIdString = $PartitionId 
        $PartitionIdString = $PartitionIdString.Trim("@{PartitionId=")
        $PartitionIdString = $PartitionIdString.Substring(0, $PartitionIdString.Length - 1)
       
        Write-PSFMessage -Message "Looking up PartitionID $PartitionIdString." -Level Verbose
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
    END {
    }
}