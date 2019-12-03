function Start-D365FOLBDDBSync {
    <#
    .SYNOPSIS
   Grabs the configuration of the local business data environment
   .DESCRIPTION
   Grabs the configuration of the local business data environment through logic using the Service Fabric Cluster XML,
   AXSF.Package.Current.xml and OrchestrationServicePkg.Package.Current.xml
   .EXAMPLE
   Get-D365LBDConfig
   Will get config from the local machine.
   .EXAMPLE
    Get-D365LBDConfig -ComputerName "LBDServerName" -verbose
   Will get the Dynamics 365 Config from the LBD server
   .PARAMETER ComputerName
   Parameter 
   optional string 
   The name of the Local Business Data Computer.
   If ignored will use local host.
   
   #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False)]
        [string]$AXSFServer, ## Remote execution needs to be tested and worked on use localhost until then
        [Parameter(Mandatory = $true)]
        [string]$AXDatabaseServer,
        [Parameter(Mandatory = $true)]
        [string]$AXDatabaseName,
        [Parameter(Mandatory = $true)]
        [string]$SQLUser,
        [Parameter(Mandatory = $true)]
        [securestring]$SQLUserPassword,
        [int]$Timeout
    )
    
    begin {
        
    }
    
    process {
        if ($AXSFServer.IsLocalhost) {
            Write-PSFMessage -Message "Looking for the AX Process to find deployment exe and the packages folder to start the Database Synchronize" -Level Warning 
            $AXSFCodeFolder = Split-Path $(Get-Process | Where-Object {$_.name -eq "AXService"}).Path -Parent
            $AXSFCodePackagesFolder = Join-Path $AXSFCodeFolder "\Packages"
            $AXSFCodeBinFolder = Join-Path $AXSFCodeFolder "\bin"
            $D365DeploymentExe = Get-ChildItem $AXSFCodeBinFolder | Where-Object {$_.Name -eq "Microsoft.Dynamics.AX.Deployment.Setup.exe"}

            ##Props to Microsoft for below technique in next few lines copied/learned from the 2012 deployment scripts https://gallery.technet.microsoft.com/scriptcenter/Build-and-deploy-for-b166c6e4
            $CommandLineArgs = '-metadatadir {0} --bindir {1} --sqlserver {2} --sqldatabase {3} --sqluser {4} --sqlpwd {5} --setupmode sync --syncmode fullall --isazuresql false --verbose true' -f $AXSFCodePackagesFolder, $AXSFCodePackagesFolder, $AXDatabaseServer, $AXDatabaseName, $SQLUser, $SQLUserPassword
            Start-Process $D365DeploymentExe -ArgumentList $CommandLineArgs
        }
        else {
            Write-PSFMessage -Message "Connecting to admin share on $AXSFServer for cluster config" -Level Verbose
            if ($(Test-Path "\\$AXSFServer\C$\ProgramData\SF\clusterManifest.xml") -eq $False) {
                Stop-PSFFunction -Message "Error: This is not an Local Business Data server. Can't find Cluster Manifest. Stopping" -EnableException $true -Cmdlet $PSCmdlet
            }
            $ClusterManifestXMLFile = get-childitem "\\$AXSFServer\C$\ProgramData\SF\clusterManifest.xml"
        }
        
    }
    
    end {
        
    }
}