function ConvertTo-Hashtable {
	[CmdletBinding()]
	param (
		[Parameter(ValueFromPipeline = $true)]
		$InputObject,

		[object[]]
		$Parents = @()
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