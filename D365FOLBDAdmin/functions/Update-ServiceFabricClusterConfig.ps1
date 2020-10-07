function Update-ServiceFabricClusterConfig {
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
        $SFFolder = Get-ChildItem "\\$OrchestratorServerName\C$\ProgramData\SF\*\Fabric\work\Applications\__FabricSystem\_App*\work\Store\*\$SFNumber"
        $SFCab = Get-ChildItem $SFFolder 
        Copy-Item -Path $SFCab.FullName -Destination $Workingfolder\MicrosoftAzureServiceFabric.cab
        
        try {
            Write-PSFMessage -Message "Trying to connect to $ConnectionEndpoint using $ServerCertificate" -Level Verbose
            $SFModuleSession = New-PSSession -ComputerName $OrchestratorServerName
            $module = Import-Module -Name ServiceFabric -PSSession $SFModuleSession 
            $connection = Connect-ServiceFabricCluster -ConnectionEndpoint $ConnectionEndpoint -X509Credential -FindType FindByThumbprint -FindValue $ServerCertificate -ServerCertThumbprint $ServerCertificate -StoreLocation LocalMachine -StoreName My
            Get-ServiceFabricClusterConfiguration -UseApiVersion -ApiVersion 10-2017 >$Workingfolder\ClusterConfig.json
            Write-PSFMessage -Level Verbose -Message "$Workingfolder\ClusterConfig.json Created Need to modify this JSON then run Start-ServiceFabricClusterConfigrationUpgrade"
            if ($config.$invalidnodes)
            {
                Write-PSFMessage -Message "Warning: Suggest removing invalid Node(s) $invalidnodes" -Level Warning
                Write-PSFMessage -Message "Warning: Make sure to remove the ""WindowsIdentities"" $$id 3 area " -Level Warning
            }
        }
        catch {
            Write-PSFMessage -message "Can't Connect to Service Fabric $_" -Level Verbose
        }
    }
    end {

    }
}