function Get-D365LBDTestConfigData {
    <#
    .SYNOPSIS
   Made to test D365 Config functions without a test environment
   #>
    [alias("Get-D365TestConfigData")]
    [CmdletBinding()]
    param(        
    )
    ##Gather Information from the Dynamics 365 Orchestrator Server Config
    BEGIN {
    }
    PROCESS {
        # Collect information into a hashtable
        $Properties = @{
            "AllAppServerList"                             = ('Server1', 'Server2', 'Server3', 'Server4', 'Server5')
            "OrchestratorServerNames"                      = ('Server1', 'Server2')
            "AXSFServerNames"                              = ('Server3', 'Server4', 'Server5')
            "ReportServerServerName"                       = 'Server5'
            "ReportServerServerip"                         = '1.1.1.1'
            "OrchDatabaseName"                             = 'Orchestrator'
            "OrchDatabaseServer"                           = 'OrchestratorDBServer'
            "AgentShareLocation"                           = '\\fileshare\share\agent'
            "SFClientCertificate"                          = 'A233E'
            "SFClusterID"                                  = 'D365SFCluster'
            "SFConnectionEndpoint"                         = '1.2.3.4:19000'
            "SFServerCertificate"                          = 'B12131233E'
            "SFClusterCertificate"                         = 'C12313233E'
            "ClientURL"                                    = 'https://ax.offandonit.com/namespaces/AXSF/'
            "AXDatabaseServer"                             = 'AXDBServer'
            "AXDatabaseName"                               = 'AXDB'
            "LCSEnvironmentID"                             = 'LCSEnvironmentID'
            "LCSEnvironmentName"                           = 'LCSEnvironmentID'
            "TenantID"                                     = '123912084123-123d0-1232-11234123'
            "SourceComputerName"                           = 'D365ManagementServer'
            "CustomModuleVersion"                          = '2020.1.28.1'
            "DataEncryptionCertificate"                    = 'E1231233E'
            "DataSigningCertificate"                       = 'F1231233E'
            "SessionAuthenticationCertificate"             = 'G1233123233E'
            "SharedAccessSMBCertificate"                   = 'H12331233E'
            "LocalAgentCertificate"                        = 'I2134213233E'
            "DataEnciphermentCertificate"                  = 'J12312233E'
            "FinancialReportingCertificate"                = 'K123113233E'
            "ReportingSSRSCertificate"                     = 'LASDSA233E'
            "OrchServiceLocalAgentVersionNumber"           = '2.3.0.0'
            "NewlyAddedAXSFServers"                        = 'Server4'
            'SFVersionNumber'                              = '7.1.465.9590'
            'InvalidSFServers'                             = 'Server5'
            'DisabledSFServers'                            = 'Server4'
            'AOSKernelVersion'                             = '7.0.6969.42069'
            'DatabaseEncryptionCertificate'                = 'ASES123113233E'
            'DatabaseClusteredStatus'                      = 'Clustered'
            'DatabaseClusterServerNames'                   = ('DatabaseServer1', 'DatabaseServer2')
            'SFClientCertificateExpiresAfter'              = '5/15/2022 8:24:06 PM'
            'SFServerCertificateExpiresAfter'              = '5/15/2022 8:24:06 PM'
            'DataEncryptionCertificateExpiresAfter'        = '5/15/2022 8:24:06 PM'
            'DataSigningCertificateExpiresAfter'           = '5/15/2022 8:24:06 PM'
            'SessionAuthenticationCertificateExpiresAfter' = '5/15/2022 8:24:06 PM'
            'SharedAccessSMBCertificateExpiresAfter'       = '5/15/2022 8:24:06 PM'
            'LocalAgentCertificateExpiresAfter'            = '5/15/2022 8:24:06 PM'
            'DataEnciphermentCertificateExpiresAfter'      = '5/15/2022 8:24:06 PM'
            'FinancialReportingCertificateExpiresAfter'    = '5/15/2022 8:24:06 PM'
            'ReportingSSRSCertificateExpiresAfter'         = '5/15/2022 8:24:06 PM'
            'DatabaseEncryptionCertificateExpiresAfter'    = '5/15/2022 8:24:06 PM'
        }
        ##Sends Custom Object to Pipeline
        [PSCustomObject]$Properties
    }
    END {
    }
}