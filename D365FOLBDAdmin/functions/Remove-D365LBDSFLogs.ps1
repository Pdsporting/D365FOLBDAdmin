
function Remove-D365LBDSFLogs {
    <#
   .SYNOPSIS
  Removes older files in the service fabric fabric logs folder
   .DESCRIPTION
   Removes older files in the service fabric fabric logs folder
   .EXAMPLE
   Remove-D365SFLogs -verbose
    Will remove the log files on each server that are older than 1 day on the local machines environment. Recommended to run on verbose to see what server/step its at.
   .EXAMPLE
   $config = get-d365Config
    Remove-D365SFLogs config $config -CleanupOlderThanDays 2 -verbose
   Will remove the log files on each server that are older than 2 days on the defined configurations environment. Recommended to run on verbose to see what server/step its at.
   .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module
   .PARAMETER CleanupOlderThanDays 
   integer
   Value in days that would be considered not needed. Example if set to 5 the cert expires in less than 5 days it delete all logs older than 5 days. Default of 1.
   .PARAMETER ControlFile
   switch
   Turns on making/appending a control file in the log folder saying how many files were deleted.
     #>
    [alias("Remove-D365SFLogs")]
    [CmdletBinding()]
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
        [switch]$ControlFile
    )
    BEGIN {
    }
    PROCESS {
        if (!$Config -or $Config.OrchestratorServerNames.Count -eq 0) {
            Write-PSFMessage -Level VeryVerbose -Message "Config not defined or Config is invalid. Trying to Get new config using $ComputerName"
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly   
        }
        if ($CleanupOlderThanDays -lt 1){
            Stop-PSFFunction -Message "Error: CleanupOlderThanDays can't be less than 1 day". -EnableException $true -FunctionName $_ 
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