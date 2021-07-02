function Start-D365LBDDBSync {
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
   The name of the Local Business Data SQL Database Computer should be FQDN
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
    [alias("Start-D365DBSync", "Start-D365FOLBDDBSync")]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False,
            ParameterSetName = 'NoConfig')]
        [string]$AXSFServer, ## Remote execution needs to be tested and worked on use localhost until then
        [Parameter(Mandatory = $true,
            ParameterSetName = 'NoConfig')]
        [string]$AXDatabaseServer, ##FQDN
        [Parameter(Mandatory = $true,
            ParameterSetName = 'NoConfig')]
        [string]$AXDatabaseName,
        [Parameter(Mandatory = $true)]
        [string]$SQLUser,
        [Parameter(Mandatory = $true)]
        [string]$SQLUserPassword,
        [int]$Timeout = 60,
        [Parameter(ParameterSetName = 'Config',
            ValueFromPipeline = $True)]
        [psobject]$Config,
        [Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [switch]$Wait
    )
    
    begin {
    }
    process {
        $starttime = Get-date
        if (!$Config -and !$AXSFServer) {
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly
        }
        if ($Config) {
            $AXDatabaseServer = $Config.AXDatabaseServer
            $AXDatabaseName = $Config.AXDatabaseName
            $AXSFServer = $Config.SourceAXSFServer
            Write-PSFMessage -Level VeryVerbose -Message "Sync will be using AXSF Server: $AXSFServer and Database Server: $AXDatabaseServer DB: $AXDatabaseName"
        }
        $LatestEventinLog = $(Get-WinEvent -LogName Microsoft-Dynamics-AX-DatabaseSynchronize/Operational -maxevents 1 -computername $AXSFServer -ErrorAction Stop).TimeCreated
        if (($AXSFServer.IsLocalhost) -or ($AXSFServer -eq $env:COMPUTERNAME) -or ($AXSFServer -eq "$env:COMPUTERNAME.$env:UserDNSDOMAINNAME")) {
            Write-PSFMessage -Message "AXSF is local Server" -Level Verbose
            Write-PSFMessage -Message "Looking for the AX Process to find deployment exe and the packages folder to start the Database Synchronize" -Level Warning 
            $AXSFCodeFolder = Split-Path $(Get-Process | Where-Object { $_.name -eq "AXService" }).Path -Parent
            $AXSFCodePackagesFolder = Join-Path $AXSFCodeFolder "\Packages"
            $AXSFCodeBinFolder = Join-Path $AXSFCodeFolder "\bin"
            $D365DeploymentExe = Get-ChildItem $AXSFCodeBinFolder | Where-Object { $_.Name -eq "Microsoft.Dynamics.AX.Deployment.Setup.exe" }

            $CommandLineArgs = '--metadatadir {0} --bindir {1} --sqlserver {2} --sqldatabase {3} --sqluser {4} --sqlpwd {5} --setupmode sync --syncmode fullall --isazuresql false --verbose true' -f $AXSFCodePackagesFolder, $AXSFCodePackagesFolder, $AXDatabaseServer, $AXDatabaseName, $SQLUser, $SQLUserPassword
            
            Write-PSFMessage -Level Verbose -Message "$($D365DeploymentExe.FullName)"
            Write-PSFMessage -Level Verbose -Message '-metadatadir {0} --bindir {1} --sqlserver {2} --sqldatabase {3} --sqluser {4} --sqlpwd removed --setupmode sync --syncmode fullall --isazuresql false --verbose true' -f $AXSFCodePackagesFolder, $AXSFCodePackagesFolder, $AXDatabaseServer, $AXDatabaseName, $SQLUser
               
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
            ##REMOTE START
            Write-PSFMessage -Message "Connecting to admin share on $AXSFServer for cluster config" -Level Verbose
            if ($(Test-Path "\\$AXSFServer\C$\ProgramData\SF\clusterManifest.xml") -eq $false) {
                Stop-PSFFunction -Message "Error: This is not an Local Business Data server. Can't find Cluster Manifest. Stopping" -EnableException $true -Cmdlet $PSCmdlet
            }
            Write-PSFMessage -Message "Not running DB Sync locally due to not AXSF server will trigger via WinRM" -Level Verbose           
            $AXSFCodePackagesFolder = Invoke-Command -ComputerName $AXSFServer -ScriptBlock { 
                Write-PSFMessage -Message "Looking for the AX Process to find deployment exe and the packages folder to start the Database Synchronize" -Level Warning 
                $AXSFCodeFolder = Split-Path $(Get-Process | Where-Object { $_.name -eq "AXService" }).Path -Parent
                $AXSFCodePackagesFolder = Join-Path $AXSFCodeFolder "\Packages"
                $AXSFCodePackagesFolder
            }
            $D365DeploymentExe = Invoke-Command -ComputerName $AXSFServer -ScriptBlock { 
                $AXSFCodeFolder = Split-Path $(Get-Process | Where-Object { $_.name -eq "AXService" }).Path -Parent
                $AXSFCodeBinFolder = Join-Path $AXSFCodeFolder "\bin"
                $D365DeploymentExe = Get-ChildItem $AXSFCodeBinFolder | Where-Object { $_.Name -eq "Microsoft.Dynamics.AX.Deployment.Setup.exe" }
                $D365DeploymentExe
            }
            $CommandLineArgs2 = "$('-metadatadir {0} --bindir {1} --sqlserver {2} --sqldatabase {3} --sqluser {4} --sqlpwd removed --setupmode sync --syncmode fullall --isazuresql false --verbose true' -f $AXSFCodePackagesFolder, $AXSFCodePackagesFolder, $AXDatabaseServer, $AXDatabaseName, $SQLUser)"
            Write-PSFMessage -Level Verbose -Message "$CommandLineArgs2"
             $session = New-PSSession -ComputerName $AXSFServer
            invoke-command -Session $session -ScriptBlock {
            $CommandLineArgs = '--metadatadir {0} --bindir {1} --sqlserver {2} --sqldatabase {3} --sqluser {4} --sqlpwd {5} --setupmode sync --syncmode fullall --isazuresql false --verbose true' -f $using:AXSFCodePackagesFolder, $using:AXSFCodePackagesFolder, $using:AXDatabaseServer, $using:AXDatabaseName, $using:SQLUser, $using:SQLUserPassword
            if ($using:Wait) {
                $DBSyncProcess = Start-Process -file $using:D365DeploymentExe.fullname -ArgumentList "$CommandLineArgs" -Wait
            }
            else {
                Start-Process -file $using:D365DeploymentExe.fullname -ArgumentList "$CommandLineArgs" -Wait
                Start-Sleep -Seconds 5
            }
        } -ArgumentList $D365DeploymentExe, $AXSFCodePackagesFolder, $AXSFCodePackagesFolder, $AXDatabaseServer, $AXDatabaseName, $SQLUser, $SQLUserPassword, $Wait
           Remove-PSSession $session
 
        }
        $currtime = Get-date
        $timediff = New-TimeSpan -Start $starttime -End $currtime
        $LatestEventinLogNew = $(Get-WinEvent -LogName Microsoft-Dynamics-AX-DatabaseSynchronize/Operational -maxevents 1 -computername $AXSFServer -ErrorAction Stop).TimeCreated
        if ($LatestEventinLogNew -eq $LatestEventinLog ) {
            Write-PSFMessage -Level Verbose -Message "No deployment happened, check username/password or SQL cert expiration"
        }
        else {
            Write-PSFMessage -Level Verbose -Message "Database Sync took $timediff"
        }
    }
    end {
    }
}