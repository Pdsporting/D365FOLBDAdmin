function Send-D365LBDUpdateMSTeams {
    <#
   .SYNOPSIS
  Uses switches to set different deployment options
  .DESCRIPTION

  .EXAMPLE
  Set-D365LBDOptions -RemoveMR

  .EXAMPLE

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
        [string]$MSTeamsCustomStatus,
        [string]$MessageType,
        [string]$CustomModuleName,
        [string]$EnvironmentName,
        [string]$EnvironmentURL,
        [string]$LCSProjectId,
        [string]$LCSEnvironmentID,
        [string]$PlainTextMessage,
        [string]$PlainTextTitle
    )
    BEGIN {
    }
    PROCESS {
        switch ( $MessageType) {
            "PreDeployment" { $status = 'PreDeployment Started' }
            "PostDeployment" { $status = 'Deployment Completed' }
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
            if (!$CustomModuleName) {
                $Config = Get-D365LBDConfig -ComputerName $ComputerName -CustomModuleName $CustomModuleName -HighLevelOnly 
            }
            else {
                $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly 
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

        if (($CustomModuleName) -and $MessageType -eq "BuildPrepped" -and ($MSTeamsBuildName)) {
            ## BUILD PREPPED Beginning
            Write-PSFMessage -Level VeryVerbose -Message "MessageType is: BuildPrepped - BuildName has been defined ($MSTeamsBuildName)"
            if (!$EnvironmentName) {
                if (!$CustomModuleName) {
                    $Config = Get-D365LBDConfig -ComputerName $ComputerName -CustomModuleName $CustomModuleName -HighLevelOnly 
                }
                else {
                    $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly 
                }
                $LCSEnvironmentName = $Config.LCSEnvironmentName
                $clienturl = $Config.clienturl
                $LCSEnvironmentURL = $Config.LCSEnvironmentURL
            }
            if ($LCSEnvironmentID) {
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
        }
        if (($CustomModuleName) -and $MessageType -eq "BuildPrepped" -and (!$MSTeamsBuildName)) {
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
                    $LCSProjectId = $config.LCSProjectID
                    $LCSEnvironmentID = $Config.LCSEnvironmentID
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
                }
                else {
                    foreach ($build in $Prepped) {
                        Write-PSFMessage -Message "Found multiple prepped builds including: $build" -Level VeryVerbose
                    }
                }
            }
            else {
                if ($EnvironmentName -and $MSTeamsBuildName) {
                    $LCSEnvironmentName = $EnvironmentName
                    $clienturl = $Config.clienturl
                    $LCSEnvironmentURL = $Config.LCSEnvironmentURL
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
                            "value": "$Prepped"
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
                    Write-PSFMessage -Level VeryVerbose -Message "No newly prepped build found" ##add logic to grab latest
                }
                ## Build prepped but Environment or Build not defined end
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

        if ($MessageType -eq "BuildComplete") {
            Write-PSFMessage -Message "MessageType is: BuildComplete" -Level VeryVerbose
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

        if ($MessageType -eq "BuildPrepStarted") {   
            Write-PSFMessage -Message "MessageType is: Build Prep Started" -Level VeryVerbose
            if (!$CustomModuleName) {
                $Config = Get-D365LBDConfig -ComputerName $ComputerName -CustomModuleName $CustomModuleName -HighLevelOnly 
            }
            else {
                $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly 
            }
            $LCSEnvironmentName = $Config.LCSEnvironmentName
            $clienturl = $Config.clienturl
            $LCSEnvironmentURL = $Config.LCSEnvironmentURL
            
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
                $Config = Get-D365LBDConfig -ComputerName $ComputerName -CustomModuleName $CustomModuleName -HighLevelOnly 
            }
            else {
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
            if ($Health.Status -contains "Down") {
                $HealthCheck = "Down"
            }
            else {
                $HealthCheck = "Operational"
            }

            $Dependency = Get-D365LBDDependencyHealth -config $Config
            if ($Dependency.Status -contains "Down") {
                $DependencyCheck = "Down"
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
            "value": "[$LCSEnvironmentName]($clienturl)"
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
            Write-PSFMessage -Message "Json is empty!" -Level VeryVerbose
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