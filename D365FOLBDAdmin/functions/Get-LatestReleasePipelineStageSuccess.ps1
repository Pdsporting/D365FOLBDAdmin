function Get-AzureDevOpsLastSuccessfulRelease { 
    <#
        .SYNOPSIS
        Grabs the latest success of a specific release definition and specific stage.
        .DESCRIPTION
        Grabs the latest success of a specific release definition and specific stage.
        .EXAMPLE
        Get-AzureDevOpsLastSuccessfulRelease -Instance 'FakeVisualStudioInstance' -Project 'VisualStudioProjectName' -User 'fakeuser@fakeemail.com' -PAT 'fakepat912830985' -ReleaseDefinition 'ReleasePipeline' -ReleaseStage "LCSUpload"
        .PARAMETER ParameterName
        Parameter details
        #> 
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            HelpMessage = 'Help Message?')]
        [Alias('Get-LastSuccessfulRelease')]
        [string]$Instance,
        [string]$Project,
        [string]$User,
        [string]$PAT,
        [string]$ReleaseDefinition, 
        [string]$ReleaseStage
    )

    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User, $PAT)))
    
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add('Authorization', ('Basic {0}' -f $base64AuthInfo))
    $headers.Add('Accept', 'application/json') 
    
    # Get array of project release types and get project (release def) id
    $releasedefinitionlistURL = "https://vsrm.dev.azure.com/$Instance/$Project/_apis/release/definitions?api-version=5.1"
    $results = Invoke-RestMethod -Headers $Headers -ContentType application/json -Uri $releasedefinitionlistURL -Method Get -UseBasicParsing

    $SpecificReleaseDefinition = $results.value | Where-Object { $_.name -eq $ReleaseDefinition }
    $ReleaseDefinitionId = $SpecificReleaseDefinition.id

    if (!$ReleaseDefinitionId) {
        Stop-PSFFunction -Message "Error: Cannot find release definition. Stopping" -EnableException $true -Cmdlet $PSCmdlet
    }
    
    $SpecificDefinitionIDSuccessAPI = "https://vsrm.dev.azure.com/$Instance/$Project/_apis/release/deployments?definitionid=$ReleaseDefinitionId&deploymentStatus=succeeded"
    $RPResults = Invoke-RestMethod -Method Get -Headers $Headers -ContentType application/json -Uri $SpecificDefinitionIDSuccessAPI -UseBasicParsing
    
    $ReleaseId = $RPResults.value.release.id | Sort-Object -Descending | Select-Object -First 1

    # Get release list
    $releaseapi = "https://vsrm.dev.azure.com/$Instance/$Project/_apis/release/releases/?api-version=5.1"
    $releaseapiResult = Invoke-RestMethod -Method Get -Headers $Headers -ContentType application/json -Uri $releaseapi -UseBasicParsing
    
    # Filter by release id and find build number
    $releaseapiFiltered = $releaseapiResult.value | Where-Object { $_.id -eq $ReleaseId }
    $TempArray = $releaseapiFiltered.description.Split(" ")
    $ReleaseName = $TempArray[$TempArray.Count - 1].TrimEnd(".")
    $url = "https://vsrm.dev.azure.com/$Instance/$Project/_apis/release/releases/$releaseID" + "?api-version=5.1"
    $Variables = (invoke-restmethod -method Get -uri $url -Headers $headers).variables
    $VariableNames = $Variables | Get-Member | Where-Object { $_.MemberType -eq "NoteProperty" -and $_.Name -ne "System.Debug" } | Select-Object Name

    $Properties = @{
        "ReleaseId"             = $ReleaseId
        "ReleaseName"           = $ReleaseName
        "ReleaseDefinitionName" = $ReleaseDefinition
    }
    $Output = New-Object PSObject -Property $Properties
    foreach ($VariableName in $VariableNames.Name) {
        
        $value = $Variables.$VariableName.value
        Write-PSFMessage -Level VeryVerbose -Message "Adding Variable $VariableName with a value of $value"
        Add-Member -Name $VariableName -Value $value -InputObject $Output -MemberType NoteProperty
    }


    return $Output
}