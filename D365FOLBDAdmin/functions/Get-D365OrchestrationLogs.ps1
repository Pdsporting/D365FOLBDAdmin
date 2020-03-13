function Get-D365OrchestrationLogs {
    param (
        [string]$ComputerName,
        [string]$ActiveSecondary,
        [int]$NumberofEvents = 5
    )
    $LatestEventInLog = $(Get-WinEvent -LogName Microsoft-Dynamics-AX-LocalAgent/Operational -MaxEvents 1 -ComputerName $ComputerName).TimeCreated
    $primary = Get-WinEvent -LogName Microsoft-Dynamics-AX-LocalAgent/Operational -MaxEvents $NumberofEventsToCheck -ComputerName $ComputerName | 
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
    $secondary = Get-WinEvent -LogName Microsoft-Dynamics-AX-LocalAgent/Operational -MaxEvents $NumberofEventsToCheck -ComputerName $ActiveSecondary | 
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
    $all = $Primary + $secondary | Sort-Object { $_.TimeCreated } -Descending | Select-Object -First $NumberofEventsToCheck
    return $all
}