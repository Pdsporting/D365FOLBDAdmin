function Start-D365LBDSleepForNewAssetPrep {
    [alias("Start-D365SleepForNewAssetPrep")]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(Mandatory = $true)][string]$CustomModuleName,
        [int]$TimeOutMinutes = 400
    )

    if (!$config) {
        $config = Get-D365Config -ComputerName "$Computername" -CustomModuleName "$CustomModuleName" -HighLevelOnly
    }
    $config = Get-D365Config -ComputerName $config.SourceAXSFServer -CustomModuleName "$CustomModuleName" -HighLevelOnly
    $LatestFullyPreppedVersion = $config.LastFullyPreppedCustomModuleAsset
    $CustommoduleVersion = $config.CustomModuleVersion
    $CheckforOldPrepped = Export-D365AssetModuleVersion -CustomModuleName $CustomModuleName -Config $config

    Write-PSFMessage -Level VeryVerbose -message "Currently running $CustommoduleVersion with a prepped version of $LatestFullyPreppedVersion"
    Write-verbose "Timeout set to $TimeOutMinutes minutes" -verbose
    do {
        Write-PSFMessage -Level VeryVerbose "Looking for new build new prep every minute. Runtime: $runtime" -Verbose
        Start-Sleep -Seconds 60
        $Runtime = $Runtime + 1
        $newversion = Export-D365AssetModuleVersion -CustomModuleName $CustomModuleName -Config $config
    }
    until($newversion -or $Runtime -gt $TimeOutMinutes)
  
    if ($Runtime -gt $TimeOutMinutes) {
        Stop-PSFFunction -Message "Error: Timeout hit. Stopping" -EnableException $true -Cmdlet $PSCmdlet
    }
    else {
        $Updatedconfig = Get-D365Config -ComputerName $config.SourceAXSFServer -CustomModuleName "$CustomModuleName" -HighLevelOnly
        Write-PSFMessage -Level VeryVerbose -Message "$($Updatedconfig.LastFullyPreppedCustomModuleAsset) newversion has been prepped. Took $Runtime"
        Write-PSFMessage -Level VeryVerbose -Message "RunBook Task $($Updatedconfig.LastRunbookName) has a state is $($Updatedconfig.OrchestratorJobRunBookState) of been prepped"
        $Updatedconfig 
    }

}


