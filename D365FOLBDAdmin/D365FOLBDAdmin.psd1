@{
	# Script module or binary module file associated with this manifest
	RootModule = 'D365FOLBDAdmin.psm1'
	
	# Version number of this module.
	ModuleVersion = '1.0.0'
	
	# ID used to uniquely identify this module
	GUID = '7ddad589-c6ec-443f-a365-7b3055e14d12'
	
	# Author of this module
	Author = 'StefanRLand'
	
	# Company or vendor of this module
	CompanyName = 'Off and On IT'
	
	# Copyright statement for this module
	Copyright = 'Copyright (c) 2019 StefanRLand Off and On IT'
	
	# Description of the functionality provided by this module
	Description = 'For Dynamics 365 Finance and Operations Local Business Data (LBD) Administration'
	
	# Minimum version of the Windows PowerShell engine required by this module
	PowerShellVersion = '5.0'
	
	# Modules that must be imported into the global environment prior to importing
	# this module
	RequiredModules = @(
		@{ ModuleName='PSFramework'; ModuleVersion='1.1.59' }
	)
	
	# Assemblies that must be loaded prior to importing this module
	# RequiredAssemblies = @('bin\D365FOLBDAdmin.dll')
	
	# Type files (.ps1xml) to be loaded when importing this module
	# TypesToProcess = @('xml\D365FOLBDAdmin.Types.ps1xml')
	
	# Format files (.ps1xml) to be loaded when importing this module
	# FormatsToProcess = @('xml\D365FOLBDAdmin.Format.ps1xml')
	
	# Functions to export from this module
	FunctionsToExport = @(
		'Get-D365LBDConfig',
		'Start-D365LBDDBSync',
		'Export-D365LBDAssetModuleVersion',
		'Get-D365LBDOrchestrationLogs',
		'Get-D365LBDOrchestrationNodes',
		'Remove-D365LBDStuckApps',
		'Export-D365LBDCertificates',
		'Import-D365LBDCertificates',
		'Get-D365LBDCertsFromConfig',
		'Export-D365Certificates',
		'Get-D365LBDTestConfigData',
		'Start-MonitorD365Deployment',
		'Add-D365LBDDataEnciphermentCertConfig',
		"New-D365LBDAXSFNode",
		"Update-ServiceFabricD365ClusterConfig",
		"Get-D365LBDDBEvents",
		'Add-D365LBDDatabaseDetailsandCert',
		'Enable-D365LBDSFAppServers',
		'Disable-D365LBDSFAppServers',
		'Export-D365LBDConfigReport',
		'Restart-D365LBDSFAppServers',
		'Set-D365LBDOptions',
		'Get-D365LBDEnvironmentHealth',
		'Remove-D365LBDSFOldAssets',
		'Remove-D365LBDSFLogs',
		'Send-D365LBDUpdateMSTeams',
		'Get-D365LBDDependencyHealth'
		)
	# Cmdlets to export from this module
	CmdletsToExport = ''
	
	# Variables to export from this module
	VariablesToExport = ''
	
	# Aliases to export from this module
	AliasesToExport = @('Add-D365DataEnciphermentCertConfig',
	"Export-D365AssetModuleVersion",
	"Export-D365FOLBDAssetModuleVersion", 
	"Get-D365CertsFromConfig",
	"Get-D365Config",
	"Get-D365OrchestrationLogs",
	"Get-D365OrchestrationNodes",
	"Get-D365TestConfigData",
	"Import-D365LBDCertificates"
	"New-D365AXSFNode",
	"Remove-D365StuckApps",
	"Remove-D365SFOldAssets",
	"Start-D365DBSync",
	"Start-D365FOLBDDBSync",
	"Get-D365DBEvents",
	'Add-D365DatabaseDetailsandCert',
	'Disable-D365SFAppServers',
	'Enable-D365SFAppServers',
	'Set-D365PreDeploymentOptions',
	'Remove-D365SFOldAssets',
	'Remove-D365SFLogs',
	'Send-D365UpdateMSTeams',
	'Get-D365DependencyHealth')
	
	# List of all modules packaged with this module
	ModuleList = @()
	
	# List of all files packaged with this module
	FileList = @()
	
	# Private data to pass to the module specified in ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
	PrivateData = @{
		
		#Support for PowerShellGet galleries.
		PSData = @{
			
			# Tags applied to this module. These help with module discovery in online galleries.
			 Tags = @('D365','D365F&O','LBD','D365LBD')
			
			# A URL to the license for this module.
			 LicenseUri = 'https://github.com/stefanland/D365FOLBDAdmin/blob/master/LICENSE'
			
			# A URL to the main website for this project.
			 ProjectUri = 'https://github.com/stefanland/D365FOLBDAdmin'
			
			# A URL to an icon representing this module.
			 IconUri = 'https://offandonit.com/favicon.png'

             #HelpInfoUri = 'https://offandonit.com/tag/d365folbdadmin'
			
			# ReleaseNotes of this module
			# ReleaseNotes = ''
			
		} # End of PSData hashtable
		
	} # End of PrivateData hashtable
}