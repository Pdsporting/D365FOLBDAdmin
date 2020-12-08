function Enable-D365LBDSFAppServers {
    <#
    .SYNOPSIS
   Grabs the configuration of the local business data environment
   .DESCRIPTION
   Grabs the configuration of the local business data environment through logic using the Service Fabric Cluster XML,
   AXSF.Package.Current.xml and OrchestrationServicePkg.Package.Current.xml
   .EXAMPLE
   Get-D365LBDConfig
   Will get config from the local machine.
   .EXAMPLE
    Get-D365LBDConfig -ComputerName "LBDServerName" -verbose
   Will get the Dynamics 365 Config from the LBD server
   .PARAMETER ComputerName
   optional string 
   The name of the Local Business Data Computer.
   If ignored will use local host.
   .PARAMETER ConfigImportFromFile
   optional string 
   The name of the config file to import (if you are choosing to import rather than pull dynamically)
   .PARAMETER ConfigExportToFile
   optional string 
   The name of the config file to export 
   .PARAMETER CustomModuleName
   optional string 
   The name of the custom module you will be using to caputre the version number

   #>
    [alias("Enable-D365SFAppServers")]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name',
            ParameterSetName = 'NoConfig')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ParameterSetName='Config',
        ValueFromPipeline = $True)]
        [psobject]$Config
    )
    ##Gather Information from the Dynamics 365 Orchestrator Server Config
    BEGIN {
    } 
    PROCESS {
        if (!$Config) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName 
        }[int]$count = 0
        while (!$connection) {
            do {
                $OrchestratorServerName = $Config.$OrchestratorServerName | Select-Object -First 1 -Skip $count
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
                Stop-PSFFunction -Message "Error: Can't conenct to Service Fabric"
            }
        }

       $AppNodes = get-servicefabricnode | Where-Object { ($_.NodeType -eq "AOSNodeType") -or ($_.NodeType -eq "MRType") } 
        $primarynodes = get-servicefabricnode | Where-Object { ($_.NodeType -eq "PrimaryNodeType") } 
        if ($primarynodes.count -gt 0) {
            Stop-PSFFunction -Message "Error: Primary Node configuration not supported" -EnableException -FunctionName $_
        }
        foreach ($AppNode in $AppNodes) {
            Enable-ServiceFabricNode -NodeName $AppNode.NodeName 
        }
        Start-Sleep -Seconds 1

        $nodestatus = Get-serviceFabriceNode | Where-Object { $_.NodeStatus -eq 'Disabled' -and (($_.NodeType -eq "AOSNodeType") -or ($_.NodeType -eq "MRType")) }
        do {
            $nodestatus = Get-serviceFabriceNode | Where-Object { $_.NodeStatus -eq 'Disabled' -and (($_.NodeType -eq "AOSNodeType")-or ($_.NodeType -eq "MRType")) } 
            Start-Sleep -Seconds 5
        } until (!$nodestatus -or $nodestatus -eq 0)
        Write-PSFMessage -Message "All App Nodes Enabled" -Level VeryVerbose
    }
    END{}
}