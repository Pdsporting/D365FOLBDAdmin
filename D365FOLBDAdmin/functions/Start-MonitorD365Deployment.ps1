function Start-MonitorD365Deployment {
    <#
   .SYNOPSIS
  Looks inside the agent share extracts the version from the zip by using the custom module name. Puts an xml in root for easy idenitification
  .DESCRIPTION
   Exports 
  .EXAMPLE
  Export-D365FOLBDAssetModuleVersio

  .EXAMPLE
   Export-D365FOLBDAssetModuleVersion

  .PARAMETER AgentShare
  optional string 
   The location of the Agent Share
  .PARAMETER CustomModuleName
  optional string 
  The name of the custom module you will be using to capture the version number

  #>
    param
    (
        [Parameter(Mandatory = $true)]
        [int]$Timeout
    )
    $propsToCompare = $Primary[0].psobject.properties.name

    $allnow = $Primary + $secondary | Sort-Object { $_.TimeCreated } -Descending | Select-Object -First $NumberofEventsToCheck
 
    if (Compare-Object -ReferenceObject $all -DifferenceObject  $allnow -Property  $propsToCompare) {
        $allnow
    }
    else {
        Write-Host "Nothing New"
    }
}