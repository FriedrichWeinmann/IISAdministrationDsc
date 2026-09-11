[DscResource()]
class IISConfigCollection {
	#region DSC Properties
	<#
	The properties you can define in configuration settings.
	The [DscProperty(...)] attribute has a few possible values:
	- <empty>: Nothing specified makes this an optional property you can leave empty when defining the configuration setting.
	- Mandatory: A Property that MUST be set when defining the configuration setting.
	- Key: The property is considered as the identifier for the resource modified. It is mandatory AND there cannot be multiple configuration entries with the same value for this property!
	- NotConfigurable: ReadOnly property. Mostly used for integration into Azure Guest Configurations
	#>
	[DscProperty(Mandatory, Key)]
	[string] $SectionPath
	
	[DscProperty(Key)]
	[string] $Site

	[DscProperty(Key)]
	[string] $Path
	
	[DscProperty(Mandatory, Key)]
	[string] $Name
	
	# PowerShell Code that will be passed to Where-Object to determine legal collection elements
	# E.g. '$false' (Empty Collection), '$_.Name -in "txt","json"' (Elements with name txt or json)
	[DscProperty(Mandatory)]
	[string] $Filter

	[DscProperty()]
	[Ensure] $Ensure = 'Present'

	[array] $Elements

	[DscProperty(NotConfigurable)]
	[Reason[]] $Reasons # Reserved for Azure Guest Configuration
	#endregion DSC Properties

	[void]Set() {
		# Apply Desired State
		if ($this.Test()) { return }

		$parent = $this.GetElement()
		if (-not $parent) {
			throw "Parent Element of collection $($this.Name) does not exist: '$($this.SectionPath) > $($this.Site) > $($this.Path)'"
		}

		$current = $this.Get()
		if (
			$this.Ensure -eq 'Absent' -and
			$current.Ensure -eq 'Present'
		) {
			throw 'Deleting collections is not supported'
		}

		if (
			$this.Ensure -eq 'Present' -and
			$current.Ensure -eq 'Absent'
		) {
			throw 'Creating collections is not supported'
		}

		try { $code = [scriptblock]::Create($this.Filter) }
		catch { throw "Invalid Filter: $($this.Filter)" }

		$collection = Get-IISConfigCollection -ConfigElement $parent -CollectionName $this.Name
		# Note: RawAttributes is a calculated property and regenerated on each request
		foreach ($element in $collection) { Add-Member -InputObject $element -MemberType NoteProperty -Name AttributesEx -Value $element.RawAttributes }

		$legalElementsAttributes = $($collection).AttributesEx | Where-Object $code
		$legalElements = $collection | Where-Object AttributesEx -in $legalElementsAttributes
		$countChanges = 0
		foreach ($illegal in $collection | Where-Object { $_ -notin $legalElements } ) {
			$collection.Remove($illegal)
			$countChanges++
		}

		if (0 -eq $countChanges) { return }
		$iis = Get-IISServerManager
		$iis.CommitChanges()
	}

	[IISConfigCollection]Get() {
		# Return current actual state
		$current = [IISConfigCollection]::new()
		$current.SectionPath = $this.SectionPath
		$current.Site = $this.Site
		$current.Path = $this.Path
		$current.Name = $this.Name
		$current.Filter = $this.Filter

		$parent = $this.GetElement()
		if (-not $parent) {
			$current.Ensure = 'Absent'
			return $current
		}

		$collection = Get-IISConfigCollection -ConfigElement $parent -CollectionName $this.Name
		if (-not $collection) {
			$current.Ensure = 'Absent'
			return $current
		}

		$current.Ensure = 'Present'
		$current.Elements = $($collection)
		return $current
	}

	[bool]Test() {
		# Check whether current state = desired state
		$collection = $this.Get()
		if ($this.Ensure -ne $collection.Ensure) { return $false }

		if (-not $this.Filter) { return $true }

		try { $code = [scriptblock]::Create($this.Filter) }
		catch { throw "Invalid Filter: $($this.Filter)" }

		# Note: RawAttributes is a calculated property and regenerated on each request
		foreach ($element in $collection.Elements) { Add-Member -InputObject $element -MemberType NoteProperty -Name AttributesEx -Value $element.RawAttributes }
		$legalElementsAttributes = $($collection.Elements).AttributesEx | Where-Object $code
		$legalElements = $collection.Elements | Where-Object AttributesEx -in $legalElementsAttributes
		if ($collection.Elements | Where-Object { $_ -notin $legalElements }) { return $false }
		return $true
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
		foreach ($property in [IISConfigCollection].GetProperties().Name) {
			# Checks if "NotConfigurable" attribute is set
			$notConfigurable = [IISConfigCollection].GetProperty($property).GetCustomAttributes($false).Where({ $_ -is [System.Management.Automation.DscPropertyAttribute] }).NotConfigurable
			if (!$notConfigurable) {
				$value = $this.$property
				# Gets the list of valid values from the ValidateSet attribute
				$validateSet = [IISConfigCollection].GetProperty($property).GetCustomAttributes($false).Where({ $_ -is [System.Management.Automation.ValidateSetAttribute] }).ValidValues
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