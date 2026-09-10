function Read-Hashtable {
	<#
.Synopsis
    Reads a hash table and returns its contents as key/value objects.

.DESCRIPTION
    Reads a hash table and returns its contents as a hierarchical structure.
    Use the AsHashtable switch to return the result as a flat hashtable, rather than one object per.

.PARAMETER Hashtable
    The input hash table that is to be read.

.PARAMETER Namespace
    The namespace under which the keys should be read.
	Used to recursively resolve hashtables

.PARAMETER AsHashtable
    Specifies if the contents of the hash table are returned as an object
    hierarchy or as a hash table itself.

.EXAMPLE
    $struct = @{
        first = @{ second = '213' }
    }
    Read-Hashtable -Hashtable $struct

    Name                   Value
    ----                   -----
    first.second           213
#>
	[OutputType([hashtable])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[hashtable]
		$Hashtable,
		
		[string]
		$Namespace,

		[switch]
		$AsHashtable
	)

	$prefix = ''
	if ($Namespace) { $prefix = "$Namespace." }

	$results = foreach ($pair in $Hashtable.GetEnumerator()) {
		$name = '{0}{1}' -f $prefix, $pair.Key
		if ($pair.Value -is [hashtable] -and $pair.Value.Count -gt 0) {
			Read-HashTable -Namespace $name -Hashtable $pair.Value
			continue
		}
		[PSCustomObject]@{
			Name  = $name
			Value = $pair.Value
		}
	}

	if (-not $AsHashtable) { return $results }

	$resultHash = @{ }
	foreach ($result in $results) {
		$resultHash[$result.Name] = $result.Value
	}
	$resultHash
}