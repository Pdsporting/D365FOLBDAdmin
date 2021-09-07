
function Get-D365LBDEnvironmentHealth {
    <#
   .SYNOPSIS
   Checks and validates the health of the D365 environment.  
  .DESCRIPTION
    Checks and validates the health of the D365 environment. This includes checking for AXSF endpoints, D365 system databases (including ssrs), Certificates being valid and hard drive space.
  .EXAMPLE
    Get-D365LBDEnvironmentHealth
   Checks and validates the health of the D365 environment on the local machines environment
  .EXAMPLE
  $config = get-d365Config
   Get-D365LBDEnvironmentHealth -config $config
   Checks and validates the health of the D365 environment on the specified configurations environment
  .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module
   .PARAMETER CustomModuleName
   optional string 
   The name of the custom module you will be using to capture the version number
   .PARAMETER CheckForHardDriveDetails
   switch 
   When gathering the health of the environment to iterate through each server to check for hard drives being full
   .PARAMETER HDWarningValue
   integer
   Value in percentage that would be considered a warning in free space. Example if set to 5 if hard drive is less than 5% free it would result in a warning. if not defined will try using additional config.
   .PARAMETER HDErrorValue
   integer
   Value in percentage that would be considered a error in free space. Example if set to 2 if hard drive is less than 2% free it would result in a error. if not defined will try using additional config.
   .PARAMETER CertWarningValue
   integer
   Value in days that would be considered a warning in days until the certificate is no longer valid. Example if set to 30 the cert expires in less than 30 days it would result in a warning. Default of 30.
   .PARAMETER CertErrorValue
   integer
   Value in days that would be considered a error in days until the certificate is no longer valid. Example if set to 5 the cert expires in less than 5 days it would result in a error. Default of 5.
  #>
    [alias("Get-D365EnvironmentHealth")]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [int]$Timeout = 120,
        [psobject]$Config,
        [string]$CustomModuleName,
        [switch]$CheckForHardDriveDetails,
        [int]$HDWarningValue, ## integer that checks percentage
        [int]$HDErrorValue, ## integer that checks percentage
        [int]$CertWarningValue = 30, ##in Days
        [int]$CertErrorValue = 5 ## in Days
    )
    BEGIN {
    }
    PROCESS {
        if (!$Config -or $Config.OrchestratorServerNames.Count -eq 0) {
            Write-PSFMessage -Level VeryVerbose -Message "Config not defined or Config is invalid. Trying to Get new config using $ComputerName"
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
         
        $AssemblyList = "Microsoft.SqlServer.Management.Common", "Microsoft.SqlServer.Smo", "Microsoft.SqlServer.Management.Smo"
        foreach ($Assembly in $AssemblyList) {
            $AssemblyLoad = [Reflection.Assembly]::LoadWithPartialName($Assembly) 
        }
        if (!$ReportServerServerName) {
            $ReportServerServerName = $using:ReportServerServerName
        }
        $SQLSSRSServer = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $ReportServerServerName 
        Write-PSFMessage -Level Verbose -Message "Connecting to $ReportServerServerName for SSRS Database and its system dbs"
        $SystemDatabasesWithIssues = 0
        $SystemDatabasesAccessible = 0

        if ($SQLSSRSServer) {
            Write-PSFMessage -Level VeryVerbose -Message "Connected to $SQLSSRSServer for SSRS Database and its system dbs $($SQLSSRSServer.Databases)"
        }
        else {
            Write-PSFMessage -Level VeryVerbose -Message "Having issues connecting to $SQLSSRSServer for SSRS Database and its system dbs"
        }
        try {
            foreach ($database in $SQLSSRSServer.Databases) {
            }
        }
        catch {
            if ($_.Exception -like "*Failed to connect to server *") {
                Write-Warning -Message "Can't Verify if SQL Server $ReportServerServerName is up because can't connect. Check permissions "
                $CantConnect = 'True'
            }
        }
        if ($CantConnect -eq 'True') {
            $whoami = whoami
            $Properties = @{'Name' = "SSRSSystemDatabasesDatabase"
                'Details'          = "$whoami can't connect to the databases. Check permissions"
                'State'            = "Down" 
                'ExtraInfo'        = ""
                'Source'           = $ReportServerServerName
                'Group'            = 'Database'
            }
            $Output = New-Object -TypeName psobject -Property $Properties
            $OutputList += $Output
        }
        else {
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
                            'State'            = "$dbstatus" 
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
                            'State'            = "$dbstatus" 
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
                    'State'            = "Operational" 
                    'ExtraInfo'        = ""
                    'Source'           = $ReportServerServerName
                    'Group'            = 'Database'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            else {
                $Properties = @{'Name' = "SSRSSystemDatabasesDatabase"
                    'Details'          = "$SystemDatabasesAccessible databases are accessible. $SystemDatabasesWithIssues are not accessible"
                    'State'            = "Down" 
                    'ExtraInfo'        = ""
                    'Source'           = $ReportServerServerName
                    'Group'            = 'Database'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
        }

        
        ##DB AX
        $CantConnect = 'False'
        if (!$AXDatabaseServer) {
            $AXDatabaseServer = $using:AXDatabaseServer
        }
        $AXDatabaseServerConnection = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $AXDatabaseServer
        Write-PSFMessage -Level Verbose -Message "Connecting to $AXDatabaseServer for AXDB Database and its system dbs"
        $SystemDatabasesWithIssues = 0
        $SystemDatabasesAccessible = 0
        if ($AXDatabaseServerConnection) {
            Write-PSFMessage -Level VeryVerbose -Message "Connected to $AXDatabaseServerConnection  for AXDB Database and its system dbs $($AXDatabaseServerConnection.Databases)"
        }
        else {
            Write-PSFMessage -Level VeryVerbose -Message "Having issues connecting to $AXDatabaseServerConnection for AXDB Database and its system dbs"
        }

        try {
            foreach ($database in $AXDatabaseServerConnection.Databases) {
            }
        }
        catch {
            if ($_.Exception -like "*Failed to connect to server *") {
                Write-Warning -Message "Can't Verify if SQL Server $AXDatabaseServer is up because can't connect. Check permissions "
                $CantConnect = 'True'
            }
        }
        if ($CantConnect -eq 'True') {
            $whoami = whoami
            $Properties = @{'Name' = "AXDBSystemDatabasesDatabase"
                'Details'          = "$whoami can't connect to the databases. Check permissions"
                'State'            = "Down" 
                'ExtraInfo'        = ""
                'Source'           = $AXDatabaseServer
                'Group'            = 'Database'
            }
            $Output = New-Object -TypeName psobject -Property $Properties
            $OutputList += $Output
        }

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
                        'State'            = "$dbstatus" 
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
                'State'            = "Operational" 
                'ExtraInfo'        = ""
                'Source'           = $AXDatabaseServer
                'Group'            = 'Database'
            }
            $Output = New-Object -TypeName psobject -Property $Properties
            $OutputList += $Output
        }
        else {
            $Properties = @{'Name' = "AXDBSystemDatabasesDatabase"
                'Details'          = "$SystemDatabasesAccessible databases are accessible. $SystemDatabasesWithIssues are not accessible"
                'State'            = "Down" 
                'ExtraInfo'        = ""
                'Source'           = $AXDatabaseServer
                'Group'            = 'Database'
            }
            $Output = New-Object -TypeName psobject -Property $Properties
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
                        if (!$HDErrorValue) {
                            $HDErrorValue = 2
                        }
                        if ($FreeSpace -lt $HDErrorValue) {
                            Write-PSFMessage -Message "ERROR: $($HardDrive.DeviceId) on $ApplicationServer has only $freespace percentage" -Level Warning
                            $Properties = @{'Name' = "Hard Disk Space"
                                'Details'          = $HardDrive.DeviceId
                                'State'            = "Down" 
                                'ExtraInfo'        = "Free Space Percentage: $freespace"
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
                        'State'            = "Operational" 
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
                    if (!$HDErrorValue) {
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
                $issuelist = $OutputList | Where-Object { $_.Operational -eq "Down" -and $_.Name -eq "Hard Disk Space" }
                Write-PSFMessage -Level Error -Message "Error: Found Hard Drive Issues on $issuelist"
            }
        }##Check HD end

        if (!$Config -or $Config.OrchestratorServerNames.Count -eq 0) {
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
        $HealthyApps = (Get-ServiceFabricApplication | Where-Object { $_.HealthState -eq "OK" }).Count

        if ($TotalApplications -eq $HealthyApps) {
            Write-PSFMessage -Message "All Service Fabric Applications are healthy $HealthyApps / $TotalApplications" -Level VeryVerbose
            $Properties = @{'Name' = "ServiceFabricApplications"
                'Details'          = "Healthy: $HealthyApps / Total: $TotalApplications"
                'State'            = "Operational" 
                'ExtraInfo'        = ""
                'Source'           = $OrchestratorServerName
                'Group'            = 'ServiceFabric'
            }
            $Output = New-Object -TypeName psobject -Property $Properties
            $OutputList += $Output
        }
        else {
            $NotHealthyApps = Get-ServiceFabricApplication | Where-Object { $_.HealthState -ne "OK" }
            Write-PSFMessage -Message "Warning: Not all Service Fabric Applications are healthy $HealthyApps / $TotalApplications " -Level VeryVerbose
            Write-PSFMessage -Message "Issue App:" -Level VeryVerbose
            foreach ($NotHealthyApp in $NotHealthyApps) {
                $HealthReport = Get-ServiceFabricApplicationHealth -ApplicationName $NotHealthyApp.ApplicationName
                Write-PSFMessage -Message "$HealthReport" -Level VeryVerbose
            }
            $Properties = @{'Name' = "ServiceFabricApplications"
                'Details'          = "Healthy: $HealthyApps / Total: $TotalApplications"
                'State'            = "Down" 
                'ExtraInfo'        = "$NotHealthyApps"
                'Source'           = $OrchestratorServerName
                'Group'            = 'ServiceFabric'
            }
            $Output = New-Object -TypeName psobject -Property $Properties
            $OutputList += $Output
        }
        
        $ServiceFabricPartitionIdForAXSF = $(get-servicefabricpartition -servicename 'fabric:/AXSF/AXService').PartitionId
        foreach ($node in $nodes) {
            $nodename = $node.Nodename
            $replicainstanceIdofnode = $(get-servicefabricreplica -partition $ServiceFabricPartitionIdForAXSF | Where-Object { $_.NodeName -eq "$NodeName" }).InstanceId
            $ReplicaDetails = Get-Servicefabricdeployedreplicadetail -nodename $nodename -partitionid $ServiceFabricPartitionIdForAXSF -ReplicaOrInstanceId $replicainstanceIdofnode -replicatordetail
            $endpoints = $ReplicaDetails.deployedservicereplicainstance.address | ConvertFrom-Json
            if ($endpoints.Endpoints )
            {
                $deployedinstancespecificguid = $($endpoints.Endpoints | Get-Member | Where-Object { $_.MemberType -eq "NoteProperty" }).Name
                Write-PSFMessage -Level VeryVerbose -Message "$NodeName is accessible via $httpsurl with a guid $deployedinstancespecificguid"
            }
            else{
                Write-PSFMessage -Level Warning -Message "$NodeName does not have AXService accessible"
            }
            $httpsurl = $endpoints.Endpoints.$deployedinstancespecificguid

            if ($httpsurl.Length -gt 3) {
                $Status = "Operational"
            }
            else {
                $Status = "Down"
            }
            $Properties = @{'Name' = "AXSFGUIDEndpoint"
                'Details'          = "$deployedinstancespecificguid"
                'State'            = "$Status" 
                'ExtraInfo'        = "$httpsurl"
                'Source'           = $NodeName 
                'Group'            = 'ServiceFabric'
            }
            $Output = New-Object -TypeName psobject -Property $Properties
            $OutputList += $Output
        }
        
        $CurrentDate = Get-Date
        $ErrorDateCerts = $CurrentDate.AddDays(-$CertErrorValue)
        $WarningDateCerts = $CurrentDate.AddDays(-$CertWarningValue)

        if ($Config.SessionAuthenticationCertificateExpiresAfter) {
            if ($Config.SessionAuthenticationCertificateExpiresAfter -lt $ErrorDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "SessionAuthentication"
                    'State'            = "Down" 
                    'ExtraInfo'        = "$($Config.SessionAuthenticationCertificateExpiresAfter)"
                    'Source'           = $Config.SessionAuthenticationCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            elseif ($Config.SessionAuthenticationCertificateExpiresAfter -lt $WarningDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "SessionAuthentication"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.SessionAuthenticationCertificateExpiresAfter)"
                    'Source'           = $Config.SessionAuthenticationCertificate
                    'Group'            = 'D365Certificates'
                }
                Write-PSFMessage -Level Warning -Message "WARNING: SessionAuthentication is expiring soon $($Config.SessionAuthenticationCertificateExpiresAfter)"
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            else {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "SessionAuthentication"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.SessionAuthenticationCertificateExpiresAfter)"
                    'Source'           = $Config.SessionAuthenticationCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
        }
        else {
            Write-PSFMessage -Level VeryVerbose -Message "Expiration not found for SessionAuthenticationCertificate"
        }

        
        if ($Config.SFClientCertificateExpiresAfter) {
            if ($Config.SFClientCertificateExpiresAfter -lt $ErrorDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "SFClientCertificate"
                    'State'            = "Down" 
                    'ExtraInfo'        = "$($Config.SFClientCertificateExpiresAfter)"
                    'Source'           = $Config.SFClientCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            elseif ($Config.SFClientCertificateExpiresAfter -lt $WarningDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "SessionAuthentication"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.SFClientCertificateExpiresAfter)"
                    'Source'           = $Config.SFClientCertificate
                    'Group'            = 'D365Certificates'
                }
                Write-PSFMessage -Level Warning -Message "WARNING: SFClientCertificate is expiring soon $($Config.SFClientCertificateExpiresAfter)"
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            else {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "SessionAuthentication"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.SFClientCertificateExpiresAfter)"
                    'Source'           = $Config.SFClientCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
        }
        else {
            Write-PSFMessage -Level VeryVerbose -Message "Expiration not found for SFClientCertificate"
        }

        #SFServerCertificate

        if ($Config.SFServerCertificateExpiresAfter) {
            if ($Config.SFServerCertificateExpiresAfter -lt $ErrorDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "SFServerCertificate"
                    'State'            = "Down" 
                    'ExtraInfo'        = "$($Config.SFServerCertificateExpiresAfter)"
                    'Source'           = $Config.SFServerCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            elseif ($Config.SFServerCertificateExpiresAfter -lt $WarningDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "SFServerCertificate"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.SFServerCertificateExpiresAfter)"
                    'Source'           = $Config.SFServerCertificate
                    'Group'            = 'D365Certificates'
                }
                Write-PSFMessage -Level Warning -Message "WARNING: SFServerCertificate is expiring soon $($Config.SFServerCertificateExpiresAfter)"
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            else {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "SFServerCertificate"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.SFServerCertificateExpiresAfter)"
                    'Source'           = $Config.SFServerCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
        }
        else {
            Write-PSFMessage -Level VeryVerbose -Message "Expiration not found for SFServerCertificate"
        }


        if ($Config.DataEncryptionCertificateExpiresAfter) {
            if ($Config.DataEncryptionCertificateExpiresAfter -lt $ErrorDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "DataEncryptionCertificate"
                    'State'            = "Down" 
                    'ExtraInfo'        = "$($Config.DataEncryptionCertificateExpiresAfter)"
                    'Source'           = $Config.DataEncryptionCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            elseif ($Config.DataEncryptionCertificateExpiresAfter -lt $WarningDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "DataEncryptionCertificate"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.DataEncryptionCertificateExpiresAfter)"
                    'Source'           = $Config.DataEncryptionCertificate
                    'Group'            = 'D365Certificates'
                }
                Write-PSFMessage -Level Warning -Message "WARNING: DataEncryptionCertificate is expiring soon $($Config.DataEncryptionCertificateExpiresAfter)"
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            else {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "DataEncryptionCertificate"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.DataEncryptionCertificateExpiresAfter)"
                    'Source'           = $Config.DataEncryptionCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
        }
        else {
            Write-PSFMessage -Level VeryVerbose -Message "Expiration not found for DataEncryptionCertificate"
        }
        if ($Config.DataSigningCertificateExpiresAfter) {
            if ($Config.DataSigningCertificateExpiresAfter -lt $ErrorDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "DataSigningCertificate"
                    'State'            = "Down" 
                    'ExtraInfo'        = "$($Config.DataSigningCertificateExpiresAfter)"
                    'Source'           = $Config.DataSigningCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            elseif ($Config.DataSigningCertificateExpiresAfter -lt $WarningDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "DataSigningCertificate"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.DataSigningCertificateExpiresAfter)"
                    'Source'           = $Config.DataSigningCertificate
                    'Group'            = 'D365Certificates'
                }
                Write-PSFMessage -Level Warning -Message "WARNING: DataSigningCertificate is expiring soon $($Config.DataSigningCertificateExpiresAfter)"
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            else {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "DataSigningCertificate"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.DataSigningCertificateExpiresAfter)"
                    'Source'           = $Config.DataSigningCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
        }
        else {
            Write-PSFMessage -Level VeryVerbose -Message "Expiration not found for DataSigningCertificate"
        }

        if ($Config.SessionAuthenticationCertificateExpiresAfter) {
            if ($Config.SessionAuthenticationCertificateExpiresAfter -lt $ErrorDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "SessionAuthenticationCertificate"
                    'State'            = "Down" 
                    'ExtraInfo'        = "$($Config.SessionAuthenticationCertificateExpiresAfter)"
                    'Source'           = $Config.SessionAuthenticationCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            elseif ($Config.SessionAuthenticationCertificateExpiresAfter -lt $WarningDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "SessionAuthenticationCertificate"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.SessionAuthenticationCertificateExpiresAfter)"
                    'Source'           = $Config.SessionAuthenticationCertificate
                    'Group'            = 'D365Certificates'
                }
                Write-PSFMessage -Level Warning -Message "WARNING: SessionAuthenticationCertificate is expiring soon $($Config.SessionAuthenticationCertificateExpiresAfter)"
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            else {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "SessionAuthenticationCertificate"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.SessionAuthenticationCertificateExpiresAfter)"
                    'Source'           = $Config.SessionAuthenticationCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
        }
        else {
            Write-PSFMessage -Level VeryVerbose -Message "Expiration not found for SessionAuthenticationCertificate"
        }

        if ($Config.FinancialReportingCertificateExpiresAfter) {
            if ($Config.FinancialReportingCertificateExpiresAfter -lt $ErrorDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "FinancialReportingCertificate"
                    'State'            = "Down" 
                    'ExtraInfo'        = "$($Config.FinancialReportingCertificateExpiresAfter)"
                    'Source'           = $Config.FinancialReportingCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            elseif ($Config.FinancialReportingCertificateExpiresAfter -lt $WarningDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "FinancialReportingCertificate"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.FinancialReportingCertificateExpiresAfter)"
                    'Source'           = $Config.FinancialReportingCertificate
                    'Group'            = 'D365Certificates'
                }
                Write-PSFMessage -Level Warning -Message "WARNING: FinancialReportingCertificate is expiring soon $($Config.FinancialReportingCertificateExpiresAfter)"
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            else {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "FinancialReportingCertificate"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.FinancialReportingCertificateExpiresAfter)"
                    'Source'           = $Config.FinancialReportingCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
        }
        else {
            Write-PSFMessage -Level VeryVerbose -Message "Expiration not found for FinancialReportingCertificate"
        }
        if ($Config.ReportingSSRSCertificateExpiresAfter) {
            if ($Config.ReportingSSRSCertificateExpiresAfter -lt $ErrorDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "ReportingSSRSCertificate"
                    'State'            = "Down" 
                    'ExtraInfo'        = "$($Config.ReportingSSRSCertificateExpiresAfter)"
                    'Source'           = $Config.ReportingSSRSCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            elseif ($Config.ReportingSSRSCertificateExpiresAfter -lt $WarningDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "ReportingSSRSCertificate"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.ReportingSSRSCertificateExpiresAfter)"
                    'Source'           = $Config.ReportingSSRSCertificate
                    'Group'            = 'D365Certificates'
                }
                Write-PSFMessage -Level Warning -Message "WARNING: ReportingSSRSCertificate is expiring soon $($Config.ReportingSSRSCertificateExpiresAfter)"
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            else {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "ReportingSSRSCertificate"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.ReportingSSRSCertificateExpiresAfter)"
                    'Source'           = $Config.ReportingSSRSCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
        }
        else {
            Write-PSFMessage -Level VeryVerbose -Message "Expiration not found for ReportingSSRSCertificate"
        }
        if ($Config.LocalAgentCertificateExpiresAfter) {
            if ($Config.LocalAgentCertificateExpiresAfter -lt $ErrorDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "LocalAgentCertificate"
                    'State'            = "Down" 
                    'ExtraInfo'        = "$($Config.LocalAgentCertificateExpiresAfter)"
                    'Source'           = $Config.LocalAgentCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            elseif ($Config.LocalAgentCertificateExpiresAfter -lt $WarningDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "LocalAgentCertificate"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.LocalAgentCertificateExpiresAfter)"
                    'Source'           = $Config.LocalAgentCertificate
                    'Group'            = 'D365Certificates'
                }
                Write-PSFMessage -Level Warning -Message "WARNING: LocalAgentCertificate is expiring soon $($Config.LocalAgentCertificateExpiresAfter)"
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            else {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "LocalAgentCertificate"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.LocalAgentCertificateExpiresAfter)"
                    'Source'           = $Config.LocalAgentCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
        }
        else {
            Write-PSFMessage -Level VeryVerbose -Message "Expiration not found for LocalAgentCertificate"
        }
        if ($Config.DataEnciphermentCertificateExpiresAfter) {
            if ($Config.DataEnciphermentCertificateExpiresAfter -lt $ErrorDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "DataEnciphermentCertificate"
                    'State'            = "Down" 
                    'ExtraInfo'        = "$($Config.DataEnciphermentCertificateExpiresAfter)"
                    'Source'           = $Config.DataEnciphermentCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            elseif ($Config.DataEnciphermentCertificateExpiresAfter -lt $WarningDateCerts) {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "DataEnciphermentCertificate"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.DataEnciphermentCertificateExpiresAfter)"
                    'Source'           = $Config.DataEnciphermentCertificate
                    'Group'            = 'D365Certificates'
                }
                Write-PSFMessage -Level Warning -Message "WARNING: DataEnciphermentCertificate is expiring soon $($Config.DataEnciphermentCertificateExpiresAfter)"
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
            else {
                $Properties = @{'Name' = "D365Certificates"
                    'Details'          = "DataEnciphermentCertificate"
                    'State'            = "Operational" 
                    'ExtraInfo'        = "$($Config.DataEnciphermentCertificateExpiresAfter)"
                    'Source'           = $Config.DataEnciphermentCertificate
                    'Group'            = 'D365Certificates'
                }
                $Output = New-Object -TypeName psobject -Property $Properties
                $OutputList += $Output
            }
        }
        else {
            Write-PSFMessage -Level VeryVerbose -Message "Expiration not found forDataEnciphermentCertificate"
        }

        [PSCustomObject]$OutputList

    }
    END {
        if ($SFModuleSession) {
            Remove-PSSession -Session $SFModuleSession  
        }
    }
}