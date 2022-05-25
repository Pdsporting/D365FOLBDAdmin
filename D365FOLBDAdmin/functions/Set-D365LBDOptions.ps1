function Set-D365LBDOptions {
    <#
   .SYNOPSIS
  Uses switches to set different deployment options created for expanding the pre and post deployment scripts. 
  .DESCRIPTION
  Uses switches to set different deployment options created for expanding the pre and post deployment scripts. 
  Recommend: Run multiple times for each task then the last run run with the teams communication.
  .EXAMPLE
  $config = Get-D365Config
  Set-D365LBDOptions -RemoveMR -predeployment -config $config
  Prevents the installation of Management reporter in the predeployment stage
  .EXAMPLE
   $config = Get-D365Config
    Set-D365LBDOptions -predeployment -enableuserid 'stefan' -config $config
    Enables user stefan in the predeployment stage
 .EXAMPLE
   $config = Get-D365Config
     Set-D365LBDOptions -predeployment -OtherTaskName 'TalkedToMyself' -OtherTaskStatus 'Success' -config $config
    Adds a custom task and status to the predeployment list for communication
  .EXAMPLE
   $config = Get-D365Config
    Set-D365LBDOptions -postdeployment -MSTEAMSCustomStatus 'Deployment Finished' -MSTeamsURI 'https://fake.outlook.com/webhook/fakeurl/123123' -MSTeamsBuildName '2021.03.04.01' -MSTeamsExtraDetails 'Web Search' -MSTeamsExtraDetailsURI 'https://google.com' -config $config
    Custom status of deployment finished and added an extra field called Web Search with a link to google. Also says the Build name as '2021.03.04.01' (recommend making a build name related to the config)
  #>
    [alias("Set-D365Options")]
    [CmdletBinding()]
    param
    (
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ParameterSetName = 'Config',
            ValueFromPipeline = $True)]
        [psobject]$Config,
        [switch]$PreDeployment,
        [switch]$PostDeployment,
        [switch]$RemoveMR,
        [switch]$MaintenanceModeOn,
        [switch]$MaintenanceModeOff,
        [string]$MSTeamsURI,
        [string]$MSTeamsExtraDetailsURI,
        [string]$MSTeamsExtraDetails,
        [string]$MSTeamsBuildName,
        [string]$MSTeamsCustomStatus,
        [string]$SQLQueryToRun,
        [string]$EnableUserid,
        [string]$DisableUserid,
        [string]$OtherTaskName,
        [string]$OtherTaskStatus
    )
    BEGIN {
    }
    PROCESS {
        if (!$Config -or $Config.OrchestratorServerNames.Count -eq 0) {
            Write-PSFMessage -Level VeryVerbose -Message "Config not defined or Config is invalid. Trying to Get new config using $ComputerName"
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly   
        }
        if ($PreDeployment) {
            Write-PSFMessage -Level Verbose -Message "PreDeployment Selected"
            $filenameprename = "PREDeployment"
        }
        if ($PostDeployment) {
            Write-PSFMessage -Level Verbose -Message "PostDeployment Selected"
            $filenameprename = "PostDeployment"
        }
        if ($Config) {
            $agentsharelocation = $Config.AgentShareLocation
            $AXDatabaseServer = $Config.AXDatabaseServer
            $AXDatabaseName = $Config.AXDatabaseName
            $LCSEnvironmentName = $Config.LCSEnvironmentName
            $clienturl = $Config.clienturl
            $LastRunbookTaskId = $Config.LastRunbookTaskId
            if (!$AXDatabaseServer) {
                $AXDatabaseServer = $config.databaseclusterservernames | select -First 1
                if (!$AXDatabaseServer) {
                    $AXDatabaseServer = $config.OrchDatabaseServer
                }
            }
        }
        if ((Test-Path $agentsharelocation\scripts\D365FOLBDAdmin) -eq $false) {
            
            new-item -path "$agentsharelocation\scripts\" -Name "D365FOLBDAdmin"  -ItemType "directory"
        }
        if ($null -eq $LastRunbookTaskId) {
            $norunbooktaskid = get-date -Format MMddyy
            if ((Test-Path $agentsharelocation\scripts\D365FOLBDAdmin\$filenameprename$norunbooktaskid.xml) -eq $false) {
                #$newfile = New-Item $agentsharelocation -path $agentsharelocation\scripts\D365FOLBDAdmin -Name "$filenameprename$norunbooktaskid.xml"
                @{} | Export-Clixml "$agentsharelocation\scripts\D365FOLBDAdmin\$filenameprename$norunbooktaskid.xml"

            }
            else {
                Write-PSFMessage -Level VeryVerbose -Message "$filenameprename$LastRunbookTaskId.xml already exists"
            }
        }
        else {
            if ((Test-Path $agentsharelocation\scripts\D365FOLBDAdmin\$filenameprename$LastRunbookTaskId.xml) -eq $false) {
                $newfile = New-Item -path $agentsharelocation\scripts\D365FOLBDAdmin -Name "$filenameprename$LastRunbookTaskId.xml"
                @{} | Export-Clixml "$agentsharelocation\scripts\D365FOLBDAdmin\$filenameprename$LastRunbookTaskId.xml"
                $CLIXML = Import-Clixml "$agentsharelocation\scripts\D365FOLBDAdmin\$filenameprename$LastRunbookTaskId.xml"
            }
            else {
                Write-PSFMessage -Level VeryVerbose -Message "$agentsharelocation\scripts\D365FOLBDAdmin\$filenameprename$LastRunbookTaskId.xml already exists"
                $newfile = Get-ChildItem $agentsharelocation\scripts\D365FOLBDAdmin\$filenameprename$LastRunbookTaskId.xml
                $CLIXML = Import-Clixml "$agentsharelocation\scripts\D365FOLBDAdmin\$filenameprename$LastRunbookTaskId.xml"
            } 
        }
        if ($OtherTaskName) {
            if (!$OtherTaskStatus) {
                $OtherTaskStatus = "Success"
            }
            $CLIXML += @{"$OtherTaskName" = "$OtherTaskStatus" }  
        }
        
        if ($RemoveMR) {
            Write-PSFMessage -Level Verbose -Message "Attempting to Remove MR"
            if ($PreDeployment -eq $True) {
                $JsonLocation = Get-ChildItem $AgentShareLocation\wp\*\StandaloneSetup-*\SetupModules.json | Sort-Object { $_.CreationTime } -Descending | Select-Object -First 1 
                $JsonLocationRoot = Get-ChildItem $AgentShareLocation\wp\*\StandaloneSetup-*\  | Sort-Object { $_.CreationTime } -Descending | Select-Object -First 1
                copy-item $JsonLocation.fullName -Destination $AgentShareLocation\OriginalSetupModules.json
                $json = Get-Content $JsonLocation.FullName -Raw | ConvertFrom-Json
                $json.components = $json.components | Where-Object { $_.name -ne 'financialreporting' }
                $json | ConvertTo-Json -Depth 100 | Out-File $JsonLocationRoot\Setupmodules.json -Force -Verbose
                $CLIXML += @{'Removed MR' = 'Success' }  
            }
            else {
                Write-PSFMessage -Message "Error: Can't remove MR during anything other than PreDeployment" -Level VeryVerbose
                $CLIXML += @{'Removed MR' = 'Failed - Cant run outside of predeployment' }
            }
        }
        function Invoke-SQL {
            param(
                [string] $dataSource = ".\SQLEXPRESS",
                [string] $database = "MasterData",
                [string] $sqlCommand = $(throw "Please specify a query.")
            )

            $connectionString = "Data Source=$dataSource; " +
            "Integrated Security=SSPI; " +
            "Initial Catalog=$database"

            $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
            $command = new-object system.data.sqlclient.sqlcommand($sqlCommand, $connection)
            $connection.Open()

            $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
            $dataset = New-Object System.Data.DataSet
            $adapter.Fill($dataSet) | Out-Null

            $connection.Close()
            $dataSet.Tables
        }

        if ($MaintenanceModeOn) {
            if (!$AXDatabaseServer) {
                Write-PSFMessage -Level Error -Message "Config does not have AX Database Server cant turn on maintenance mode"
            }
            Write-PSFMessage -Message "Turning On Maintenance Mode" -Level Verbose
            $SQLQuery = "update SQLSYSTEMVARIABLES SET VALUE = 1 Where PARM = 'CONFIGURATIONMODE'"
            $Sqlresults = invoke-sql -datasource $AXDatabaseServer -database $AXDatabaseName -sqlcommand $SQLQuery
            if (!$PostDeployment -or !$PreDeployment) {
                foreach ($AXSFServer in $config.AXSFServerNames) {
                    Restart-Computer -ComputerName $AXSFServer -Force
                }
            }
            Write-PSFMessage -Message "$SQLresults" -Level VeryVerbose
            if ($Sqlresults) {
                $CLIXML += @{'Turned On Maintenance Mode' = "Success - $SQLQuery" }  
                Write-PSFMessage -Message "Turned On Maintenance Mode. Note AXSF needs to be restarted (or done as predeployment step) for maintenance mode to be fully on." -Level VeryVerbose
            }
            else {
                $CLIXML += @{'Turned Off Maintenance Mode' = "Success - $SQLQuery" }  
            }
        }

        if ($MaintenanceModeOff) {
            if (!$AXDatabaseServer) {
                Write-PSFMessage -Level Error -Message "Config does not have AX Database Server cant turn off maintenance mode"
            }
            Write-PSFMessage -Message "Turning Off Maintenance Mode" -Level Verbose
            $SQLQuery = "update SQLSYSTEMVARIABLES SET VALUE = 0 Where PARM = 'CONFIGURATIONMODE'"
            $Sqlresults = invoke-sql -datasource $AXDatabaseServer -database $AXDatabaseName -sqlcommand $SQLQuery
            if ($PostDeployment -eq $false -or $PreDeployment -eq $false) {
                foreach ($AXSFServer in $config.AXSFServerNames) {
                    Restart-Computer -ComputerName $AXSFServer -Force
                }
            }
            Write-PSFMessage -Message "$SQLresults" -Level VeryVerbose
            if ($Sqlresults) {
                $CLIXML += @{'Turned Off Maintenance Mode' = "Success - $SQLQuery" }  
                Write-PSFMessage -Message "Turned Off Maintenance Mode. Note AXSF needs to be restarted (or done as predeployment step) for maintenance mode to be fully off." -Level VeryVerbose
            }
            else {
                $CLIXML += @{'Turned Off Maintenance Mode' = "Failed - $SQLQuery" }  
            }
        }

        if ($EnableUserid) {
            ##Trim 8 characters
            if (!$AXDatabaseServer) {
                Write-PSFMessage -Level Error -Message "Config does not have AX Database Server cant enable user"
            }
            Write-PSFMessage -Message "Enabling $EnableUserid. Note: User must already exist in system" -Level Verbose
            $SQLQuery = "update userinfo SET Enable = 1, RECVERSION = RECVERSION +1 Where id = '$EnableUserid'"
            $SQLQuery2 = "select * from userinfo where enable = 1 and id = '$EnableUserid'"
            $SqlresultsUpdate = invoke-sql -datasource $AXDatabaseServer -database $AXDatabaseName -sqlcommand $SQLQuery
            $Sqlresults = invoke-sql -datasource $AXDatabaseServer -database $AXDatabaseName -sqlcommand $SQLQuery2 
            if ($Sqlresults) {
                if ($PreDeployment -or $PostDeployment) {
                    $CLIXML += @{"Enable User $EnableUserid" = "Success - $SQLQuery" }  
                }
                Write-PSFMessage -Message "$EnableUserid enabled." -Level VeryVerbose
            }
            else {
                if ($PreDeployment -or $PostDeployment) {
                    $CLIXML += @{"Enable User $EnableUserid" = "Failed - $SQLQuery" } 
                } 
                Write-PSFMessage -Message "$EnableUserid enable failed." -Level VeryVerbose
            }
            Write-PSFMessage -Message "ID: $($SQLresults.ID) EnableFlag: $($SQLresults.Enable) " -Level VeryVerbose
        }
            
        if ($DisableUserid) {
            if (!$AXDatabaseServer) {
                Write-PSFMessage -Level Error -Message "Config does not have AX Database Server cant disable user"
            }
            else {
                Write-PSFMessage -Message "Disabling $DisableUserid. Note: User must already exist in system" -Level Verbose
                $SQLQuery = "update userinfo SET Enable = 0, RECVERSION = RECVERSION +1 Where id = '$DisableUserid'"
                $SQLQuery2 = "select * from userinfo where enable = 0 and id = '$DisableUserid'"
                $SQLQuery3 = "SELECT [USER_] ,[SECURITYROLE],  t2.NAME, t2.AOTNAME  FROM [dbo].[SECURITYUSERROLE]  t1  inner join  [SECURITYROLE] t2 on t1.SECURITYROLE=t2.RECID  where USER_ = '$DisableUserid'"
                $SqlresultsUpdate = invoke-sql -datasource $AXDatabaseServer -database $AXDatabaseName -sqlcommand $SQLQuery 
                $Sqlresults2 = invoke-sql -datasource $AXDatabaseServer -database $AXDatabaseName -sqlcommand $SQLQuery2
                $Sqlresults3 = invoke-sql -datasource $AXDatabaseServer -database $AXDatabaseName -sqlcommand $SQLQuery3 
                Write-PSFMessage -Message "ID: $($SQLresults2.ID) EnableFlag: $($SQLresults2.Enable) " -Level VeryVerbose
                Write-PSFMessage -Message "User in the following groups" -Level VeryVerbose
                Write-PSFMessage -Message "$($($Sqlresults3.Name) -join ', ')"
            }
            if ($Sqlresults2) {
                if ($PreDeployment -or $PostDeployment) {
                    $CLIXML += @{'Disable User' = "Success - $SQLQuery" }  
                }
                write-PSFMessage -Message "$DisableUserid disabled." -Level VeryVerbose
            }
            else {
                if ($PreDeployment -or $PostDeployment) {
                    $CLIXML += @{'Disable User' = "Failed - $SQLQuery" }  
                }
                Write-PSFMessage -Message "$DisableUserid disable failed." -Level VeryVerbose
            }
        }

        if ($SQLQueryToRun) {
            if (!$AXDatabaseServer) {
                Write-PSFMessage -Level Error -Message "Config does not have AX Database Server cant run SQL command"
            }
            $Sqlresults = invoke-sql -datasource $AXDatabaseServer -database $AXDatabaseName -sqlcommand $SQLQueryToRun
            Write-PSFMessage -Message "$SQLresults" -Level VeryVerbose
            $CountofSQLScripts = $($CLIXML.GetEnumerator() | Where-Object { $_.Name -like "SQL*" }).Count
            $CountOfSQLScripts = $CountofSQLScripts + 1
            if ($Sqlresults) {
                $CLIXML += @{"SQL$CountOfSQLScripts" = "Success - $SQLQueryToRun" }  
            }
            else {
                $CLIXML += @{"SQL$CountOfSQLScripts" = "Failed - $SQLQueryToRun" }  
            }
        }
        ##EXPORT FILE AFTER CHANGES
        $CLIXML | Export-Clixml $newfile.FullName

        if ($MSTeamsURI) {
            Write-PSFMessage -Level VeryVerbose -Message "MSTeamsURI defined sending message"
            $MSTeamsFormmatedJSONofCLIItems = ""
            foreach ($XMLItem in $CLIXML.GetEnumerator()) {
                $WorkingJSON = @"
,{
"name": "$($XMLItem.Name)",
"value": "$($XMLItem.Value)"
}   
"@
                $MSTeamsFormmatedJSONofCLIItems += $WorkingJSON
            }

            if ($PreDeployment) {
                $status = 'PreDeployment Started'
            }
            if ($PostDeployment) {
                $status = 'Deployment Finished. PostDeployment Started'
            }
            if ($MSTeamsCustomStatus) {
                $status = "$MSTeamsCustomStatus"
            }
            if (!$MSTeamsBuildName) {
                $MSTeamsBuildName = $config.LastFullyPreppedCustomModuleAsset
            }
            if ($MSTeamsFormmatedJSONofCLIItems) {
                $bodyjson = @"
                {
                    "@type": "MessageCard",
                    "@context": "http://schema.org/extensions",
                    "themeColor": "ff0000",
                    "title": "D365 $LCSEnvironmentName $status",
                    "summary": "D365 $LCSEnvironmentName $status",
                    "sections": [{
                        "facts": [{
                            "name": "Environment",
                            "value": "[$LCSEnvironmentName]($clienturl)"
                        },{
                            "name": "Build Version/Name",
                            "value": "$MSTeamsBuildName"
                        },{
                            "name": "Status",
                            "value": "$status"
                        }$MSTeamsFormmatedJSONofCLIItems],
                        "markdown": true
                    }]
                }            
"@
            }
            else {
                $bodyjson = @"
                {
                    "@type": "MessageCard",
                    "@context": "http://schema.org/extensions",
                    "themeColor": "ff0000",
                    "title": "D365 $LCSEnvironmentName $status",
                    "summary": "D365 $LCSEnvironmentName $status",
                    "sections": [{
                        "facts": [{
                            "name": "Environment",
                            "value": "[$LCSEnvironmentName]($clienturl)"
                        },{
                            "name": "Build Version/Name",
                            "value": "$MSTeamsBuildName"
                        },{
                            "name": "Status",
                            "value": "$status"
                        }],
                        "markdown": true
                    }]
                }            
"@
            }
            if ($MSTeamsExtraDetails) {
                if ($MSTeamsFormmatedJSONofCLIItems) {
                    $bodyjson = @"
                    {
                        "@type": "MessageCard",
                        "@context": "http://schema.org/extensions",
                        "themeColor": "ff0000",
                        "title": "D365 $LCSEnvironmentName $status",
                        "summary": "D365 $LCSEnvironmentName $status",
                        "sections": [{
                            "facts": [{
                                "name": "Environment",
                                "value": "[$LCSEnvironmentName]($clienturl)"
                            },{
                                "name": "Build Version",
                                "value": "$MSTeamsBuildName"
                            },{
                                "name": "Details",
                                "value": "[$MSTeamsExtraDetails]($MSTeamsExtraDetailsURI)"
                            },{
                                "name": "Status",
                                "value": "$status"
                            }$MSTeamsFormmatedJSONofCLIItems],
                            "markdown": true
                        }]
                    }            
"@
                }
                else {
                    $bodyjson = @"
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "ff0000",
    "title": "D365 $LCSEnvironmentName $status",
    "summary": "D365 $LCSEnvironmentName $status",
    "sections": [{
        "facts": [{
            "name": "Environment",
            "value": "[$LCSEnvironmentName]($clienturl)"
        },{
            "name": "Build Version",
            "value": "$MSTeamsBuildName"
        },{
            "name": "Details",
            "value": "[$MSTeamsExtraDetails]($MSTeamsExtraDetailsURI)"
        },{
            "name": "Status",
            "value": "$status"
        }],
        "markdown": true
    }]
}            
"@
                }
            }
            Write-PSFMessage -Message "Calling $MSTeamsURI with Post of $bodyjson" -Level VeryVerbose
            $WebRequestResults = Invoke-WebRequest -uri $MSTeamsURI -ContentType 'application/json' -Body $bodyjson -UseBasicParsing -Method Post -Verbose
            Write-PSFMessage -Message "$WebRequestResults" -Level VeryVerbose
        }
    }
    END {
    }
}
