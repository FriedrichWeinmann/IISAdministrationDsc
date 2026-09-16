configuration IISConfigAttributes {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[hashtable[]]
		$Items
	)

	Import-DscResource -ModuleName PSDesiredStateConfiguration
	Import-DscResource -ModuleName IISAdministrationDsc

	foreach ($item in $items) {
		$executionName = $item.ConfigName
		$item.Remove('ConfigName')

		if ($item.ContainsKey('AttributeValue')) {
			$val = $item.AttributeValue
			$val.PSObject.Properties.Remove('__File')
			$hash = @{ value = $val }
			$item.AttributeValue = $hash | ConvertTo-Json -Compress
		}

		(Get-DscSplattedResource -ResourceName IISConfigAttribute -ExecutionName $executionName -Properties $item -NoInvoke).Invoke($item)
	}
}

configuration IISConfigCollections {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[hashtable[]]
		$Items
	)

	Import-DscResource -ModuleName PSDesiredStateConfiguration
	Import-DscResource -ModuleName IISAdministrationDsc

	foreach ($item in $items) {
		$executionName = $item.ConfigName
		$item.Remove('ConfigName')

		(Get-DscSplattedResource -ResourceName IISConfigCollection -ExecutionName $executionName -Properties $item -NoInvoke).Invoke($item)
	}
}

configuration IISConfigCollectionItems {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[hashtable[]]
		$Items
	)

	Import-DscResource -ModuleName PSDesiredStateConfiguration
	Import-DscResource -ModuleName IISAdministrationDsc

	foreach ($item in $items) {
		$executionName = $item.ConfigName
		$item.Remove('ConfigName')

		if ($item.ContainsKey('Data')) {
			$hash = @{} + $item.Data
			$hash.Remove('__File')
			$item.Data = $hash | ConvertTo-Json -Compress 
		}

		(Get-DscSplattedResource -ResourceName IISConfigCollectionItem -ExecutionName $executionName -Properties $item -NoInvoke).Invoke($item)
	}
}
