
function Remove-D365LBDSFInstalledFinancialReporting {
    <#
 ##created for deployment bug when the local agent can't clean up properly this was fixed in later local agent versions but still has value when but use only in extreme situations
 #>
    [alias("Remove-D365SFInstalledFinancialReporting")]
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
        if (!$Config -or $Config.OrchestratorServerNames.Count -eq 0) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName 
        }

        if (-not $($config.TenantID)) {
            $cachedconfigfile = Join-path $($config.AgentShareLocation) -ChildPath "scripts\config.xml" 
            $config = Get-D365LBDConfig -ConfigImportFromFile $cachedconfigfile
        }
        if ($SFServerCertificate) {
            Connect-ServiceFabricCluster -ConnectionEndpoint $SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $SFServerCertificate -ServerCertThumbprint $SFServerCertificate
        }
        else {
            [int]$count = 0
            Write-PSFMessage -Message "Trying to connect to service fabric to find primary and secondary orchestration servers" -Level VeryVerbose
            while (!$connection) {
                do {
                    $OrchestratorServerName = $Config.OrchestratorServerNames | Select-Object -First 1 -Skip $count
                    Write-PSFMessage -Message "Verbose: Reaching out to $OrchestratorServerName to try and connect to the service fabric" -Level Verbose
                    $SFModuleSession = New-PSSession -ComputerName $OrchestratorServerName
                    if (!$module) {
                        $module = Import-Module -Name ServiceFabric -PSSession $SFModuleSession 
                    }
                    $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $config.SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
                    if (!$connection) {
                        $trialEndpoint = "https://$OrchestratorServerName" + ":198000"
                        $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $trialEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
                    }
                    $count = $count + 1
                    if (!$connection) {
                        Write-PSFMessage -Message "Count of servers tried $count" -Level Verbose
                    }
                } until ($connection -or ($count -eq $($Config.OrchestratorServerName).Count) -or ($($Config.OrchestratorServerName).Count) -eq 0)
                if (($count -eq $($Config.OrchestratorServerNames).Count) -and (!$connection)) {
                    Write-PSFMessage -Level VeryVerbose -Message "Error: Can't connect to Service Fabric"
                }
            }
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
       
        Write-PSFMessage -Message "Deleting Financial Reporting applications inside of Service Fabric" -Level Verbose

        Get-ServiceFabricApplication |  Where-Object { $_.ApplicationName -eq "fabric:/FinancialReporting" } |  Remove-ServiceFabricApplication -Force
        Get-ServiceFabricApplicationType |  Where-Object { $_.ApplicationTypeName -eq "FinancialReportingType" } |      Unregister-ServiceFabricApplicationType -Force

     
       
    }
    END {
    }
}