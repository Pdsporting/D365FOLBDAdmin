function Get-D365LBDConfigTemplate {
    <#
    .SYNOPSIS
  Checks the event viewer of the primary and secondary orchestrator nodes.
   .DESCRIPTION
   Checks the event viewer of the primary and secondary orchestrator nodes.
   .EXAMPLE
   Get-D365LBDDBEvents 
  
   .EXAMPLE
    Get-D365LBDDBEvents  -ComputerName "LBDServerName" -verbose
   
   .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER NumberofEvents
   Integer
   Number of Events to be pulled defaulted to 20
   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module

   #>
    [CmdletBinding()]
    [alias("Get-D365ConfigTemplate")]
    param ([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name',
            ParameterSetName = 'NoConfig')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ParameterSetName = 'Config',
            ValueFromPipeline = $True)]
        [psobject]$Config,
        [string]$infrastructurescriptspath
    )
    BEGIN {
    } 
    PROCESS {
        if (!$Config -and !$infrastructurescriptspath) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly
        }
        $path = Join-Path $infrastructurescriptspath -ChildPath "Configtemplate.xml"
        [xml]$Configtemplatexml = get-content $path.fullname
        $Certs = $Configtemplatexml.COnfig.Certificates.Certificate
        foreach ($Cert in $Certs)
        {
            $parent = $Cert.ParentNode
            $CertNameinConfig = $parent.Certificate | Where-Object {$_.Thumbprint -eq $Cert.Thumbprint}
            Write-PSFMessage -Level VeryVerbose -Message "Looking for $CertNameinConfig with a thumbprint of $Cert"
            $CertinStore = Get-ChildItem "Cert:\Currentuser\My" |Where-Object {$_.Thumbprint -eq $Cert.Thumbprint}
            if (!$CertinStore)
            {
                Write-PSFMessage -Level VeryVerbose "Can't find Cert $Cert in CurrentUser Checking local machine"
                $CertinStore = Get-ChildItem "Cert:\LocalMachine\My" |Where-Object {$_.Thumbprint -eq $Cert.Thumbprint}
            }
            if ($CertinStore)
            {
                $CertinStore | Select-Object FriendlyName, Thumbprint, NotAfter, Location
            }
            else {
                $parent = $Cert.ParentNode
                $parent.Cert
                Write-PSFMessage -Level VeryVerbose "Warning: Can't find the Thumbprint $Cert on specific machine"
            }

        }


     
    }
    END {
    }
}