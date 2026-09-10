function Test-Hashtable {
	[CmdletBinding()]
	param (
		[System.Collections.IDictionary]
		$Intended,
		
		[System.Collections.IDictionary]
		$Actual,

		[switch]
		$ExactMatch
	)
	process {
		$intendedHash = @{}
		if ($Intended -is [hashtable]) { $intendedHash = $Intended }
		else {
			foreach ($key in $Intended.Keys) { $intendedHash[$key] = $Intended[$Key] }
		}

		$actualHash = @{}
		if ($Actual -is [hashtable]) { $actualHash = $Actual }
		else {
			foreach ($key in $Actual.Keys) { $actualHash[$key] = $Actual[$Key] }
		}

		$delta = Compare-Hashtable -ReferenceHashtable $intendedHash -DifferenceHashtable $actualHash
		if (-not $delta) { return $true }
		if ($delta.Direction -contains '!=') { return $false }
		if ($delta.Direction -contains '<=' -and $ExactMatch) { return $false }
		if ($delta.Direction -contains '=>') { return $false }
		return $true
	}
}