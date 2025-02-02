﻿function Get-D365LBDConfig {
    <#
    .SYNOPSIS
   Grabs the configuration of the local business data environment
   .DESCRIPTION
   Grabs the configuration of the local business data environment through logic using the Service Fabric Cluster XML,
   AXSF.Package.Current.xml and OrchestrationServicePkg.Package.Current.xml Also loads this modules custom XML (AdditionalEnvironmentDetails.xml) if configured
   .EXAMPLE
   Get-D365LBDConfig
   Will get config from the local machine.
   .EXAMPLE
    Get-D365LBDConfig -ComputerName "LBDServerName" -verbose
   Will get the Dynamics 365 Config from the LBD server
   .EXAMPLE
   $Config = Get-D365LBDConfig -ConfigImportFromFile "C:\XMLExports\EnvironmentConfig.xml"
   This will import the config
   .EXAMPLE
   Get-D365LBDConfig -ConfigExportToFile "C:\XMLExports\EnvironmentConfig.xml" -CustomModuleName 'CUS'
   This will export the config
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
   The name of the custom module you will be using to capture the version number
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
                if (Test-path "C:\ProgramData\SF\$env:COMPUTERNAME\ClusterManifest.current.xml") {
                    $ClusterManifestXMLFile = "C:\ProgramData\SF\$env:COMPUTERNAME\ClusterManifest.current.xml"
                }
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

            if (($null -eq $OrchestratorServerNames) -or (!$OrchestratorServerNames)) {
                $OrchestratorServerNames = $($xml.ClusterManifest.Infrastructure.WindowsServer.NodeList.Node | Where-Object { $_.NodeTypeRef -contains 'PrimaryNodeType' }).NodeName
                $AXSFServerNames = $($xml.ClusterManifest.Infrastructure.WindowsServer.NodeList.Node | Where-Object { $_.NodeTypeRef -contains 'PrimaryNodeType' }).NodeName
            }
            $ReportServerServerName = $($xml.ClusterManifest.Infrastructure.WindowsServer.NodeList.Node | Where-Object { $_.NodeTypeRef -contains 'ReportServerType' }).NodeName 
            $ReportServerServerip = $($xml.ClusterManifest.Infrastructure.WindowsServer.NodeList.Node | Where-Object { $_.NodeTypeRef -contains 'ReportServerType' }).IPAddressOrFQDN
            $ManagementReporterServerName = $($xml.ClusterManifest.Infrastructure.WindowsServer.NodeList.Node | Where-Object { $_.NodeTypeRef -contains 'MRType' }).NodeName 
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
            $fabricfolder = get-childitem "\\$OrchestratorServerName\C$\ProgramData\SF\*\Fabric" | Sort-Object { $_.LastWriteTime }  -Descending | Select-Object -First 1
            if ($(Test-Path "$fabricfolder\clusterManifest.current.xml") -eq $True) {
                Write-PSFMessage -Message "Gathering Current Manifest from $ComputerName as it exists"
                $ClusterManifestXMLFile = get-childitem "$fabricfolder\clusterManifest.current.xml"   
            }
            [xml]$xml = get-content $ClusterManifestXMLFile
            Write-PSFMessage -Message "Reading $ClusterManifestXMLFile" -Level Verbose ##
            $AXSFServerNames = $($xml.ClusterManifest.Infrastructure.WindowsServer.NodeList.Node | Where-Object { $_.NodeTypeRef -contains 'AOSNodeType' -or $_.NodeTypeRef -contains 'PrimaryNodeType' }).NodeName
        
            $ReportServerServerName = $($xml.ClusterManifest.Infrastructure.WindowsServer.NodeList.Node | Where-Object { $_.NodeTypeRef -contains 'ReportServerType' }).NodeName 
            $ReportServerServerip = $($xml.ClusterManifest.Infrastructure.WindowsServer.NodeList.Node | Where-Object { $_.NodeTypeRef -contains 'ReportServerType' }).IPAddressOrFQDN
            $SFClusterCertificate = $(($($xml.ClusterManifest.FabricSettings.Section | Where-Object { $_.Name -eq "Security" })).Parameter | Where-Object { $_.Name -eq "ClusterCertThumbprints" }).value
            $ServerCertificate = $SFClusterCertificate | Select-Object -First 1
            if (!$OrchServiceLocalAgentConfigXML) {
                Stop-PSFFunction -Message "Error: Can't find any Local Agent file on the Orchestrator Node" -EnableException $true -Cmdlet $PSCmdlet
            }
            Write-PSFMessage -Message "Reading $OrchServiceLocalAgentConfigXML" -Level Verbose
            [xml]$xml = get-content $OrchServiceLocalAgentConfigXML

            $RetrievedXMLData = $xml.ServicePackage.DigestedConfigPackage.ConfigOverride.Settings.Section | Where-Object { $_.Name -eq 'AAD' } 
            $LocalAgentCertificate = ($RetrievedXMLData.Parameter | Where-Object { $_.Name -eq "ServicePrincipalThumbprint" }).value

            $RetrievedXMLData = $xml.ServicePackage.DigestedConfigPackage.ConfigOverride.Settings.Section | Where-Object { $_.Name -eq 'Data' } 
            $OrchDBConnectionString = $RetrievedXMLData.Parameter
            $sb = New-Object System.Data.Common.DbConnectionStringBuilder
            $sb.set_ConnectionString($($OrchDBConnectionString.Value))
            $OrchDatabase = $sb.'initial catalog'
            $OrchdatabaseServer = $sb.'data source'
    
            $RetrievedXMLData = $xml.ServicePackage.DigestedConfigPackage.ConfigOverride.Settings.Section | Where-Object { $_.Name -eq 'Download' } 
            $downloadfolderLocation = $RetrievedXMLData.Parameter
    
            $RetrievedXMLData = $xml.ServicePackage.DigestedConfigPackage.ConfigOverride.Settings.Section | Where-Object { $_.Name -eq 'ServiceFabric' } 
            $ServiceFabricConnectionDetails = $RetrievedXMLData.Parameter

            $ClientCert = $($ServiceFabricConnectionDetails | Where-Object { $_.Name -eq "ClientCertificate" }).value
            $ClusterID = $($ServiceFabricConnectionDetails | Where-Object { $_.Name -eq "ClusterID" }).value
            $ConnectionEndpoint = $($ServiceFabricConnectionDetails | Where-Object { $_.Name -eq "ConnectionEndpoint" }).value
            if (!$ServerCertificate) {
                $ServerCertificate = $($ServiceFabricConnectionDetails | Where-Object { $_.Name -eq "ServerCertificate" }).value ##
            }
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
                $ADFSIdentifier = $($AAD.Parameter | Where-Object { $_.Name -eq 'ADFSIdentifier' }).value 
                $ClientURL = $($AAD.Parameter | Where-Object { $_.Name -eq 'AADValidAudience' }).value + "namespaces/AXSF/"
                $SFExplorerURL = $($ClientURL.Replace('//ax.', '//sf.')).Replace('/namespaces/AXSF/', ':19080')

                $Infrastructure = $xml.ServicePackage.DigestedConfigPackage.ConfigOverride.Settings.Section | Where-Object { $_.Name -EQ 'Infrastructure' }
                $SessionAuthenticationCertificate = $($Infrastructure.Parameter | Where-Object { $_.Name -eq 'SessionAuthenticationCertificateThumbprint' }).value

                $SMBStorage = $xml.ServicePackage.DigestedConfigPackage.ConfigOverride.Settings.Section | Where-Object { $_.Name -EQ 'SmbStorage' }
                $SharedAccessSMBCertificate = $($SMBStorage.Parameter | Where-Object { $_.Name -eq 'SharedAccessThumbprint' }).value
            }

            $AgentShareLocation = $downloadfolderLocation.Value
            $AgentShareWPConfigJson = Get-ChildItem "$AgentShareLocation\wp\*\StandaloneSetup-*\config.json" | Sort-Object { $_.CreationTime } -Descending | Select-Object -First 1

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
            $LCSProjectID = $($($(Get-ChildItem $AgentShareLocation\assets\*\*\*\packages | Sort-Object { $_.CreationTime } -Descending | Where-Object { $_.Name -ne "chk" -and $_.Name -ne "topology.xml" -and $_.Name -ne "ControlFile.txt" } | Select-Object -First 1).Parent).Parent).Name
            if ($LCSProjectID -and $LCSEnvironmentId) {
                $LCSEnvironmentURL = "https://lcs.dynamics.com/v2/EnvironmentDetailsV3New/$LCSProjectID" + "?" + "EnvironmentId=$LCSEnvironmentId"
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
            
            $AXServiceConfigXMLFile = get-childitem "\\$AXSFConfigServerName\C$\ProgramData\SF\*\Fabric\work\Applications\AXSFType_App*\AXSF.Code*\AXService.exe.config" | Sort-Object { $_.CreationTime } -Descending | Select-Object -First 1
            Write-PSFMessage -Message "Reading $AXServiceConfigXMLFile" -Level Verbose 
            if (!$AXServiceConfigXMLFile) {
                Write-PSFMessage -Message "Warning: AXSF doesnt seem installed; config cannot be found" -Level Warning
            }
            else {
                [xml]$AXServiceConfigXML = get-content $AXServiceConfigXMLFile
            }
            $AOSKerneldll = get-childitem "\\$AXSFConfigServerName\C$\ProgramData\SF\*\Fabric\work\Applications\AXSFType_App*\AXSF.Code*\bin\AOSKernel.dll"
            $AOSKernelVersion = $AOSKerneldll.VersionInfo.ProductVersion

            $FinancialReportingCertificate = $($AXServiceConfigXML.configuration.claimIssuerRestrictions.issuerrestrictions.add | Where-Object { $_.alloweduserids -eq "FRServiceUser" }).name

            if (test-path $AgentShareLocation\scripts\D365FOLBDAdmin\AdditionalEnvironmentDetails.xml) {
                Write-PSFMessage -Level Verbose -Message "Found AdditionalEnvironmentDetails config"
                $EnvironmentAdditionalConfig = get-childitem  "$AgentShareLocation\scripts\D365FOLBDAdmin\AdditionalEnvironmentDetails.xml"
            }
            else {
                Write-PSFMessage -Message "Warning: Can't find additional Environment Config. Not needed but recommend making one" -level warning  
            }

            if ($EnvironmentAdditionalConfig) {
                Write-PSFMessage -Message "Reading $EnvironmentAdditionalConfig" -Level Verbose
                [xml]$EnvironmentAdditionalConfigXML = get-content  $EnvironmentAdditionalConfig
                $EnvironmentType = $EnvironmentAdditionalConfigXML.D365LBDEnvironment.EnvironmentType.'#text'.Trim()
                
                if (!$CustomModuleName) {
                    if ($($EnvironmentAdditionalConfigXML.D365LBDEnvironment.EnvironmentAdditionalConfig.CustomModuleName.'#text')) {
                        $CustomModuleNameinConfig = $($EnvironmentAdditionalConfigXML.D365LBDEnvironment.EnvironmentAdditionalConfig.CustomModuleName.'#text').TrimStart()
                    }
                    else {
                        if ($($EnvironmentAdditionalConfigXML.D365LBDEnvironment.EnvironmentAdditionalConfig.CustomModuleName)) {
                            $CustomModuleNameinConfig = $($EnvironmentAdditionalConfigXML.D365LBDEnvironment.EnvironmentAdditionalConfig.CustomModuleName).TrimStart()
                        }
                    }
                    if ($CustomModuleNameinConfig.Length -gt 0) {
                        $CustomModuleNameinConfig = $CustomModuleNameinConfig.TrimEnd()
                        $CustomModuleName = $CustomModuleNameinConfig
                    }
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
           
            ##checking for after deployment added servers
            try {
                $currentclustermanifestxmlfile = get-childitem "\\$AXSFConfigServerName\C$\ProgramData\SF\*\Fabric\clustermanifest.current.xml" | Sort-Object { $_.CreationTime } -Descending | Select-Object -First 1
                [xml]$currentclustermanifestxml = Get-Content $currentclustermanifestxmlfile
                $AXSFServerListToCompare = $currentclustermanifestxml.clusterManifest.Infrastructure.NodeList.Node | Where-Object { $_.NodeTypeRef -eq 'AOSNodeType' -or $_.NodeTypeRef -eq 'PrimaryNodeType' }
                $SFClusterCertificate = $(($($currentclustermanifestxml.ClusterManifest.FabricSettings.Section | Where-Object { $_.Name -eq "Security" })).Parameter | Where-Object { $_.Name -eq "ClusterCertThumbprints" }).value
                $ServerCertificate = $SFClusterCertificate | Select-Object -First 1
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
                    <#NewConnection logic start#>
                    $count = 0
                    if (!$connection) {
                        do {
                            $OrchestratorServerName = $OrchestratorServerNames | Select-Object -First 1 -Skip $count
                            Write-PSFMessage -Message "Verbose: Reaching out to $OrchestratorServerName to try and connect to the service fabric" -Level Verbose
                            $SFModuleSession = New-PSSession -ComputerName $OrchestratorServerName
                            if (!$module) {
                                $module = Import-Module -Name ServiceFabric -PSSession $SFModuleSession 4>5
                            }
                            $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $ConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $ServerCertificate -ServerCertThumbprint $ServerCertificate -StoreLocation LocalMachine -StoreName My
                            if ($connection) {
                                Write-PSFMessage -Message "Connected to Service Fabric Via: Connect-ServiceFabricCluster -ConnectionEndpoint $ConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $ServerCertificate -ServerCertThumbprint $ServerCertificate -StoreLocation LocalMachine -StoreName My"
                            }
                            if (!$connection) {
                                $trialEndpoint = "https://$OrchestratorServerName" + ":198000"
                                $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $trialEndpoint -X509Credential -FindType FindByThumbprint -FindValue $ServerCertificate -ServerCertThumbprint $ServerCertificate -StoreLocation LocalMachine -StoreName My
                                if ($connection) {
                                    Write-PSFMessage -Message "Connected to Service Fabric Via: Connect-ServiceFabricCluster -ConnectionEndpoint $trialEndpoint -X509Credential -FindType FindByThumbprint -FindValue $ServerCertificate -ServerCertThumbprint $ServerCertificate -StoreLocation LocalMachine -StoreName My"
                                }
                            }
                            if (!$connection) {
                                $connection = Connect-ServiceFabricCluster
                                if ($connection) {
                                    Write-PSFMessage -Message "Connected to Service Fabric Via: Connect-ServiceFabricCluster"
                                }
                            }
                            $count = $count + 1
                            if (!$connection) {
                                Write-PSFMessage -Message "Count of servers tried $count" -Level Verbose
                            }
                            
                        } until ($connection -or ($count -eq $($OrchestratorServerNames).Count) -or ($($OrchestratorServerNames).Count) -eq 0)
                    }
                    <#NewConnection logic end#>
                   
                    $NumberOfAppsinServicefabric = $($(get-servicefabricclusterhealth | select ApplicationHealthStates).ApplicationHealthStates.Count) - 1
                    if ($NumberOfAppsinServicefabric -eq -1) {
                        $NumberOfAppsinServicefabric = $null
                    }
                    $AggregatedSFState = $(get-servicefabricclusterhealth | select AggregatedHealthState).AggregatedHealthState
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

                    try {
                        $ServiceFabricPartitionIdForAXSF = $(get-servicefabricpartition -servicename 'fabric:/AXSF/AXService' -ErrorAction Stop).PartitionId
                    }
                    catch {
                    }
                    if (!$ServiceFabricPartitionIdForAXSF) {
                        Write-PSFMessage -Level VeryVerbose -Message "Warning: AXSF Partition not found cannot gather node details as AXSF is not installed"
                    }
                    else {
                        foreach ($node in $nodes) {
                            $nodename = $node.Nodename
                            $replicainstanceIdofnode = $(get-servicefabricreplica -partition $ServiceFabricPartitionIdForAXSF | Where-Object { $_.NodeName -eq "$NodeName" }).InstanceId
                            if ($replicainstanceIdofnode){
                                $ReplicaDetails = Get-Servicefabricdeployedreplicadetail -nodename $nodename -partitionid $ServiceFabricPartitionIdForAXSF -ReplicaOrInstanceId $replicainstanceIdofnode -replicatordetail
                                $endpoints = $ReplicaDetails.deployedservicereplicainstance.address | ConvertFrom-Json
                            }     
                            if ($endpoints.Endpoints) {
                                $deployedinstancespecificguid = $($endpoints.Endpoints | Get-Member | Where-Object { $_.MemberType -eq "NoteProperty" }).Name
                                $httpsurl = $endpoints.Endpoints.$deployedinstancespecificguid
                                Write-PSFMessage -Level VeryVerbose -Message "$NodeName is accessible via $httpsurl with a guid $deployedinstancespecificguid "
                            }
                            else {
                                Write-PSFMessage -Level Warning -Message "Warning: $nodename doesnt have an endpoint. Likely AXSF is down on that node"
                            }
                        }
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
            foreach ($ComputerName in $ManagementReporterServerName) {
                if (($AllAppServerList -contains $ComputerName) -eq $false) {
                    $AllAppServerList += $ComputerName
                }
            }
            $AllAppServerList = $AllAppServerList | select -Unique
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
                    $path = Get-ChildItem "$agentsharelocation\wp\*\StandaloneSetup-*\Apps\AOS\AXServiceApp\AXSF\InstallationRecords\MetadataModelInstallationRecords" | Sort-Object { $_.CreationTime } -Descending | Select-Object -first 1 -ExpandProperty FullName
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
            if ($AXDatabaseServer) {
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
            }
            else {
                Write-PSFMessage "$AXDatabaseServer not found so cant get database details" -Level Verbose
                if (!$AXDatabaseServer) {
                    $AXDatabaseServer = $DatabaseClusterServerNames | Select-Object -First 1
                }
                
                if (!$AXDatabaseServer) {
                    $AXDatabaseServer = $OrchdatabaseServer 
                }
            }
            $SQLQueryToGetOrchestratorDataOrchestratorJob = "select top 1 State, QueuedDateTime, LastProcessedDateTime, EndDateTime,JobId, DeploymentInstanceId from OrchestratorJob order by ScheduledDateTime desc"
            $SQLQueryToGetOrchestratorDataRunBook = "select top 1 RunBookTaskId, Name, Description, State, StartDateTime, EndDateTime, OutputMessage from RunBookTask order by StartDateTime desc"
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

                switch ($OrchestratorDataOrchestratorJobStateInt ) {
                    0 { $OrchestratorJobState = 'Not Started' }
                    1 { $OrchestratorJobState = 'In Progress' }
                    2 { $OrchestratorJobState = 'Successful' }
                    3 { $OrchestratorJobState = 'Failed' }
                    4 { $OrchestratorJobState = 'Cancelled' }
                    5 { $OrchestratorJobState = 'Unknown Status' }
                }
                switch ( $OrchestratorDataRunBookStateInt) {
                    0 { $OrchestratorJobRunBookState = 'Not Started' }
                    1 { $OrchestratorJobRunBookState = 'In Progress' }
                    2 { $OrchestratorJobRunBookState = 'Successful' }
                    3 { $OrchestratorJobRunBookState = 'Failed' }
                    4 { $OrchestratorJobRunBookState = 'Cancelled' }
                    5 { $OrchestratorJobRunBookState = 'Unknown Status' }
                }
                $OrchJobQuery = 'select top 1 JobId,State from OrchestratorJob order by ScheduledDateTime desc'
                $RunBookQuery = 'select top 1 RunbookTaskId, State,Name from RunBookTask order by StartDateTime desc'
                $OrchJobQueryResults = Invoke-SQL -dataSource $OrchDatabaseServer -database $OrchDatabase -sqlCommand $OrchJobQuery
                $RunBookQueryResults = Invoke-SQL -dataSource $OrchDatabaseServer -database $OrchDatabase -sqlCommand $RunBookQuery 
                $LastOrchJobId = $($OrchJobQueryResults | select JobId).JobId
                $LastRunbookTaskId = $($RunBookQueryResults | select RunbookTaskId).RunbookTaskId
                $LastRunbookName = $($RunBookQueryResults | select Name).Name
            }

            $SQLQueryToGetAlwaysOn = " WITH AGStatus AS(
                SELECT name as AGName,
                replica_server_name,
                AGDatabases.database_name AS Databasename
                FROM master.sys.availability_groups Groups
                INNER JOIN master.sys.availability_replicas Replicas ON groups.group_id = Replicas.group_id
                INNER JOIN sys.availability_databases_cluster AGDatabases ON groups.group_id = AGDatabases.group_id
                INNER JOIN master.sys.dm_hadr_availability_group_states States ON Groups.group_id = States.group_id
                )
                SELECT DISTINCT
                [Replica_server_name] FROM AGStatus
                WHERE
                [databasename] = '$AXDatabaseName'"
            try {
                $SQLQueryToGetAlwaysOnResults = Invoke-SQL -dataSource $AXDatabaseServer -database 'master' -sqlCommand $SQLQueryToGetAlwaysOn
            }
            catch {}
            $listofsqlservers = @()
            if ($SQLQueryToGetAlwaysOnResults.Count -eq 0) {
                Write-PSFMessage -Level VeryVerbose -Message "Looks like always on is not set up in the database $AXDatabaseName Source: $AXDatabaseServer "
                $DatabaseClusteredStatus = "NonClustered"
                $listofsqlservers = $AXDatabaseServer
                $DatabaseClusterServerNames = $listofsqlservers 
            }
            else {
                $DatabaseClusteredStatus = "Clustered"
                foreach ($SQLQueryToGetAlwaysOnResult in $($SQLQueryToGetAlwaysOnResults | select replica_server_name)) {
                    $listofsqlservers += $SQLQueryToGetAlwaysOnResult.Replica_server_name
                }
                $DatabaseClusterServerNames = $listofsqlservers 
            }

            if ($EnvironmentAdditionalConfigXML) {
                if (!$DatabaseClusterServerNames) {
                    $DatabaseClusterServerNames = $EnvironmentAdditionalConfigXML.D365LBDEnvironment.EnvironmentAdditionalConfig.SQLDetails.SQLServer | ForEach-Object -Process { New-Object -TypeName psobject -Property `
                        @{'DatabaseClusterServerNames' = $_.ServerName } }
                    $DatabaseEncryptionThumbprints = $EnvironmentAdditionalConfigXML.D365LBDEnvironment.EnvironmentAdditionalConfig.SQLDetails.SQLServer | ForEach-Object -Process { New-Object -TypeName psobject -Property `
                        @{'DatabaseEncryptionCertificates' = $_.DatabaseEncryptionThumbprint } }
                    $DatabaseEncryptionThumbprints = $DatabaseEncryptionThumbprints.DatabaseEncryptionCertificates
                    $DatabaseClusterServerNames = $DatabaseClusterServerNames.DatabaseClusterServerNames
                    $DataEnciphermentCertificate = $EnvironmentAdditionalConfigXML.D365LBDEnvironment.EnvironmentAdditionalConfig.DataEnciphermentCertThumbprint
                    if ($DatabaseClusterServerNames.Count -gt 1) {
                        $DatabaseClusteredStatus = 'Clustered'
                    }
                    else {
                        $DatabaseClusteredStatus = 'NonClustered'
                    }
                }
            }
            $listofsqlcerts = @()
            foreach ($sqlserver in $DatabaseClusterServerNames) {
                try {
                    $ProductVersionSQLResults = Invoke-SQL -dataSource $sqlserver -database 'master' -sqlCommand 'SELECT SERVERPROPERTY(''Productversion'') as ''Productversion'' '
                    [string]$SQLMajorVersionNumber = $($ProductVersionSQLResults | select Productversion).Productversion
                    $SQLMajorVersionNumber = $SQLMajorVersionNumber.Substring(0, 2)
                }
                catch {}
                try {
                    $InstanceNameSQLResults = Invoke-SQL -dataSource $sqlserver -database 'master' -sqlCommand 'SELECT @@SERVICENAME as ''Servicename'' '
                }
                catch {}
                $InstanceName = $($InstanceNameSQLResults | select Servicename).Servicename
                $SQLVersionandInstance = 'MSSQL' + $SQLMajorVersionNumber + '.' + $InstanceName
                Write-PSFMessage -Level VeryVerbose -Message "Connecting to Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SQL Server\$SQLVersionandInstance\MSSQLSERVER\SuperSocketNetLib"

                try {
                    $SQLCert = $null
                    $SQLCert = invoke-command -ScriptBlock {
                        if (!$SQLVersionandInstance) {
                            $SQLVersionandInstance = $using:SQLVersionandInstance
                        }
                        $cert = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SQL Server\$SQLVersionandInstance\MSSQLSERVER\SuperSocketNetLib"
                        $cert.Certificate.ToUpper()
                    } -ComputerName $sqlserver -ErrorAction Stop
                }                
                catch {
                    $whoami = whoami
                    Write-PSFMessage -Level Warning -Message "Warning: Can't connect to $SqlServer with account $whoami to gather SQL Cert Encryption details"
                }
                $listofsqlcerts += $SQLCert      
            }
            $DatabaseEncryptionThumbprints = $listofsqlcerts 

            if ($CustomModuleName) {
                $newassets = Export-D365FOLBDAssetModuleVersion -AgentShare $AgentShareLocation -CustomModuleName $CustomModuleName
                if ($newassets) {
                    foreach ($newasset in $newassets) {
                        Write-PSFMessage -Level VeryVerbose -Message "Found new prepped asset $newasset"
                    }
                    $NewPreppedAsset = $newassets | select -First 1
                }
                
                $assets = Get-ChildItem -Path "$AgentShareLocation\assets" | Where-object { ($_.Name -ne "chk") -and ($_.Name -ne "topology.xml") } | Sort-Object { $_.CreationTime } -Descending
                $versions = @()
                foreach ($asset in $assets) {
                    $versionfile = (Get-ChildItem $asset.FullName -File | Where-Object { $_.Name -like "$CustomModuleName*" }).Name
                    $version = ($versionfile -replace $CustomModuleName) -replace ".xml"
                    $versions += $version
                }
                $versions = $versions | Where-Object { $_ }
                $CustomModuleVersionFullPreppedinAgentShare = $versions | Sort-Object { $_.CreationTime } -Descending | Select-Object -First 1
                if ($CustomModuleVersionFullPreppedinAgentShare) {
                    $CustomModuleVersionFullPreppedinAgentShare = $CustomModuleVersionFullPreppedinAgentShare.trim()
                }
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
                try {
                    $events = Get-WinEvent -LogName Microsoft-Dynamics-AX-DatabaseSynchronize/Operational -computername $ServerWithLatestLog -maxevents 100
                }
                catch {}
                if (!$events) {
                    Write-PSFMessage -Level Warning -Message "Warning: Having troubles grabbing DatabaseSynchronize from $ServerWithLatestLog "
                }
                else {
                    try {
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
                    }
                    catch {}

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
            }
            $AssetFolders = Get-ChildItem "$AgentShareLocation\assets" | Where-Object { $_.Name -ne "topology.xml" -and $_.Name -ne "chk" } | Sort-Object CreationTime -Descending 
            $latestfound = 0
            foreach ($Asset in $AssetFolders) {
                $versionlatest = Get-ChildItem "$($Asset.FullName)\$CustomModuleName*.xml"
                if ($versionlatest -and $latestfound -ne 1) {
                    $StandaloneSetupZip = Get-ChildItem "$($Asset.FullName)\*\*\Packages\*\StandaloneSetup.zip"
                    Write-PSFMessage -Message "Last Version: $($versionlatest.BaseName) " -Level veryVerbose
                    Write-PSFMessage -Message "Finished Prep at: $($StandaloneSetupZip.LastWriteTime)" -Level veryVerbose
                    $LastFullyPreppedCustomModuleAsset = $versionlatest.BaseName
                    $LastFullyPreppedCustomModuleAsset = $LastFullyPreppedCustomModuleAsset -replace "$CustomModeName",""
                    $LastFullyPreppedCustomModuleAsset = $LastFullyPreppedCustomModuleAsset.trim()
                    $latestfound = 1
                }
            }
            $WPAssetIDTXT = Get-ChildItem $AgentShareLocation\wp\*\AssetID.txt |  Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($WPAssetIDTXT) {
                $WPAssetIDTXTContent = Get-Content $WPAssetIDTXT.FullName
                $DeploymentAssetIDinWPFolder = $WPAssetIDTXTContent[0] -replace "AssetID: ", ""
            }
            try {
                Write-PSFMessage -Level Verbose -Message "Looking for process AXService $AXSFConfigServerName to get the running folder"
                $RunningAXCodeFolder = Invoke-Command -ComputerName $AXSFConfigServerName -ScriptBlock { $($process = Get-Process | Where-Object { $_.Name -eq "AXService" }; if ($process) { split-path $($process | Select-Object *).Path -Parent }) }
                $RunningAXCodeFolderLastWriteTime = $(Invoke-Command -ComputerName $AXSFConfigServerName -ScriptBlock { get-childitem $using:RunningAXCodeFolder -directory | select LastWriteTime -First 1 }).LastWriteTime
            }
            catch {
            }
            $WPFolder = join-path $AgentShareLocation "wp\$LCSEnvironmentName"
            $SetupJson = Get-ChildItem "$WPFolder\StandaloneSetup-*\setupmodules.json" | Select-Object -First 1
            $json = Get-Content $SetupJson.FullName -Raw | ConvertFrom-Json 
            $componentsinsetupmodule = $json.components.name
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
                'DatabaseEncryptionCertificates'             = $DatabaseEncryptionThumbprints
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
                'ManagementReporterServers'                  = $ManagementReporterServerName 
                'SSRSClusterServerNames'                     = $SSRSClusterServerNames
                'RunningAXCodeFolder'                        = $RunningAXCodeFolder 
                'AggregatedSFState'                          = $AggregatedSFState
                'NumberOfAppsinServicefabric'                = $NumberOfAppsinServicefabric
                'LastOrchJobId'                              = $LastOrchJobId
                'LastRunbookTaskId'                          = $LastRunbookTaskId
                'ComponentsinSetupModule'                    = $componentsinsetupmodule
                'LCSProjectID'                               = $LCSProjectID 
                'LCSEnvironmentURL'                          = $LCSEnvironmentURL
                'SFExplorerURL'                              = $SFExplorerURL
                'CustomModuleName'                           = $CustomModuleName
                'LastFullyPreppedCustomModuleAsset'          = $LastFullyPreppedCustomModuleAsset
                'ADFSIdentifier'                             = $ADFSIdentifier
                "FoundNewPreppedAsset"                       = $NewPreppedAsset
                'RunningAXCodeFolderLastWriteTime'           = $RunningAXCodeFolderLastWriteTime
                'LastRunbookName'                            = $LastRunbookName
            }

            $certlist = ('SFClientCertificate', 'SFServerCertificate', 'DataEncryptionCertificate', 'DataSigningCertificate', 'SessionAuthenticationCertificate', 'SharedAccessSMBCertificate', 'LocalAgentCertificate', 'DataEnciphermentCertificate', 'FinancialReportingCertificate', 'ReportingSSRSCertificate', 'DatabaseEncryptionCertificates')
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
                            if ($cert -eq 'DatabaseEncryptionCertificates' -and !$certexpiration) {
                                try {
                                    foreach ($DatabaseClusterServerName in $DatabaseClusterServerNames) {
                                        if (!$certexpiration -and $value) {
                                            $certexpiration = invoke-command -scriptblock { param($value) $(Get-ChildItem Cert:\LocalMachine\my | Where-Object { $_.Thumbprint -eq "$value" }).NotAfter } -ComputerName $DatabaseClusterServerName -ArgumentList $value -ErrorAction Stop
                                        }
                                        if (!$certexpiration -and $value) {
                                            $certexpiration = invoke-command -scriptblock { param($value) $(Get-ChildItem Cert:\CurrentUser\my | Where-Object { $_.Thumbprint -eq "$value" }).NotAfter } -ComputerName $DatabaseClusterServerName -ArgumentList $value -ErrorAction Stop
                                        }
                                        if (!$certexpiration -and $value) {
                                            $certexpiration = invoke-command -scriptblock { param($value) $(Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Thumbprint -eq "$value" }).NotAfter } -ComputerName $AXSFConfigServerName -ArgumentList $value -ErrorAction Stop
                                        }
                                    }
                                }
                                catch {
                                    Write-PSFMessage -Level Warning "Warning: Issue grabbing DatabaseEncryptionCertificate $value information. $_"
                                }
                            }
                            if ($certexpiration) {
                                
                                Write-PSFMessage -Level Verbose -Message "$value expires at $certexpiration"
                            }
                            else {
                                if ($value -eq 'DatabaseEncryptionCertificate' -or $value -eq '') {

                                }
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
                        if ($name -eq "DatabaseEncryptionCertificate" -or $name -eq 'DataEnciphermentCertificate') {
                            Write-PSFMessage -Level Warning -Message "Note: Expired Certificate $name is not dynamically pulled so this could be a false negative"
                        }
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
            if ($SFModuleSession) {
                Remove-PSSession -Session $SFModuleSession  
            }
            [PSCustomObject] $FinalOutput
        }
    }
    
    END {
        if ($ConfigExportToFile) {
            $FinalOutput | Export-Clixml -Path $ConfigExportToFile
        }
        if ($SFModuleSession) {
            Remove-PSSession -Session $SFModuleSession  
        }
    }
}