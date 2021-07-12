
function Remove-D365LBDSFOldAssets {
   
    [alias("Remove-D365SFOldAssets")]
    param
    (
        [Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name',
            ParameterSetName = 'NoConfig')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [psobject]$Config,
        [int]$NumberofAssetsToKeep,
        [switch]$ControlFile,
        [switch]$ScanForInvalidZips
    )
    BEGIN {
    }
    PROCESS {
        if (!$Config) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly   
        }

        if ($NumberofAssetsToKeep -lt 2) {
            Stop-PSFFunction -Message "Error: Number of Assets to keep must be 2 or larger as you should always keep the main and backup" -EnableException $True  
        }
        $AssetsFolderinAgentShareLocation = join-path -Path $Config.AgentShareLocation -ChildPath "\assets"
        $Onedayold = $(get-date).AddDays(-1)
        $AlreadyDeployedAssetIDInWPFolder = $Config.DeploymentAssetIDinWPFolder
        $StartTime = Get-Date
        Write-PSFMessage -Level Verbose -Message "Checking for invalid assets in $AssetsFolderinAgentShareLocation"
        $AssetFolders = Get-ChildItem $AssetsFolderinAgentShareLocation | Where-Object { $_.Name -ne "chk" -and $_.Name -ne "topology.xml" -and $_.Name -ne "$AlreadyDeployedAssetIDInWPFolder" -and $_.CreateDate -lt $Onedayold -and $_.Name -ne "ControlFile.txt" } 
        foreach ($AssetFolder  in $AssetFolders ) {
            $StandaloneSetupZip = $null
            $StandaloneSetupZip = Get-ChildItem "$($AssetFolder.Fullname)\*\*\Packages\*\StandaloneSetup.zip"
            if ($ScanForInvalidZips){
                $job = $null
                $job = start-job -ScriptBlock { Add-Type -AssemblyName System.IO.Compression.FileSystem; $zip = [System.IO.Compression.ZipFile]::OpenRead($using:StandaloneSetupZip) }
                if (Wait-Job $j -Timeout 300) { Receive-Job $job }else {
                    Write-PSFMessage -Level VeryVerbose -message "Invalid Zip file $StandaloneSetupZip."
                    Write-PSFMessage -Message "$AssetFolder is invalid - deleting" -Level VeryVerbose
                    Get-ChildItem $AssetFolder.Fullname | Remove-Item -Recurse -Force
                    Get-ChildItem $AssetsFolderinAgentShareLocation | Where-object { $_.Name -eq $AssetFolder } | Remove-Item -Recurse -Force
                }
            }
            Remove-Job $job
            if (!$StandaloneSetupZip) {
                Write-PSFMessage -Message "$AssetFolder is invalid no StandaloneSetup found - deleting" -Level VeryVerbose
                Get-ChildItem $AssetFolder.Fullname | Remove-Item -Recurse -Force
                Get-ChildItem $AssetsFolderinAgentShareLocation | Where-object { $_.Name -eq $AssetFolder } | Remove-Item -Recurse -Force
            }
            else {
                if ($StandaloneSetupZip.Length -eq 0) {
                    Write-PSFMessage -Message "Standalone zip in $AssetFolder is invalid - deleting" -Level VeryVerbose
                    Get-ChildItem $AssetFolder.Fullname | Remove-Item -Recurse -Force
                    Get-ChildItem $AssetsFolderinAgentShareLocation | Where-object { $_.Name -eq $AssetFolder } | Remove-Item -Recurse -Force
                }
                else {
                    Write-PSFMessage -Message "Standalone zip in $AssetFolder is VALID" -Level Verbose
                }
            }

        }
        Write-PSFMessage -Level Verbose -Message "Starting Clean on $AssetsFolderinAgentShareLocation"
        $FilesThatAreBeingDeleted = Get-ChildItem $AssetsFolderinAgentShareLocation | Where-Object { $_.Name -ne "chk" -and $_.Name -ne "topology.xml" -and $_.Name -ne "$AlreadyDeployedAssetIDInWPFolder" -and $_.CreateDate -lt $Onedayold -and $_.Name -ne "ControlFile.txt" } | Sort-Object LastWriteTime | Select-Object -SkipLast $NumberofAssetsToKeep
        $FileCount = $FilesThatAreBeingDeleted.Count
        if ($FileCount -or $FileCount -ne 0) {
            $FilesThatAreBeingDeleted.FullName | Remove-Item -Force -Recurse
        }
        $EndTime = Get-Date
        $TimeDiff = New-TimeSpan -Start $StartTime -End $EndTime
        Write-PSFMessage -Level VeryVerbose -Message "$AssetsFolderinAgentShareLocation - StartTime: $StartTime - EndTime: $EndTime - Execution Time: $($TimeDiff.Minutes) Minutes $($TimeDiff.Seconds) Seconds - Count of Files: $FileCount"
        if ($ControlFile -and $FileCount -gt 0) {
            "$AssetsFolderinAgentShareLocation - StartTime: $StartTime - EndTime: $EndTime - Execution Time: $($TimeDiff.Minutes) minutes $($TimeDiff.Seconds) seconds - Count of Files: $FileCount " | Out-File $AssetsFolderinAgentShareLocation\ControlFile.txt -append
        }
        Write-PSFMessage -Level VeryVerbose -Message "$($config.LCSEnvironmentName) AgentShare Assets have been cleaned"

    }
    END {
    }
}