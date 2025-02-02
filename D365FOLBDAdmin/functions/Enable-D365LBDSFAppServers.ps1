function Enable-D365LBDSFAppServers {
    <#
      .SYNOPSIS
  Enables all the D365 application servers inside of service fabric (not orchestrator nodes)
   .DESCRIPTION
   Connects to service fabric then enables all the D365 application servers inside of service fabric (not orchestrator nodes).
   .EXAMPLE
   Enable-D365LBDSFAppServers
   Enables all the application servers on the local machines environment
   .EXAMPLE
    Enable-D365LBDSFAppServers -ComputerName "LBDServerName" -verbose
    Enables all the application servers on the specified servers environment
    .EXAMPLE
    $config = get-d365Config
   Enable-D365LBDSFAppServers -config $Config 
    Enables all the application servers on the specified configurations environment
   .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module
    .PARAMETER Timeout 
    Integer 
    Timeout in seconds for how long for the command to run has a default of 600 seconds
   #>
    [alias("Enable-D365SFAppServers")]
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
            $Config = Get-D365LBDConfig -ComputerName $ComputerName
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
            }  until ($connection -or ($count -eq $($Config.OrchestratorServerNames).Count) -or ($($Config.OrchestratorServerNames).Count) -eq 0)
            if (($count -eq $($Config.OrchestratorServerNames).Count) -and (!$connection)) {
                Stop-PSFFunction -Message "Error: Can't connect to Service Fabric" -EnableException $true -FunctionName $_
            }
        }
        $AppNodes = Get-ServiceFabricNode | Where-Object { ($_.NodeType -eq "AOSNodeType") -or ($_.NodeType -eq "MRType") -or ($_.NodeType -eq "ReportServerType") } 
        $primarynodes = Get-ServiceFabricNode | Where-Object { ($_.NodeType -eq "PrimaryNodeType") } 
        if ($primarynodes.count -gt 0) {
            Stop-PSFFunction -Message "Error: Primary Node configuration not supported with enable or disable. Restart-D365LBDSFAppServers is supported." -EnableException $true -FunctionName $_
        }
        foreach ($AppNode in $AppNodes) {
            Enable-ServiceFabricNode -NodeName $AppNode.NodeName 
        }
        Start-Sleep -Seconds 1
        [int]$timeoutondisablecounter = 0
        $nodestatus = Get-ServiceFabricNode | Where-Object { $_.NodeStatus -eq 'Disabled' -and (($_.NodeType -eq "AOSNodeType") -or ($_.NodeType -eq "MRType")) }
        do {
            $nodestatus = Get-ServiceFabricNode | Where-Object { $_.NodeStatus -eq 'Disabled' -and (($_.NodeType -eq "AOSNodeType") -or ($_.NodeType -eq "MRType")) } 
            $timeoutondisablecounter = $timeoutondisablecounter + 5
            Start-Sleep -Seconds 5
        } until (!$nodestatus -or $nodestatus -eq 0 -or ($timeoutondisablecounter -gt $Timeout))
        Write-PSFMessage -Message "All App Nodes Enabled" -Level VeryVerbose
    }
    END {}
}