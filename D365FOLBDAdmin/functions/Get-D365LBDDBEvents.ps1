function Get-D365LBDDBEvents {
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
    [CmdletBinding()]
    [alias("Get-D365DBEvents")]
    param ([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name',
            ParameterSetName = 'NoConfig')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [int]$NumberofEvents = 20,
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
    
        Foreach ($AXSFServerName in $config.AXSFServerNames) {
            try {
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
        Write-PSFMessage -Level VeryVerbose -Message "Gathering from $ServerWithLatestLog"
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
     
            ##if ($events.Message -eq 'Database Synchronize Succeeded.')
        }
        $events
    }
    END {
    }
}