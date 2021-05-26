
function Get-D365LBDEnvironmentHealth {
    <#
   .SYNOPSIS
  Looks inside the agent share extracts the version from the zip by using the custom module name. Puts an xml in root for easy idenitification
  .DESCRIPTION
   Exports 
  .EXAMPLE
    Get-D365LBDEnvironmentHealth

  .EXAMPLE
   Get-D365LBDEnvironmentHealth

  .PARAMETER AgentShare
  optional string 
   The location of the Agent Share
  .PARAMETER CustomModuleName
  optional string 
  The name of the custom module you will be using to capture the version number

  ##Switch fix minor issues 

  #>
    [alias("Get-D365EnvironmentHealth")]
    param
    (
        [Parameter(Mandatory = $true)]
        [int]$Timeout,
        [psobject]$Config,
        [string]$CustomModuleName
    )
    BEGIN {
    }
    PROCESS {
        if (!$Config) {
            if ($CustomModuleName) {
                $Config = Get-D365LBDConfig -ComputerName $ComputerName -CustomModuleName $CustomModuleName
            }
            else {
                $Config = Get-D365LBDConfig -ComputerName $ComputerName 
            }
        }
        $SourceAXSFServer = $Config.SourceAXSFServer
        $SFModuleSession = New-PSSession -ComputerName $SourceAXSFServer
        Invoke-Command -SessionName $SFModuleSession -ScriptBlock {
            $AssemblyList = "Microsoft.SqlServer.Management.Common", "Microsoft.SqlServer.Smo", "Microsoft.SqlServer.Management.Smo"
            foreach ($Assembly in $AssemblyList) {
                $AssemblyLoad = [Reflection.Assembly]::LoadWithPartialName($Assembly) 
            }
        }
        $AssemblyList = "Microsoft.SqlServer.Management.Common", "Microsoft.SqlServer.Smo", "Microsoft.SqlServer.Management.Smo"
        foreach ($Assembly in $AssemblyList) {
            $AssemblyLoad = [Reflection.Assembly]::LoadWithPartialName($Assembly) 
        }
        $SQLSSRSServer = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $ReportServerServerName 
        $SystemDatabasesWithIssues = 0
        $SystemDatabasesAccessible = 0

        foreach ($database in $SQLSSRSServer.Databases) {
            switch ($database) {
                { @("[model]", "[master]", "[msdb]", "[tempdb]") -contains $_ } {
                    if ($database.IsAccessible) {
                        $SystemDatabasesAccessible = $SystemDatabasesAccessible + 1
                    }
                    else {
                        $SystemDatabasesWithIssues = $SystemDatabasesWithIssues + 1
                    }
                }
                "[DynamicsAxReportServer]" {
                    switch ($database.IsAccessible) {
                        "True" { $dbstatus = "Online" }
                        "False" { $dbstatus = "Offline" }
                    }
                    $Properties = @{'Object' = "SSRSDatabase"
                        'Details'            = $database.name
                        'Status'             = "$dbstatus" 
                        'Source'             = $ReportServerServerName
                    }
                    New-Object -TypeName psobject -Property $Properties
                }
                "[DynamicsAxReportServerTempDB]" {
                    switch ($database.IsAccessible) {
                        "True" { $dbstatus = "Online" }
                        "False" { $dbstatus = "Offline" }
                    }
                    $Properties = @{'Object' = "SSRSTempDBDatabase"
                        'Details'            = $database.name
                        'Status'             = "$dbstatus" 
                        'Source'             = $ReportServerServerName
                    }
                    New-Object -TypeName psobject -Property $Properties
                }
                Default {}
            }
        }
        if ($SystemDatabasesWithIssues -eq 0) {
            $Properties = @{'Object' = "SSRSSystemDatabasesDatabase"
                'Details'            = "$SystemDatabasesAccessible databases are accessible"
                'Status'             = "Online" 
                'Source'             = $ReportServerServerName
            }
            New-Object -TypeName psobject -Property $Properties
        }
        else {
            $Properties = @{'Object' = "SSRSSystemDatabasesDatabase"
                'Details'            = "$SystemDatabasesAccessible databases are accessible. $SystemDatabasesWithIssues are not accessible"
                'Status'             = "Offline" 
                'Source'             = $ReportServerServerName
            }
            New-Object -TypeName psobject -Property $Properties
        }
        $AgentShareLocation = $config.AgentShareLocation
        if (test-path $AgentShareLocation\scripts\D365FOLBDAdmin\AdditionalEnvironmentDetails.xml) {
            ##additional details start
            Write-PSFMessage -Level Verbose -Message "Found AdditionalEnvironmentDetails config"
            $EnvironmentAdditionalConfig = get-childitem  "$AgentShareLocation\scripts\D365FOLBDAdmin\AdditionalEnvironmentDetails.xml"

            [xml]$XMLAdditionalConfig = Get-Content "$AgentShareLocation\scripts\D365FOLBDAdmin\AdditionalEnvironmentDetails.xml"
            $CheckForHardDriveDetails = $XMLAdditionalConfig.d365LBDEnvironment.Automation.CheckForHealthIssues.CheckAllHardDisks
            $HDErrorValue = $CheckForHardDriveDetails.HardDriveError
            $HDWarningValue = $CheckForHardDriveDetails.HardDriveWarning

            if ($CheckForHardDriveDetails.Enabled -eq $true) {
                ##check HD Start
                Write-PSFMessage -Message "Checking Hard drive free space" -Level Verbose
                foreach ($ApplicationServer in $config.AllAppServerList) {
                    $HardDrives = Get-WmiObject -Class "Win32_LogicalDisk" -Namespace "root\CIMV2" -ComputerName $ApplicationServer
                    foreach ($HardDrive in $HardDrives) {
                        $FreeSpace = (($HardDrive.freespace / $HardDrive.size) * 100)
                        if ($FreeSpace -lt $HDErrorValue) {
                            Write-PSFMessage -Message "ERROR: $($HardDrive.DeviceId) on $ApplicationServer has only $freespace percentage" -Level Warning
                        }
                        elseif ($FreeSpace -lt $HDWarningValue) {
                            Write-PSFMessage -Message "WARNING: $($HardDrive.DeviceId) on $ApplicationServer has only $freespace percentage" -Level Warning
                        }
                        else {
                            Write-PSFMessage -Message  "VERBOSE: $($HardDrive.DeviceId) on $ApplicationServer has only $freespace percentage" -Level Verbose
                        }
                    }
                }
            }##Check HD end
        }##additional details end
        else {
            Write-PSFMessage -Message "Warning: Can't find additional environment Config. Not needed but recommend making one" -level warning  
        }
    }
    END {
    }
}