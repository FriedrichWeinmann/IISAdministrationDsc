<#
This script publishes the module to the gallery.
It expects as input an ApiKey authorized to publish the module.

Insert any build steps you may need to take before publishing it here.
#>
param (
	$ApiKey,
	
	$WorkingDirectory,
	
	$Repository = 'PSGallery',

	$PublishPath,
	
	[switch]
	$LocalRepo,
	
	[switch]
	$SkipPublish,
	
	[switch]
	$AutoVersion
)

#region Handle Working Directory Defaults
if (-not $WorkingDirectory)
{
	if ($env:RELEASE_PRIMARYARTIFACTSOURCEALIAS)
	{
		$WorkingDirectory = Join-Path -Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY -ChildPath $env:RELEASE_PRIMARYARTIFACTSOURCEALIAS
	}
	else { $WorkingDirectory = $env:SYSTEM_DEFAULTWORKINGDIRECTORY }
}
if (-not $WorkingDirectory) { $WorkingDirectory = Split-Path $PSScriptRoot }
if (-not $PublishPath) { $PublishPath = Join-Path -Path $WorkingDirectory -ChildPath publish }
#endregion Handle Working Directory Defaults

# Prepare publish folder
Write-Host "Creating and populating publishing directory"
$publishDir = New-Item -Path $PublishPath -ItemType Directory -Force
Copy-Item -Path "$($WorkingDirectory)\IISAdministrationDsc" -Destination $publishDir.FullName -Recurse -Force

#region Gather text data to compile
$text = @('$script:ModuleRoot = $PSScriptRoot')

# Gather Classes
Get-ChildItem -Path "$($publishDir.FullName)\IISAdministrationDsc\internal\classes\" -Recurse -File -Filter "*.ps1" | ForEach-Object {
	$text += [System.IO.File]::ReadAllText($_.FullName)
}

# Gather DSC Resources
$resourceNames = Get-ChildItem -Path "$($publishDir.FullName)\IISAdministrationDsc\resources\" -Recurse -File -Filter "*.ps1" | ForEach-Object {
	$text += [System.IO.File]::ReadAllText($_.FullName) -replace '(?m)^using', '# using' # (?m) turns "^" into "Start of line", rather than "Start of text"
	$_.BaseName
}
Update-ModuleManifest -Path "$($publishDir.FullName)\IISAdministrationDsc\IISAdministrationDsc.psd1" -DscResourcesToExport @($resourceNames)

# Gather commands
Get-ChildItem -Path "$($publishDir.FullName)\IISAdministrationDsc\internal\functions\" -Recurse -File -Filter "*.ps1" | ForEach-Object {
	$text += [System.IO.File]::ReadAllText($_.FullName)
}
Get-ChildItem -Path "$($publishDir.FullName)\IISAdministrationDsc\functions\" -Recurse -File -Filter "*.ps1" | ForEach-Object {
	$text += [System.IO.File]::ReadAllText($_.FullName)
}

# Gather scripts
Get-ChildItem -Path "$($publishDir.FullName)\IISAdministrationDsc\internal\scripts\" -Recurse -File -Filter "*.ps1" | ForEach-Object {
	$text += [System.IO.File]::ReadAllText($_.FullName)
}

#region Update the psm1 file & Cleanup
[System.IO.File]::WriteAllText("$($publishDir.FullName)\IISAdministrationDsc\IISAdministrationDsc.psm1", ($text -join "`n`n"), [System.Text.Encoding]::UTF8)
Remove-Item -Path "$($publishDir.FullName)\IISAdministrationDsc\internal" -Recurse -Force
Remove-Item -Path "$($publishDir.FullName)\IISAdministrationDsc\functions" -Recurse -Force
Remove-Item -Path "$($publishDir.FullName)\IISAdministrationDsc\resources" -Recurse -Force
#endregion Update the psm1 file & Cleanup

#region Updating the Module Version
if ($AutoVersion)
{
	Write-Host  "Updating module version numbers."
	try { [version]$remoteVersion = (Find-Module 'IISAdministrationDsc' -Repository $Repository -ErrorAction Stop).Version }
	catch
	{
		throw "Failed to access $($Repository) : $_"
	}
	if (-not $remoteVersion)
	{
		throw "Couldn't find IISAdministrationDsc on repository $($Repository) : $_"
	}
	$newBuildNumber = $remoteVersion.Build + 1
	[version]$localVersion = (Import-PowerShellDataFile -Path "$($publishDir.FullName)\IISAdministrationDsc\IISAdministrationDsc.psd1").ModuleVersion
	Update-ModuleManifest -Path "$($publishDir.FullName)\IISAdministrationDsc\IISAdministrationDsc.psd1" -ModuleVersion "$($localVersion.Major).$($localVersion.Minor).$($newBuildNumber)"
}
#endregion Updating the Module Version

#region Cleanup Manifest for DSC
<#
Issue: https://github.com/PowerShell/PSDesiredStateConfiguration/issues/117
DSC Resources cannot be found, if Functions, Cmdlets AND Aliases are being exported, even if empty.
Update-ModuleManifest automatically defines them as problematic, hence manual override here
#>
$manifestHash = Import-PowerShellDataFile -Path "$($publishDir.FullName)\IISAdministrationDsc\IISAdministrationDsc.psd1"
$manifestText = [System.IO.File]::ReadAllText("$($publishDir.FullName)\IISAdministrationDsc\IISAdministrationDsc.psd1")

if ($manifestHash.ContainsKey('FunctionsToExport') -and -not $manifestHash.FunctionsToExport) {
	$manifestText = $manifestText -replace 'FunctionsToExport','# FunctionsToExport'
}
if ($manifestHash.ContainsKey('CmdletsToExport') -and -not $manifestHash.FunctionsToCmdletsToExportExport) {
	$manifestText = $manifestText -replace 'CmdletsToExport','# CmdletsToExport'
}
if ($manifestHash.ContainsKey('AliasesToExport') -and -not $manifestHash.AliasesToExport) {
	$manifestText = $manifestText -replace 'AliasesToExport','# AliasesToExport'
}

[System.IO.File]::WriteAllText("$($publishDir.FullName)\IISAdministrationDsc\IISAdministrationDsc.psd1", $manifestText, [System.Text.UTF8Encoding]::new($true))
#endregion Cleanup Manifest for DSC

#region Publish
if ($SkipPublish) { return }
if ($LocalRepo)
{
	# Dependencies must go first
	Write-Host  "Creating Nuget Package for module: PSFramework"
	New-PSMDModuleNugetPackage -ModulePath (Get-Module -Name PSFramework).ModuleBase -PackagePath .
	Write-Host  "Creating Nuget Package for module: IISAdministrationDsc"
	New-PSMDModuleNugetPackage -ModulePath "$($publishDir.FullName)\IISAdministrationDsc" -PackagePath .
}
else
{
	# Publish to Gallery
	Write-Host  "Publishing the IISAdministrationDsc module to $($Repository)"
	Publish-Module -Path "$($publishDir.FullName)\IISAdministrationDsc" -NuGetApiKey $ApiKey -Force -Repository $Repository
}
#endregion Publish