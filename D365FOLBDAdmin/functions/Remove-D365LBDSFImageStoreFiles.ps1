function Remove-D365LBDSFImageStoreFiles {
    <# TODO: Needs more testing
    .SYNOPSIS
  Created to clean service fabric image store. needs more testing.
   .DESCRIPTION
   Created to clean service fabric image store. needs more testing.
   .EXAMPLE
   Remove-D365LBDSFImageStoreFiles 
  Removes Image store files inside of the local environments Service fabric.
   .EXAMPLE
   $config = get-d365Config
    Remove-D365LBDSFImageStoreFiles -config $config
    Removes Image store files inside of the defined environments Service fabric.
   .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module

   #>
    [alias("Remove-D365SFImageStoreFiles")]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ValueFromPipeline = $True)]
        [psobject]$Config)
    BEGIN {
    }
    PROCESS {
        if (!$Config -or $Config.OrchestratorServerNames.Count -eq 0) {
            Write-PSFMessage -Level VeryVerbose -Message "Config not defined or Config is invalid. Trying to Get new config using $ComputerName"
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly
        }
        [int]$count = 0
        while (!$connection) {
            do {
                $OrchestratorServerName = $Config.OrchestratorServerNames | Select-Object -First 1 -Skip $count
                Write-PSFMessage -Message "Verbose: Reaching out to $OrchestratorServerName to try and connect to the service fabric" -Level Verbose
                $SFModuleSession = New-PSSession -ComputerName $OrchestratorServerName
                if (!$module) {
                    $module = Import-Module -Name ServiceFabric -PSSession $SFModuleSession 
                }
                $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $config.SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
                if (!$connection) {
                    $trialEndpoint = "https://$OrchestratorServerName" + ":198000"
                    $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $trialEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.SFServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
                }
                $count = $count + 1
                if (!$connection) {
                    Write-PSFMessage -Message "Count of servers tried $count" -Level Verbose
                }
            }  until ($connection -or ($count -eq $($OrchestratorServerNames).Count) -or ($($OrchestratorServerNames).Count) -eq 0)
            if (($count -eq $($Config.OrchestratorServerNames).Count) -and (!$connection)) {
                Stop-PSFFunction -Message "Error: Can't connect to Service Fabric"
            }
        }
        
        $content = Get-servicefabricimagestorecontent -remoterelativepath "\" -ImageStoreConnectionString fabric:ImageStore
        foreach ($folder in $content) {
            if (($folder.StoreRelativePath -ne "Store") -and ($folder.StoreRelativePath -ne "WindowsFabricStore")) {
                Write-PSFMessage "Deleting $($folder.StoreRelativePath)" -Level VeryVerbose
                Remove-ServiceFabricApplicationPackage -ApplicationPackagePathInImageStore $folder.StoreRelativePath -ImageStoreConnectionString fabric:ImageStore
            }
        }
    }
    END {
    }
}