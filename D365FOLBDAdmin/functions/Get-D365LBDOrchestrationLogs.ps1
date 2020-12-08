function Get-D365LBDOrchestrationLogs {
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
    [alias("Get-D365OrchestrationLogs")]
    param ([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name',
            ParameterSetName = 'NoConfig')]
        [string]$ComputerName,
        [string]$ActiveSecondary,
        [int]$NumberofEvents = 5,
        [Parameter(ParameterSetName='Config',
        ValueFromPipeline = $True)]
        [psobject]$Config
    )
    BEGIN {
    }
    PROCESS {
        if (!$Config) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly
        }
    
        $LatestEventInLog = $(Get-WinEvent -LogName Microsoft-Dynamics-AX-LocalAgent/Operational -MaxEvents 1 -ComputerName $ComputerName).TimeCreated
        $primary = Get-WinEvent -LogName Microsoft-Dynamics-AX-LocalAgent/Operational -MaxEvents $NumberofEvents -ComputerName $ComputerName | 
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
        $LatestEventInLog = $(Get-WinEvent -LogName Microsoft-Dynamics-AX-LocalAgent/Operational -MaxEvents 1 -ComputerName $ActiveSecondary).TimeCreated
        $secondary = Get-WinEvent -LogName Microsoft-Dynamics-AX-LocalAgent/Operational -MaxEvents $NumberofEvents -ComputerName $ActiveSecondary | 
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
        $all = $Primary + $secondary | Sort-Object { $_.TimeCreated } -Descending | Select-Object -First $NumberofEvents
        return $all
    }
    END {
    }
}