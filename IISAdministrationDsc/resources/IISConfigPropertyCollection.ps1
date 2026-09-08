[DscResource()]
class IISConfigPropertyCollection {
	#region DSC Properties
	<#
	The properties you can define in configuration settings.
	The [DscProperty(...)] attribute has a few possible values:
	- <empty>: Nothing specified makes this an optional property you can leave empty when defining the configuration setting.
	- Mandatory: A Property that MUST be set when defining the configuration setting.
	- Key: The property is considered as the identifier for the resource modified. It is mandatory AND there cannot be multiple configuration entries with the same value for this property!
	- NotConfigurable: ReadOnly property. Mostly used for integration into Azure Guest Configurations

	Example Properties:

<#
SectionPath: system.applicationHost/sites
ConfigAttribute: @{ name = 'Default Web Site' }
ElementName: 'limits'
AttributeName: 'MaxUrlSegments'
AttributeValue: 16
# >

$ConfigSection = Get-IISConfigSection -SectionPath 'system.applicationHost/sites'
$SitesCollection = Get-IISConfigCollection -ConfigElement $ConfigSection
$Site = Get-IISConfigCollectionElement -ConfigCollection $SitesCollection -ConfigAttribute @{
	'name' = 'Default Web Site'
}
$Elem = Get-IISConfigElement -ConfigElement $Site -ChildElementName 'limits'
Set-IISConfigAttributeValue -ConfigElement $Elem -AttributeName 'MaxUrlSegments' -AttributeValue 16
	#>
	[DscProperty(Mandatory, Key)]
	[string] $SectionPath
	
	[DscProperty(Mandatory)]
	[hashtable] $ConfigAttribute
	
	[DscProperty(Mandatory, Key)]
	[string] $ConfigID
		
	[DscProperty(Mandatory, Key)]
	[string] $ElementName
		
	[DscProperty(Mandatory, Key)]
	[string] $AttributeName
		
	[DscProperty(Mandatory)]
	[object] $AttributeValue

	[DscProperty(Mandatory)]
	[Ensure] $Ensure

	[DscProperty(NotConfigurable)]
	[Reason[]] $Reasons # Reserved for Azure Guest Configuration
	#endregion DSC Properties

	[void]Set() {
		# Apply Desired State
		try {
			$configSection = Get-IISConfigSection -SectionPath $this.SectionPath
			$collection = Get-IISConfigCollection -ConfigElement $configSection
			$colElement = Get-IISConfigCollectionElement -ConfigCollection $collection -ConfigAttribute $this.ConfigAttribute
			$element = Get-IISConfigElement -ConfigElement $colElement -ChildElementName $this.ElementName
			Set-IISConfigAttributeValue -ConfigElement $element -AttributeName $this.AttributeName -AttributeValue $this.AttributeValue
		}
		catch {
			throw $_
		}
	}

	[IISConfigPropertyCollection]Get() {
		# Return current actual state

		try {
			$configSection = Get-IISConfigSection -SectionPath $this.SectionPath
			$collection = Get-IISConfigCollection -ConfigElement $configSection
			$colElement = Get-IISConfigCollectionElement -ConfigCollection $collection -ConfigAttribute $this.ConfigAttribute
			$element = Get-IISConfigElement -ConfigElement $colElement -ChildElementName $this.ElementName
		}
		catch { $element = $null }

		$new = [IISConfigPropertyCollection]::new()
		$new.SectionPath = $this.SectionPath
		$new.ConfigAttribute = $this.ConfigAttribute
		$new.ConfigID = $this.ConfigID
		$new.ElementName = $this.ElementName
		$new.AttributeName = $this.AttributeName
		$new.AttributeValue = @($element.Attributes).Where{$_.Name -eq $this.AttributeName}.Value
		$new.Ensure = 'Present'
		if (-not $element) { $new.Ensure = 'Absent' }

		return $new
	}

	[bool]Test() {
		# Check whether current state = desired state
		$current = $this.Get()

		return (
			$this.Ensure -eq $current.Ensure -and
			$this.AttributeValue -eq $current.AttributeValue
		)
	}

	[Hashtable] GetConfigurableDscProperties() {
		# This method returns a hashtable of properties with two special workarounds
		# The hashtable will not include any properties marked as "NotConfigurable"
		# Any properties with a ValidateSet of "True","False" will beconverted to Boolean type
		# The intent is to simplify splatting to functions
		# Source: https://gist.github.com/mgreenegit/e3a9b4e136fc2d510cf87e20390daa44
		$dscProperties = @{}
		foreach ($property in [IISConfigPropertyCollection].GetProperties().Name) {
			# Checks if "NotConfigurable" attribute is set
			$notConfigurable = [IISConfigPropertyCollection].GetProperty($property).GetCustomAttributes($false).Where({ $_ -is [System.Management.Automation.DscPropertyAttribute] }).NotConfigurable
			if (!$notConfigurable) {
				$value = $this.$property
				# Gets the list of valid values from the ValidateSet attribute
				$validateSet = [IISConfigPropertyCollection].GetProperty($property).GetCustomAttributes($false).Where({ $_ -is [System.Management.Automation.ValidateSetAttribute] }).ValidValues
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