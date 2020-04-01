function Start-D365FOLBDDBSync {
    <#
    .SYNOPSIS
   Starts a Database Synchronization on a Dynamics 365 Finance and Operations Server
   .DESCRIPTION
   Starts a Database Synchronization on a Dynamics 365 Finance and Operations Server using the "Microsoft.Dynamics.AX.Deployment.Setup.exe" executable
   .EXAMPLE
   Start-D365FOLBDDBSync
   
   .EXAMPLE
    Start-D365FOLBDDBSync
   
   .PARAMETER AXSFServer
   Parameter 
   string 
   The name of the Local Business Data Computer that is runnign the AXSF role.
   If ignored will use local host.
   .PARAMETER AXDatabaseServer
   Parameter 
   string 
   The name of the Local Business Data SQL Database Computer
   .PARAMETER AXDatabaseName
   Parameter 
   string 
   The name of the Local Business Data SQL Database name.
   .PARAMETER SQLUser
   Parameter 
   string 
   The name of the user to login with SQL authentication
   .PARAMETER SQLUserPassword
   Parameter 
   string 
   The password of the user to login with SQL authentication
   .PARAMETER Timeout
   Parameter 
   int 
   The timeout period of the database synchronization
   
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
        [string]$SQLUserPassword,
        [int]$Timeout=60
    )
    
    begin {
    }
    
    process {
        #$AXSFServer = Select-Object -First 1 $AXSFServer
        if (($AXSFServer.IsLocalhost) -or ($AXSFServer -eq $env:COMPUTERNAME) -or ($AXSFServer -eq "$env:COMPUTERNAME.$env:UserDNSDOMAINNAME"))  {
            Write-PSFMessage -Message "AXSF is local Server" -Level Verbose
            Write-PSFMessage -Message "Looking for the AX Process to find deployment exe and the packages folder to start the Database Synchronize" -Level Warning 
            $AXSFCodeFolder = Split-Path $(Get-Process | Where-Object { $_.name -eq "AXService" }).Path -Parent
            $AXSFCodePackagesFolder = Join-Path $AXSFCodeFolder "\Packages"
            $AXSFCodeBinFolder = Join-Path $AXSFCodeFolder "\bin"
            $D365DeploymentExe = Get-ChildItem $AXSFCodeBinFolder | Where-Object { $_.Name -eq "Microsoft.Dynamics.AX.Deployment.Setup.exe" }

            ##Props to Microsoft for below technique in next few lines copied/learned from the 2012 deployment scripts https://gallery.technet.microsoft.com/scriptcenter/Build-and-deploy-for-b166c6e4
            $CommandLineArgs = '-metadatadir {0} --bindir {1} --sqlserver {2} --sqldatabase {3} --sqluser {4} --sqlpwd {5} --setupmode sync --syncmode fullall --isazuresql false --verbose true' -f $AXSFCodePackagesFolder, $AXSFCodePackagesFolder, $AXDatabaseServer, $AXDatabaseName, $SQLUser, $SQLUserPassword
            $DbSyncProcess = Start-Process -filepath $D365DeploymentExe.FullName -ArgumentList $CommandLineArgs -Verbose -PassThru -OutVariable out

            if ($DbSyncProcess.WaitForExit(60000 * $Timeout) -eq $false) {
                $DbSyncProcess.Kill()
                Stop-PSFFunction -Message "Error: Database Sync failed did not complete within $timeout minutes"  -EnableException $true -Cmdlet $PSCmdlet
            }
            else {
                return $true;
            }
        }
        else {
            Write-PSFMessage -Message "Connecting to admin share on $AXSFServer for cluster config" -Level Verbose
            if ($(Test-Path "\\$AXSFServer\C$\ProgramData\SF\clusterManifest.xml") -eq $false) {
                Stop-PSFFunction -Message "Error: This is not an Local Business Data server. Can't find Cluster Manifest. Stopping" -EnableException $true -Cmdlet $PSCmdlet
            }
            Write-PSFMessage -Message "Not running DB Sync Locally will trigger via WinRM" -Level Verbose

            $process = Invoke-PSFCommand -ComputerName $AXSFServer -ScriptBlock { 
                Write-PSFMessage -Message "Looking for the AX Process to find deployment exe and the packages folder to start the Database Synchronize" -Level Warning 
                $AXSFCodeFolder = Split-Path $(Get-Process | Where-Object { $_.name -eq "AXService" }).Path -Parent
                $AXSFCodePackagesFolder = Join-Path $AXSFCodeFolder "\Packages"
                $AXSFCodeBinFolder = Join-Path $AXSFCodeFolder "\bin"
                $D365DeploymentExe = Get-ChildItem $AXSFCodeBinFolder | Where-Object { $_.Name -eq "Microsoft.Dynamics.AX.Deployment.Setup.exe" }
    
                ##Props to Microsoft for below technique in next few lines copied/learned from the 2012 deployment scripts https://gallery.technet.microsoft.com/scriptcenter/Build-and-deploy-for-b166c6e4
                $CommandLineArgs = '-metadatadir {0} --bindir {1} --sqlserver {2} --sqldatabase {3} --sqluser {4} --sqlpwd {5} --setupmode sync --syncmode fullall --isazuresql false --verbose true' -f $AXSFCodePackagesFolder, $AXSFCodePackagesFolder, $AXDatabaseServer, $AXDatabaseName, $SQLUser, $SQLUserPassword
                Write-PSFMessage -Level Verbose -Message "$D365DeploymentExe  $CommandLineArgs"
                $DbSyncProcess = Start-Process -filepath $D365DeploymentExe.FullName -ArgumentList $CommandLineArgs
    
                if ($DbSyncProcess.WaitForExit(60000 * $Timeout) -eq $false) {
                    $DbSyncProcess.Kill()
                    return $false;
                    Stop-PSFFunction -Message "Error: Database Sync failed did not complete within $timeout minutes"  -EnableException $true -Cmdlet $PSCmdlet
                }
                else {
                    return $true;
                }
            }
        }
        
    }
    
    end {
        
    }
}