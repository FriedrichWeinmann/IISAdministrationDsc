[DscResource()]
class IISConfigAttribute {
	#region DSC Properties
	<#
	The properties you can define in configuration settings.
	The [DscProperty(...)] attribute has a few possible values:
	- <empty>: Nothing specified makes this an optional property you can leave empty when defining the configuration setting.
	- Mandatory: A Property that MUST be set when defining the configuration setting.
	- Key: The property is considered as the identifier for the resource modified. It is mandatory AND there cannot be multiple configuration entries with the same value for this property!
	- NotConfigurable: ReadOnly property. Mostly used for integration into Azure Guest Configurations

	Example Properties:

    [DscProperty(Key)]
    [string]$Path

    [DscProperty(Mandatory)]
    [string]$Text
	#>

	[DscProperty(Mandatory, Key)]
	[string] $SectionPath
	
	[DscProperty(Key)]
	[string] $Site

	[DscProperty(Key)]
	[string] $Path

	[DscProperty(Mandatory, Key)]
	[string] $AttributeName
		
	[DscProperty(Mandatory)]
	[string] $AttributeValue

	[DscProperty()]
	[Ensure]$Ensure = 'Present'

	[DscProperty(NotConfigurable)]
	[Reason[]] $Reasons # Reserved for Azure Guest Configuration
	#endregion DSC Properties

	[object] GetValue() {
		return $this.AttributeValue | ConvertFrom-Json
	}

	[void]Set() {
		# Apply Desired State
		$currentElement = $this.GetElement()
		if ($null -eq $currentElement) { throw 'Element not found: {0} > {1} > {2}' -f $this.SectionPath, $this.Site, $this.Path }

		Set-IISConfigAttributeValue -ConfigElement $currentElement -AttributeName $this.AttributeName -AttributeValue $this.GetValue().PSObject.BaseObject
	}

	[IISConfigAttribute]Get() {
		# Return current actual state
		$currentConfig = $this.GetElement()
		$current = [IISConfigAttribute]::new()
		$current.SectionPath = $this.SectionPath
		$current.Site = $this.Site
		$current.Path = $this.Path
		$current.AttributeName = $this.AttributeName
		$current.AttributeValue = @($currentConfig.Attributes).Where{ $_.Name -eq $this.AttributeName }.Value
		$current.Ensure = 'Present'
		if (-not $currentConfig) { $current.Ensure = 'Absent' }
		return $current
	}

	[bool]Test() {
		# Check whether current state = desired state
		$current = $this.Get()

		return (
			$this.Ensure -eq $current.Ensure -and
			$this.GetValue() -eq $current.AttributeValue
		)
	}

	[object]GetElement() {
		$pathElements = $this.Path -split '/'

		$param = @{
			SectionPath = $this.SectionPath
		}
		try {
			if ($this.Site -and $this.SectionPath -notlike 'system.applicationHost/*') { $param.CommitPath = $this.Site }
			$currentConfig = Get-IISConfigSection @param
			if ($this.SectionPath -eq 'system.applicationHost/sites' -and $this.Site) {
				$collection = Get-IISConfigCollection -ConfigElement $currentConfig
				$currentConfig = Get-IISConfigCollectionElement -ConfigCollection $collection -ConfigAttribute @{ name = $this.Site }
			}
			foreach ($pathElement in $pathElements) {
				if (-not $pathElement) { continue }
				$currentConfig = Get-IISConfigElement -ConfigElement $currentConfig -ChildElementName $pathElement
			}
		}
		catch { return $null }
		return $currentConfig
	}

	[Hashtable] GetConfigurableDscProperties() {
		# This method returns a hashtable of properties with two special workarounds
		# The hashtable will not include any properties marked as "NotConfigurable"
		# Any properties with a ValidateSet of "True","False" will beconverted to Boolean type
		# The intent is to simplify splatting to functions
		# Source: https://gist.github.com/mgreenegit/e3a9b4e136fc2d510cf87e20390daa44
		$dscProperties = @{}
		foreach ($property in [IISConfigAttribute].GetProperties().Name) {
			# Checks if "NotConfigurable" attribute is set
			$notConfigurable = [IISConfigAttribute].GetProperty($property).GetCustomAttributes($false).Where({ $_ -is [System.Management.Automation.DscPropertyAttribute] }).NotConfigurable
			if (!$notConfigurable) {
				$value = $this.$property
				# Gets the list of valid values from the ValidateSet attribute
				$validateSet = [IISConfigAttribute].GetProperty($property).GetCustomAttributes($false).Where({ $_ -is [System.Management.Automation.ValidateSetAttribute] }).ValidValues
				if ($validateSet) {
					# Workaround for boolean types
					if ($null -eq (Compare-Object @('True', 'False') $validateSet)) {
						$value = [System.Convert]::ToBoolean($this.$property)
					}
				}
				# Add property to new
				$dscProperties.add($property, $value)
			}
		}
		return $dscProperties
	}
}