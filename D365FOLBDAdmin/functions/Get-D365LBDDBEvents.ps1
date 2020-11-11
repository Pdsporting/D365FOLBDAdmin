function Get-D365LBDDBEvents {
    [alias("Get-D365DBEvents")]
    param (
        [int]$NumberofEvents = 20
    )

    $config = Get-D365LBDConfig 
    
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
            if (($LatestEventinLog -gt $LatestEventinAllLogs) -or (!$LatestEventinAllLogs)) {
                $LatestEventinAllLogs = $LatestEventinLog
                $ServerWithLatestLog = $AXSFServerName 
                Write-PSFMessage -Level Verbose -Message "Server with latest log updated to $ServerWithLatestLog"
            }
        }
        Write-PSFMessage -Level VeryVerbose -Message "Gathering from $ServerWithLatestLog"
        Get-WinEvent -LogName Microsoft-Dynamics-AX-DatabaseSynchronize/Operational -maxevents $NumberofEvents -computername $ServerWithLatestLog
    }
}