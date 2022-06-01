function Get-D365LBDDBEvents {
    <#
    .SYNOPSIS
   Checks the event viewer of the for the latest Database Synchronization events.
   .DESCRIPTION
   Checks the event viewer of the for the latest Database Synchronization events.
   .EXAMPLE
   Get-D365LBDDBEvents 
   Gets the latest Database Synchronization events on the application servers on the local machines environment
   .EXAMPLE
    Get-D365LBDDBEvents  -ComputerName "LBDServerName" -verbose
   Gets the latest Database Synchronization events on the application servers on the specified machines environment
    .EXAMPLE
    $config = get-d365Config
    Get-D365DBEvents -config $config -numberofevents 3
    Gets the latest Database Synchronization events on the application servers on the specified configuration's environment
   .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER NumberofEvents
   Integer
   Number of Events to be pulled defaulted to 20 (suggest grabbing less for reading easy)
   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module
   #>
    [CmdletBinding()]
    [alias("Get-D365DBEvents")]
    param ([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [int]$NumberofEvents = 20,
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
    
        Foreach ($AXSFServerName in $config.AXSFServerNames) {
            try {
                Write-PSFMessage -Level Verbose -Message "Reaching out to $AXSFServerName to look for DB logs"
                $LatestEventinLog = $(Get-WinEvent -LogName Microsoft-Dynamics-AX-DatabaseSynchronize/Operational -maxevents 1 -computername $AXSFServerName -ErrorAction Stop).TimeCreated
            }
            catch {
                Write-PSFMessage -Level VeryVerbose -Message "$AXSFServerName $_"
                if ($_.Exception.Message -eq "No events were found that match the specified selection criteria") {
                    $LatestEventinLog = $null
                }
                if ($_.Exception.Message -eq "The RPC Server is unavailable") {
                    {           
                        Write-PSFMessage -Level Verbose -Message "The RPC Server is Unavailable trying WinRM"       
                        $LatestEventinLog = Invoke-Command -ComputerName $AXSFServerName -ScriptBlock { $(Get-EventLog -LogName Microsoft-Dynamics-AX-DatabaseSynchronize/Operational -maxevents 1 -computername $AXSFServerName).TimeCreated }
                    }
                }
            }
            if (($LatestEventinLog -gt $LatestEventinAllLogs) -or (!$LatestEventinAllLogs)) {
                $LatestEventinAllLogs = $LatestEventinLog
                $ServerWithLatestLog = $AXSFServerName 
                Write-PSFMessage -Level Verbose -Message "Server with latest log updated to $ServerWithLatestLog with a date time of $LatestEventinLog"
            }
        }
        Write-PSFMessage -Level VeryVerbose -Message "Gathering database sync events from $ServerWithLatestLog"
        $events = Get-WinEvent -LogName Microsoft-Dynamics-AX-DatabaseSynchronize/Operational -maxevents $NumberofEvents -computername $ServerWithLatestLog | 
        ForEach-Object -Process { `
                New-Object -TypeName PSObject -Property `
            @{'MachineName'        = $ServerWithLatestLog ;
                'EventMessage'     = $_.Properties[0].value;
                'EventDetails'     = $_.Properties[1].value; 
                'Message'          = $_.Message;
                'LevelDisplayName' = $_.LevelDisplayName;
                'TimeCreated'      = $_.TimeCreated;
                'TaskDisplayName'  = $_.TaskDisplayName
                'UserId'           = $_.UserId;
                'LogName'          = $_.LogName;
                'ProcessId'        = $_.ProcessId;
                'ThreadId'         = $_.ThreadId;
                'Id'               = $_.Id;
            }
            $SyncStatusFound = $false
            foreach ($event in $events) {
                if ((($event.message -contains "Table synchronization failed.") -or ($event.message -contains "Database Synchronize Succeeded.")) -and $SyncStatusFound -eq $false) {
                    if ($event.message -contains "Table synchronization failed.") {
                        Write-PSFMessage -Message "Found a DB Sync Failure $($event.ServerWithLatestLog) ($($event.TimeCreated)" -Level Verbose
                    }
                    if ($event.message -contains "Database Synchronize Succeeded.") {
                        Write-PSFMessage -Message "Found a DB Sync Success $($event.ServerWithLatestLog) ($($event.TimeCreated)" -Level Verbose
                    }
                    $SyncStatusFound = $true
                }
            }        
        }
        $events
    }
    END {
    }
}