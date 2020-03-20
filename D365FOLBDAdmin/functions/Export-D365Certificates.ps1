function Export-D365Certificates {
    <#
   .SYNOPSIS
  Looks inside the agent share extracts the version from the zip by using the custom module name. Puts an xml in root for easy idenitification
  .DESCRIPTION
   Exports 
  .EXAMPLE
  Export-D365FOLBDAssetModuleVersio

  .EXAMPLE
   Export-D365FOLBDAssetModuleVersion

  .PARAMETER AgentShare
  optional string 
   The location of the Agent Share
  .PARAMETER CustomModuleName
  optional string 
  The name of the custom module you will be using to capture the version number

  #>
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$CertThumbprint,
        [Parameter(Mandatory = $true)]
        [string]$ExportLocation,
        [string]$Username
    )
    ##Export
    $cert = $CertThumbprint
    mkdir $ExportLocation
if ($Username)
{
    $Username = whoami
}
    try {
        Get-ChildItem "Cert:\localmachine\my" | Where-Object { $_.Thumbprint -eq $cert } | ForEach-Object -Process { Export-PfxCertificate -Cert $_ -FilePath $("$ExportLocation\" + $_.FriendlyName + ".pfx") -ProtectTo "$Username" }
    }
    catch {
        try {
            Get-ChildItem "Cert:\CurrentUser\my" | Where-Object { $_.Thumbprint -eq $cert } | ForEach-Object -Process { Export-PfxCertificate -Cert $_ -FilePath $("$ExportLocation\" + $_.FriendlyName + ".pfx") -ProtectTo "$Username" }
        }
        catch {
            Write-PSFMessage -Level Verbose "Can't Export Certificate"
            $_
        }
    }
}