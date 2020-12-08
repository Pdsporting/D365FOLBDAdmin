##Get Primary and Secondary
function Get-D365LBDOrchestrationNodes {
    [alias("Get-D365OrchestrationNodes")]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name',
            ParameterSetName = 'NoConfig')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [string]$Thumbprint,
        [Parameter(ParameterSetName='Config',
        ValueFromPipeline = $True)]
        [psobject]$Config)
    BEGIN {
    }
    PROCESS {

        if (!$Config) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName 
        }

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
    END {
    }
}