function Send-D365UpdateMSTeams {
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
        [string]$SQLQueryToRun
    )
    BEGIN {
    }
    PROCESS {
        if ($MSTeamsURI) {
            if ($PreDeployment) {
                $status = 'PreDeployment Started'
            }
            if ($PostDeployment) {
                $status = 'Deployment Finished. PostDeployment Started'
            }
            if ($MSTeamsCustomStatus) {
                $status = "$MSTeamsCustomStatus"
            }
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
    }
    END {
    }
}