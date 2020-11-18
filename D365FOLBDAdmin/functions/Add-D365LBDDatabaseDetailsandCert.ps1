function Add-D365LBDDatabaseDetailsandCert {
    <#
    .SYNOPSIS
   Adds the Encipherment Cert into the D365 Servers for the configuration of the local business data environment
   .DESCRIPTION
    Adds the Encipherment Cert into the D365 Servers for the configuration of the local business data environment
   .EXAMPLE
   Add-D365LBDDataEnciphermentCertConfig -Thumbprint "1243asd234213"
   Will get config from the local machine.
   .PARAMETER Thumbrint
   required string 
    the thumbprint of the DataEncipherment certificate
   #>
    [alias("Add-D365DatabaseDetailsandCert")]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [switch]$Clustered,
        [string[]]$DatabaseServerNames,
        [string]$Thumbprint,
        [psobject]$Config
  
    )
    ##Gather Information from the Dynamics 365 Orchestrator Server Config
    BEGIN {
    }
    PROCESS {
        if (!$Config) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName 
        }

        foreach ($server in $Config.AllAppServerList) {
            if ($Clustered) {
                "Clustered" | Out-file \\$server\c$\ProgramData\SF\DatabaseDetailsandCert.txt -Force
                Write-PSFMessage -Level Verbose "Clustered Selected make sure you entered in all database server names in other parameter"
            }
            else {
                "NotClustered" | Out-file \\$server\c$\ProgramData\SF\DatabaseDetailsandCert.txt -Force
            }
            $Thumbprint | Out-file \\$server\c$\ProgramData\SF\DatabaseDetailsandCert.txt -append 
            $DatabaseServerNames | Out-file \\$server\c$\ProgramData\SF\DatabaseDetailsandCert.txt -append 
            
        }
        Write-PSFMessage -Level Verbose "c:\ProgramData\SF\DatabaseDetailsandCert.txt created/updated"
    }
    END {
      
    }
}