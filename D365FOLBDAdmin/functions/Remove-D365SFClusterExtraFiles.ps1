function Remove-D365SFClusterExtraFiles {
    <#
   .SYNOPSIS

  #>
    [alias("Remove-D365ClusterExtraFiles")]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$CertThumbprint,
        [Parameter(Mandatory = $true)]
        [string]$ExportLocation,
        [string]$Config
    )
    BEGIN {
    }
    PROCESS {
        $AllAppServerList = $config.AllAppServerList
        foreach ($AppServer in $AllAppServerList)
        {
            Invoke-Command -ScriptBlock { $SFFolder = Get-ChildItem "C:\ProgramData" -Directory |Where-Object {$_.Name -eq "SF"};
        if ($SFFolder.Count -eq 1 ){
            $items.FullName | Remove-Item -Recurse -Force -Confirm
            Write-PSFMessage -Level VeryVerbose -Message "Cleaned SF Folder on $AppServer "
        }
        else {
            Write-PSFMessage -Level VeryVerbose -Message "SF Folder in Program Data doesnt exist on $AppServer"
        }
    } -ComputerName $AppServer
        }

    }
    END{}
}
