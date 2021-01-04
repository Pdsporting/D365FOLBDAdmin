function Restart-D365LBDSFAppServers {
    <#
      .SYNOPSIS
  
   .DESCRIPTION
   
   .EXAMPLE
   Restart-D365LBDSFAppServers
  
   .EXAMPLE
    Enable-D365LBDSFAppServers -ComputerName "LBDServerName" -verbose
   
   .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module
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
        [int]$Timeout = 600,
        [switch]$waittillhealthy
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
                $OrchestratorServerName = $Config.OrchestratorServerNames | Select-Object -First 1 -Skip $count
                Write-PSFMessage -Message "Verbose: Reaching out to $OrchestratorServerName to try and connect to the service fabric" -Level Verbose
                $SFModuleSession = New-PSSession -ComputerName $OrchestratorServerName
                if (!$module) {
                    $module = Import-Module -Name ServiceFabric -PSSession $SFModuleSession 
                }
                Write-PSFMessage -Message "-ConnectionEndpoint $($config.SFConnectionEndpoint) -X509Credential -FindType FindByThumbprint -FindValue $($config.SFServerCertificate) -ServerCertThumbprint $($config.SFServerCertificate) -StoreLocation LocalMachine -StoreName My" -Level Verbose
                $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $config.SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
                $count = $count + 1
                if (!$connection) {
                    Write-PSFMessage -Message "Count of servers tried $count" -Level Verbose
                }
            } until ($connection -or ($count -eq $($Config.OrchestratorServerNames).Count))
            if (($count -eq $($Config.OrchestratorServerNames).Count) -and (!$connection)) {
                Stop-PSFFunction -Message "Error: Can't connect to Service Fabric"
            }
        }
        $AppNodes = Get-ServiceFabricNode | Where-Object { ($_.NodeType -eq "AOSNodeType") -or ($_.NodeType -eq "MRType") -or ($_.NodeType -eq "ReportServerType") } 
      
        foreach ($AppNode in $AppNodes) {
            Restart-ServiceFabricNode -NodeName $AppNode.NodeName -CommandCompletionMode Verify -Timeout 200
        }
      
        Start-Sleep -Seconds 5
        [int]$timeoutondisablecounter = 0
        $nodestatus = Get-ServiceFabricNode | Where-Object { $_.NodeStatus -eq 'Disabled' -and (($_.NodeType -eq "AOSNodeType") -or ($_.NodeType -eq "MRType")) }
        do {
            $nodestatus = Get-ServiceFabricNode | Where-Object { $_.NodeStatus -eq 'Disabled' -and (($_.NodeType -eq "AOSNodeType") -or ($_.NodeType -eq "MRType")) } 
            $timeoutondisablecounter = $timeoutondisablecounter + 5
            Start-Sleep -Seconds 5
        } until (!$nodestatus -or $nodestatus -eq 0 -or ($timeoutondisablecounter -gt $Timeout))
        Write-PSFMessage -Message "All App Nodes Enabled" -Level VeryVerbose

        do {
            try {
                $apps = Get-ServiceFabricApplication -ErrorAction Stop
                Start-Sleep -Seconds 5
            }
            catch {}

        } until ($apps.count -gt 0)
        $counterofhealthyapps = 0
        foreach ($app in $apps) {
            $health = Get-serviceFabricApplicationHealth -ApplicationName $app.ApplicationName

            if ($health.aggregatedhealthstate -eq "Ok") {
                $counterofhealthyapps = $counterofhealthyapps + 1
            }
            else {
                Write-PSFMessage -Level Warning -Message "Warning: $($health.ApplicationName) is Unhealthy"
                if ($waittillhealthy) {
                    $timer = 0
                    do {
                        $health = Get-serviceFabricApplicationHealth -ApplicationName $app.ApplicationName
                        $timer = $timer + 10
                        Start-Sleep -Seconds 10
                        Write-PSFMessage -Message "Waiting for $($app.ApplicationName) to be healthy" -Level VeryVerbose
                
                    } until ($health.aggregatedhealthstate -eq "Ok" -or $timer -gt $Timeout)
                }
                if ($timer -gt $Timeout)
                {
                    Write-PSFMessage -Message "Warning: Timeout occured" -Level Warning
                }
            }

        }
    }
    END {}
}