function Set-D365LBDPreDeploymentOptions {
    <#
   .SYNOPSIS
  Uses switches to set different deployment options
  .DESCRIPTION

  .EXAMPLE
  Set-D365LBDPreDeploymentOptions -RemoveMR

  .EXAMPLE

  #>
    [alias("Set-D365PreDeploymentOptions")]
    param
    (
        [Parameter(ParameterSetName = 'AgentShare')]
        [Alias('AgentShare')]
        [string]$AgentShareLocation,
        [string]$CustomModuleName,
        [Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name',
            ParameterSetName = 'NoConfig')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ParameterSetName = 'Config',
            ValueFromPipeline = $True)]
        [psobject]$Config,
        [switch]$RemoveMR
    )
    BEGIN {
    }
    PROCESS {
        if (!$Config -and !$AgentShareLocation) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly
           
        }
        if ($Config) {
            $agentsharelocation = $Config.AgentShareLocation
        }
        if ($RemoveMR) {
            $JsonLocation = Get-ChildItem $AgentShareLocation\wp\*\StandaloneSetup-*\SetupModules.json | Sort-Object { $_.CreationTime }  | Select-Object -First 1 
            copy-item $JsonLocation.fullName -Destination $AgentShareLocation\OriginalSetupModules
            $json = Get-Content $JsonLocation.FullName -Raw | ConvertFrom-Json
            $json.components = $json.components | Where-Object { $_.name -ne 'financialreporting' }
            $json | ConvertTo-Json -Depth 100 | Out-File $JsonLocation.FullName -Force
        }
    }
    END {
    }
}
