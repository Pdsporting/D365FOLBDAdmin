function Update-ServiceFabricD365ClusterConfig {
    <#
   .SYNOPSIS
  todo not working yet

  .DESCRIPTION
   Connect-ServiceFabricAutomatic

  .EXAMPLE
  Connect-ServiceFabricAutomatic

  .EXAMPLE
  Connect-ServiceFabricAutomatic

  .PARAMETER Config
  optional custom object generated from Get-D365LBDConfig 
  #>
    param
    (
        [Parameter(Mandatory = $false)]
        [psobject]$Config,
        [string]$Workingfolder = "C:\temp"

    )
    BEGIN {
        if ((!$Config)) {
            Write-PSFMessage -Message "No paramters selected will try and get config" -Level Verbose
            $Config = Get-D365LBDConfig
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