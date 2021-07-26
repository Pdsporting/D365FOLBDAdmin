
function Remove-D365LBDStuckApps {
    ##created for deployment bug when it cant clean properly this was fixed in later local agent versions
    [alias("Remove-D365StuckApps")]
    [CmdletBinding()]
    param (
        [string]$SFServerCertificate,
        [string]$SFConnectionEndpoint,
        [string]$AgentShareLocation,
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ParameterSetName = 'Config',
            ValueFromPipeline = $True)]
        [psobject]$Config
    )
    BEGIN {
    }
    PROCESS {
        if (!$Config) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName 
        }

        if (-not $($config.TenantID)) {
            $cachedconfigfile = Join-path $($config.AgentShareLocation) -ChildPath "scripts\config.xml" 
            $config = Get-D365LBDConfig -ConfigImportFromFile $cachedconfigfile
        }
        if ($SFServerCertificate)
        {
            Connect-ServiceFabricCluster -ConnectionEndpoint $SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $SFServerCertificate -ServerCertThumbprint $SFServerCertificate
        }
        else{
            Connect-ServiceFabricCluster -ConnectionEndpoint $config.SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate
        }

        if ($AgentShareLocation) {
            $environmentwp = get-childitem $(Join-path $AgentShareLocation -ChildPath "\wp")
            $archivefolder = $(Join-path $AgentShareLocation -ChildPath "\archive")
        }
        else {
            $environmentwp = get-childitem $(Join-path $config.AgentShareLocation -ChildPath "\wp")
            $archivefolder = $(Join-path $config.AgentShareLocation -ChildPath "\archive")
        }
        
        if ((Test-Path $archivefolder) -eq $false) {
            Write-PSFMessage -Message "Creating archive folder" -Level Verbose
            mkdir $archivefolder
        }
        else {
            Write-PSFMessage -Message "Archive folder already exists" -Level Verbose
            if (!$environmentwp) {
                Write-PSFMessage -Level VeryVerbose -Message "WP Folder already cleaned up"
            }
        }
        
        Write-PSFMessage -Message "Deleting applications inside of Service Fabric" -Level Verbose

        $applicationNamesToIgnore = @('fabric:/LocalAgent', 'fabric:/Agent-Monitoring', 'fabric:/Agent-LBDTelemetry')
        $applicationTypeNamesToIgnore = @('MonitoringAgentAppType-Agent', 'LocalAgentType', 'LBDTelemetryType-Agent')
 
        Get-ServiceFabricApplication | `
            Where-Object { $_.ApplicationName -notin $applicationNamesToIgnore } | `
            Remove-ServiceFabricApplication -Force
 
        Get-ServiceFabricApplicationType | `
            Where-Object { $_.ApplicationTypeName -notin $applicationTypeNamesToIgnore } | `
            Unregister-ServiceFabricApplicationType -Force

        if (!$environmentwp) {
        }
        else {
            Write-PSFMessage "Moving $($environmentwp.FullName) to $archivefolder " -Level VeryVerbose
            Move-Item -Path $environmentwp.FullName -Destination $archivefolder -Force -Verbose
        }
    
        Write-PSFMessage -Level Verbose -Message "Trigger deployment/retry in LCS"
    }
    END {
    }
}