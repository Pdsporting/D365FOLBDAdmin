
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
        Foreach ($SFServerName in $config.AllAppServerList) {
            $LogFolder = Get-ChildItem -Path "\\$SFServerName\c$\ProgramData\SF\DiagnosticStore\fabriclogs*\*\Fabric*" | Select-Object -First 1 -ExpandProperty FullName
            $StartTime = Get-Date
            Write-PSFMessage -Level Verbose -Message "Starting Clean on $LogFolder"
            $FilesThatAreBeingDeleted = Get-ChildItem -path $LogFolder | Sort-Object LastWriteTime | Where-Object { $_.Name -ne "ControlFile.txt" -and $_.LastWriteTime -lt (Get-Date).AddDays(-$CleanupOlderThanDays) }
            $FileCount = $FilesThatAreBeingDeleted.CreationTimeUtc
            Write-PSFMessage -Level Verbose -Message "Deleting $FileCount files on $SFServerName"
            $FilesThatAreBeingDeleted | Remove-Item -Force -Recurse
            $EndTime = Get-Date
            $TimeDiff = New-TimeSpan -Start $StartTime -End $EndTime
            Write-PSFMessage -Level VeryVerbose -Message "$SFServerName - StartTime: $StartTime - EndTime: $EndTime - Execution Time: $($TimeDiff.Minutes) $($TimeDiff.Seconds) Count of Files: $FileCount"
            if ($ControlFile) {
                "$SFServerName - StartTime: $StartTime - EndTime: $EndTime - Execution Time: $($TimeDiff.Minutes) $($TimeDiff.Seconds) Count of Files: $FileCount " | Out-File $LogFolder\ControlFile.txt -append
            }
        }
        Write-PSFMessage -Level VeryVerbose -Message "$($config.LCSEnvironmentName) Service Fabric Servers have been cleaned"
    }
    END {
        
    }
}