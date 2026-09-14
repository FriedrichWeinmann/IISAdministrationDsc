function ConvertTo-Hashtable {
	<#
	.SYNOPSIS
		Simple Object to Hashtable conversion.
	
	.DESCRIPTION
		Simple Object to Hashtable conversion.
		Only converts at a flat level.

		- Hashtables are cloned
		- Other Dictionaries are translated to hashtable
		- Other items have their PSObject's properties enumerated and copied to hashtable

		Primitive types will not be handled gracefully and likely end in an empty hashtable.
	
	.PARAMETER InputObject
		The object to convert to hashtable.
	
	.EXAMPLE
		PS C:\> $data | ConvertTo-Hashtable

		Converts $data to hashtable.
	#>
	[OutputType([hashtable])]
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline = $true)]
		$InputObject
	)
	process {
		if ($null -eq $InputObject) { return }

		if ($InputObject -is [hashtable]) { return $InputObject.Clone() }

		$hash = @{}
		if ($InputObject -is [System.Collections.IDictionary]) {
			foreach ($key in $InputObject.Keys) {
				$hash[$key] = $InputObject.$key
			}
		}
		else {
			foreach ($property in $InputObject.PSObject.Properties) {
				$hash[$property.Name] = $property.Value
			}
		}
		$hash
	}
}