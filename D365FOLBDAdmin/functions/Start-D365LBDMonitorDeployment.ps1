function Start-D365LBDMonitorDeployment {
    <# TODO: incomplete function.
   .SYNOPSIS
  Looks inside the agent share extracts the version from the zip by using the custom module name. Puts an xml in root for easy idenitification
  .DESCRIPTION
   Exports 
  .EXAMPLE
    Start-D365LBDMonitorDeployment

  .EXAMPLE
   Export-D365FOLBDAssetModuleVersion

  .PARAMETER AgentShare
  optional string 
   The location of the Agent Share
  .PARAMETER CustomModuleName
  optional string 
  The name of the custom module you will be using to capture the version number

  #>
    [alias("Start-D365MonitorDeployment")]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [int]$Timeout,
        [Parameter(ValueFromPipeline = $True)]
        [psobject]$Config
    )
    BEGIN {
    }
    PROCESS {
        foreach ($AXSFServerName in $Config.AllAppServerList.ComputerName){
            Write-PSFMessage -Level VeryVerbose -Message "Checking $AXSFServerName for running Database Sync"
            try{
                $process = Get-Process -name "Microsoft.Dynamics.AX.Deployment.Setup" -ComputerName $AXSFServerName -ErrorAction Stop
            }
            catch{

            }
            if ($process.ProcessName -eq "Microsoft.Dynamics.AX.Deployment.Setup"){
                $ServerRunningDBSync = $AXSFServerName
                Write-PSFMessage -Level VeryVerbose -Message "DB Sync is  $AXSFServerName for running DBSync"
            }
        }
        if ($ServerRunningDBSync){
            $processwatcher = Get-Process -name "Microsoft.Dynamics.AX.Deployment.Setup" -ComputerName $ServerRunningDBSync -ErrorAction Stop
            While ($processwatcher){
                $processwatcher = Get-Process -name "Microsoft.Dynamics.AX.Deployment.Setup" -ComputerName $ServerRunningDBSync -ErrorAction Stop
                ##Add get DB sync logs
                Start-Sleep  -Seconds 5
            }
            Write-PSFMessage -Level VeryVerbose -Message "Finished Database Sync"
        }
        $propsToCompare = $Primary[0].psobject.properties.name

        $allnow = $Primary + $secondary | Sort-Object { $_.TimeCreated } -Descending | Select-Object -First $NumberofEventsToCheck
 
        if (Compare-Object -ReferenceObject $all -DifferenceObject $allnow -Property  $propsToCompare) {
            $allnow
        }
        else {
            Write-Host "Nothing New"
        }
    }
    END {
    }
}