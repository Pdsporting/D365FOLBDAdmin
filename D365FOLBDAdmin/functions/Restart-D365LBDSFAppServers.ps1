function Restart-D365LBDSFAppServers {
    <#
    .SYNOPSIS
    Restarts all application nodes in the service fabric layer. Also has the ability to reboot the whole Operating system (OS) and also to restart the orchestrator nodes (full OS restart only)
   .DESCRIPTION
   Restarts all application nodes in the service fabric layer. Also has the ability to reboot the whole Operating system (OS) and also to restart the orchestrator nodes (full OS restart only)
   .EXAMPLE
   Restart-D365LBDSFAppServers
   Based on the local server it will determine all the environment's servers and restart the service fabric nodes in the service fabric layer.
   .EXAMPLE
    Restart-D365LBDSFAppServers -ComputerName "LBDServerName" -verbose
    Based on the defined server it will determine all the environment's servers and restart the service fabric nodes in the service fabric layer.
   .EXAMPLE
    Restart-D365LBDSFAppServers -config $config -RebootWholeOS -verbose
    Based on the defined config it will determine all the environment's AX SF application servers and restart the whole Operating system of each.
    .EXAMPLE
    Restart-D365LBDSFAppServers -config $config -RebootWholeOSIncludingOrch -verbose -waittillhealthy
    Based on the config it will determine all the environment's servers including orchestrator nodes and restart the whole Operating system of each and will wait till the servers are "healthy" (can be accessed for more commands).
   .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module
   #>
    [alias(" Restart-D365SFAppServers")]
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
        [switch]$waittillhealthy,
        [switch]$RebootWholeOS,
        [switch]$RebootWholeOSIncludingOrch
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
                    $trialEndpoint = "https://$OrchestratorServerName" + ":198000"
                    $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $trialEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
                }
                if (!$connection) {
                    Write-PSFMessage -Message "Count of servers tried $count" -Level Verbose
                }
            } until ($connection -or ($count -eq $($Config.OrchestratorServerNames).Count))
            if (($count -eq $($Config.OrchestratorServerNames).Count) -and (!$connection)) {
                Stop-PSFFunction -Message "Error: Can't connect to Service Fabric"
            }
        }
        $AppNodes = Get-ServiceFabricNode | Where-Object { ($_.NodeType -eq "AOSNodeType") -or ($_.NodeType -eq "MRType") -or ($_.NodeType -eq "ReportServerType") -or ($_.NodeType -eq "PrimaryNodeType") } 
      
        if ($RebootWholeOS -or $RebootWholeOSIncludingOrch) {
            if ($RebootWholeOSIncludingOrch) {
                if ($waittillhealthy) {
                    Write-PSFMessage -Message "Restarting $($config.AllAppServerList) and Waiting for Powershell to be available" -Level Verbose
                    Restart-computer -ComputerName  $config.AllAppServerList -Force -Wait -for PowerShell -Delay 2 -Verbose
                }
                else {
                    Write-PSFMessage -Message "Restarting $($config.AllAppServerList)" -Level Verbose
                    Restart-computer -ComputerName  $config.AllAppServerList -Force -Wait -for PowerShell -Delay 2 -Verbose
                }   
            }
            else{ ## Only SF nodes
                if ($waittillhealthy) {
                    Write-PSFMessage -Message "Restarting $($config.AXSFServerNames) and Waiting for Powershell to be available" -Level Verbose
                    Restart-computer -ComputerName  $config.AXSFServerNames -Force -Wait -for PowerShell -Delay 2
                }
                else {
                    Write-PSFMessage -Message "Restarting $($config.AXSFServerNames)" -Level Verbose
                    Restart-computer -ComputerName  $config.AXSFServerNames -Force -Verbose
                }  
            }
        }
        else {
            foreach ($AppNode in $AppNodes) {
                Restart-ServiceFabricNode -NodeName $AppNode.NodeName -CommandCompletionMode Verify -Timeout 200
            }
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
                if ($timer -gt $Timeout) {
                    Write-PSFMessage -Message "Warning: Timeout occured" -Level Warning
                }
            }

        }
    }
    END {}
}