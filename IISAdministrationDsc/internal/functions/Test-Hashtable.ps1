function Test-Hashtable {
	<#
	.SYNOPSIS
		Tests, whether the provided Hashtable matches the intended one.
	
	.DESCRIPTION
		Tests, whether the provided Hashtable matches the intended one.
		Compares hashtables / dictionaries in depth, including nested hashtables.
	
	.PARAMETER Intended
		The hashtable containing the desired data.
	
	.PARAMETER Actual
		The object collected from the field that is compared to the desired state.
	
	.PARAMETER ExactMatch
		Require an exact match between the two hashtables.
		By default, the actual hashtable may contain entries in addition to the oones the intended one requires.
	
	.EXAMPLE
		PS C:\> Test-Hashtable -Intended $template -Actual $data
		
		Tests, whether the hashtable in $data has all the settings defined in $template.
		$data may contain additional settings, beyond what is defined in $template.
	
	.EXAMPLE
		PS C:\> Test-Hashtable -Intended $template -Actual $data -ExactMatch
		
		Tests, whether the hashtable in $data has all the settings defined in $template.
		$data may NOT contain additional settings, beyond what is defined in $template.
	#>
	[OutputType([bool])]
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