function Send-D365LBDUpdateMSTeams {
    <#
   .SYNOPSIS
  Created to Send D365 updates to MSTeams
  .DESCRIPTION
Created to Send D365 updates to MSTeams
  .EXAMPLE
  Send-D365LBDUpdateMSTeams -messageType "StatusReport" -MSTeamsURI "htts://fakemicrosoft.office.com/webhookb2/98984684987156465-4654/incominginwebhook/ea5s6d4sa6" -config $config

  .EXAMPLE
Send-D365LBDUpdateMSTeams -messageType "BuildPrepStarted" -MSTeamsURI "htts://fakemicrosoft.office.com/webhookb2/98984684987156465-4654/incominginwebhook/ea5s6d4sa6" -config $config

  .EXAMPLE
Send-D365LBDUpdateMSTeams -messageType "BuildPrepped" -MSTeamsURI "htts://fakemicrosoft.office.com/webhookb2/98984684987156465-4654/incominginwebhook/ea5s6d4sa6" -config $config -CustomModuleName 'CUS'

  .EXAMPLE
Send-D365LBDUpdateMSTeams -messageType "BuildStart" -MSTeamsURI "htts://fakemicrosoft.office.com/webhookb2/98984684987156465-4654/incominginwebhook/ea5s6d4sa6" -MSTeamsBuildName '1.1.2021' -CustomModuleName 'CUS'

 .EXAMPLE
Send-D365LBDUpdateMSTeams -messageType "BuildComplete" -MSTeamsURI "htts://fakemicrosoft.office.com/webhookb2/98984684987156465-4654/incominginwebhook/ea5s6d4sa6" -MSTeamsBuildName '1.1.2021' -CustomModuleName 'CUS'

 .EXAMPLE
Send-D365LBDUpdateMSTeams -messageType "PlainText" -MSTeamsURI "htts://fakemicrosoft.office.com/webhookb2/98984684987156465-4654/incominginwebhook/ea5s6d4sa6" -PlainTextTitle 'TITLE' -PlainTextMessage 'Message'

 .EXAMPLE
  Send-D365LBDUpdateMSTeams -messageType "StatusReport" -MSTeamsURI "htts://fakemicrosoft.office.com/webhookb2/98984684987156465-4654/incominginwebhook/ea5s6d4sa6" -config $config -MSTeamsExtraDetailsTitle 'FactTitle' -MSTeamsExtraDetails 'Fact Text' -MSTeamsExtraDetailsURI 'http://google.com'

 .EXAMPLE
Send-D365LBDUpdateMSTeams -messageType "PlainText" -MSTeamsURI "htts://fakemicrosoft.office.com/webhookb2/98984684987156465-4654/incominginwebhook/ea5s6d4sa6" -PlainTextTitle 'TITLE' -PlainTextMessage 'Message'


  #>
    [alias("Send-D365UpdateMSTeams")]
    [CmdletBinding()]
    param
    (
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ParameterSetName = 'Config',
            ValueFromPipeline = $True)]
        [psobject]$Config,
        [string]$MSTeamsURI,
        [string]$MSTeamsExtraDetailsURI,
        [string]$MSTeamsExtraDetails,
        [string]$MSTeamsExtraDetailsTitle,
        [string]$MSTeamsBuildName,
        [string]$MSTeamsBuildURL,
        [string]$MSTeamsCustomStatus,
        [string]$MessageType,
        [string]$CustomModuleName,
        [string]$EnvironmentName,
        [string]$EnvironmentURL,
        [string]$PlainTextMessage,
        [string]$PlainTextTitle,
        [switch]$StatusReportIgnorePermissionErrors
    )
    BEGIN {
    }
    PROCESS {
        switch ( $MessageType) {
            "PreDeployment" { Stop-PSFFunction -Message "PreDeployment use Set-D365LBDOptions" }
            "PostDeployment" { Stop-PSFFunction -Message "PostDeployment use Set-D365LBDOptions" }
            "BuildStart" { $status = 'Build Started' }
            "BuildComplete" { $status = 'Build Completed' }
            "BuildPrepStarted" { $status = 'Build Prep Started' }
            "BuildPrepped" { $status = 'Build Prepped' }
            "StatusReport" { $Status = "Status Report" }
            "PlainText" {}
            default { Stop-PSFFunction -Message "Message type $MessageType is not supported" }
        }
        if ($MSTeamsCustomStatus) {
            $status = "$MSTeamsCustomStatus"
        }
        if (!$MSTeamsURI) {
            Write-PSFMessage -Level VeryVerbose -Message "MSTeamsURI not defined attemping to find in config"
            if (!$CustomModuleName) {
                if (!$Config) {
                    $Config = Get-D365LBDConfig -ComputerName $ComputerName -CustomModuleName $CustomModuleName -HighLevelOnly 
                } 
            }
            else {
                if (!$Config) {
                    $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly 
                }      
            }
            $AgentShareLocation = $config.AgentShareLocation 
            $EnvironmentAdditionalConfig = get-childitem "$AgentShareLocation\scripts\D365FOLBDAdmin\AdditionalEnvironmentDetails.xml"
            [xml]$EnvironmentAdditionalConfigXML = get-content $EnvironmentAdditionalConfig.FullName
        
            $MSTeamsURIS = $EnvironmentAdditionalConfigXML.D365LBDEnvironment.Communication.Webhooks.Webhook | Where-Object { $_.Type.'#text'.Trim() -eq "MSTeams" }
           
            if (!$MSTeamsURI -and !$MSTeamsURIS) {
                Stop-PSFFunction -Message "Error: MS Teams URI not specified and can't find one in configs" -EnableException $true -Cmdlet $PSCmdlet
            }
        }
        
        if (!$MSTeamsURIS) {
            $MSTeamsURIS = $MSTeamsURI
        }
        if (!$CustomModuleName -and $MessageType -eq "BuildPrepped") {
            if (!$Config) {
                $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly 
            } 
            $CustomModuleName = $Config.CustomModuleName
            if (!$CustomModuleName -and !$MSTeamsBuildName) {
                Stop-PSFFunction -Message "ERROR: CustomModuleName NOT DEFINED and MSTeamsBuildName NOT DEFINED." -EnableException $true -Cmdlet $PSCmdlet
            }
            if (!$CustomModuleName -and $MSTeamsBuildName) {
                $CustomModuleName = "CustomModule"
            }
        }

        if (($CustomModuleName) -and $MessageType -eq "BuildPrepped" -and ($MSTeamsBuildName)) {
            ## BUILD PREPPED Beginning 
            Write-PSFMessage -Level VeryVerbose -Message "MessageType is: BuildPrepped - BuildName has been defined ($MSTeamsBuildName)"
            if (!$EnvironmentName) {
                if (!$CustomModuleName -and $CustomModuleName -ne "CustomModule") {
                    if (!$Config) {
                        $Config = Get-D365LBDConfig -ComputerName $ComputerName -CustomModuleName $CustomModuleName -HighLevelOnly 
                    }
                }
                else {
                    if (!$Config) {
                        $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly 
                    }
                }
                $LCSEnvironmentName = $Config.LCSEnvironmentName
                $clienturl = $Config.clienturl
                $LCSEnvironmentURL = $Config.LCSEnvironmentURL
            }
            if (!$EnvironmentName) {
                $bodyjson = @"
{
     "@type": "MessageCard",
     "@context": "http://schema.org/extensions",
     "themeColor": "ff0000",
    "title": "$LCSEnvironmentName $status",
      "summary": "$LCSEnvironmentName $status",
      "sections": [{
      "facts": [{
       "name": "Environment",
       "value": "[$LCSEnvironmentName]($clienturl)"
         },{
        "name": "Build Version/Name",
        "value": "$MSTeamsBuildName"
         },{
         "name": "LCS",
         "value": "[LCS]($LCSEnvironmentURL)"
        }],
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
    "title": "$EnvironmentName $status ",
      "summary": "$EnvironmentName $status",
      "sections": [{
      "facts": [{
       "name": "Environment",
       "value": "[$EnvironmentName]($EnvironmentURL)"
         },{
        "name": "Build Version/Name",
        "value": "$MSTeamsBuildName"
         }],
         "markdown": true
          }]
}            
"@

            }
            $bodyjsonformed = 1
        }
        ##
        if (($CustomModuleName) -and $MessageType -eq "BuildPrepped" -and $bodyjsonformed -ne 1) {
            Write-PSFMessage -Level VeryVerbose -Message "MessageType is: BuildPrepped - BuildName has NOT been defined"
            if (!$CustomModuleName -and !$Config) {
                $Config = Get-D365LBDConfig -ComputerName $ComputerName -CustomModuleName $CustomModuleName -HighLevelOnly 
            }
            else {
                if (!$Config) {
                    $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly 
                }
            }
            $Prepped = Export-D365LBDAssetModuleVersion -CustomModuleName $CustomModuleName -config $Config
            if ($Prepped) {
                if ($Prepped.Count -eq 1) {
                    Write-PSFMessage -Message "Found a prepped build: $Prepped" -Level VeryVerbose
                    $LCSEnvironmentName = $Config.LCSEnvironmentName
                    $clienturl = $Config.clienturl 
                    $LCSEnvironmentURL = $Config.LCSEnvironmentURL
                    $bodyjson = @"
{
                    "@type": "MessageCard",
                    "@context": "http://schema.org/extensions",
                    "themeColor": "ff0000",
                    "title": "$status $LCSEnvironmentName",
                    "summary": "$status $LCSEnvironmentName",
                    "sections": [{
                        "facts": [{
                            "name": "Environment",
                            "value": "[$LCSEnvironmentName]($clienturl)"
                        },{
                            "name": "Build Version/Name",
                            "value": "$Prepped"
                        },{
                            "name": "LCS",
                            "value": "[LCS]($LCSEnvironmentURL)"
                        }],
                        "markdown": true
                    }]
                }            
"@
                    $bodyjsonformed = 1
                }
                else {
                    foreach ($build in $Prepped) {
                        Write-PSFMessage -Message "Found multiple prepped builds including: $build" -Level VeryVerbose
                    }
                }
            } ## if preppfound end starting else to find the latest built
                
            if ($bodyjsonformed -ne 1) {
                Write-PSFMessage -Level VeryVerbose -Message "No newly prepped build found" ##add logic to grab latest
                $MSTeamsBuildName = $Config.CustomModuleVersion
                if ($EnvironmentName) {
                    $LCSEnvironmentName = $EnvironmentName
                }
                else {
                    $LCSEnvironmentName = $config.LCSEnvironmentName
                }
                
                
                $clienturl = $Config.clienturl
                $LCSEnvironmentURL = $Config.LCSEnvironmentURL
                $Prepped = $config.LastFullyPreppedCustomModuleAsset
                if (!$MSTeamsBuildName) {
                    Write-PSFMessage -Message "Can't find Version removing from json"
 
                    $bodyjson = @"
{
                                        "@type": "MessageCard",
                                        "@context": "http://schema.org/extensions",
                                        "themeColor": "ff0000",
                                        "title": "$LCSEnvironmentName $status",
                                        "summary": "$LCSEnvironmentName $status",
                                        "sections": [{
                                            "facts": [{
                                                "name": "Environment",
                                                "value": "[$LCSEnvironmentName]($clienturl)"
                                            },{
                                                "name": "LCS",
                                                "value": "[LCS]($LCSEnvironmentURL)"
                                            }],
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
                    "title": "$LCSEnvironmentName $status",
                    "summary": "$LCSEnvironmentName $status",
                    "sections": [{
                        "facts": [{
                            "name": "Environment",
                            "value": "[$LCSEnvironmentName]($clienturl)"
                        },{
                            "name": "Build Version/Name",
                            "value": "$MSTeamsBuildName"
                        },{
                            "name": "LCS",
                            "value": "[LCS]($LCSEnvironmentURL)"
                        }],
                        "markdown": true
                    }]
                }            
"@
                }
                          
            }
        } ## end of build prep
        
        if ($MessageType -eq "PlainText") {
            Write-PSFMessage -Level VeryVerbose -Message "MessageType is: Plain Text Message" 
            if ($PlainTextTitle) {
                Write-PSFMessage -Level VeryVerbose -Message "Plain Text Message with Custom Title" 
                $bodyjson = @"
                {
                    "title":"$($("$PlainTextTitle $status").trim())",
                    "text":"$PlainTextMessage"
                }     
"@
            }
            else {
                Write-PSFMessage -Level VeryVerbose -Message "Plain Text Message"              
                $bodyjson = @"
{
    "title":"$($("$PlainTextTitle $status").trim())",
    "text":"$PlainTextMessage"
}     
"@
            }
        } ## PLAIN TEXT END


        if ($MessageType -eq "BuildStart") {
            Write-PSFMessage -Message "MessageType is: BuildStart" -Level VeryVerbose
            if (!$MSTeamsBuildName) {
                Stop-PSFFunction -Message "Error: MSTEAMSBuildName needs to be defined" -EnableException $true -Cmdlet $PSCmdlet
            }
            else {
                if ($MSTeamsBuildURL) {
                    $bodyjson = @"
{
                        "@type": "MessageCard",
                        "@context": "http://schema.org/extensions",
                        "themeColor": "ff0000",
                        "title": "$status",
                        "summary": "$status",
                        "sections": [{
                            "facts": [{
                                "name": "Build Version",
                                "value": "[$MSTeamsBuildName]($MSTeamsBuildURL)"
                            }],
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
                        "title": "$status",
                        "summary": "$status",
                        "sections": [{
                            "facts": [{
                                "name": "Build Version",
                                "value": "$MSTeamsBuildName"
                            }],
                            "markdown": true
                        }]
                    } 
"@
                }

            }
        }

        if ($MessageType -eq "BuildComplete") {
            Write-PSFMessage -Message "MessageType is: BuildComplete" -Level VeryVerbose
            if (!$MSTeamsBuildName) {
                Stop-PSFFunction -Message "Error: MSTEAMSBuildName needs to be defined" -EnableException $true -Cmdlet $PSCmdlet
            }
            else {
                if ($MSTeamsBuildURL) {
                    $bodyjson = @"
{
                        "@type": "MessageCard",
                        "@context": "http://schema.org/extensions",
                        "themeColor": "ff0000",
                        "title": "$status",
                        "summary": "$status",
                        "sections": [{
                            "facts": [{
                                "name": "Build Version",
                                "value": "[$MSTeamsBuildName]($MSTeamsBuildURL)"
                            }],
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
    "title": "$status",
    "summary": "$status",
    "sections": [{
        "facts": [{
            "name": "Build Version",
            "value": "$MSTeamsBuildName"
        }],
        "markdown": true
    }]
}            
"@
                }
            }
        }

        if ($MessageType -eq "BuildPrepStarted") {   
            Write-PSFMessage -Message "MessageType is: Build Prep Started" -Level VeryVerbose
            if (!$CustomModuleName) {
                if (!$Config) {    
                    $Config = Get-D365LBDConfig -ComputerName $ComputerName -CustomModuleName $CustomModuleName -HighLevelOnly 
                }
            }
            else {
                if (!$Config) {
                    $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly 
                }
            }
            $LCSEnvironmentName = $Config.LCSEnvironmentName
            $clienturl = $Config.clienturl
            $LCSEnvironmentURL = $Config.LCSEnvironmentURL
            
            if (!$MSTeamsBuildName) {
                Stop-PSFFunction -Message "Error: MSTEAMSBuildName needs to be defined" -EnableException $true -Cmdlet $PSCmdlet
            }
            $bodyjson = @"
{
     "@type": "MessageCard",
     "@context": "http://schema.org/extensions",
     "themeColor": "ff0000",
    "title": "$LCSEnvironmentName $status",
      "summary": "$LCSEnvironmentName $status",
      "sections": [{
      "facts": [{
       "name": "Environment",
       "value": "[$LCSEnvironmentName]($clienturl)"
         },{
        "name": "Build Version/Name",
        "value": "$MSTeamsBuildName"
         },{
         "name": "LCS",
         "value": "[LCS]($LCSEnvironmentURL)"
        }],
         "markdown": true
          }]
}            
"@
        }

        if ($MessageType -eq "StatusReport") {   
            Write-PSFMessage -Message "MessageType is: StatusReport" -Level VeryVerbose
            if (!$CustomModuleName) {
                if (!$Config) { 
                    $Config = Get-D365LBDConfig -ComputerName $ComputerName 
                }
            }
            else {
                if (!$Config) {
                    $Config = Get-D365LBDConfig -ComputerName $ComputerName -CustomModuleName $CustomModuleName
                }
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
            if (!$EnvironmentName) {
                $LCSEnvironmentName = $Config.LCSEnvironmentName
            }
            else {
                $LCSEnvironmentName = $EnvironmentName
            }
            if (!$EnvironmentURL) {
                $EnvironmentURL = $Config.ClientURL
            }
            
            if (!$MSTeamsBuildName) {
                $MSTeamsBuildName = $Config.CustomModuleVersion

            }

            $Health = Get-D365LBDEnvironmentHealth -Config $config 
            if ($StatusReportIgnorePermissionErrors){
                $Health = $Health | Where-Object {$_.Details -notlike "*Check Permissions"}
            }
            if ($Health.State -contains "Down") {
                foreach ($issue in $($health | Where-Object { $_.State -eq 'Down' })) {
                    $HealthCheck = "$HealthCheck" + "Down" + "$($issue.ExtraInfo)"
                }
            }
            else {
                $HealthCheck = "Operational"
            }

            $Dependency = Get-D365LBDDependencyHealth -config $Config
            if ($Dependency.State -contains "Down") {
                foreach ($issue in $($Dependency | Where-Object { $_.State -eq 'Down' })) {
                    $DependencyCheck = "$DependencyCheck" + "Down" + " $($issue.ExtraInfo)"
                }
            }
            else {
                $DependencyCheck = "Operational"
            }

            $bodyjson = @"
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "ff0000",
    "title": "$LCSEnvironmentName $status",
    "summary": "$LCSEnvironmentName $status",
    "sections": [{
        "facts": [{
            "name": "Environment",
            "value": "[$LCSEnvironmentName]($EnvironmentURL)"
        },{
            "name": "Build Version",
            "value": "$MSTeamsBuildName"
        },{
            "name": "Healthy Apps/Total Apps",
            "value": "$HealthyApps / $TotalApplications"
        },{
            "name": "D365 Health Check",
            "value": "$HealthCheck"
        },{
            "name": "D365 Dependency Check",
            "value": "$DependencyCheck"
        }],
        "markdown": true
    }]
}            
"@
        }

        if ($MSTeamsExtraDetails) {
            Write-PSFMessage -Level VeryVerbose -Message "Adding extra Details to JSON"
            $Additionaljson = @"
    ,{
            "name": "$MSTeamsExtraDetailsTitle",
            "value": "[$MSTeamsExtraDetails]($MSTeamsExtraDetailsURI)"
        }],                  
"@
            $bodyjson = $bodyjson.Replace('],', "$Additionaljson")
        }
        if (!$bodyjson) {
            Write-PSFMessage -Message "ERROR: JSON is empty!" -Level VeryVerbose
        }
        if ($MSTeamsURIS) {
            foreach ($MSTeamsURI in $MSTeamsURIS) {
                Write-PSFMessage -Message "Calling $MSTeamsURI with Post of $bodyjson" -Level VeryVerbose
                $WebRequestResults = Invoke-WebRequest -uri $MSTeamsURI -ContentType 'application/json' -Body $bodyjson -UseBasicParsing -Method Post -Verbose
                Write-PSFMessage -Message "$WebRequestResults" -Level VeryVerbose
            }
        }
    }
    END {
    }
}