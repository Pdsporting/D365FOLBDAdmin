function Get-D365LBDConfig {
    <#
    .SYNOPSIS
   Grabs the configuration of the local business data environment
   .DESCRIPTION
   Grabs the configuration of the local business data environment through logic using the Service Fabric Cluster XML,
   AXSF.Package.Current.xml and OrchestrationServicePkg.Package.Current.xml
   .EXAMPLE
   Get-D365LBDConfig
   Will get config from the local machine.
   .EXAMPLE
    Get-D365LBDConfig -ComputerName "LBDServerName" -verbose
   Will get the Dynamics 365 Config from the LBD server
   .PARAMETER ComputerName
   optional string 
   The name of the Local Business Data Computer.
   If ignored will use local host.
   .PARAMETER ConfigImportFromFile
   optional string 
   The name of the config file to import (if you are choosing to import rather than pull dynamically)
   .PARAMETER ConfigExportToFile
   optional string 
   The name of the config file to export 
   .PARAMETER CustomModuleName
   optional string 
   The name of the custom module you will be using to caputre the version number
   .PARAMETER HighLevelOnly
   optional switch
   for quicker runs grab the config without verifying or grabbing additional details from the service fabric cluster

   #>
    [alias("Get-D365Config")]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(Mandatory = $false)][string]$ConfigImportFromFile,
        [Parameter(Mandatory = $false)][string]$ConfigExportToFile,
        [Parameter(Mandatory = $false)][string]$CustomModuleName,
        [switch]$HighLevelOnly
    )
    ##Gather Information from the Dynamics 365 Orchestrator Server Config
    BEGIN {
    } 
    PROCESS {
        Set-Location C:\
        if ($ConfigImportFromFile) {
            Write-PSFMessage -Message "Warning: Importing config this data may not be the most up to date" -Level Warning
            if (-not (Test-Path $ConfigImportFromFile)) {
                Stop-PSFFunction -Message "Error: This config file doesn't exist. Stopping" -EnableException $true -Cmdlet $PSCmdlet
            }
            $Properties = Import-clixml -path $ConfigImportFromFile
            [PSCustomObject]$Properties
        }
        else {
            if ($ComputerName.IsLocalhost) {
                Write-PSFMessage -Message "Looking for the clusterconfig (Cluster Manifest) on the localmachine as no ComputerName provided" -Level Warning 
                if ($(Test-Path "C:\ProgramData\SF\clusterManifest.xml") -eq $False) {
                    Stop-PSFFunction -Message "Error: This is not an Local Business Data server or no config is found (import config if you have to). Stopping" -EnableException $true -Cmdlet $PSCmdlet
                }
                $ClusterManifestXMLFile = get-childitem "C:\ProgramData\SF\clusterManifest.xml" 
            }
            else {
                Write-PSFMessage -Message "Connecting to admin share on $ComputerName for cluster config" -Level Verbose
                if ($(Test-Path "\\$ComputerName\C$\ProgramData\SF\clusterManifest.xml") -eq $False) {
                    Stop-PSFFunction -Message "Error: This is not an Local Business Data server. Can't find Cluster Manifest. Stopping" -EnableException $true -Cmdlet $PSCmdlet
                }
                $ClusterManifestXMLFile = get-childitem "\\$ComputerName\C$\ProgramData\SF\clusterManifest.xml"
            }
            if (!($ClusterManifestXMLFile)) {
                Stop-PSFFunction -Message "Error: This is not an Local Business Data server or the application is not installed. Can't find Cluster Manifest. Stopping" -EnableException $true -Cmdlet $PSCmdlet
            }
            if ($(test-path $ClusterManifestXMLFile) -eq $false) {
                Stop-PSFFunction -Message "Error: This is not an Local Business Data server. Can't find Cluster Manifest. Stopping" -EnableException $true -Cmdlet $PSCmdlet
            }
            Write-PSFMessage -Message "Reading $ClusterManifestXMLFile" -Level Verbose
            [xml]$xml = get-content $ClusterManifestXMLFile

            $OrchestratorServerNames = $($xml.ClusterManifest.Infrastructure.WindowsServer.NodeList.Node | Where-Object { $_.NodeTypeRef -contains 'OrchestratorType' }).NodeName
            $AXSFServerNames = $($xml.ClusterManifest.Infrastructure.WindowsServer.NodeList.Node | Where-Object { $_.NodeTypeRef -contains 'AOSNodeType' }).NodeName
            $ReportServerServerName = $($xml.ClusterManifest.Infrastructure.WindowsServer.NodeList.Node | Where-Object { $_.NodeTypeRef -contains 'ReportServerType' }).NodeName 
            $ReportServerServerip = $($xml.ClusterManifest.Infrastructure.WindowsServer.NodeList.Node | Where-Object { $_.NodeTypeRef -contains 'ReportServerType' }).IPAddressOrFQDN

            if (($null -eq $OrchestratorServerNames) -or (!$OrchestratorServerNames)) {
                $OrchestratorServerNames = $($xml.ClusterManifest.Infrastructure.WindowsServer.NodeList.Node | Where-Object { $_.NodeTypeRef -contains 'PrimaryNodeType' }).NodeName
                $AXSFServerNames = $($xml.ClusterManifest.Infrastructure.WindowsServer.NodeList.Node | Where-Object { $_.NodeTypeRef -contains 'PrimaryNodeType' }).NodeName
                $ReportServerServerName = $($xml.ClusterManifest.Infrastructure.WindowsServer.NodeList.Node | Where-Object { $_.NodeTypeRef -contains 'ReportServerType' }).NodeName 
                $ReportServerServerip = $($xml.ClusterManifest.Infrastructure.WindowsServer.NodeList.Node | Where-Object { $_.NodeTypeRef -contains 'ReportServerType' }).IPAddressOrFQDN
            }
            foreach ($OrchestratorServerName in $OrchestratorServerNames) {
                if (!$OrchServiceLocalAgentConfigXML) {
                    Write-PSFMessage -Message "Verbose: Connecting to $OrchestratorServerName for Orchestrator config" -Level Verbose
                    $OrchServiceLocalAgentConfigXML = get-childitem "\\$OrchestratorServerName\C$\ProgramData\SF\*\Fabric\work\Applications\LocalAgentType_App*\OrchestrationServicePkg.Package.Current.xml"
                }
                if (!$OrchServiceLocalAgentVersionNumber) {
                    Write-PSFMessage -Message "Verbose: Connecting to $OrchestratorServerName for Orchestrator Local Agent version" -Level Verbose
                    $OrchServiceLocalAgentVersionNumber = $(get-childitem "\\$OrchestratorServerName\C$\ProgramData\SF\*\Fabric\work\Applications\LocalAgentType_App*\OrchestrationServicePkg.Code.*\OrchestrationService.exe").VersionInfo.Fileversion
                }
                If (!$SFVersionNumber) {
                    try {
                        $SFVersionNumber = Invoke-Command -ScriptBlock { Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Service Fabric\' -Name FabricVersion } -ComputerName $OrchestratorServerName
                    }
                    Catch {
                        Write-PSFMessage -Message  "Warning: Can't get Service Fabric Version" -Level Warning
                    }
                }
            }
            if (!$OrchServiceLocalAgentConfigXML) {
                Stop-PSFFunction -Message "Error: Can't find any Local Agent file on the Orchestrator Node" -EnableException $true -Cmdlet $PSCmdlet
            }
            Write-PSFMessage -Message "Reading $OrchServiceLocalAgentConfigXML" -Level Verbose
            [xml]$xml = get-content $OrchServiceLocalAgentConfigXML

            $RetrievedXMLData = $xml.ServicePackage.DigestedConfigPackage.ConfigOverride.Settings.Section | Where-Object { $_.Name -eq 'AAD' } 
            $LocalAgentCertificate = ($RetrievedXMLData.Parameter | Where-Object { $_.Name -eq "ServicePrincipalThumbprint" }).value

            $RetrievedXMLData = $xml.ServicePackage.DigestedConfigPackage.ConfigOverride.Settings.Section | Where-Object { $_.Name -eq 'Data' } 
            $OrchDBConnectionString = $RetrievedXMLData.Parameter
    
            $RetrievedXMLData = $xml.ServicePackage.DigestedConfigPackage.ConfigOverride.Settings.Section | Where-Object { $_.Name -eq 'Download' } 
            $downloadfolderLocation = $RetrievedXMLData.Parameter
    
            $RetrievedXMLData = $xml.ServicePackage.DigestedConfigPackage.ConfigOverride.Settings.Section | Where-Object { $_.Name -eq 'ServiceFabric' } 
            $ServiceFabricConnectionDetails = $RetrievedXMLData.Parameter

            $ClientCert = $($ServiceFabricConnectionDetails | Where-Object { $_.Name -eq "ClientCertificate" }).value
            $ClusterID = $($ServiceFabricConnectionDetails | Where-Object { $_.Name -eq "ClusterID" }).value
            $ConnectionEndpoint = $($ServiceFabricConnectionDetails | Where-Object { $_.Name -eq "ConnectionEndpoint" }).value
            $ServerCertificate = $($ServiceFabricConnectionDetails | Where-Object { $_.Name -eq "ServerCertificate" }).value
    
            ## With Orch Server config get more details for automation
            [int]$count = 1
            $AXSFConfigServerName = $AXSFServerNames | Select-Object -First $count
            Write-PSFMessage -Message "Verbose: Reaching out to $AXSFConfigServerName for AX config" -Level Verbose
            
            $SFConfig = get-childitem "\\$AXSFConfigServerName\C$\ProgramData\SF\*\Fabric\work\Applications\AXSFType_App*\AXSF.Package.Current.xml"
            if (!$SFConfig) {
                $SFConfig = get-childitem "\\$AXSFConfigServerName\C$\ProgramData\SF\*\Fabric\work\Applications\AXSFType_App*\AXSF.Package.1.0.xml"
            }
            if (!$SFConfig) {
                do {
                    $AXSFConfigServerName = $AXSFServerNames | Select-Object -First 1 -Skip $count
                    Write-PSFMessage -Message "Verbose: Reaching out to $AXSFConfigServerName for AX config total servers $($AXSFServerNames.Count))" -Level Verbose
                    $SFConfig = get-childitem  "\\$AXSFConfigServerName\C$\ProgramData\SF\*\Fabric\work\Applications\AXSFType_App*\AXSF.Package.Current.xml"
                    if (!$SFConfig) {
                        $SFConfig = get-childitem "\\$AXSFConfigServerName\C$\ProgramData\SF\*\Fabric\work\Applications\AXSFType_App*\AXSF.Package.1.0.xml"
                    }
                    $count = $count + 1
                    Write-PSFMessage -Message "Count of servers tried $count" -Verbose
                } until ($SFConfig -or ($count -eq $AXSFServerNames.Count))
            } 
            
            if (!$SFConfig) {
                Write-PSFMessage -Message "Verbose: Can't find AX SF. App may not be installed. All values won't be grabbed" -Level Warning
            }
            else {
                [xml]$xml = get-content $SFConfig 

                $DataAccess = $xml.ServicePackage.DigestedConfigPackage.ConfigOverride.Settings.Section | Where-Object { $_.Name -EQ 'DataAccess' }
                $AXDatabaseName = $($DataAccess.Parameter | Where-Object { $_.Name -eq 'Database' }).value
                $AXDatabaseServer = $($DataAccess.Parameter | Where-Object { $_.Name -eq 'DbServer' }).value
                $DataEncryptionCertificate = $($DataAccess.Parameter | Where-Object { $_.Name -eq 'DataEncryptionCertificateThumbprint' }).value
                $DataSigningCertificate = $($DataAccess.Parameter | Where-Object { $_.Name -eq 'DataSigningCertificateThumbprint' }).value

                $AAD = $xml.ServicePackage.DigestedConfigPackage.ConfigOverride.Settings.Section | Where-Object { $_.Name -EQ 'Aad' }
                $ClientURL = $($AAD.Parameter | Where-Object { $_.Name -eq 'AADValidAudience' }).value + "namespaces/AXSF/"

                $Infrastructure = $xml.ServicePackage.DigestedConfigPackage.ConfigOverride.Settings.Section | Where-Object { $_.Name -EQ 'Infrastructure' }
                $SessionAuthenticationCertificate = $($Infrastructure.Parameter | Where-Object { $_.Name -eq 'SessionAuthenticationCertificateThumbprint' }).value

                $SMBStorage = $xml.ServicePackage.DigestedConfigPackage.ConfigOverride.Settings.Section | Where-Object { $_.Name -EQ 'SmbStorage' }
                $SharedAccessSMBCertificate = $($SMBStorage.Parameter | Where-Object { $_.Name -eq 'SharedAccessThumbprint' }).value
       
                $sb = New-Object System.Data.Common.DbConnectionStringBuilder
                $sb.set_ConnectionString($($OrchDBConnectionString.Value))
                $OrchDatabase = $sb.'initial catalog'
                $OrchdatabaseServer = $sb.'data source'
            }

            $AgentShareLocation = $downloadfolderLocation.Value
            $AgentShareWPConfigJson = Get-ChildItem "$AgentShareLocation\wp\*\StandaloneSetup-*\config.json" | Sort-Object { $_.CreationTime } | Select-Object -First 1

            if ($AgentShareWPConfigJson) {
                Write-PSFMessage -Message "Verbose: Using AgentShare config at $AgentShareWPConfigJson to get Environment ID, EnvironmentName and TenantID." -Level Verbose
                $jsonconfig = get-content $AgentShareWPConfigJson
                $LCSEnvironmentId = $($jsonconfig | ConvertFrom-Json).environmentid
                $TenantID = $($jsonconfig | ConvertFrom-Json).tenantid
                $LCSEnvironmentName = $($jsonconfig | ConvertFrom-Json).environmentName
            }
            else {
                Write-PSFMessage -Message "Warning: Can't Find Config in WP folder can't get Environment ID or TenantID. All values won't be grabbed" -Level Warning
                $LCSEnvironmentId = ""
                $TenantID = ""
                $LCSEnvironmentName = ""
            }
            try {
                $reportconfig = Get-ChildItem "\\$ReportServerServerName\C$\ProgramData\SF\*\Fabric\work\Applications\ReportingService_*\ReportingBootstrapperPkg.Package.current.xml"
                [xml]$xml = Get-Content $reportconfig.FullName
                $Reportingconfigdetails = $xml.ServicePackage.DigestedConfigPackage.ConfigOverride.Settings.Section | Where-Object { $_.Name -EQ 'ReportingServices' }
                $ReportingSSRSCertificate = ($Reportingconfigdetails.parameter | Where-Object { $_.Name -eq "ReportingClientCertificateThumbprint" }).value
            }
            catch {
                try {
                    $reportconfig = Get-ChildItem "\\$ReportServerServerName\C$\ProgramData\SF\*\Fabric\work\Applications\ReportingService_*\ReportingBootstrapperPkg.Package.1.0.xml"
                    [xml]$xml = Get-Content $reportconfig.FullName
                    $Reportingconfigdetails = $xml.ServicePackage.DigestedConfigPackage.ConfigOverride.Settings.Section | Where-Object { $_.Name -EQ 'ReportingServices' }
                    $ReportingSSRSCertificate = ($Reportingconfigdetails.parameter | Where-Object { $_.Name -eq "ReportingClientCertificateThumbprint" }).value
                }
                catch {
                    Write-PSFMessage -Level Warning -Message "Warning: Can't gather information from the Reporting Server $ReportServerServerName"
                }
            }
            $CustomModuleVersion = ''
            if (($CustomModuleName)) {
                try {
                    $CustomModuleDll = get-childitem "\\$AXSFConfigServerName\C$\ProgramData\SF\*\Fabric\work\Applications\AXSFType_App*\AXSF.Code*\Packages\$CustomModuleName\bin\Dynamics.AX.$CustomModuleName.dll"
                    if (-not (Test-Path $CustomModuleDll)) {
                        Write-PSFMessage -Message "Warning: Custom Module not found; version unable to be found" -Level Warning
                    }
                    else {
                        $CustomModuleVersion = $CustomModuleDll.VersionInfo.FileVersion
                    }
                }
                catch {}
            }
            $AXServiceConfigXMLFile = get-childitem "\\$AXSFConfigServerName\C$\ProgramData\SF\*\Fabric\work\Applications\AXSFType_App*\AXSF.Code*\AXService.exe.config" | Sort-Object { $_.CreationTime } | Select-Object -First 1
            Write-PSFMessage -Message "Reading $AXServiceConfigXMLFile" -Level Verbose 
            if (!$AXServiceConfigXMLFile) {
                Write-PSFMessage -Message "Warning: AXSF doesnt seem installed; config cannot be found" -Level Warning
            }
            else {
                [xml]$AXServiceConfigXML = get-content $AXServiceConfigXMLFile
            }
            $AOSKerneldll = get-childitem "\\$AXSFConfigServerName\C$\ProgramData\SF\*\Fabric\work\Applications\AXSFType_App*\AXSF.Code*\bin\AOSKernel.dll"
            $AOSKernelVersion = $AOSKerneldll.VersionInfo.ProductVersion

            $jsonClusterConfig = get-content "\\$AXSFConfigServerName\C$\ProgramData\SF\clusterconfig.json"
            $SFClusterCertificate = ($jsonClusterConfig | ConvertFrom-Json).properties.security.certificateinformation.clustercertificate.Thumbprint
            $FinancialReportingCertificate = $($AXServiceConfigXML.configuration.claimIssuerRestrictions.issuerrestrictions.add | Where-Object { $_.alloweduserids -eq "FRServiceUser" }).name

            if (test-path $AgentShareLocation\scripts\D365FOLBDAdmin\AdditionalEnvironmentDetails.xml) {
                Write-PSFMessage -Level Verbose -Message "Found AdditionalEnvironmentDetails config"
                $EnvironmentAdditionalConfig = get-childitem  "$AgentShareLocation\scripts\D365FOLBDAdmin\AdditionalEnvironmentDetails.xml"
            }
            else {
                Write-PSFMessage -Message "Warning: Can't find additional Environment Config. Not needed but recommend making one" -level warning  
            }

            if ($EnvironmentAdditionalConfig) {
                Write-PSFMessage -Message "Reading  $EnvironmentAdditionalConfig " -Level Verbose
                [xml]$EnvironmentAdditionalConfigXML = get-content  $EnvironmentAdditionalConfig
                $EnvironmentType = $EnvironmentAdditionalConfigXML.D365LBDEnvironment.EnvironmentType.'#text'.Trim()
                $DatabaseClusterServerNames = $EnvironmentAdditionalConfigXML.D365LBDEnvironment.EnvironmentAdditionalConfig.SQLDetails.SQLServer | ForEach-Object -Process { New-Object -TypeName psobject -Property `
                    @{'DatabaseClusterServerNames' = $_.ServerName } }
                $DatabaseEncryptionThumbprints = $EnvironmentAdditionalConfigXML.D365LBDEnvironment.EnvironmentAdditionalConfig.SQLDetails.SQLServer | ForEach-Object -Process { New-Object -TypeName psobject -Property `
                    @{'DatabaseEncryptionCertificates' = $_.DatabaseEncryptionThumbprint } }
                $DatabaseEncryptionThumbprints = $DatabaseEncryptionThumbprints.DatabaseEncryptionThumprints
                $DatabaseClusterServerNames = $DatabaseClusterServerNames.DatabaseClusterServerNames

            }
           
            if ((test-path \\$ComputerName\c$\ProgramData\SF\DataEnciphermentCert.txt) -and !$EnvironmentAdditionalConfig) {
                Write-PSFMessage -Level Verbose -Message "Found DataEncipherment config"
                $DataEnciphermentCertificate = Get-Content \\$ComputerName\c$\ProgramData\SF\DataEnciphermentCert.txt
            }
            else {
                Write-PSFMessage -Level Warning -Message "Warning: No Encipherment Cert found run the function use Add-D365LBDDataEnciphermentCertConfig to add"
            }

            if ((test-path \\$ComputerName\c$\ProgramData\SF\DatabaseDetailsandCert.txt) -and !$EnvironmentAdditionalConfig) {
                $DatabaseDetailsandCertConfig = Get-Content \\$ComputerName\c$\ProgramData\SF\DatabaseDetailsandCert.txt
                Write-PSFMessage -Level Verbose -Message "Found DatabaseDetailsandCert config additional details added to config data"
                $DatabaseEncryptionCertificate = $DatabaseDetailsandCertConfig[1]
                $DatabaseClusteredStatus = $DatabaseDetailsandCertConfig[0]
                $DatabaseClusterServerNames = $DatabaseDetailsandCertConfig[2]
            }
            else {
                Write-PSFMessage -Level Warning -Message "Warning: No additional Database config Details found use Add-D365LBDDatabaseDetailsandCert to add"
            }
            ##checking for after deployment added servers
            try {
                $currentclustermanifestxmlfile = get-childitem "\\$AXSFConfigServerName\C$\ProgramData\SF\*\Fabric\clustermanifest.current.xml" | Sort-Object { $_.CreationTime } | Select-Object -First 1
                [xml]$currentclustermanifestxml = Get-Content $currentclustermanifestxmlfile
                $AXSFServerListToCompare = $currentclustermanifestxml.clusterManifest.Infrastructure.NodeList.Node | Where-Object { $_.NodeTypeRef -eq 'AOSNodeType' -or $_.NodeTypeRef -eq 'PrimaryNodeType' }
                foreach ($Node in $AXSFServerListToCompare) {
                    if (($AXSFServerNames -contains $Node) -eq $false) {
                        $AXSFServerNames += $Node
                    }
                }
            }
            catch {
                Write-PSFMessage -Level Warning -Message "Warning: $_"
            }
            if ($HighLevelOnly) {
                Write-PSFMessage -Level Verbose -Message "High Level Only will not connect to service fabric"
            }
            else {
                try {
                    Write-PSFMessage -Message "Trying to connect to $ConnectionEndpoint using $ServerCertificate" -Level Verbose
                    $SFModuleSession = New-PSSession -ComputerName $OrchestratorServerName
                    $module = Import-Module -Name ServiceFabric -PSSession $SFModuleSession 
                    $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $ConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $ServerCertificate -ServerCertThumbprint $ServerCertificate -StoreLocation LocalMachine -StoreName My
                    $nodes = get-servicefabricnode | Where-Object { ($_.NodeType -eq "AOSNodeType") -or ($_.NodeType -eq "PrimaryNodeType") } 
                    Write-PSFMessage -message "Service Fabric connected. Grabbing nodes to validate status" -Level Verbose
                    $appservers = $nodes.NodeName | Sort-Object
                    $invalidsfnodes = get-servicefabricnode | Where-Object { ($_.NodeStatus -eq "Invalid") } 
                    $disabledsfnodes = get-servicefabricnode | Where-Object { ($_.NodeStatus -eq "Disabled") } 
                    $invalidnodes = $invalidsfnodes.NodeName | Sort-Object
                    $disablednodes = $disabledsfnodes.NodeName | Sort-Object
                    $invalidnodescount = $invalidnodes.count
                    if (!$invalidnodes -and $invalidnodescount -ne 0 ) {
                        Write-PSFMessage -Level Warning -Message "Warning: Invalid Node found. Suggest running Update-ServiceFabricD365ClusterConfig to help fix. $invalidnodes"
                    }
                }
                catch {
                    Write-PSFMessage -message "Can't connect to Service Fabric $_" -Level Verbose
                }
                $AXSFServersViaServiceFabricNodes = @()
                foreach ($NodeName in $appservers) {
                    $AXSFServersViaServiceFabricNodes += $NodeName  
                }
            
                $NewlyAddedAXSFServers = @()
                foreach ($Node in $AXSFServersViaServiceFabricNodes) {
                    if (($AXSFServerNames -contains $Node) -eq $false) {
                        Write-PSFMessage -Level Verbose -Message "Adding $Node to AXSFServerList "
                        $AXSFServerNames += $Node
                        $NewlyAddedAXSFServers += $Node
                    }
                }

                [System.Collections.ArrayList]$AXSFActiveNodeList = $AXSFServerNames
                [System.Collections.ArrayList]$AXOrchActiveNodeList = $OrchestratorServerNames
                foreach ($Node in $invalidnodes) {
                    if (($AXSFServerNames -contains $Node) -eq $true) {
                        foreach ($AXSFNode in $AXSFServerNames) {
                            Write-PSFMessage -Level Verbose -Message "Found the Invalid SF Node $Node in AXSFServerList. Removing from list. Use Update-ServiceFabricD365ClusterConfig to get a headstart on fixing. "
                            $AXSFActiveNodeList.Remove($node)
                        }
                    }
                    if (($OrchestratorServerNames -contains $Node) -eq $true) {
                        foreach ($AXSFNode in $OrchestratorServerNames) {
                            Write-PSFMessage -Level Verbose -Message "Found the Invalid Orchestrator Node $Node in OrchestratorServerNames. Removing from OrchestratorServerNames list"
                            $AXOrchActiveNodeList.Remove($node)
                        }
                    }
                }
                $AXSFServerNames = $AXSFActiveNodeList
                $OrchestratorServerNames = $AXOrchActiveNodeList
            }
            $AllAppServerList = @()
            foreach ($ComputerName in $AXSFServerNames) {
                if (($AllAppServerList -contains $ComputerName) -eq $false) {
                    $AllAppServerList += $ComputerName
                }
            }
            foreach ($ComputerName in $ReportServerServerName) {
                if (($AllAppServerList -contains $ComputerName) -eq $false) {
                    $AllAppServerList += $ComputerName
                }
            }
            foreach ($ComputerName in $OrchestratorServerNames) {
                if (($AllAppServerList -contains $ComputerName) -eq $false) {
                    $AllAppServerList += $ComputerName
                }
            }
            ##
            <# Source: https://stackoverflow.com/questions/8423541/how-do-you-run-a-sql-server-query-from-powershell
#>
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
            try {
                if ($CustomModuleName) {
                    $path = Get-ChildItem "$agentsharelocation\wp\*\StandaloneSetup-*\Apps\AOS\AXServiceApp\AXSF\InstallationRecords\MetadataModelInstallationRecords" | Select-Object -first 1 -ExpandProperty FullName
                    $pathtoxml = "$path\$CustomModuleName.xml"
                    if ($path) {
                        [xml]$xml = Get-Content $pathtoxml
                        $CustomModuleVersioninAgentShare = $xml.MetadataModelInstallationInfo.Version
                    }
                    else {
                        Write-PSFMessage -Level Warning -Message "Can't find $path\$CustomModuleName.xml to get Version in Agent Share "
                    }
                }
            }
            catch {}
            if (!$AXDatabaseName) {
                $AXDatabaseName = "AXDB"
            }
            $SQLQueryToGetRefreshinfo = " Select top 1 [rh].[destination_database_name], [sd].[create_date], [bs].[backup_start_date], [rh].[restore_date], [bmf].[physical_device_name] as 'backup_file_used_for_restore' 
from msdb..restorehistory rh 
inner join msdb..backupset bs on [rh].[backup_set_id] = [bs].[backup_set_id] 
inner join msdb..backupmediafamily bmf on [bs].[media_set_id] = [bmf].[media_set_id]
inner join sys.databases sd on [sd].[name] = [rh].[destination_database_name]
where [rh].[destination_database_name] = '$AXDatabaseName'
ORDER BY [rh].[restore_date] DESC"

            try {
                $SqlresultsToGetRefreshinfo = invoke-sql -datasource $AXDatabaseServer -database $AXDatabaseName -sqlcommand $SQLQueryToGetRefreshinfo
            }
            catch {}
            if ($SqlresultsToGetRefreshinfo.Count -eq 0) {
                $whoami = whoami
                Write-PSFMessage -Level VeryVerbose -Message "Can't find SQL results with query. Check if database is up and permissions are set for $whoami. Server: $AXDatabaseServer - DatabaseName: $AXDatabaseName."
            }
            else {
                $AXDatabaseRestoreDateSQL = $SqlresultsToGetRefreshinfo | Select-Object restore_date
                [string]$AXDatabaseRestoreDate = $AXDatabaseRestoreDateSQL
                $AXDatabaseRestoreDate = $AXDatabaseRestoreDate.Trim("@{restore_date=")
                $AXDatabaseRestoreDate = $AXDatabaseRestoreDate.Substring(0, $AXDatabaseRestoreDate.Length - 1)

                $AXDatabaseCreationDateSQL = $SqlresultsToGetRefreshinfo | Select-Object create_date
                [string]$AXDatabaseCreationDate = $AXDatabaseCreationDateSQL
                $AXDatabaseCreationDate = $AXDatabaseCreationDate.Trim("@{create_date=")
                $AXDatabaseCreationDate = $AXDatabaseCreationDate.Substring(0, $AXDatabaseCreationDate.Length - 1)

                $AXDatabaseBackupStartDateSQL = $SqlresultsToGetRefreshinfo | Select-Object backup_start_date
                [string]$AXDatabaseBackupStartDate = $AXDatabaseBackupStartDateSQL 
                $AXDatabaseBackupStartDate = $AXDatabaseBackupStartDate.Trim("@{backup_start_date=")
                $AXDatabaseBackupStartDate = $AXDatabaseBackupStartDate.Substring(0, $AXDatabaseBackupStartDate.Length - 1)

                $AXDatabaseBackupFileUsedForRestoreSQL = $SqlresultsToGetRefreshinfo | Select-Object backup_file_used_for_restore
                [string]$AXDatabaseBackupFileUsedForRestore = $AXDatabaseBackupFileUsedForRestoreSQL
                $AXDatabaseBackupFileUsedForRestore = $AXDatabaseBackupFileUsedForRestore.Trim("@{backup_file_used_for_restore=")
                $AXDatabaseBackupFileUsedForRestore = $AXDatabaseBackupFileUsedForRestore.Substring(0, $AXDatabaseBackupFileUsedForRestore.Length - 1)

                $SQLQueryToGetConfigMode = "select * from SQLSYSTEMVARIABLES Where PARM = 'CONFIGURATIONMODE'"
                try {
                    $SqlresultsToGetConfigMode = invoke-sql -datasource $AXDatabaseServer -database $AXDatabaseName -sqlcommand $SQLQueryToGetConfigMode
                }
                catch {}
                $ConfigurationModeSQL = $SqlresultsToGetConfigMode | Select-Object value
                [string]$ConfigurationModeString = $ConfigurationModeSQL
                $ConfigurationModeString = $ConfigurationModeString.Trim("@{value=")
                $ConfigurationModeString = $ConfigurationModeString.Trim("VALUE=")
                $ConfigurationModeString = $ConfigurationModeString.Substring(0, $ConfigurationModeString.Length - 1)
                [int]$configurationmode = $ConfigurationModeString 
                if ($configurationmode -eq 1) {
                    Write-PSFMessage -Level VeryVerbose -Message "Warning: Found that Maintenance Mode is On"
                    $ConfigurationModeEnabledDisabled = 'Enabled'
                }
                if ($configurationmode -eq 0)
                { $ConfigurationModeEnabledDisabled = 'Disabled' }
            }
            
            $SQLQueryToGetOrchestratorDataOrchestratorJob = "select top 1 State, QueuedDateTime, LastProcessedDateTime, EndDateTime,JobId, DeploymentInstanceId from OrchestratorJob order by ScheduledDateTime desc"
            $SQLQueryToGetOrchestratorDataRunBook = "select top 1 RunBookTaskId, Name, Description, State, StartDateTime, EndDateTime, OutputMessage from RunBookTask"
            try {
                $SqlresultsToGetOrchestratorDataOrchestratorJob = invoke-sql -datasource $OrchdatabaseServer -database $OrchDatabase -sqlcommand $SQLQueryToGetOrchestratorDataOrchestratorJob
            }
            catch {}
            try {
                $SqlresultsToGetOrchestratorDataRunBook = invoke-sql -datasource $OrchdatabaseServer -database $OrchDatabase -sqlcommand $SQLQueryToGetOrchestratorDataRunBook
            }
            catch {}
            if ($SqlresultsToGetOrchestratorDataRunBook.Count -eq 0) {
                $whoami = whoami
                Write-PSFMessage -Level VeryVerbose -Message "Can't find SQL results with query. Check if database is up and permissions are set for $whoami. Server: $OrchdatabaseServer - DatabaseName: $OrchDatabase."
            }
            else {
                $OrchestratorJobSQL = $SqlresultsToGetOrchestratorDataOrchestratorJob | Select-Object State
                [string]$OrchestratorDataOrchestratorJobStateString = $OrchestratorJobSQL
                $OrchestratorDataOrchestratorJobStateString = $OrchestratorDataOrchestratorJobStateString.Trim("@{State=")
                $OrchestratorDataOrchestratorJobStateString = $OrchestratorDataOrchestratorJobStateString.Trim("State=")
                $OrchestratorDataOrchestratorJobStateString = $OrchestratorDataOrchestratorJobStateString.Substring(0, $OrchestratorDataOrchestratorJobStateString.Length - 1)
                [int]$OrchestratorDataOrchestratorJobStateInt = $OrchestratorDataOrchestratorJobStateString

                $RunBookSQL = $SqlresultsToGetOrchestratorDataRunBook | Select-Object State
                [string]$OrchestratorDataRunBookStateString = $RunBookSQL
                $OrchestratorDataRunBookStateString = $OrchestratorDataRunBookStateString.Trim("@{State=")
                $OrchestratorDataRunBookStateString = $OrchestratorDataRunBookStateString.Trim("State=")
                $OrchestratorDataRunBookStateString = $OrchestratorDataRunBookStateString.Substring(0, $OrchestratorDataRunBookStateString.Length - 1)
                [int]$OrchestratorDataRunBookStateInt = $OrchestratorDataRunBookStateString

                switch ( $OrchestratorDataRunBookStateInt) {
                    0 { $OrchestratorJobRunBookState = 'Not Started' }
                    1 { $OrchestratorJobRunBookState = 'In Progress' }
                    2 { $OrchestratorJobRunBookState = 'Successful' }
                    3 { $OrchestratorJobRunBookState = 'Failed' }
                    4 { $OrchestratorJobRunBookState = 'Cancelled' }
                    5 { $OrchestratorJobRunBookState = 'Unknown Status' }
                }
                switch ($OrchestratorDataOrchestratorJobStateInt ) {
                    0 { $OrchestratorJobRunBookState = 'Not Started' }
                    1 { $OrchestratorJobRunBookState = 'In Progress' }
                    2 { $OrchestratorJobRunBookState = 'Successful' }
                    3 { $OrchestratorJobRunBookState = 'Failed' }
                    4 { $OrchestratorJobRunBookState = 'Cancelled' }
                    5 { $OrchestratorJobState = 'Unknown Status' }
                }
            }

            if ($CustomModuleName) {
                $assets = Get-ChildItem -Path "$AgentShareLocation\assets" | Where-object { ($_.Name -ne "chk") -and ($_.Name -ne "topology.xml") } | Sort-Object { $_.CreationTime } -Descending
                $versions = @()
                foreach ($asset in $assets) {
                    $versionfile = (Get-ChildItem $asset.FullName -File | Where-Object { $_.Name -like "$CustomModuleName*" }).Name
                    $version = ($versionfile -replace $CustomModuleName) -replace ".xml"
                    $versions += $version
                }
                $CustomModuleVersionFullPreppedinAgentShare = $versions | Sort-Object { $_.CreationTime } -Descending | Select-Object -First 1
                $CustomModuleVersionFullPreppedinAgentShare = $CustomModuleVersionFullPreppedinAgentShare.trim()
            }
            ##Getting DB Sync Status using winevent Start
            Foreach ($AXSFServerName in $AXSFServerNames) {
                try {
                    $LatestEventinLog = $(Get-WinEvent -LogName Microsoft-Dynamics-AX-DatabaseSynchronize/Operational -maxevents 1 -computername $AXSFServerName -ErrorAction Stop).TimeCreated
                }
                catch {
                    Write-PSFMessage -Level VeryVerbose -Message "$AXSFServerName $_"
                    if ($_.Exception.Message -eq "No events were found that match the specified selection criteria") {
                        $LatestEventinLog = $null
                    }
                    if ($_.Exception.Message -eq "The RPC Server is unavailable") {
                        {           
                            Write-PSFMessage -Level Verbose -Message "The RPC Server is Unavailable trying WinRM"       
                            $LatestEventinLog = Invoke-Command -ComputerName $AXSFServerName -ScriptBlock { $(Get-EventLog -LogName Microsoft-Dynamics-AX-DatabaseSynchronize/Operational -maxevents 1 -computername $AXSFServerName).TimeCreated }
                        }
                    }
                }
                if (($LatestEventinLog -gt $LatestEventinAllLogs) -or (!$LatestEventinAllLogs)) {
                    $LatestEventinAllLogs = $LatestEventinLog
                    $ServerWithLatestLog = $AXSFServerName 
                    Write-PSFMessage -Level Verbose -Message "Server with latest database synchronization log updated to $ServerWithLatestLog with a date time of $LatestEventinLog"
                }
            }
            if (!$HighLevelOnly) {
                ##Found which server is getting the latest database sync using winevent end
                Write-PSFMessage -Level VeryVerbose -Message "Gathering Database Logs from $ServerWithLatestLog"
                $events = Get-WinEvent -LogName Microsoft-Dynamics-AX-DatabaseSynchronize/Operational -computername $ServerWithLatestLog -maxevents 100  | 
                ForEach-Object -Process { `
                        New-Object -TypeName PSObject -Property `
                    @{'MachineName'        = $ServerWithLatestLog ;
                        'EventMessage'     = $_.Properties[0].value;
                        'EventDetails'     = $_.Properties[1].value; 
                        'Message'          = $_.Message;
                        'LevelDisplayName' = $_.LevelDisplayName;
                        'TimeCreated'      = $_.TimeCreated;
                        'TaskDisplayName'  = $_.TaskDisplayName
                        'UserId'           = $_.UserId;
                        'LogName'          = $_.LogName;
                        'ProcessId'        = $_.ProcessId;
                        'ThreadId'         = $_.ThreadId;
                        'Id'               = $_.Id;
                    }
                }
                $SyncStatusFound = $false
                foreach ($event in $events) {
                    if ((($event.message -contains "Table synchronization failed.") -or ($event.message -contains "Database Synchronize Succeeded.") -or ($event.message -contains "Database Synchronize Failed.")) -and $SyncStatusFound -eq $false) {
                        if (($event.message -contains "Table synchronization failed.") -or ($event.message -contains "Database Synchronize Failed.")) {
                            Write-PSFMessage -Message "Found a DB Sync failure $event" -Level Verbose
                            $DBSyncStatus = "Failed"
                            $DBSyncTimeStamp = $event.TimeCreated
                        }
                        if ($event.message -contains "Database Synchronize Succeeded.") {
                            Write-PSFMessage -Message "Found a DB Sync Success $event" -Level Verbose
                            $DBSyncStatus = "Succeeded"
                            $DBSyncTimeStamp = $event.TimeCreated
                        }
                        $SyncStatusFound = $true
                    }
                }
            }
            $WPAssetIDTXT = Get-ChildItem $AgentShareLocation\wp\*\AssetID.txt |  Sort-Object LastWriteTime | Select-Object -First 1
            if ($WPAssetIDTXT) {
                $WPAssetIDTXTContent = Get-Content $WPAssetIDTXT.FullName
                $DeploymentAssetIDinWPFolder = $WPAssetIDTXTContent[0] -replace "AssetID: ", ""
            }
            try {
                $RunningAXCodeFolder = Invoke-Command -ComputerName $AXSFConfigServerName -ScriptBlock { $(Split-Path $(Get-Process | Where-Object { $_.Name -eq "AXService" } | select *).Path -Parent) }
            }
            catch {

            }
            $SSRSClusterServerNames = $ReportServerServerName
            # Collect information into a hashtable Add any new field to Get-D365TestConfigData
            # Make sure to add Certification to Cert list below properties if adding cert
            $Properties = @{
                "AllAppServerList"                           = $AllAppServerList
                "OrchestratorServerNames"                    = $OrchestratorServerNames
                "AXSFServerNames"                            = $AXSFServerNames
                "ReportServerServerName"                     = $ReportServerServerName
                "ReportServerServerip"                       = $ReportServerServerip
                "OrchDatabaseName"                           = $OrchDatabase
                "OrchDatabaseServer"                         = $OrchdatabaseServer
                "AgentShareLocation"                         = $AgentShareLocation
                "SFClientCertificate"                        = $ClientCert
                "SFClusterID"                                = $ClusterID
                "SFConnectionEndpoint"                       = $ConnectionEndpoint
                "SFServerCertificate"                        = $ServerCertificate
                "SFClusterCertificate"                       = $SFClusterCertificate
                "ClientURL"                                  = $ClientURL
                "AXDatabaseServer"                           = $AXDatabaseServer
                "AXDatabaseName"                             = $AXDatabaseName
                "LCSEnvironmentID"                           = $LCSEnvironmentId
                "LCSEnvironmentName"                         = $LCSEnvironmentName
                "TenantID"                                   = $TenantID
                "SourceComputerName"                         = $ComputerName
                "CustomModuleVersion"                        = $CustomModuleVersion
                "DataEncryptionCertificate"                  = $DataEncryptionCertificate 
                "DataSigningCertificate"                     = $DataSigningCertificate
                "SessionAuthenticationCertificate"           = $SessionAuthenticationCertificate
                "SharedAccessSMBCertificate"                 = $SharedAccessSMBCertificate
                "LocalAgentCertificate"                      = $LocalAgentCertificate
                "DataEnciphermentCertificate"                = "$DataEnciphermentCertificate"
                "FinancialReportingCertificate"              = $FinancialReportingCertificate
                "ReportingSSRSCertificate"                   = "$ReportingSSRSCertificate"
                "OrchServiceLocalAgentVersionNumber"         = $OrchServiceLocalAgentVersionNumber
                "NewlyAddedAXSFServers"                      = $NewlyAddedAXSFServers
                'SFVersionNumber'                            = $SFVersionNumber
                'InvalidSFServers'                           = $invalidnodes
                'DisabledSFServers'                          = $disablednodes
                'AOSKernelVersion'                           = $AOSKernelVersion
                'DatabaseEncryptionCertificate'              = $DatabaseEncryptionCertificate 
                'DatabaseClusteredStatus'                    = $DatabaseClusteredStatus
                'DatabaseClusterServerNames'                 = $DatabaseClusterServerNames
                'SourceAXSFServer'                           = $AXSFConfigServerName
                'CustomModuleVersioninAgentShare'            = $CustomModuleVersioninAgentShare
                'AXDatabaseRestoreDate'                      = $AXDatabaseRestoreDate
                'AXDatabaseCreationDate'                     = $AXDatabaseCreationDate
                'AXDatabaseBackupStartDate'                  = $AXDatabaseBackupStartDate
                'AXDatabaseBackupFileUsedForRestore'         = $AXDatabaseBackupFileUsedForRestore
                'CustomModuleVersionFullPreppedinAgentShare' = $CustomModuleVersionFullPreppedinAgentShare
                'DBSyncStatus'                               = $DBSyncStatus
                'DBSyncTimeStamp'                            = $DBSyncTimeStamp
                'DBSyncServerWithLatestLog'                  = $ServerWithLatestLog 
                'ConfigurationModeEnabledDisabled'           = $ConfigurationModeEnabledDisabled
                'DeploymentAssetIDinWPFolder'                = $DeploymentAssetIDinWPFolder
                'OrchestratorJobRunBookState'                = $OrchestratorJobRunBookState
                'OrchestratorJobState'                       = $OrchestratorJobState
                'D365FOLBDAdminEnvironmentType'              = $EnvironmentType
                'DatabaseEncryptionThumbprints'              = $DatabaseEncryptionThumbprints
                'ManagementReporterServers'                  = $ManagementReporterServers
                'SSRSClusterServerNames'                     = $SSRSClusterServerNames
                'RunningAXCodeFolder'                        = $RunningAXCodeFolder 
            }

            $certlist = ('SFClientCertificate', 'SFServerCertificate', 'DataEncryptionCertificate', 'DataSigningCertificate', 'SessionAuthenticationCertificate', 'SharedAccessSMBCertificate', 'LocalAgentCertificate', 'DataEnciphermentCertificate', 'FinancialReportingCertificate', 'ReportingSSRSCertificate', 'DatabaseEncryptionCertificate')
            $CertificateExpirationHash = @{}
            if ($HighLevelOnly) {
                if ($messagecount -eq 0) {
                    Write-PSFMessage -Level Verbose -Message "High Level Only will not connect to service fabric"
                    $messagecount = $messagecount + 1
                }
            }
            else {
                foreach ($cert in  $certlist) {
                    $certthumbprint = $null 
                    $certthumbprint = $Properties.$cert
                    $certexpiration = $null
                    if ($certthumbprint) {
                        $value = $certthumbprint
                        try {
                            if ($cert -eq 'LocalAgentCertificate' -and !$certexpiration) {
                                $certexpiration = invoke-command -scriptblock { param($value) $(Get-ChildItem Cert:\LocalMachine\my | Where-Object { $_.Thumbprint -eq "$value" }).NotAfter } -ComputerName $OrchestratorServerName -ArgumentList $value
                                if (!$certexpiration) {
                                    $certexpiration = invoke-command -scriptblock { param($value) $(Get-ChildItem Cert:\CurrentUser\my | Where-Object { $_.Thumbprint -eq "$value" }).NotAfter } -ComputerName $OrchestratorServerName -ArgumentList $value
                                }
                            } if (!$certexpiration) {
                                $certexpiration = invoke-command -scriptblock { param($value) $(Get-ChildItem Cert:\LocalMachine\my | Where-Object { $_.Thumbprint -eq "$value" }).NotAfter } -ComputerName $AXSFConfigServerName -ArgumentList $value
                            }
                            if (!$certexpiration) {
                                $certexpiration = invoke-command -scriptblock { param($value) $(Get-ChildItem Cert:\CurrentUser\my | Where-Object { $_.Thumbprint -eq "$value" }).NotAfter } -ComputerName $AXSFConfigServerName -ArgumentList $value
                            }
                            if (!$certexpiration) {
                                $certexpiration = invoke-command -scriptblock { param($value) $(Get-ChildItem Cert:\LocalMachine\Trust | Where-Object { $_.Thumbprint -eq "$value" }).NotAfter } -ComputerName $AXSFConfigServerName -ArgumentList $value
                            }
                            if ($cert -eq 'DatabaseEncryptionCertificate' -and !$certexpiration) {
                                $DatabaseClusterServerName = $DatabaseClusterServerNames | Select-Object -First 1
                                try {
                                    $certexpiration = invoke-command -scriptblock { param($value) $(Get-ChildItem Cert:\LocalMachine\my | Where-Object { $_.Thumbprint -eq "$value" }).NotAfter } -ComputerName $DatabaseClusterServerName -ArgumentList $value -ErrorAction Stop
                                    if (!$certexpiration) {
                                        $certexpiration = invoke-command -scriptblock { param($value) $(Get-ChildItem Cert:\CurrentUser\my | Where-Object { $_.Thumbprint -eq "$value" }).NotAfter } -ComputerName $DatabaseClusterServerName -ArgumentList $value -ErrorAction Stop
                                    }
                                }
                                catch {
                                    Write-PSFMessage -Level Warning "Warning: Issue grabbing DatabaseEncryptionCertificate information. $_"
                                }
                            }
                            if ($certexpiration) {
                                Write-PSFMessage -Level Verbose -Message "$value expires at $certexpiration"
                            }
                            else {
                                Write-PSFMessage -Level Verbose -Message "Could not find Certificate $cert $value"
                            }
                        }
                        catch {
                            Write-PSFMessage -Level Warning -Message "$value $_ cant be found"
                        }
                    }
                    $name = $cert + "ExpiresAfter"
                
                    $currdate = get-date
                    if ($currdate -gt $certexpiration -and $certexpiration) {
                        Write-PSFMessage -Level Warning -Message "WARNING: Expired Certificate $name with an expiration of $certexpiration"
                    }
                    $hash = $CertificateExpirationHash.Add($name, $certexpiration)
                }
            }
            Function Merge-Hashtables([ScriptBlock]$Operator) {
                ##probably will put in internal to test
                $Output = @{}
                ForEach ($Hashtable in $Input) {
                    If ($Hashtable -is [Hashtable]) {
                        ForEach ($Key in $Hashtable.Keys) { $Output.$Key = If ($Output.ContainsKey($Key)) { @($Output.$Key) + $Hashtable.$Key } Else { $Hashtable.$Key } }
                    }
                }
                If ($Operator) { ForEach ($Key in @($Output.Keys)) { $_ = @($Output.$Key); $Output.$Key = Invoke-Command $Operator } }
                $Output
            }
            $FinalOutput = $CertificateExpirationHash, $Properties | Merge-Hashtables
            ##Sends Custom Object to Pipeline
            [PSCustomObject] $FinalOutput
        }
    }
    END {
        if ($ConfigExportToFile) {
            $FinalOutput | Export-Clixml -Path $ConfigExportToFile
        }
    }
}