function Get-D365LBDConfigTemplate {
    <# TODO: Need to rethink this command
    .SYNOPSIS
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
        [Parameter(ParameterSetName = 'InfrastructurePath',
            ValueFromPipeline = $True)]
        [string]$infrastructurescriptspath,
        [switch]$CreateCopy
    )
    BEGIN {
    } 
    PROCESS {
        if (!$Config -and !$infrastructurescriptspath) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly
        }
        $path = Join-Path $infrastructurescriptspath -ChildPath "Configtemplate.xml"
        [xml]$Configtemplatexml = get-content $path
        $Certs = $Configtemplatexml.Config.Certificates.Certificate
        foreach ($Cert in $Certs) {
            $parent = $Cert.ParentNode
            $CertNameinConfig = $parent.Certificate | Where-Object { $_.Thumbprint -eq $Cert.Thumbprint }
            $CertName = $CertNameinConfig.Name
            Write-PSFMessage -Level VeryVerbose -Message "Looking for $CertName with a thumbprint of $Cert"
            $CertinStore = Get-ChildItem "Cert:\Currentuser\My" | Where-Object { $_.Thumbprint -eq $Cert.Thumbprint }
            if (!$CertinStore) {
                Write-PSFMessage -Level VeryVerbose "Can't find Cert $Cert in CurrentUser Checking local machine"
                $CertinStore = Get-ChildItem "Cert:\LocalMachine\My" | Where-Object { $_.Thumbprint -eq $Cert.Thumbprint }
            }
            if ($CertinStore) {
                if ($CertinStore.NotAfter -lt $(get-date)) {
                    Write-PSFMessage -Level Warning -Message "$CertName with Thumbprint $($Cert.Thumbprint) is expired! $($Cert.PSPath)"
                }
                $CertinStore | Select-Object FriendlyName, Thumbprint, NotAfter
            }
            else {
                $parent = $Cert.ParentNode
                $parent.Cert
                Write-PSFMessage -Level VeryVerbose "Warning: Can't find the Thumbprint $Cert on specific machine for $CertName"
            }
        }
        IF ($Createcopy) {
            ##Create Archive folder inside of config template
            If (!(Test-path $infrastructurescriptspath/Archive)) {
                New-Item -ItemType Directory -Force -Path $infrastructurescriptspath/Archive
            }
            $name = "Config$((Get-Date).ToString('yyyy-MM-dd')).xml"
            Copy-Item $path -Destination "$infrastructurescriptspath/Archive/$name"
        }
    }
    END {
    }
}