function Get-D365LBDADFSSID {
    <#
    .SYNOPSIS

   .DESCRIPTION

   .EXAMPLE

   .EXAMPLE

    .EXAMPLE

   .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module
   #>
    [CmdletBinding()]
    [alias("Get-D365ADFSSID")]
    param ([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [string]$UsernamewithEmail,
        [Parameter(ValueFromPipeline = $True)]
        [psobject]$Config,
        [string]$ADFSIdentifier
    )
    BEGIN {
       

    } 
    PROCESS {
        if (!$Config) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly
        }
        if (!$ADFSIdentifier) {
            $ADFSIdentifier = $Config.ADFSIdentifier
            Write-PSFMessage -Level VeryVerbose -Message "Using $ADFSIdentifier as ADFS Identifier"
        }
            
        if (!$ADFSIdentifier) {
            Stop-PSFFunction -Message "Error: Please define ADFS Identifier"  -EnableException $true -Cmdlet $PSCmdlet
        }
        if (!$Config) {
            Stop-PSFFunction -Message "Error: Cannot find AX environment"  -EnableException $true -Cmdlet $PSCmdlet
        }
        $codepath = (get-item $Config.RunningAXCodeFolder).FullName
        $DLL = Join-Path $codepath "\bin\Microsoft.Dynamics>AX.Security.SidGenerator.DLL"
        $SourceAXServer = $config.SourceAXSFServer

        $Session = New-PSSession -ComputerName $SourceAXServer
        $ADFSSID = invoke-command -Session $Session -ScriptBlock { 
            $DLLFileName = $using:DLL
            $UsernamewithEmail = $using:UsernamewithEmail
            $ADFSIdentifier = $using:ADFSIdentifier
            $ADFSIdentifier = $ADFSIdentifier.trim('')
            Write-Verbose "Loading $DLLFileName on $env:Computername "
            Add-Type -path $DLLFileName
            try {
                $ADFSSID = [Microsoft.Dynamics.Ax.Security.SidGenerator]::Generate("$UsernamewithEmail", $ADFSIdentifier, 'sha1')
            }
            catch {}

        }
        if (!$ADFSSID) {
            $ADFSSID = invoke-command -Session $Session -ScriptBlock { 
                try {
                    $ADFSSID = [Microsoft.Dynamics.Ax.Security.SidGenerator]::Generate("$UsernamewithEmail", $ADFSIdentifier)
                }
                catch {}
            }

        }
        if ($ADFSSID) {
            write-PSFMessage -Level VeryVerbose -Message "SID for $UsernamewithEmail created using $ADFSIdentifier."
            write-PSFMessage -Level VeryVerbose -Message "SID: $ADFSSID"
            $ADFSSID
        }
        else {
            write-PSFMessage -Level Error -Message "SID cannot be generated"
        }

    }
    END {
        if ($Session ) {
            Remove-PSSession -Session $Session   
        }
    }
}