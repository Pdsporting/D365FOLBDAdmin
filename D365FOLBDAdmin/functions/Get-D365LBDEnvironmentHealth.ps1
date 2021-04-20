
function Get-D365LBDEnvironmentHealth {
    <#
   .SYNOPSIS
  Looks inside the agent share extracts the version from the zip by using the custom module name. Puts an xml in root for easy idenitification
  .DESCRIPTION
   Exports 
  .EXAMPLE
    Get-D365LBDEnvironmentHealth

  .EXAMPLE
   Get-D365LBDEnvironmentHealth

  .PARAMETER AgentShare
  optional string 
   The location of the Agent Share
  .PARAMETER CustomModuleName
  optional string 
  The name of the custom module you will be using to capture the version number

  ##Switch fix minor issues 

  #>
    [alias("Get-D365EnvironmentHealth")]
    param
    (
        [Parameter(Mandatory = $true)]
        [int]$Timeout,
        [psobject]$Config,
        [string]$CustomModuleName
    )
    BEGIN {
    }
    PROCESS {
        if (!$Config) {
            if ($CustomModuleName) {
                $Config = Get-D365LBDConfig -ComputerName $ComputerName -CustomModuleName $CustomModuleName
            }
            else {
                $Config = Get-D365LBDConfig -ComputerName $ComputerName 
            }
        }
        $SourceAXSFServer = $Config.SourceAXSFServer
        $SFModuleSession = New-PSSession -ComputerName $SourceAXSFServer
        Invoke-Command -SessionName $SFModuleSession -ScriptBlock {
            $AssemblyList = "Microsoft.SqlServer.Management.Common", "Microsoft.SqlServer.Smo", "Microsoft.SqlServer.Management.Smo"
            foreach ($Assembly in $AssemblyList) {
                $AssemblyLoad = [Reflection.Assembly]::LoadWithPartialName($Assembly) 
            }
        }
        $AssemblyList = "Microsoft.SqlServer.Management.Common", "Microsoft.SqlServer.Smo", "Microsoft.SqlServer.Management.Smo"
        foreach ($Assembly in $AssemblyList) {
            $AssemblyLoad = [Reflection.Assembly]::LoadWithPartialName($Assembly) 
        }
        $SQLSSRSServer = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $ReportServerServerName 
        $SystemDatabasesWithIssues = 0
        $SystemDatabasesAccessible = 0

        foreach ($database in $SQLSSRSServer.Databases) {
            switch ($database) {
                { @("[model]", "[master]", "[msdb]", "[tempdb]") -contains $_ } {
                    if ($database.IsAccessible) {
                        $SystemDatabasesAccessible = $SystemDatabasesAccessible + 1
                    }
                    else {
                        $SystemDatabasesWithIssues = $SystemDatabasesWithIssues + 1
                    }
                }
                "[DynamicsAxReportServer]" {
                    switch ($database.IsAccessible) {
                        "True" { $dbstatus = "Online" }
                        "False" { $dbstatus = "Offline" }
                    }
                    $Properties = @{'Object' = "SSRSDatabase"
                        'Details'            = $database.name
                        'Status'             = "$dbstatus" 
                        'Source'             = $ReportServerServerName
                    }
                    New-Object -TypeName psobject -Property $Properties
                }
                "[DynamicsAxReportServerTempDB]" {
                    switch ($database.IsAccessible) {
                        "True" { $dbstatus = "Online" }
                        "False" { $dbstatus = "Offline" }
                    }
                    $Properties = @{'Object' = "SSRSTempDBDatabase"
                        'Details'            = $database.name
                        'Status'             = "$dbstatus" 
                        'Source'             = $ReportServerServerName
                    }
                    New-Object -TypeName psobject -Property $Properties
                }
                Default {}
            }
        }
        if ($SystemDatabasesWithIssues -eq 0) {
            $Properties = @{'Object' = "SSRSSystemDatabasesDatabase"
                'Details'            = "$SystemDatabasesAccessible databases are accessible"
                'Status'             = "Online" 
                'Source'             = $ReportServerServerName
            }
            New-Object -TypeName psobject -Property $Properties
        }
        else {
            $Properties = @{'Object' = "SSRSSystemDatabasesDatabase"
                'Details'            = "$SystemDatabasesAccessible databases are accessible. $SystemDatabasesWithIssues are not accessible"
                'Status'             = "Offline" 
                'Source'             = $ReportServerServerName
            }
            New-Object -TypeName psobject -Property $Properties
        }
    }
    END {
    }
}