function Export-D365LBDAssetModuleVersion {
    <#
    .SYNOPSIS 
   Exports the version inside downloaded assets of the custom module name and also creates an xml in root for easy idenitification
   .DESCRIPTION
    Looks inside the agent share then extracts the version from the zip by using the custom module name. 
   Exports the version and also creates an xml in root for easy idenitification. 
   This is also a way to determine if a build has been fully prepped.
   .EXAMPLE
   Export-D365LBDAssetModuleVersion
 Exports all the assets in the agent share on the specified configurations environment
   .EXAMPLE
   $config = get-d365Config
    Export-D365LBDAssetModuleVersion -config $Config
    Exports all the assets in the agent share on the specified configurations environment
   .PARAMETER AgentShareLocation
   optional string 
    The location of the Agent Share
   .PARAMETER CustomModuleName
   optional string 
   The name of the custom module you will be using to capture the version number
   .PARAMETER Timeout
    Integer 
    Timeout in seconds for how long for the command to run has a default of 120 seconds
   #>
    [alias("Export-D365FOLBDAssetModuleVersion", "Export-D365AssetModuleVersion")]
    [CmdletBinding()]
    param
    (
        [Alias('AgentShare')]
        [string]$AgentShareLocation,
        [string]$CustomModuleName,
        [Parameter(ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True,
            Mandatory = $false,
            HelpMessage = 'D365FO Local Business Data Server Name')]
        [PSFComputer]$ComputerName = "$env:COMPUTERNAME",
        [Parameter(ValueFromPipeline = $True)]
        
        
        [int]$Timeout = 120
        
    ) BEGIN {
    } 
    PROCESS {
        if ($Config) {
            $AgentShareLocation = $Config.AgentShareLocation
        }
        if (!$AgentShareLocation) {
            if ($CustomModuleName){
                Write-PSFMessage -Level VeryVerbose -Message "Connecting to $ComputerName to get config"
                $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly -custommoduleName $CustomModuleName
            }
            
            $AgentShareLocation = $Config.AgentShareLocation
        }
        if (!$CustomModuleName) {
            if ($Config.CustomModuleName) {
                $CustomModuleName = $Config.CustomModuleName
                if ($CustomModuleName){
                    $Config = Get-D365LBDConfig -ComputerName $ComputerName -HighLevelOnly -custommoduleName $CustomModuleName
                }
            }
            else {
                Stop-PSFFunction -Message "Error: Custom Module Name must be defined in parameter or in config." -EnableException $true -FunctionName $_
            }
        }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $Filter = "*/Apps/AOS/AXServiceApp/AXSF/InstallationRecords/MetadataModelInstallationRecords/$CustomModuleName*.xml"
        $AssetFolders = Get-ChildItem "$AgentShareLocation\assets" | Where-Object { $_.Name -ne "topology.xml" -and $_.Name -ne "chk" } | Sort-Object LastWriteTime -Descending

        foreach ($AssetFolder in $AssetFolders ) {
            Write-PSFMessage -Message "Checking $AssetFolder" -Level Verbose
            $versionfile = $null
            $invalidfile = $false
            $versionfilepath = $AssetFolder.FullName + "\$CustomModuleName*.xml"
            $versionfile = Get-ChildItem -Path $versionfilepath
            if (($null -eq $versionfile) -or !($versionfile)) {
                ##SpecificAssetFolder which will be output
                $SpecificAssetFolder = $AssetFolder.FullName
                ##StandAloneSetupZip path to the zip that will be looked into for the module
                $StandaloneSetupZip = Get-ChildItem $SpecificAssetFolder\*\*\Packages\*\StandaloneSetup.zip
                $job = $null
                
                $job = start-job -ScriptBlock { Add-Type -AssemblyName System.IO.Compression.FileSystem; $zip = [System.IO.Compression.ZipFile]::OpenRead($using:StandaloneSetupZip) } -ErrorAction SilentlyContinue
           
                if (Wait-Job $job -Timeout $Timeout) { Receive-Job $job -ErrorAction SilentlyContinue }else {
                    Write-PSFMessage -Level VeryVerbose -message "Invalid Zip file $StandaloneSetupZip."
                    $invalidfile = $true
                    stop-job $job
                }
                if ($invalidfile -eq $false) {
                    $zip = [System.IO.Compression.ZipFile]::OpenRead($StandaloneSetupZip)
                    $count = $($zip.Entries | Where-Object { $_.FullName -like $Filter }).Count
                }
                else {
                    $count = 0
                }

                Remove-Job $job -Force
                
                if ($count -eq 0) {
                    Write-PSFMessage -Level Verbose -Message "Invalid Zip file or Module name $StandaloneSetupZip"
                }
                else {
                    try {
                        $zip.Entries | 
                        Where-Object { $_.FullName -like $Filter } |
                        ForEach-Object { 
                            # extract the selected items from the ZIP archive
                            # and copy them to the out folder
                            $FileName = $_.Name
                            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, "$SpecificAssetFolder\$FileName") 
                        } -ErrorAction Continue
                    }
                    catch {
                        Write-PSFMessage -Message "$_" -Level VeryVerbose
                    }
                    finally {
                        $zip.Dispose()
                    }
                    ##Closes Zip
                    $NewfileWithoutVersionPath = $SpecificAssetFolder + "\$CustomModuleName.xml"
                    Write-PSFMessage -Message "$SpecificAssetFolder\$FileName exported" -Level Verbose

                    $NewfileWithoutVersion = Get-ChildItem "$NewfileWithoutVersionPath"
                    if (!$NewfileWithoutVersion) {
                        Write-PSFMessage -Message "Error Module not found" -ErrorAction Continue
                    }
                    [xml]$xml = Get-Content "$NewfileWithoutVersion"
                    $Version = $xml.MetadataModelInstallationInfo.Version
                    Rename-Item -Path $NewfileWithoutVersionPath -NewName "$CustomModuleName $Version.xml" -Verbose | Out-Null
                    Write-PSFMessage -Message "$CustomModuleName $Version.xml exported" -Level Verbose
                    Write-Output "$Version"
                    Write-PSFMessage -Message "Finished Prep at: $($StandaloneSetupZip.LastWriteTime)" -Level veryVerbose
                }
            }
        }
        if ($foundprepped -ne 1) {
            Write-PSFMessage -Level VeryVerbose -Message "No new version prepped trying to find latest" 
            $AssetFolders = Get-ChildItem "$AgentShareLocation\assets" | Where-Object { $_.Name -ne "topology.xml" -and $_.Name -ne "chk" } | Sort-Object CreationTime -Descending
            foreach ($Asset in $AssetFolders) {
                if ($foundprepped -ne 1) {
                    $versionlatest = Get-ChildItem "$($Asset.FullName)\$CustomModuleName*.xml"
                    if ($versionlatest) {
                        $StandaloneSetupZip = Get-ChildItem "$($Asset.FullName)\*\*\Packages\*\StandaloneSetup.zip"
                        Write-PSFMessage -Message "Last Version: $($versionlatest.BaseName) " -Level veryVerbose
                        Write-PSFMessage -Message "Finished Prep at: $($StandaloneSetupZip.LastWriteTime)" -Level veryVerbose
                        $foundprepped = 1
                    }
                }
            }
        }
    }
    END {}
}