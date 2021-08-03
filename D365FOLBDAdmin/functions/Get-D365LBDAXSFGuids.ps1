function Get-D365LBDAXSFGuids {
    <#
   .SYNOPSIS
    Gathers Each AXSF Endpoint details includes its GUID (used for single server issue diagnostics), https endpoint and its current status.
  .DESCRIPTION
    Gathers Each AXSF Endpoint details includes its GUID (used for single server issue diagnostics), https endpoint and its current status.
  .EXAMPLE
  $config = get-d365Config
  Get-D365LBDAXSFGuids -config $Config 
 Gathers Each AXSF Endpoint details based on the configuration that was gathered
  .EXAMPLE
  Get-D365LBDAXSFGuids
 Gathers Each AXSF Endpoint details based on the the local machines environment
  .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module
    .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
  #>
    [alias("Get-D365AXSFGuids")]
    [CmdletBinding()]
    param
    (
        [psobject]$Config,
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME"
    )
    BEGIN {
    }
    PROCESS {
        if (!$Config) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName
        }
        [int]$count = 0
        $OutputList = @()
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
            } until ($connection -or ($count -eq $($Config.OrchestratorServerNames).Count))
            if (($count -eq $($Config.OrchestratorServerNames).Count) -and (!$connection)) {
                Stop-PSFFunction -Message "Error: Can't connect to Service Fabric"
            }
        }
        $nodes = get-servicefabricnode | Where-Object { ($_.NodeType -eq "AOSNodeType") -or ($_.NodeType -eq "PrimaryNodeType") } 
        $ServiceFabricPartitionIdForAXSF = $(get-servicefabricpartition -servicename 'fabric:/AXSF/AXService').PartitionId
        foreach ($node in $nodes) {
            $nodename = $node.Nodename
            $replicainstanceIdofnode = $(get-servicefabricreplica -partition $ServiceFabricPartitionIdForAXSF | Where-Object { $_.NodeName -eq "$NodeName" }).InstanceId
            $ReplicaDetails = Get-Servicefabricdeployedreplicadetail -nodename $nodename -partitionid $ServiceFabricPartitionIdForAXSF -ReplicaOrInstanceId $replicainstanceIdofnode -replicatordetail
            $endpoints = $ReplicaDetails.deployedservicereplicainstance.address | ConvertFrom-Json
            $deployedinstancespecificguid = $($endpoints.Endpoints | Get-Member | Where-Object { $_.MemberType -eq "NoteProperty" }).Name
            $httpsurl = $endpoints.Endpoints.$deployedinstancespecificguid
            Write-PSFMessage -Level VeryVerbose -Message "$NodeName is accessible via $httpsurl with a guid $deployedinstancespecificguid"

            if ($httpsurl.Length -gt 3){
                $Status = "Operational"
            }
            else{
                $Status = "Down"
            }
            $Properties = @{'Name' = "AXSFGUIDEndpoint"
                'Details'          = "$deployedinstancespecificguid"
                'Status'           = "$Status" 
                'ExtraInfo'        = "$httpsurl"
                'Source'           = $NodeName 
                'Group'            = 'ServiceFabric'
            }
            $Output = New-Object -TypeName psobject -Property $Properties
            $OutputList += $Output

        }
        [PSCustomObject] $OutputList | Sort-Object {$_.Source}
        
    }
    END {
        if ($SFModuleSession) {
            Remove-PSSession -Session $SFModuleSession  
        }
    }
} 