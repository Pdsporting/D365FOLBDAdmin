function Get-D365LBDOrchestrationLogs {
    [alias("Get-D365OrchestrationLogs")]
    param (
        [string]$ComputerName,
        [string]$ActiveSecondary,
        [int]$NumberofEvents = 5,
        [psobject]$Config
    )
    if (!$Config) {
        $Config = Get-D365LBDConfig -ComputerName $ComputerName 
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