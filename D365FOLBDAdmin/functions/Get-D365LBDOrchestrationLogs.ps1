function Get-D365LBDOrchestrationLogs {
    <#
    .SYNOPSIS
  
   .DESCRIPTION
   
   .EXAMPLE
    Get-D365LBDOrchestrationLogs
  
   .EXAMPLE
     Get-D365LBDOrchestrationLogs -ComputerName "LBDServerName" -verbose
    .EXAMPLE
    $config = Get-D365Config
     Get-D365OrchestrationLogs -config $config -numberofevents 5
   
   .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module

   #>
    [alias("Get-D365OrchestrationLogs")]
    [CmdletBinding()]
    param ([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name')]
        [string]$ComputerName,
        [int]$NumberofEvents = 5,
        [Parameter(ValueFromPipeline = $True)]
        [psobject]$Config
    )
    BEGIN {
    }
    PROCESS {
        if (!$Config -or $Config.OrchestratorServerNames.Count -eq 0) {
            Write-PSFMessage -Level VeryVerbose -Message "Config not defined or Config is invalid. Trying to Get new config using $ComputerName"
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
                    Import-PSSession -Session $SFModuleSession
                }
                $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $config.SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
                $count = $count + 1
                
                if (!$connection) {
                    $trialEndpoint = "https://$OrchestratorServerName" + ":198000"
                    $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $trialEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
                    if ($connection) {
                        Write-PSFMessage -Message "Connected to Service Fabric Via: Connect-ServiceFabricCluster -ConnectionEndpoint $trialEndpoint -X509Credential -FindType FindByThumbprint -FindValue $ServerCertificate -ServerCertThumbprint $ServerCertificate -StoreLocation LocalMachine -StoreName My"
                    }
                }
                if (!$connection) {
                    $connection = Connect-ServiceFabricCluster
                    if ($connection) {
                        Write-PSFMessage -Message "Connected to Service Fabric Via: Connect-ServiceFabricCluster"
                    }
                }
            }  until ($connection -or ($count -eq $($Config.OrchestratorServerNames).Count) -or ($($Config.OrchestratorServerNames).Count) -eq 0)
            if (($count -eq $($Config.OrchestratorServerName).Count) -and (!$connection)) {
                Stop-PSFFunction -Message "Error: Can't connect to Service Fabric"
            }
            if (!$connection) {
                Write-PSFMessage -Message "Count of servers tried $count" -Level Verbose
            }
        }
        $orchnodes = Get-D365LBDOrchestrationNodes -config $Config
        Write-PSFMessage -Level Verbose -Message "$orchnodes"
    
        $LatestEventInLog = $(Get-WinEvent -LogName Microsoft-Dynamics-AX-LocalAgent/Operational -MaxEvents 1 -ComputerName $orchnodes.PrimaryNodeName).TimeCreated
        if ($NumberofEvents -eq 1) {
            $primary = Get-WinEvent -LogName Microsoft-Dynamics-AX-LocalAgent/Operational -MaxEvents 2 -ComputerName $orchnodes.PrimaryNodeName | 
            ForEach-Object -Process { `
                    New-Object -TypeName PSObject -Property `
                @{'MachineName'        = $_.Properties[0].value;
                    'EventMessage'     = $_.Properties[1].value;
                    'EventDetails'     = $_.Properties[2].value; 
                    'Message'          = $_.Message;
                    'LevelDisplayName' = $_.LevelDisplayName;
                    'TimeCreated'      = $_.TimeCreated;
                    'UserId'           = $_.UserId;
                    'LogName'          = $_.LogName;
                    'ProcessId'        = $_.ProcessId;
                    'ThreadId'         = $_.ThreadId;
                    'Id'               = $_.Id;
                    'ReplicaType'      = 'Primary';
                    'LatestEventInLog' = $LatestEventInLog;
                }
            }
        }
        else {
            $primary = Get-WinEvent -LogName Microsoft-Dynamics-AX-LocalAgent/Operational -MaxEvents $NumberofEvents -ComputerName $orchnodes.PrimaryNodeName | 
            ForEach-Object -Process { `
                    New-Object -TypeName PSObject -Property `
                @{'MachineName'        = $_.Properties[0].value;
                    'EventMessage'     = $_.Properties[1].value;
                    'EventDetails'     = $_.Properties[2].value; 
                    'Message'          = $_.Message;
                    'LevelDisplayName' = $_.LevelDisplayName;
                    'TimeCreated'      = $_.TimeCreated;
                    'UserId'           = $_.UserId;
                    'LogName'          = $_.LogName;
                    'ProcessId'        = $_.ProcessId;
                    'ThreadId'         = $_.ThreadId;
                    'Id'               = $_.Id;
                    'ReplicaType'      = 'Primary';
                    'LatestEventInLog' = $LatestEventInLog;
                }
            }
        }
        $LatestEventInLog = $(Get-WinEvent -LogName Microsoft-Dynamics-AX-LocalAgent/Operational -MaxEvents 1 -ComputerName $orchnodes.SecondaryNodeName).TimeCreated
        if ($NumberofEvents -eq 1) {
            $secondary = Get-WinEvent -LogName Microsoft-Dynamics-AX-LocalAgent/Operational -MaxEvents 2 -ComputerName $orchnodes.SecondaryNodeName | 
            ForEach-Object -Process { `
                    New-Object -TypeName PSObject -Property `
                @{'MachineName'        = $_.Properties[0].value;
                    'EventMessage'     = $_.Properties[1].value;
                    'EventDetails'     = $_.Properties[2].value; 
                    'Message'          = $_.Message;
                    'LevelDisplayName' = $_.LevelDisplayName;
                    'TimeCreated'      = $_.TimeCreated;
                    'UserId'           = $_.UserId;
                    'LogName'          = $_.LogName;
                    'ProcessId'        = $_.ProcessId;
                    'ThreadId'         = $_.ThreadId;
                    'Id'               = $_.Id;
                    'ReplicaType'      = 'ActiveSecondary';
                    'LatestEventInLog' = $LatestEventInLog;
                }
            }
        }
        else {
            $secondary = Get-WinEvent -LogName Microsoft-Dynamics-AX-LocalAgent/Operational -MaxEvents $NumberofEvents -ComputerName $orchnodes.SecondaryNodeName | 
            ForEach-Object -Process { `
                    New-Object -TypeName PSObject -Property `
                @{'MachineName'        = $_.Properties[0].value;
                    'EventMessage'     = $_.Properties[1].value;
                    'EventDetails'     = $_.Properties[2].value; 
                    'Message'          = $_.Message;
                    'LevelDisplayName' = $_.LevelDisplayName;
                    'TimeCreated'      = $_.TimeCreated;
                    'UserId'           = $_.UserId;
                    'LogName'          = $_.LogName;
                    'ProcessId'        = $_.ProcessId;
                    'ThreadId'         = $_.ThreadId;
                    'Id'               = $_.Id;
                    'ReplicaType'      = 'ActiveSecondary';
                    'LatestEventInLog' = $LatestEventInLog;
                }
            }
        }
        foreach ($primarylog in $primary) {
            if ($primarylog.EventMessage -like "status of job *, Success") {
                Write-PSFMessage -Message "Found RunBook Success Message" -Level Verbose
            }
            if ($primarylog.EventMessage -like "status of job *, Error") {
                Write-PSFMessage -Message "Found RunBook Error Message" -Level Verbose
            }
        }
        if (!$secondary) {
            $all = $Primary | Sort-Object { $_.TimeCreated } -Descending | Select-Object -First $NumberofEvents
        }
        else {
            $all = $Primary + $secondary | Sort-Object { $_.TimeCreated } -Descending | Select-Object -First $NumberofEvents
        }
        return $all
    }
    END {
    }
}