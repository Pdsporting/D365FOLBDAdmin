
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
    [CmdletBinding()]
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
        $OutputList = @()
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
                    $Output = New-Object -TypeName psobject -Property $Properties
                    $OutputList += $Output
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
                    $Output = New-Object -TypeName psobject -Property $Properties
                    $OutputList += $Output
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
            $Output =New-Object -TypeName psobject -Property $Properties
            $OutputList += $Output
        }
        else {
            $Properties = @{'Name' = "SSRSSystemDatabasesDatabase"
                'Details'          = "$SystemDatabasesAccessible databases are accessible. $SystemDatabasesWithIssues are not accessible"
                'Status'           = "Down" 
                'ExtraInfo'        = ""
                'Source'           = $ReportServerServerName
                'Group'            = 'Database'
            }
            $Output = New-Object -TypeName psobject -Property $Properties
            $OutputList += $Output
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
                    $Output = New-Object -TypeName psobject -Property $Properties
                    $OutputList += $Output
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
            $Output =New-Object -TypeName psobject -Property $Properties
            $OutputList += $Output
        }
        else {
            $Properties = @{'Name' = "AXDBSystemDatabasesDatabase"
                'Details'          = "$SystemDatabasesAccessible databases are accessible. $SystemDatabasesWithIssues are not accessible"
                'Status'           = "Down" 
                'ExtraInfo'        = ""
                'Source'           = $AXDatabaseServer
                'Group'            = 'Database'
            }
            $Output =New-Object -TypeName psobject -Property $Properties
            $OutputList += $Output
        }


        $AgentShareLocation = $config.AgentShareLocation
        $CheckedHardDrives = "false"
        $ServerswithHDIssues = @()
        if (test-path $AgentShareLocation\scripts\D365FOLBDAdmin\AdditionalEnvironmentDetails.xml) {
            ##additional details start
            Write-PSFMessage -Level Verbose -Message "Found AdditionalEnvironmentDetails config"
 
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
                        if (!$HDErrorValue){
                            $HDErrorValue = 2
                        }
                        if ($FreeSpace -lt $HDErrorValue) {
                            Write-PSFMessage -Message "ERROR: $($HardDrive.DeviceId) on $ApplicationServer has only $freespace percentage" -Level Warning
                            $Properties = @{'Name' = "AXDBSystemDatabasesDatabase"
                                'Details'          = $HardDrive.DeviceId
                                'Status'           = "Down" 
                                'ExtraInfo'        = "$ServerswithHDIssues"
                                'Source'           = $ApplicationServer
                            }
                            $Output = New-Object -TypeName psobject -Property $Properties
                            $OutputList += $Output
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
                    $Output = New-Object -TypeName psobject -Property $Properties
                    $OutputList += $Output
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
                    if (!$HDErrorValue){
                        $HDErrorValue = 2
                    }
                    if ($FreeSpace -lt $HDErrorValue) {
                        Write-PSFMessage -Message "ERROR: $($HardDrive.DeviceId) on $ApplicationServer has only $freespace percentage" -Level Warning
                        $Properties = @{
                            'Source'    = $ApplicationServer ;
                            'Name'      = "Hard Disk Space"
                            'Details'   = $HardDrive.DeviceId
                            'State'     = "Down" 
                            'ExtraInfo' = "$ServerswithHDIssues";
                            'Group'     = 'OS'
                               
                        }
                        $Output = New-Object -TypeName psobject -Property $Properties
                        $OutputList += $Output
                        $foundHardDrivewithIssue = $true
                        $ServerswithHDIssues += "$ApplicationServer"
                    }
                    elseif ($FreeSpace -lt $HDWarningValue) {
                        Write-PSFMessage -Message "WARNING: $($HardDrive.DeviceId) on $ApplicationServer has only $freespace percentage" -Level Warning
                        $Properties = @{
                            'Source'    = $ApplicationServer ;
                            'Name'      = "Hard Disk Space"
                            'Details'   = $HardDrive.DeviceId
                            'State'     = "Operational" 
                            'ExtraInfo' = "$ServerswithHDIssues";
                            'Group'     = 'OS'
                               
                        }
                        $Output = New-Object -TypeName psobject -Property $Properties
                        $OutputList += $Output
                    }
                    else {
                        Write-PSFMessage -Message  "VERBOSE: $($HardDrive.DeviceId) on $ApplicationServer has only $freespace percentage" -Level VeryVerbose
                        $Properties = @{
                            'Source'    = $ApplicationServer ;
                            'Name'      = "Hard Disk Space"
                            'Details'   = $HardDrive.DeviceId
                            'State'     = "Operational" 
                            'ExtraInfo' = "$ServerswithHDIssues";
                            'Group'     = 'OS'
                               
                        }
                        $Output = New-Object -TypeName psobject -Property $Properties
                        $OutputList += $Output
                    }
                }
            }

            if ($foundHardDrivewithIssue -eq $true) {
                $issuelist = $OutputList | Where-Object {$_.Operational -eq "Down" -and $_.Name -eq "Hard Disk Space"}
                Write-PSFMessage -Level Error -Message "Error: Found Hard Drive Issues on $issuelist"
            }
        }##Check HD end

        if (!$Config) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName
        }
        [int]$count = 0
        while (!$connection) {
            do {
                $OrchestratorServerName = $Config.OrchestratorServerNames | Select-Object -First 1 -Skip $count
                Write-PSFMessage -Message "Verbose: Reaching out to $OrchestratorServerName to try and connect to the service fabric" -Level Verbose
                $SFModuleSession = New-PSSession -ComputerName $OrchestratorServerName
                if (!$module) {
                    $module = Import-Module -Name ServiceFabric -PSSession $SFModuleSession 
                }
                Write-PSFMessage -Message "-ConnectionEndpoint $($config.SFConnectionEndpoint) -X509Credential -FindType FindByThumbprint -FindValue $($config.SFServerCertificate) -ServerCertThumbprint $($config.SFServerCertificate) -StoreLocation LocalMachine -StoreName My" -Level Verbose
                $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $config.SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
                if (!$connection) {
                    $trialEndpoint = "https://$OrchestratorServerName" + ":198000"
                    $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $trialEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
                }
                $count = $count + 1
                if (!$connection) {
                    Write-PSFMessage -Message "Count of servers tried $count" -Level Verbose
                }
            } until ($connection -or ($count -eq $($Config.OrchestratorServerNames).Count))
            if (($count -eq $($Config.OrchestratorServerNames).Count) -and (!$connection)) {
                Stop-PSFFunction -Message "Error: Can't connect to Service Fabric"
            }
        }
        $TotalApplications = (Get-ServiceFabricApplication).Count
        $HealthyApps = (Get-ServiceFabricApplication | Where-Object {$_.HealthState -eq "OK"}).Count

        if ($TotalApplications -eq $HealthyApps){
            Write-PSFMessage -Message "All Service Fabric Applications are healthy HealthyApps / $TotalApplication" -Level VeryVerbose
            $Properties = @{'Name' = "ServiceFabricApplications"
                'Details'          = "Healthy: $HealthyApps / Total: $TotalApplication"
                'Status'           = "Operational" 
                'ExtraInfo'        = ""
                'Source'           = $OrchestratorServerName
                'Group'            = 'ServiceFabric'
            }
            $Output = New-Object -TypeName psobject -Property $Properties
            $OutputList += $Output
        }
        else{
            $NotHealthyApps = Get-ServiceFabricApplication | Where-Object {$_.HealthState -ne "OK"}
            Write-PSFMessage -Message "Warning: Not all Service Fabric Applications are healthy $HealthyApps / $TotalApplication " -Level VeryVerbose
            Write-PSFMessage -Message "Issue App:" -Level VeryVerbose
            foreach ($NotHealthyApp in $NotHealthyApps)
            {
                $HealthReport = Get-ServiceFabricApplicationHealth -ApplicationName $NotHealthyApp.ApplicationName
                Write-PSFMessage -Message "$HealthReport" -Level VeryVerbose
            }
            $Properties = @{'Name' = "ServiceFabricApplications"
                'Details'          = "Healthy: $HealthyApps / Total: $TotalApplication"
                'Status'           = "Down" 
                'ExtraInfo'        = "$NotHealthyApps"
                'Source'           = $OrchestratorServerName
                'Group'            = 'ServiceFabric'
            }
            $Output = New-Object -TypeName psobject -Property $Properties
            $OutputList += $Output
        }

        $AXSFPartitionID = $(Get-ServiceFabricPartition -ServiceName fabric:/AXSF/AXService).PartitionId
        $AXSFReplicas = Get-ServiceFabricReplica -PartitionId $AXSFPartitionID

        foreach ($AXSFReplica in $AXSFReplicas){
            $NodeName = $AXSFReplica.NodeName
            [string]$EndpointString = $AXSFReplica.ReplicaAddress
            $Index = $EndpointString.IndexOf('"{Endpoints":{"')
            $EndpointString = $EndpointString.Substring(0,$Index)
            $EndpointString = $EndpointString.Replace('{"Endpoints":{"',"")

            if ($EndpointString.Length -gt 3){
                $Status = "Operational"
            }
            else{
                $Status = "Down"
            }
            $Properties = @{'Name' = "AXSFGUIDEndpoint"
                'Details'          = "$NodeName $EndpointString"
                'Status'           = "$Status" 
                'ExtraInfo'        = "$EndpointString"
                'Source'           = $NodeName 
                'Group'            = 'ServiceFabric'
            }
            $Output = New-Object -TypeName psobject -Property $Properties
            $OutputList += $Output
        }

        [PSCustomObject]$OutputList

    }
    END {
        if ($SFModuleSession) {
            Remove-PSSession -Session $SFModuleSession  
        }
    }
}