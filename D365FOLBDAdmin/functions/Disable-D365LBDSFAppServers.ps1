function Disable-D365LBDSFAppServers {
    <#
    .SYNOPSIS
  
   .DESCRIPTION
   
   .EXAMPLE
   Disable-D365LBDSFAppServers
  
   .EXAMPLE
    Disable-D365LBDSFAppServers -ComputerName "LBDServerName" -verbose
   
   .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module

   #>
    [alias("Disable-D365SFAppServers")]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name',
            ParameterSetName = 'NoConfig')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ParameterSetName = 'Config',
            ValueFromPipeline = $True)]
        [psobject]$Config
    )
    ##Gather Information from the Dynamics 365 Orchestrator Server Config
    BEGIN {
    } 
    PROCESS {
        if (!$Config) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly
        }
        [int]$count = 0
        while (!$connection) {
            do {
                $OrchestratorServerName = $Config.$OrchestratorServerNames | Select-Object -First 1 -Skip $count
                Write-PSFMessage -Message "Verbose: Reaching out to $OrchestratorServerName to try and connect to the service fabric" -Level Verbose
                $SFModuleSession = New-PSSession -ComputerName $OrchestratorServerName
                $module = Import-Module -Name ServiceFabric -PSSession $SFModuleSession 
                $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $config.ConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.ServerCertificate -ServerCertThumbprint $config.ServerCertificate -StoreLocation LocalMachine -StoreName My
                $count = $count + 1
                if (!$connection) {
                    Write-PSFMessage -Message "Count of servers tried $count" -Level Verbose
                }
            } until ($connection -or ($count -eq $Config.$OrchestratorServerName.Count))
            if (($count -eq $Config.$OrchestratorServerName.Count) -and (!$connection)) {
                Stop-PSFFunction -Message "Error: Can't connect to Service Fabric"
            }
        }

        $AppNodes = get-servicefabricnode | Where-Object { ($_.NodeType -eq "AOSNodeType") } 
        $primarynodes = get-servicefabricnode | Where-Object { ($_.NodeType -eq "PrimaryNodeType") } 
        if ($primarynodes.count -gt 0) {
            Stop-PSFFunction -Message "Error: Primary Node configuration not supported" -EnableException -FunctionName $_
        }
        foreach ($AppNode in $AppNodes) {
            Disable-ServiceFabricNode -NodeName $AppNode.NodeName -Intent RemoveData -force -timeoutsec 30
        }
        Start-Sleep -Seconds 1

        $nodestatus = Get-serviceFabriceNode | Where-Object { $_.NodeStatus -eq 'Disabling' -and ($_.NodeType -eq "AOSNodeType") }
        do {
            $nodestatus = Get-serviceFabriceNode | Where-Object { $_.NodeStatus -eq 'Disabling' -and ($_.NodeType -eq "AOSNodeType") } 
            Start-Sleep -Seconds 5
        } until (!$nodestatus -or $nodestatus -eq 0)
        Write-PSFMessage -Message "All App Nodes Disabled" -Level VeryVerbose

    }
    END {}
}