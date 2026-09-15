<#
Resource Parameters:
- Listed legal types
- Enums
- Nested Classes with DscProperties defined (or arrays thereof)

At least one Key

Implements all mandatory methods
- Get() : Returns its own type
- Set() : Returns [void]
- Test() : Returns [bool]
#>

BeforeDiscovery {
	$projectRoot = (Resolve-Path "$global:testroot\..").Path
	$global:IISAdministrationDscResourceTestPublishPath = Join-Path ([System.IO.Path]::GetTempPath()) "IISAdministrationDsc-$([guid]::NewGuid())"

	try {
		& "$projectRoot\build\vsts-build.ps1" -WorkingDirectory $projectRoot -SkipPublish -PublishPath $global:IISAdministrationDscResourceTestPublishPath

		$resourceConfiguration = Import-PowerShellDataFile -Path "$global:testroot\general\Resources.Config.psd1"
		$artifactPath = Join-Path $global:IISAdministrationDscResourceTestPublishPath 'IISAdministrationDsc\IISAdministrationDsc.psm1'
		$tokens = $null
		$artifactParseErrors = $null
		$artifactAst = [System.Management.Automation.Language.Parser]::ParseFile($artifactPath, [ref]$tokens, [ref]$artifactParseErrors)

		$typeDefinitions = $artifactAst.FindAll({
				param ($node)
				$node -is [System.Management.Automation.Language.TypeDefinitionAst]
			}, $true)
		$resourceDefinitions = $typeDefinitions | Where-Object {
			$_.Attributes.TypeName.FullName -match '(^|\.)DscResource(Attribute)?$'
		}
		$projectDscTypes = $typeDefinitions | Where-Object {
			$_.IsEnum -or ($_.Members | Where-Object {
					$_ -is [System.Management.Automation.Language.PropertyMemberAst] -and
					$_.Attributes.TypeName.FullName -match '(^|\.)DscProperty(Attribute)?$'
				})
		} | Select-Object -ExpandProperty Name

		$dscPropertyTestCases = foreach ($resourceDefinition in $resourceDefinitions) {
			foreach ($property in $resourceDefinition.Members | Where-Object {
					$_ -is [System.Management.Automation.Language.PropertyMemberAst] -and
					$_.Attributes.TypeName.FullName -match '(^|\.)DscProperty(Attribute)?$'
				}) {
				$typeName = $property.PropertyType.TypeName.FullName
				$elementTypeName = $typeName -replace '\[\]$', ''
				@{
					ResourceName  = $resourceDefinition.Name
					PropertyName  = $property.Name
					TypeName      = $typeName
					IsAllowedType = $typeName -in $resourceConfiguration.AllowedTypes -or $elementTypeName -in $projectDscTypes
				}
			}
		}
		$syntaxTestCases = @{
			ArtifactParseErrors = $artifactParseErrors
		}

		$resourceTestCases = foreach ($resourceDefinition in $resourceDefinitions) {
			@{
				ResourceAst  = $resourceDefinition
				ResourceName = $resourceDefinition.Name
			}
		}

		$methodTestCases = foreach ($resourceDefinition in $resourceDefinitions) {
			$default = @{ ResourceAst = $resourceDefinition; ResourceName = $resourceDefinition.Name }
			@{ MethodName = 'Get'; ReturnType = $resourceDefinition.Name } + $default
			@{ MethodName = 'Set'; ReturnType = 'void' } + $default
			@{ MethodName = 'Test'; ReturnType = 'bool' } + $default
		}
	}
	catch {
		Remove-Item -Path $global:IISAdministrationDscResourceTestPublishPath -Recurse -Force -ErrorAction Ignore
		Remove-Variable -Name IISAdministrationDscResourceTestPublishPath -Scope Global -ErrorAction Ignore
		throw
	}
}

Describe 'Validating DSC resource technical requirements' {
	AfterAll {
		Remove-Item -Path $global:IISAdministrationDscResourceTestPublishPath -Recurse -Force -ErrorAction Ignore
		Remove-Variable -Name IISAdministrationDscResourceTestPublishPath -Scope Global -ErrorAction Ignore
	}

	It 'The built module should have no syntax errors' -ForEach $syntaxTestCases {
		$ArtifactParseErrors | Should -BeNullOrEmpty
	}

	It '<ResourceName> property <PropertyName> should use the legal DSC type <TypeName>' -ForEach $dscPropertyTestCases {
		$IsAllowedType | Should -BeTrue -Because "type '$TypeName' must be configured in AllowedTypes, an enum, or a class containing a DSC property"
	}

	It '<ResourceName> should have at least one key property' -ForEach $resourceTestCases {
		$keyProperties = $ResourceAst.Members | Where-Object {
			$_ -is [System.Management.Automation.Language.PropertyMemberAst] -and
			($_.Attributes | Where-Object {
				$_.TypeName.FullName -match '(^|\.)DscProperty(Attribute)?$' -and
				$_.NamedArguments.ArgumentName -contains 'Key'
			})
		}

		$keyProperties | Should -Not -BeNullOrEmpty
	}

	It '<ResourceName> should implement <ReturnType> <MethodName>()' -ForEach $methodTestCases {
		$matchingMethod = $ResourceAst.Members | Where-Object {
			$_ -is [System.Management.Automation.Language.FunctionMemberAst] -and
			$_.Name -eq $MethodName -and
			$_.ReturnType.TypeName.FullName -eq $ReturnType -and
			$_.Parameters.Count -eq 0
		}

		$matchingMethod | Should -Not -BeNullOrEmpty
	}
}