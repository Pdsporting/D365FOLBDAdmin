function Update-ServiceFabricD365ClusterConfig {
    <#
    .SYNOPSIS
  
   .DESCRIPTION
   
   .EXAMPLE
   Disable-D365LBDSFAppServers
  
   .EXAMPLE
    Disable-D365LBDSFAppServers -ComputerName "LBDServerName" -verbose
   
   .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module

   #>
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ParameterSetName = 'Config',
            ValueFromPipeline = $True)]
        [psobject]$Config,
        [string]$Workingfolder = "C:\temp"
    )
       
    BEGIN {
        if ((!$Config)) {
            Write-PSFMessage -Message "No paramters selected will try and get config" -Level Verbose
            $Config = Get-D365LBDConfig -ComputerName $ComputerName
        }  
    }
    PROCESS {
        $SFNumber = $Config.SFVersionNumber

        [int]$count = 1
        $OrchestratorServerName = $config.OrchestratorServerNames | Select-Object -First $count
        Write-PSFMessage -Message "Verbose: Reaching out to $OrchestratorServerName for service Fabric cab file version $SFNumber" -Level Verbose
        
        $SFFolder = get-childitem "\\$OrchestratorServerName\C$\ProgramData\SF\*\Fabric\work\Applications\__FabricSystem_App*\work\Store\*\$SFNumber"
      
        if (!$SFFolder) {
            do {
                $OrchestratorServerName = $config.OrchestratorServerNames | Select-Object -First $count
                Write-PSFMessage -Message "Verbose: Reaching out to $OrchestratorServerName for service Fabric cab file"  -Level Verbose
                $SFFolder = get-childitem "\\$OrchestratorServerName\C$\ProgramData\SF\*\Fabric\work\Applications\__FabricSystem_App*\work\Store\*\$SFNumber"
                $count = $count ++
                Write-PSFMessage -Message "Count of servers tried $count" -Verbose
            } until ($SFFolder -or ($count -eq $OrchestratorServerNames.Count))
        } 
     
        $SFCab = Get-ChildItem $SFFolder.FullName
        Copy-Item -Path $SFCab.FullName -Destination $Workingfolder\MicrosoftAzureServiceFabric.cab -Verbose
        
        try {
            Write-PSFMessage -Message "Trying to connect to $($config.SFConnectionEndpoint) using $($config.SFServerCertificate)" -Level Verbose
            $SFModuleSession = New-PSSession -ComputerName $OrchestratorServerName
            $module = Import-Module -Name ServiceFabric -PSSession $SFModuleSession 
            $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $config.SFConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $config.sfServerCertificate -ServerCertThumbprint $config.SFServerCertificate -StoreLocation LocalMachine -StoreName My
            Get-ServiceFabricClusterConfiguration -UseApiVersion -ApiVersion 10-2017 >$Workingfolder\ClusterConfig.json
            Write-PSFMessage -Level Verbose -Message "$Workingfolder\ClusterConfig.json Created Need to modify this JSON then run Start-ServiceFabricClusterConfigrationUpgrade"
            if ($config.InvalidSFServers) {
                Write-PSFMessage -Message "Warning: Suggest removing invalid Node(s) $($config.InvalidSFServers)" -Level Warning
                Write-PSFMessage -Message "Warning: Make sure to remove the ""WindowsIdentities"" $$id 3 area under security (if exists) " -Level Warning
            }

            $JSON = get-content $Workingfolder\ClusterConfig.json -raw | ConvertFrom-Json
            $versiontostring = $JSON.ClusterConfigurationVersion
            $version = [version]$versiontostring
            $versionincremented = [string][version]::new(
                $version.Major,
                $version.Minor,
                $version.Build + 1
            )
            Write-PSFMessage -Level Verbose -Message "Version updated from $versiontostring to $Versionincremented"
            foreach ($invalidnode in $config.InvalidSFServers) {
                $RemoveNodeJSON = @"
{
    "name":"NodesToBeRemoved",
    "value":"$invalidnode"
}                
"@
                $JSON.ClusterConfigurationVersion = $versionincremented
                $parameters = $JSON.Properties.FabricSettings.Parameters
                $parametersnew = $parameters + (ConvertFrom-Json $RemoveNodeJSON)
                $JSON.Properties.FabricSettings | Add-Member -type NoteProperty -name "Parameters" -Value $parametersnew -Force
                Write-PSFMessage -Level Verbose -Message "NodesToBeRemoved $invalidnode added to JSON"
            }
            $JSON | ConvertTo-Json -Depth 32 | Set-Content  $Workingfolder\ClusterConfig.json 
            Write-PSFMessage -Level VeryVerbose -Message "$Workingfolder\ClusterConfig.json updated and ready to be used."
        }
        catch {
            Write-PSFMessage -message "Can't Connect to Service Fabric $_" -Level Verbose
        }
    }
    end {

    }
}