function Get-D365LBDDependencyHealth {
    <#
    .SYNOPSIS
   
   .DESCRIPTION

   .EXAMPLE
    Export-D365LBDConfigReport

   .EXAMPLE
   Export-D365LBDConfigReport -computername 'AXSFServer01'
  
   .PARAMETER ComputerName
   String
   The name of the D365 LBD Server to grab the environment details; needed if a config is not specified and will default to local machine.
   .PARAMETER Config
    Custom PSObject
    Config Object created by either the Get-D365LBDConfig or Get-D365TestConfigData function inside this module


   #>
    [alias("Get-D365DependencyHealth")]
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
        [string]$CustomModuleName
    )
    ##Gather Information from the Dynamics 365 Orchestrator Server Config
    BEGIN {
    } 
    PROCESS {
        if (!$Config) {
            if ($CustomModuleName) {
                $Config = Get-D365LBDConfig -ComputerName $ComputerName -CustomModuleName $CustomModuleName -highlevelonly
            }
            else {
                $Config = Get-D365LBDConfig -ComputerName $ComputerName -highlevelonly
            }
        }
        $AgentShareLocation = $config.AgentShareLocation 
        $EnvironmentAdditionalConfig = get-childitem  "\\$AgentShareLocation\scripts\D365FOLBDAdmin\AdditionalEnvironmentDetails.xml"
        [xml]$EnvironmentAdditionalConfigXML = get-content  $EnvironmentAdditionalConfig

        ##checking WebURLS
        $EnvironmentAdditionalConfigXML.D365LBDEnvironment.Dependencies.CustomWebURLDependencies.CustomWebURL | ForEach-Object -Process { 
            if ($_.Type.'#text'.Trim() -eq 'Basic') {
                $results = Invoke-WebRequest -Uri $_.uri -UseBasicParsing
                if ($results.statusCode -eq 200) {
                    New-Object -TypeName PSObject -Property `
                    @{'CustomWebURL'     = $_.uri ;
                        'DependencyType' = "Web Service/Page"
                        'Location'       = "Web Service/Page"; 
                        'State'          = "Down";
                        'ExtraInfo'      = $results.Statuscode
                    }
                }
                else {
                    New-Object -TypeName PSObject -Property `
                    @{'CustomWebURL'     = $_.uri ;
                        'DependencyType' = "Web Service/Page"
                        'Location'       = "Web Service/Page"; 
                        'State'          = "Operational";
                        'ExtraInfo'      = $results.Statuscode
                    }
                }
            }
            else {
                $childnodes = $($_.AdvancedCustomSuccessResponse | Select-Object childnodes).childnodes
                $properties = $childnodes | Get-Member -MemberType Property
                $propertiestocheck = $properties.Name
                $results = Invoke-RestMethod -Uri $_.uri -UseBasicParsing
                foreach ($property in $propertiestocheck) {
                    $diff = compare-object $results.data.$property -DifferenceObject $childnodes.$property.trim()
                    if ($diff) {
                        Write-PSFMessage -message "Found differences $diff" -Level VeryVerbose
                        New-Object -TypeName PSObject -Property `
                        @{'CustomWebURL'     = $_.uri ;
                            'DependencyType' = "Web Service/Page"
                            'Location'       = "Web Service/Page"; 
                            'State'          = "Down";
                            'ExtraInfo'      = $results.Statuscode
                        }
                    }
                    else {
                        New-Object -TypeName PSObject -Property `
                        @{'CustomWebURL'     = $_.uri ;
                            'DependencyType' = "Web Service/Page"
                            'Location'       = "Web Service/Page"; 
                            'State'          = "Operational";
                            'ExtraInfo'      = $results.Statuscode
                        }
                    }
                }
            }
        }
        
    }
    END {}
}
