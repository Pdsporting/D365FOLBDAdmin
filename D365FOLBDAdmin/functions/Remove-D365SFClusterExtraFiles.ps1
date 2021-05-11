function Remove-D365SFClusterExtraFiles {
    <#
   .SYNOPSIS
   When removing cluster.
   Run Clean fabric scripts on each server then run this to do final cleanup.
   Restart then remake cluster.
Use Get-D365LBDConfig -ConfigImportFromFile to get config
  #>
    [alias("Remove-D365ClusterExtraFiles")]
    param
    (
        [Parameter(ParameterSetName = 'AllAppServerList',
            ValueFromPipeline = $True)]
        [string[]]$AllAppServerList,
        [Parameter(Mandatory = $false)]
        [string]$ExportLocation,
        [Parameter(ParameterSetName = 'Config',
            ValueFromPipeline = $True)]
        [psobject]$Config
    )
    BEGIN {
    }
    PROCESS {
        if ($Config)
        {
            $AllAppServerList= $config.AllAppServerList
        }
        else{

        }
         
        foreach ($AppServer in $AllAppServerList) {
            Invoke-Command -ScriptBlock { $SFFolder = Get-ChildItem "C:\ProgramData" -Directory | Where-Object { $_.Name -eq "SF" };
                if ($SFFolder.Count -eq 1 ) {
                    $items.FullName | Remove-Item -Recurse -Force -Confirm -Verbose
                    Write-PSFMessage -Level VeryVerbose -Message "Cleaned SF Folder on $env:ComputerName "
                }
                else {
                    Write-PSFMessage -Level VeryVerbose -Message "SF Folder in Program Data doesnt exist on  $env:ComputerName"
                }
            } -ComputerName $AppServer
        }

    }
    END {}
}
