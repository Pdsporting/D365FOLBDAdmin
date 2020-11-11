function Get-D365LBDDBEvents {
    [alias("Get-D365DBEvents")]
    param (
        [int]$NumberofEvents = 20
    )

    $config = Get-D365LBDConfig 
    

    Foreach ($AXSFServerName in $config.AXSFServerNames) {
        try {

            ##todoadd logic to find if eventlog exists
            $latestEventinlog = $(Get-EventLog -LogName Microsoft-Dynamics-AX-DatabaseSynchronize/Operational -maxevents 1 -computername $AXSFServerName).TimeCreated

        }
        catch {
            Write-PSFMessage -Level Verbose -Message "$AXSFServerName $_"
            if ($_.Exception.Message -eq "The RPC Server is Unavailable trying WinRM")
            {
                $latestEventinlog = Invoke-Command -ComputerName $AXSFServerName -ScriptBlock { $(Get-EventLog -LogName Microsoft-Dynamics-AX-DatabaseSynchronize/Operational -maxevents 1 -computername $AXSFServerName).TimeCreated }
            }

        }
        if (($latestEventinlog -gt $latesteventinalllogs) -or (!$latesteventinalllogs)) {
            $latesteventinalllogs = $latestEventinlog
            $serverwithlatestlog = $AXSFServerName 
        }
    }
    Write-PSFMessage -Level Verbose -Message "Gathering from $serverwithlatestlog"
    Get-WinEvent -LogName Microsoft-Dynamics-AX-DatabaseSynchronize/Operational -maxevents $NumberofEvents -computername $serverwithlatestlog
}