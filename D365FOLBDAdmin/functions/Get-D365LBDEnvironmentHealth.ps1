
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
        [int]$Timeout = 120,
        [psobject]$Config,
        [string]$CustomModuleName,
        [switch]$CheckForHardDriveDetails,
        [int]$HDWarningValue,
        [int]$HDErrorValue
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

        $ReportServerServerName = $Config.ReportServerServerName
        $AXDatabaseServer = $Config.AXDatabaseServer
        $SourceAXSFServer = $Config.SourceAXSFServer
        <#$SFModuleSession = New-PSSession -ComputerName $SourceAXSFServer
        Invoke-Command -Session $SFModuleSession -ScriptBlock {
            $AssemblyList = "Microsoft.SqlServer.Management.Common", "Microsoft.SqlServer.Smo", "Microsoft.SqlServer.Management.Smo"
            foreach ($Assembly in $AssemblyList) {
                $AssemblyLoad = [Reflection.Assembly]::LoadWithPartialName($Assembly) 
            }
        }#>
         
        $AssemblyList = "Microsoft.SqlServer.Management.Common", "Microsoft.SqlServer.Smo", "Microsoft.SqlServer.Management.Smo"
        foreach ($Assembly in $AssemblyList) {
            $AssemblyLoad = [Reflection.Assembly]::LoadWithPartialName($Assembly) 
        }
        if (!$ReportServerServerName) {
            $ReportServerServerName = $using:ReportServerServerName
        }
        $SQLSSRSServer = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $ReportServerServerName 
        Write-PSFMessage -Level Verbose -Message "Connecting to $ReportServerServerName for AXDB Database and its system dbs"
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
                ("[DynamicsAxReportServer]", "[ReportServer]") {
                    switch ($database.IsAccessible) {
                        "True" { $dbstatus = "Operational" }
                        "False" { $dbstatus = "Down" }
                    }
                    $Properties = @{'Name' = "SSRSDatabase"
                        'Details'          = $database.name
                        'Status'           = "$dbstatus" 
                        'Source'           = $ReportServerServerName
                    }
                    New-Object -TypeName psobject -Property $Properties
                }
                ("[DynamicsAxReportServerTempDB]", "[ReportServerTempDB]") {
                    switch ($database.IsAccessible) {
                        "True" { $dbstatus = "Operational" }
                        "False" { $dbstatus = "Down" }
                    }
                    $Properties = @{'Name' = "SSRSTempDBDatabase"
                        'Details'          = $database.name
                        'Status'           = "$dbstatus" 
                        'ExtraInfo'        = ""
                        'Source'           = $ReportServerServerName
                        'Group'            = 'Database'
                    }
                    New-Object -TypeName psobject -Property $Properties
                }
                Default {}
            }
        }
        if ($SystemDatabasesWithIssues -eq 0) {
            $Properties = @{'Name' = "SSRSSystemDatabasesDatabase"
                'Details'          = "$SystemDatabasesAccessible databases are accessible"
                'Status'           = "Operational" 
                'ExtraInfo'        = ""
                'Source'           = $ReportServerServerName
                'Group'            = 'Database'
            }
            New-Object -TypeName psobject -Property $Properties
        }
        else {
            $Properties = @{'Name' = "SSRSSystemDatabasesDatabase"
                'Details'          = "$SystemDatabasesAccessible databases are accessible. $SystemDatabasesWithIssues are not accessible"
                'Status'           = "Down" 
                'ExtraInfo'        = ""
                'Source'           = $ReportServerServerName
                'Group'            = 'Database'
            }
            New-Object -TypeName psobject -Property $Properties
        }
        
        ##DB AX
        if (!$AXDatabaseServer) {
            $AXDatabaseServer = $using:AXDatabaseServer
        }
        $AXDatabaseServerConnection = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $AXDatabaseServer
        Write-PSFMessage -Level Verbose -Message "Connecting to $AXDatabaseServer for AXDB Database and its system dbs"
        $SystemDatabasesWithIssues = 0
        $SystemDatabasesAccessible = 0
        foreach ($database in $AXDatabaseServerConnection.Databases) {
            switch ($database) {
                { @("[model]", "[master]", "[msdb]", "[tempdb]") -contains $_ } {
                    if ($database.IsAccessible) {
                        $SystemDatabasesAccessible = $SystemDatabasesAccessible + 1
                    }
                    else {
                        $SystemDatabasesWithIssues = $SystemDatabasesWithIssues + 1
                    }
                }
                "[AXDB]" {
                    switch ($database.IsAccessible) {
                        "True" { $dbstatus = "Operational" }
                        "False" { $dbstatus = "Down" }
                    }
                    $Properties = @{'Name' = "AXDatabase"
                        'Details'          = $database.name
                        'Status'           = "$dbstatus" 
                        'ExtraInfo'        = ""
                        'Source'           = $AXDatabaseServer
                        'Group'            = 'Database'
                    }
                    New-Object -TypeName psobject -Property $Properties
                }
                Default {}
            }
        }
        if ($SystemDatabasesWithIssues -eq 0) {
            $Properties = @{'Name' = "AXDBSystemDatabasesDatabase"
                'Details'          = "$SystemDatabasesAccessible databases are accessible"
                'Status'           = "Operational" 
                'ExtraInfo'        = ""
                'Source'           = $AXDatabaseServer
                'Group'            = 'Database'
            }
            New-Object -TypeName psobject -Property $Properties
        }
        else {
            $Properties = @{'Name' = "AXDBSystemDatabasesDatabase"
                'Details'          = "$SystemDatabasesAccessible databases are accessible. $SystemDatabasesWithIssues are not accessible"
                'Status'           = "Down" 
                'ExtraInfo'        = ""
                'Source'           = $AXDatabaseServer
                'Group'            = 'Database'
            }
            New-Object -TypeName psobject -Property $Properties
        }


        $AgentShareLocation = $config.AgentShareLocation
        $CheckedHardDrives = "false"
        $ServerswithHDIssues = @()
        if (test-path $AgentShareLocation\scripts\D365FOLBDAdmin\AdditionalEnvironmentDetails.xml) {
            ##additional details start
            Write-PSFMessage -Level Verbose -Message "Found AdditionalEnvironmentDetails config"
            #$EnvironmentAdditionalConfig = get-childitem  "$AgentShareLocation\scripts\D365FOLBDAdmin\AdditionalEnvironmentDetails.xml"

            [xml]$XMLAdditionalConfig = Get-Content "$AgentShareLocation\scripts\D365FOLBDAdmin\AdditionalEnvironmentDetails.xml"
            [string]$CheckForHardDriveDetails = $XMLAdditionalConfig.d365LBDEnvironment.Automation.CheckForHealthIssues.CheckAllHardDisks.Enabled
            if (!$HDErrorValue) {
                $HDErrorValue = $CheckForHardDriveDetails.HardDriveError
            }
            if (!$HDWarningValue) {
                $HDWarningValue = $CheckForHardDriveDetails.HardDriveWarning
            }
            
            $foundHardDrivewithIssue = $false
            if ($CheckForHardDriveDetails -eq "true") {
                $CheckedHardDrives = "true"
                ##check HD Start
                Write-PSFMessage -Message "Checking Hard drive free space" -Level Verbose
                foreach ($ApplicationServer in $config.AllAppServerList.ComputerName) {
                    $HardDrives = Get-WmiObject -Class "Win32_LogicalDisk" -Namespace "root\CIMV2" -Filter "DriveType = '3'" -ComputerName $ApplicationServer
                    if (!$HardDrives) {
                        Write-PSFMessage -Level Verbose -Message " Having trouble accessing drives on $ApplicationServer"
                    }
                    foreach ($HardDrive in $HardDrives) {
                        $FreeSpace = (($HardDrive.freespace / $HardDrive.size) * 100)
                        Write-PSFMessage -Level Verbose -Message " $ApplicationServer - $($HardDrive.DeviceID) has $FreeSpace %"
                        if ($FreeSpace -lt $HDErrorValue) {
                            Write-PSFMessage -Message "ERROR: $($HardDrive.DeviceId) on $ApplicationServer has only $freespace percentage" -Level Warning
                            $Properties = @{'Name' = "AXDBSystemDatabasesDatabase"
                                'Details'          = $HardDrive.DeviceId
                                'Status'           = "Down" 
                                'ExtraInfo'        = "$ServerswithHDIssues"
                                'Source'           = $ApplicationServer
                            }
                            New-Object -TypeName psobject -Property $Properties
                            $foundHardDrivewithIssue = $true
                            $ServerswithHDIssues += "$ApplicationServer"

                        }
                        elseif ($FreeSpace -lt $HDWarningValue) {
                            Write-PSFMessage -Message "WARNING: $($HardDrive.DeviceId) on $ApplicationServer has only $freespace percentage" -Level Warning
                        }
                        else { 
                            Write-PSFMessage -Message  "VERBOSE: $($HardDrive.DeviceId) on $ApplicationServer has only $freespace percentage" -Level VeryVerbose
                        }
                    }
                }
                if ($foundHardDrivewithIssue -eq $false) {
                    $Properties = @{'Name' = "Hard Disk Space"
                        'Details'          = $config.AllAppServerList
                        'Status'           = "Operational" 
                        'ExtraInfo'        = ""
                        'Source'           = $config.AllAppServerList
                        'Group'            = 'OS'
                    }
                    New-Object -TypeName psobject -Property $Properties
                }
            }##Check HD end
        }##additional details end
        else {
            Write-PSFMessage -Message "Warning: Can't find additional environment Config. Not needed but recommend making one" -level warning  
        }

        if ($CheckedHardDrives -eq "false" -and ($CheckForHardDriveDetails -eq $true)) {
            $foundHardDrivewithIssue = $false
            foreach ($ApplicationServer in $config.AllAppServerList.ComputerName) {
                $HardDrives = Get-WmiObject -Class "Win32_LogicalDisk" -Namespace "root\CIMV2" -Filter "DriveType = '3'" -ComputerName $ApplicationServer
                foreach ($HardDrive in $HardDrives) {
                    $FreeSpace = (($HardDrive.freespace / $HardDrive.size) * 100)
                    Write-PSFMessage -Level Verbose -Message "$ApplicationServer - $($HardDrive.DeviceID) has $FreeSpace %"
                    if ($FreeSpace -lt $HDErrorValue) {
                        Write-PSFMessage -Message "ERROR: $($HardDrive.DeviceId) on $ApplicationServer has only $freespace percentage" -Level Warning
                        $Properties = @{
                            'Source'    = $ApplicationServer ;
                            'Name'      = "AXDBSystemDatabasesDatabase"
                            'Details'   = $HardDrive.DeviceId
                            'State'     = "Down" 
                            'ExtraInfo' = "$ServerswithHDIssues";
                            'Group'     = 'OS'
                               
                        }
                        New-Object -TypeName psobject -Property $Properties
                        $foundHardDrivewithIssue = $true
                        $ServerswithHDIssues += "$ApplicationServer"
                    }
                    elseif ($FreeSpace -lt $HDWarningValue) {
                        Write-PSFMessage -Message "WARNING: $($HardDrive.DeviceId) on $ApplicationServer has only $freespace percentage" -Level Warning
                    }
                    else {
                        Write-PSFMessage -Message  "VERBOSE: $($HardDrive.DeviceId) on $ApplicationServer has only $freespace percentage" -Level VeryVerbose
                    }
                }
            }

            if ($foundHardDrivewithIssue -eq $false) {
                $Properties = @{'Name' = "Hard Disk Space"
                    'Details'          = $config.AllAppServerList
                    'Status'           = "Operational" 
                    'ExtraInfo'        = ""
                    'Source'           = $config.AllAppServerList
                    'Group'            = 'OS'
                }
                New-Object -TypeName psobject -Property $Properties
            }
        }##Check HD end

    }
    END {
        if ($SFModuleSession) {
            Remove-PSSession -Session $SFModuleSession  
        }
    }
}