function Export-D365LBDAssetModuleVersion {
    <#
    .SYNOPSIS
   Looks inside the agent share extracts the version from the zip by using the custom module name. Puts an xml in root for easy idenitification
   .DESCRIPTION
    Exports 
   .EXAMPLE
   Export-D365LBDAssetModuleVersion
 
   .EXAMPLE
    Export-D365LBDAssetModuleVersion

   .PARAMETER AgentShare
   optional string 
    The location of the Agent Share
   .PARAMETER CustomModuleName
   optional string 
   The name of the custom module you will be using to capture the version number

   #>
    [alias("Export-D365FOLBDAssetModuleVersion","Export-D365AssetModuleVersion")]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$AgentShare,
        [Parameter(Mandatory = $true)]
        [string]$CustomModuleName
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $Filter = "*/Apps/AOS/AXServiceApp/AXSF/InstallationRecords/MetadataModelInstallationRecords/$ModuleName*.xml"
    $AssetFolders = Get-ChildItem "$AgentShare\assets" | Where-Object { $_.Name -ne "topology.xml" -and $_.Name -ne "chk" } | Sort-Object LastWriteTime 

    foreach ($AssetFolder in $AssetFolders ) {
        $versionfile = $null
        $versionfilepath = $AssetFolder.FullName + "\$ModuleName*.xml"
        $versionfile = Get-ChildItem -Path $versionfilepath
        if (($null -eq $versionfile) -or !($versionfile)) {
            ##SpecificAssetFolder which will be output
            $SpecificAssetFolder = $AssetFolder.FullName
            ##StandAloneSetupZip path to the zip that will be looked into for the module
            $StandaloneSetupZip = Get-ChildItem $SpecificAssetFolder\*\*\Packages\*\StandaloneSetup.zip

            $zip = [System.IO.Compression.ZipFile]::OpenRead($StandaloneSetupZip)
            $count = $($zip.Entries | Where-Object { $_.FullName -like $Filter }).Count

            if ($count -eq 0) {
                Write-PSFMessage -Level Verbose -Message "Invalid Zip file or Module name $StandaloneSetupZip"
            }
            else {
                $zip.Entries | 
                Where-Object { $_.FullName -like $Filter } |
                ForEach-Object { 
                    # extract the selected items from the ZIP archive
                    # and copy them to the out folder
                    $FileName = $_.Name
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, "$SpecificAssetFolder\$FileName") 
                }
                ##Closes Zip
                $zip.Dispose()
                $NewfileWithoutVersionPath = $SpecificAssetFolder + "\$ModuleName.xml"
                Write-PSFMessage -Message "$SpecificAssetFolder\$FileName exported" -Level Verbose

                $NewfileWithoutVersion = Get-ChildItem "$NewfileWithoutVersionPath"
                if (!$NewfileWithoutVersion) {
                    Write-PSFMessage -Message "Error Module not found" -ErrorAction Continue
                }
                [xml]$xml = Get-Content "$NewfileWithoutVersion"
                $Version = $xml.MetadataModelInstallationInfo.Version
                Rename-Item -Path $NewfileWithoutVersionPath -NewName "$ModuleName $Version.xml" -Verbose | Out-Null
                Write-PSFMessage -Message "$ModuleName $Version.xml exported" -Level Verbose
                Write-Output "$Version"
            }
        }
    }
}