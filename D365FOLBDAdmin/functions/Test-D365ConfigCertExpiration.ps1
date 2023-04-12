function Test-D365ConfigCertExpiration {
    <#
   .SYNOPSIS
   Scans config for any expired or expiring (based on parameter)
  .DESCRIPTION
    Scans config for any expired or expiring (based on parameter) and alerts MSTeams or email
  .EXAMPLE
    Test-D365ConfigCertExpiration -config $config -MSTeamsURI 'https://fakeurl.webhook.office.com/wehbook/1kl23j1lk2j312lk3j21lk3j12lk3' -DaysConsideredExpired 14
  .EXAMPLE
    Test-D365ConfigCertExpiration -config $config -To "FakeEmail@fakedomain.com" -from "FakeSender@fakedomain.com" -smtp 'fakesmtp.smtp.com'  -DaysConsideredExpired 7
  #>
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [string[]]$To,
        [string]$SMTP,
        [string]$From,
        [string]$MSTeamsURI,
        [Parameter(ValueFromPipeline = $True)]
        [psobject]$Config,
        [System.Management.Automation.PSCredential]$Credential,
        [int]$DaysConsideredExpired = 0
    )
    BEGIN {
    }
    PROCESS {
        if (!$Config -or $Config.OrchestratorServerNames.Count -eq 0) {
            Write-PSFMessage -Level VeryVerbose -Message "Config not defined or Config is invalid. Trying to Get new config using $ComputerName"
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly
        }
        $ArrayOfExpiredCerts = @()
        $CertsToCheck = $Config | Get-Member | Where-Object { $_ -like "*Expires*" }
        $CurrDate = Get-Date
        $CurrDate = $CurrDate.AddDays($DaysConsideredExpired)
        $AlertExpiringOlderBefore = $CurrDate 
        foreach ($Name in $CertsToCheck.Name) {
            if (!$Config.$Name) {
                Write-PSFMessage -Level Warning -Message "$Name is missing in the config"
            }
            else {
                if ($Config.$Name -lt $CurrDate) {
                    $CertName = $Name -replace 'ExpiresAfter', ''
                    $Thumbprint = $Config.$CertName
                    $FoundExpired = "Yes"
                    Write-PSFMessage -Level Important -Message "Cert $CertName is expired/expiring for config $($Config.LCSEnvironmentName) expiration at $($Config.$Name). Thumbprint $Thumbprint"
                    $HashTableofSpecificCert = [PSCustomObject]@{
                        Thumbprint = $Thumbprint
                        CertName = $CertName
                        ExpirationDate = $Config.Name
                    }
                    $ArrayOfExpiredCerts=  $ArrayOfExpiredCerts + $HashTableofSpecificCert
                    if ($MSTeamsURI) {
                        Send-D365LBDUpdateMSTeams -messageType "PlainText" -MSTeamsURI $MSTeamsURI -PlainTextTitle "$CertName expiring/expired" -PlainTextMessage "$Thumbprint" -MSTeamsExtraDetails "$($Config.$name)" -MSTeamsExtraDetailsURI "$($Config.ClientURL)" -MSTeamsExtraDetailsTitle "Leniency Days $DaysConsideredExpired "
                    }
                }
            }
        }
        if (!$FoundExpired) {
            Write-PSFMessage -Level VeryVerbose -Message "Config does not contain any invalid certificates"
        }
        else{
            if ($To) {
                if ($ArrayOfExpiredCerts.Count -gt 0){
                    Write-PSFMessage -Level VeryVerbose -Message "Attemping to Send email"
                    $body = "List of Certs Expiring before $AlertExpiringOlderBefore : <br /> <ul>"
                    foreach ($ExpiredCert in $ArrayOfExpiredCerts){
                        $body += "<li> $($ExpiredCert.CertName) - $($ExpiredCert.Thumbprint) - Expiration:  $($ExpiredCert.ExpirationDate) </li>"
                    }
                    $body += "</ul>"
                }

                if ($Credential) {
                    Send-MailMessage -SmtpServer $SMTP -To $To -Body "<a href'$($config.ClientURL)'>$($config.LCSEnvironmentName)</a> has an expired/expiring certificate (Days Considered Expired/Expiring $DaysConsideredExpired). <br /> $Body" -From $From -Subject "D365 $($config.LCSEnvironmentName) Cert Expired/Expiring" -BodyAsHtml -Credential $Credential
                }
                else {
                    Send-MailMessage -SmtpServer $SMTP -To $To -Body "<a href'$($config.ClientURL)'>$($config.LCSEnvironmentName)</a> has an expired/expiring certificate (Days Considered Expired/Expiring $DaysConsideredExpired). <br /> $Body" -From $From -Subject "D365 $($config.LCSEnvironmentName) Cert Expired/Expiring" -BodyAsHtml
                }
            }
        }
    }
    END {
    }
}