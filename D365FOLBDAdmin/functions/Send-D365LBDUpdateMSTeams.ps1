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
        [string]$MessageType,
        [string]$CustomModuleName
    )
    BEGIN {
    }
    PROCESS {
        switch ( $MessageType) {
            "PreDeployment" { $status = 'PreDeployment Started' }
            "PostDeployment" { $status = 'Deployment Completed' }
            "BuildStart" { $status = 'Build Started' }
            "BuildComplete" { $status = 'PreDeployment Started' }
            "BuildPrepStarted" { $status = 'Build Prep Started' }
            "BuildPrepped" { $status = 'Build Prepped' }
            "PlainText" {}
            default { Stop-PSFFunction -Message "Message type $MessageType is not supported" }
        }
        if ($MSTeamsCustomStatus) {
            $status = "$MSTeamsCustomStatus"
        }
        if ($MessageType -eq "PreDeployment" -or $MessageType -eq "PostDeployment") {
            
            if (!$Config) {
                if (!$CustomModuleName) {
                    Get-D365LBDConfig -ComputerName $ComputerName -CustomModuleName $CustomModuleName
                }
                else {
                    Get-D365LBDConfig -ComputerName $ComputerName 
                }
            }
            if ($CustomModuleName)
            {
               $Prepped = Export-D365LBDAssetModuleVersion -CustomModuleName $CustomModuleName -config $Config
               if ($Prepped)
               {
                   if ($Prepped.Count -eq 1)
                   {
                    Write-PSFMessage -Message "Found a prepped build: $Prepped" -Level VeryVerbose
                   }
                   else{
                   foreach ($build in $Prepped){
                       Write-PSFMessage -Message "Found multiple prepped builds including: $build" -Level VeryVerbose
                   }
                }
               }
            }
            $Config.CustomModuleVersioninAgentShare

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
        Write-PSFMessage -Message "Calling $MSTeamsURI with Post of $bodyjson " -Level VeryVerbose
        $WebRequestResults = Invoke-WebRequest -uri $MSTeamsURI -ContentType 'application/json' -Body $bodyjson -UseBasicParsing -Method Post -Verbose
        Write-PSFMessage -Message "$WebRequestResults" -Level VeryVerbose
        
    }
    END {
    }
}