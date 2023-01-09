function New-D365MSSQLSelfCert {
    <#
    .SYNOPSIS
    Creates new self signed certificates on each MS SQL database server and exports the PFX file
   .DESCRIPTION
    Creates new self signed certificates on each MS SQL database server and exports the PFX file
    .EXAMPLE 
    $Certs = New-D365MSSQLSelfCert -config $Config -CertPassword 'StrongFakePass123'
   .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module
   #>
    [alias("New-MSSQLSelfCert")]
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name',
            ParameterSetName = 'NoConfig')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ParameterSetName = 'Config',
            ValueFromPipeline = $True)]
        [psobject]$Config,
        [string]$CertPassword
    )
    ##Gather Information from the Dynamics 365 Orchestrator Server Config
    BEGIN {
    } 
    PROCESS {
        if (!$Config -or $Config.OrchestratorServerNames.Count -eq 0) {
            Write-PSFMessage -Level VeryVerbose -Message "Config not defined or Config is invalid. Trying to Get new config using $ComputerName"
            $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly
        }
        ##
        <# Source: https://stackoverflow.com/questions/8423541/how-do-you-run-a-sql-server-query-from-powershell
#>
        function Invoke-SQL {
            param(
                [string] $dataSource = ".\SQLEXPRESS",
                [string] $database = "MasterData",
                [string] $sqlCommand = $(throw "Please specify a query.")
            )

            $connectionString = "Data Source=$dataSource; " +
            "Integrated Security=SSPI; " +
            "Initial Catalog=$database"

            $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
            $command = new-object system.data.sqlclient.sqlcommand($sqlCommand, $connection)
            $connection.Open()
    
            $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
            $dataset = New-Object System.Data.DataSet

            $adapter.Fill($dataSet) | Out-Null
            $connection.Close()
            $dataSet.Tables
        }

        $Listener = $Config.AXDatabaseServer

        foreach ($SQLServer in $Config.DatabaseClusterServerNames) {
            try {
                $InstanceNameSQLResults = Invoke-SQL -dataSource $sqlserver -database 'master' -sqlCommand 'SELECT @@SERVICENAME as ''Servicename'' '
            }
            catch {}
            try {
                $ProductVersionSQLResults = Invoke-SQL -dataSource $sqlserver -database 'master' -sqlCommand 'SELECT SERVERPROPERTY(''Productversion'') as ''Productversion'' '
                [string]$SQLMajorVersionNumber = $($ProductVersionSQLResults | select Productversion).Productversion
                $SQLMajorVersionNumber = $SQLMajorVersionNumber.Substring(0, 2)
            }
            catch {}
            if (!$InstanceNameSQLResults) {
                Write-PSFMessage -Level Error -Message "Check SQL DB Permissions"
            }

            $InstanceName = $($InstanceNameSQLResults | Select Servicename).Servicename
            $SQLVersionandInstance = 'MSSQL' + $SQLMajorVersionNumber + '.' + $InstanceName

            try {
                $SQLCert = $null
                $SQLCert = Invoke-Command -ScriptBlock {
                    if (!$SQLVersionandInstance) {
                        $SQLVersionandInstance = $using:SQLVersionandInstance
                    }
                    $cert = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SQL Server\$SQLVersionandInstance\MSSQLSERVER\SuperSocketNetLib"
                    $cert.Certificate.ToUpper()
                } -ComputerName $SQLServer -ErrorAction Stop
            }
            catch {
                $WhoAmI = whoami
                Write-PSFMessage -Level Warning -Message "Warning: Can't Connect to $SQLServer registry with account $WhoAmI to gather SQL Certificate Encryption Details"
            }
            Write-PSFMessage -Level Verbose -Message "$SQLServer is currently using $SQLCert"

            $NewCert = Invoke-Command -ScriptBlock {
                $ComputerName = $env:COMPUTERNAME.ToLower()
                $Domain = $env:USERDNSDOMAIN.ToLower()
                $ListenerName = $using:Listener
                $NewCertInside = New-SelfSignedCertificate -Subject "$ComputerName.$Domain" -DnsName "$ListenerName.$Domain", $Listener, $ComputerName -Provider 'Microsoft Enhanced RSA and AES Cryptographic Provider'

                if (!(test-path -PathType Container "C:\certs")) {
                    $certdir = mkdir "C:\certs"
                }
                $Thumbprint = $NewCertInside.Thumbprint
                $CertSecurePass = ConvertTo-SecureString -String $using:CertPassword -AsPlainText -Force
                $CertInsideLocalStore = Get-ChildItem -path Cert:\LocalMachine\My\$Thumbprint
                Export-PfxCertificate -Cert $CertInsideLocalStore -FilePath "C:\certs\$($CertInsideLocalStore.Thumbprint).pfx" -Force -Verbose -Password $CertSecurePass
                $CertInsideLocalStore
            } -ComputerName $SQLServer
            if (!(test-path -PathType Container "C:\certs")) {
                $certdir = mkdir "C:\certs"
            }
            [string]$NewCertThumbprint = $($NewCert.Thumbprint)
            $NewCertThumbprint = $NewCertThumbprint.Trim()
            $Source = "\\$SqlServer\C$\certs\" + $NewCertThumbprint + ".pfx"
            $Destination = "C:\certs\" + $NewCertThumbprint + ".pfx"
            Copy-Item $Source -Destination $Destination -Verbose
        }
    }
    END {}
}