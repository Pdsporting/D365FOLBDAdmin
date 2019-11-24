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
   Parameter 
   optional string 
   The name of the Local Business Data Computer.
   If ignored will use local host.
   
   #>
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME"
    )
    ##Gather Infromation from the Dynamics 365 Orchestrator Server Config
    BEGIN {
    }
    PROCESS {
        if ($ComputerName.IsLocalhost) {
            Write-PSFMessage -Level Warning -Message "Looking for the clusterconfig on the localmachine as no computername provided"
            if ($(Test-Path "C:\ProgramData\SF\clusterManifest.xml") -eq $False) {
                Stop-PSFFunction -Message "Error: This is not an Local Business Data server. Stopping" -EnableException $true -Cmdlet $PSCmdlet
            }
            $ClusterManifestXMLFile = get-childitem "C:\ProgramData\SF\clusterManifest.xml" 
        }
        else {
            Write-PSFMessage -Level Verbose "Connecting to admin share on $ComputerName for cluster config"
            if ($(Test-Path "\\$ComputerName\C$\ProgramData\SF\clusterManifest.xml") -eq $False) {
                Stop-PSFFunction -Message "Error: This is not an Local Business Data server. Can't find Cluster Manifest. Stopping" -EnableException $true -Cmdlet $PSCmdlet
            }
            $ClusterManifestXMLFile = get-childitem "\\$ComputerName\C$\ProgramData\SF\clusterManifest.xml"
        }
        if (!($ClusterManifestXMLFile)) {
            Stop-PSFFunction -Message "Error: This is not an Local Business Data server. Can't find Cluster Manifest. Stopping" -EnableException $true -Cmdlet $PSCmdlet
        }
            
        if ($(test-path $ClusterManifestXMLFile) -eq $false) {
            Stop-PSFFunction -Message "Error: This is not an Local Business Data server. Can't find Cluster Manifest. Stopping" -EnableException $true -Cmdlet $PSCmdlet
        }
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
                Write-PSFMessage -Level Verbose "Verbose: Connecting to $OrchestratorServerName for Orchestrator config" 
                $OrchServiceLocalAgentConfigXML = get-childitem "\\$OrchestratorServerName\C$\ProgramData\SF\*\Fabric\work\Applications\LocalAgentType_App*\OrchestrationServicePkg.Package.Current.xml"
            }
        }
        if (!$OrchServiceLocalAgentConfigXML) {
            Write-PSFMessage -Level Critical "Error: Can't find any Local Agent file on the Orchestrator Node"  -ErrorAction Continue
        }
    
        [xml]$xml = get-content $OrchServiceLocalAgentConfigXML
    
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
        $AllAppServerList = @()
        foreach ($ComputerName in $AXSFServerNames) {
            if (($AllAppServerList -ccontains $ComputerName) -eq $false) {
                $AllAppServerList += $ComputerName
            }
        }
        foreach ($ComputerName in $ReportServerServerName) {
            if (($AllAppServerList -ccontains $ComputerName) -eq $false) {
                $AllAppServerList += $ComputerName
            }
        }
        foreach ($ComputerName in $OrchestratorServerNames) {
            if (($AllAppServerList -ccontains $ComputerName) -eq $false) {
                $AllAppServerList += $ComputerName
            }
        }
        $AXSFConfigServerName = $AXSFServerNames | Select-Object -First 1
        Write-PSFMessage -Level Verbose "Verbose: Reaching out to $AXSFConfigServerName for AX config"

        $SFConfig = get-childitem "\\$AXSFConfigServerName\C$\ProgramData\SF\*\Fabric\work\Applications\AXSFType_App*\AXSF.Package.Current.xml"
        if (!$SFConfig) {
            Write-PSFMessage -Level Verbose "Verbose: Cant find AX SF. App may not be installed"
        }
        else {
            [xml]$xml = get-content $SFConfig 

            $DataAccess = $xml.ServicePackage.DigestedConfigPackage.ConfigOverride.Settings.Section | Where-Object { $_.Name -EQ 'DataAccess' }
            $AXDatabaseName = $($DataAccess.Parameter | Where-Object { $_.Name -eq 'Database' }).value
            $AXDatabaseServer = $($DataAccess.Parameter | Where-Object { $_.Name -eq 'DbServer' }).value

            $Infrastructure = $xml.ServicePackage.DigestedConfigPackage.ConfigOverride.Settings.Section | Where-Object { $_.Name -EQ 'Aad' }
            $ClientURL = $($Infrastructure.Parameter | Where-Object { $_.Name -eq 'AADValidAudience' }).value + "namespaces/AXSF/"
       
            $sb = New-Object System.Data.Common.DbConnectionStringBuilder
            $sb.set_ConnectionString($($OrchDBConnectionString.Value))
            $OrchDatabase = $sb.'initial catalog'
            $OrchdatabaseServer = $sb.'data source'
        }

        $AgentShareLocation = $downloadfolderLocation.Value
        $AgentShareWPConfigJson = Get-ChildItem "$AgentShareLocation\wp\*\StandaloneSetup-*\config.json" | Sort-Object { $_.CreationTime }

        if ($AgentShareWPConfigJson) {
            $jsonconfig = get-content $AgentShareWPConfigJson
            $LCSEnvironmentId = $($jsonconfig | ConvertFrom-Json).environmentid
            $TenantID = $($jsonconfig | ConvertFrom-Json).tenantid
            $LCSEnvironmentName = $($jsonconfig | ConvertFrom-Json).environmentName
        }
        else {
            Write-PSFMessage -Level Warning -Message "WARNING: Can't Find Config in WP folder cant get Environment ID or TenantID"
            $LCSEnvironmentId = ""
            $TenantID = ""
            $LCSEnvironmentName = ""
        }
    
        # Collect information into a hashtable
        $Properties = @{
            "AllAppServerList"        = $AllAppServerList
            "OrchestratorServerNames" = $OrchestratorServerNames
            "AXSFServerNames"         = $AXSFServerNames
            "ReportServerServerName"  = $ReportServerServerName
            "ReportServerServerip"    = $ReportServerServerip
            "OrchDatabaseName"        = $OrchDatabase
            "OrchDatabaseServer"      = $OrchdatabaseServer
            "AgentShareLocation"      = $AgentShareLocation
            "SFClientCertificate"     = $ClientCert
            "SFClusterID"             = $ClusterID
            "SFConnectionEndpoint"    = $ConnectionEndpoint
            "SFServerCertificate"     = $ServerCertificate
            "ClientURL"               = $ClientURL
            "AXDatabaseServer"        = $AXDatabaseServer
            "AXDatabaseName"          = $AXDatabaseName
            "LCSEnvironmentID"        = $LCSEnvironmentId
            "LCSEnvironmentName"      = $LCSEnvironmentName
            "TenantID"                = $TenantID
            "SourceComputerName"      = $ComputerName
        }
        ##Sends Custom Object to Pipeline
        [PSCustomObject]$Properties
    }
    END {
    }
}