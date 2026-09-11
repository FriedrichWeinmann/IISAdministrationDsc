[DscResource()]
class IISConfigCollectionItem {
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

    [DscProperty(Mandatory)]
    [Ensure]$Ensure
	#>

	[DscProperty(Mandatory, Key)]
	[string] $SectionPath
	
	[DscProperty(Key)]
	[string] $Site

	[DscProperty(Key)]
	[string] $Path
	
	[DscProperty(Mandatory, Key)]
	[string] $CollectionName
	
	[DscProperty(Mandatory)]
	[string] $Data
	
	[DscProperty(Mandatory, Key)]
	[string]$ItemID

	[DscProperty()]
	[bool] $ExactMatch = $true
	
	# Filter condition, on whether an item in the collection is our configured element (which might need to be updated)
	# If NOT specified, all properties on each item will be compared with the entries in the hashtable defined in $Data
	[DscProperty()]
	[string] $Filter

	[DscProperty()]
	[Ensure]$Ensure = 'Present'

	[DscProperty(NotConfigurable)]
	[Reason[]] $Reasons # Reserved for Azure Guest Configuration
	#endregion DSC Properties

	[array] $MatchingItems

	[hashtable]GetData() {
		$content = $this.Data | ConvertFrom-Json
		return $content | ConvertTo-Hashtable
	}

	[void]Set() {
		# Apply Desired State
		$current = $this.Get()
		if (@($current.MatchingItems).Count -gt 1) {
			throw 'Unexpected state: More than one collection item matches the intended item!'
		}

		if ($this.Test()) { return }

		# Case: Create
		if (-not $current.MatchingItems) {
			$parent = $this.GetElement()
			$collection = Get-IISConfigCollection -ConfigElement $parent -CollectionName $this.CollectionName
			New-IISConfigCollectionElement -ConfigCollection $collection -ConfigAttribute $this.GetData()
		}

		# Case: Delete
		elseif ($this.Ensure -eq 'Absent') {
			$parent = $this.GetElement()
			$collection = Get-IISConfigCollection -ConfigElement $parent -CollectionName $this.CollectionName
			$collection.Remove($this.MatchingItems)
		}

		# Case: Update
		else {
			$dataSet = $this.GetData()
			foreach ($key in $dataSet.Keys) {
				if ($dataSet.$key -eq $this.MatchingItems.RawAttributes.$key) { continue }
				Set-IISConfigAttributeValue -ConfigElement $this.MatchingItems -AttributeName $key -AttributeValue $dataSet.$key
			}
		}

		$iis = Get-IISServerManager
		$iis.CommitChanges()
	}

	[IISConfigCollectionItem]Get() {
		# Return current actual state
		$code = {}
		if ($this.Filter) {
			try { $code = [scriptblock]::Create($this.Filter) }
			catch { throw "Invalid PowerShell Syntax in Filter! $($this.Filter)" }
		}

		$current = [IISConfigCollectionItem]::new()
		$current.SectionPath = $this.SectionPath
		$current.Site = $this.Site
		$current.Path = $this.Path
		$current.CollectionName = $this.CollectionName
		$current.ItemID = $this.ItemID
		$current.ExactMatch = $this.ExactMatch
		$current.Filter = $this.Filter

		$parent = $this.GetElement()
		$collection = Get-IISConfigCollection -ConfigElement $parent -CollectionName $this.CollectionName

		#region Match Elements
		# Matching by filter
		if ($this.Filter) {
			foreach ($element in $collection) { Add-Member -InputObject $element -MemberType NoteProperty -Name AttributesEx -Value $element.RawAttributes }
			$matchingAttributes = $($collection).AttributesEx | Where-Object $code
			$matching = $collection | Where-Object AttributesEx -In $matchingAttributes
		}

		# Match by Attribute Match
		else {
			$matching = $collection | Where-Object {
				Test-Hashtable -Intended $this.GetData() -Actual $_.RawAttributes -ExactMatch:$this.ExactMatch
			}
		}
		#endregion Match Elements

		#region Process Matches
		# Case: No match found
		if (-not $matching) {
			$current.Ensure = 'Absent'
			return $current
		}
		# Case: Exact one match found
		if (@($matching).Count -eq 1) {
			$current.Ensure = 'Present'
			$newData = @{}
			foreach ($key in $matching.RawAttributes.Keys) {
				$newData[$key] = $matching.RawAttributes.$key
			}
			$current.Data = $newData | ConvertTo-Json -Depth 99
			$current.MatchingItems = $matching
			return $current
		}
		# Case: Too many matches found
		$current.Ensure = 'Present'
		$current.MatchingItems = $matching
		return $current
		#endregion Process Matches
	}

	[bool]Test() {
		# Check whether current state = desired state
		$current = $this.Get()
		if ($current.Ensure -ne $this.Ensure) { return $false }
		if (@($current.MatchingItems).Count -gt 1) { return $false }
		if ($this.Ensure -eq 'Absent') { return $true }
		
		return Test-Hashtable -Intended $this.GetData() -Actual $current.GetData() -ExactMatch:$this.ExactMatch
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
		foreach ($property in [IISConfigCollectionItem].GetProperties().Name) {
			# Checks if "NotConfigurable" attribute is set
			$notConfigurable = [IISConfigCollectionItem].GetProperty($property).GetCustomAttributes($false).Where({ $_ -is [System.Management.Automation.DscPropertyAttribute] }).NotConfigurable
			if (!$notConfigurable) {
				$value = $this.$property
				# Gets the list of valid values from the ValidateSet attribute
				$validateSet = [IISConfigCollectionItem].GetProperty($property).GetCustomAttributes($false).Where({ $_ -is [System.Management.Automation.ValidateSetAttribute] }).ValidValues
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