
function Remove-D365LBDSFLogs {
   
    [alias("Remove-D365SFLogs")]
    param
    (
        [Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name',
            ParameterSetName = 'NoConfig')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [psobject]$Config,
        [int]$CleanupOlderThanDays = 1,
        [string]$CustomModuleName,
        [switch]$ControlFile
    )
    BEGIN {
    }
    PROCESS {
        if (!$Config) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly   
        }
        Foreach ($SFServerName in $($config.AllAppServerList | Select-Object ComputerName).ComputerName) {
            $LogFolder = Get-ChildItem -Path "\\$SFServerName\c$\ProgramData\SF\DiagnosticsStore\fabriclogs*\*\Fabric*" | Select-Object -First 1 -ExpandProperty FullName
            $StartTime = Get-Date
            Write-PSFMessage -Level Verbose -Message "Starting Clean on $LogFolder"
            $FilesThatAreBeingDeleted = Get-ChildItem -path $LogFolder | Sort-Object LastWriteTime | Where-Object { $_.Name -ne "ControlFile.txt" -and $_.LastWriteTime -lt (Get-Date).AddDays(-$CleanupOlderThanDays) }
            $FileCount = $FilesThatAreBeingDeleted.Count
            Write-PSFMessage -Level Verbose -Message "Deleting $FileCount files on $SFServerName"
            if ($FilesThatAreBeingDeleted -and $FileCount -gt 0 ) {
                $FilesThatAreBeingDeleted.FullName | Remove-Item -Force -Recurse
            }
            $EndTime = Get-Date
            $TimeDiff = New-TimeSpan -Start $StartTime -End $EndTime
            Write-PSFMessage -Level VeryVerbose -Message "$SFServerName - StartTime: $StartTime - EndTime: $EndTime - Execution Time: $($TimeDiff.Minutes) Minutes $($TimeDiff.Seconds) Seconds - Count of Files: $FileCount"
            if ($ControlFile -and $FileCount -gt 0) {
                "$SFServerName - StartTime: $StartTime - EndTime: $EndTime - Execution Time: $($TimeDiff.Minutes) $($TimeDiff.Seconds) Count of Files: $FileCount" | Out-File $LogFolder\ControlFile.txt -append
            }
        }
        Write-PSFMessage -Level VeryVerbose -Message "$($config.LCSEnvironmentName) Service Fabric Servers have been cleaned of older than $CleanupOlderThanDays days Service Fabric Logs."
    }
    END {
        
    }
}