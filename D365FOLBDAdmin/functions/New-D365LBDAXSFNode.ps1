function New-D365LBDAXSFNode {
    <#
    .SYNOPSIS
   Can only be ran on the local machine not fully functional need to add fd and ud logic 
   #>
    [alias("New-D365AXSFNode")]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$SFConnectionEndpoint,
        [Parameter(Mandatory = $true)]
        [string]$FaultDomain,
        [string]$UpdateDomain,
        [string]$SFClusterCertificate,
        [string]$SFClientCertificate,
        [string]$ServiceFabricInstallPath
    )
    ##Gather Information from the Dynamics 365 Orchestrator Server Config
    BEGIN {
    }
    PROCESS {
        Write-PSFMessage -Message "Make sure pre reqs are installed including certificates" -Level Verbose
        $ipaddress = (Get-NetIPAddress | Where-Object { ($_.AddressFamily -eq "IPv4") -and ($_.IPAddress -ne "127.0.0.1") }).IPAddress
        Set-Location "$ServiceFabricInstallPath"
        .\AddNode.ps1 -NodeName $env:COMPUTERNAME -NodeType AOSNodeType -NodeIPAddressorFQDN $ipaddress -ExistingClientConnectionEndpoint $SFConnectionEndpoint  -UpgradeDomain $UpdateDomain -FaultDomain $FaultDomain -AcceptEULA -X509Credential -ServerCertThumbprint $SFClusterCertificate -StoreLocation LocalMachine -StoreName My -FindValueThumbprint $SFClientCertificate
    }
}