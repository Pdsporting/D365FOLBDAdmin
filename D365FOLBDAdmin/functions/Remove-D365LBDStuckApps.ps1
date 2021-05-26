
function Remove-D365LBDStuckApps {
    ##created for deployment bug when it cant clean properly this was fixed in later local agent versions
    [alias("Remove-D365StuckApps")]
    param (
        [string]$SFServerCertificate,
        [string]$SFConnectionEndpoint,
        [string]$AgentShareLocation,
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME"
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

        Connect-ServiceFabricCluster -ConnectionEndpoint $config.SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate

        $environmentwp = get-childitem $(Join-path $config.AgentShareLocation -ChildPath "\wp")
        $archivefolder = $(Join-path $config.AgentShareLocation -ChildPath "\archive")
        if ((Test-Path $archivefolder) -eq $false) {
            Write-PSFMessage -Message "Creating archive folder" -Level Verbose
            mkdir $archivefolder
        }
        else {
            Write-PSFMessage -Message "Archive folder already exists" -Level Verbose
            Get-ChildItem $environmentwp.FullName -Recurse | Remove-Item -Force
        }
        
        Write-PSFMessage -Message "Deleting applications" -Level Verbose

        $applicationNamesToIgnore = @('fabric:/LocalAgent', 'fabric:/Agent-Monitoring', 'fabric:/Agent-LBDTelemetry')
        $applicationTypeNamesToIgnore = @('MonitoringAgentAppType-Agent', 'LocalAgentType', 'LBDTelemetryType-Agent')
 
        Get-ServiceFabricApplication | `
            Where-Object { $_.ApplicationName -notin $applicationNamesToIgnore } | `
            Remove-ServiceFabricApplication -Force
 
        Get-ServiceFabricApplicationType | `
            Where-Object { $_.ApplicationTypeName -notin $applicationTypeNamesToIgnore } | `
            Unregister-ServiceFabricApplicationType -Force

            Write-PSFMessage "Moving $($environmentwp.FullName) to $archivefolder " -Level VeryVerbose
        Move-Item -Path $environmentwp.FullName -Destination $archivefolder -Force -Verbose
    
        Write-PSFMessage -Level Verbose -Message "Trigger deployment/retry in LCS"
    }
    END {
    }
}