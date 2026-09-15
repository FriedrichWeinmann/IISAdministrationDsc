# Resource: IISConfigCollection

A DSC Resource that manages which items are allowed in an IIS configuration collection.

The `Filter` setting retains matching items and removes all other items from the collection. Creating or deleting the collection itself is not supported.

## Example Configuration Entry

```powershell
IISConfigCollection AllowedFileExtensions {
    SectionPath = 'system.webServer/security/requestFiltering'
    Site = 'Default Web Site'
    Path = ''
    Name = 'fileExtensions'
    Filter = '$_.fileExtension -in ".json", ".txt"'
}
```

## Settings

### SectionPath

- Type: String
- Mandatory: True
- Key: True

The main section path under which the collection can be found.
Example: 'system.webServer/security/requestFiltering'

### Site

- Type: String
- Mandatory: False
- Key: True

The site to which the collection applies.
If not specified, the collection will be managed in the server default settings.

> Note: Sections under 'system.applicationHost' ignore the Site setting, other than those under 'system.applicationHost/sites'.

### Path

- Type: String
- Mandatory: False
- Key: True

Relative sub-path under the section specified.
Each path segment is separated by a slash.
Example: 'siteDefaults/logFile'

### Name

- Type: String
- Mandatory: True
- Key: True

The name of the collection to manage.
Example: 'fileExtensions'

### Filter

- Type: String
- Mandatory: True
- Key: False

PowerShell filter code that determines which existing collection items are retained.
The filter is evaluated against each item's raw attributes hashtable through `Where-Object`.
Items for which the filter evaluates to False are removed.

Example: '$_.fileExtension -in ".json", ".txt"'

Use '$false' to remove all items or '$true' to retain all items.

### Ensure

- Type: String | [Present|Absent]
- Mandatory: False
- Key: False

Whether the collection should be present or absent.
Defaults to Present.

> This parameter is decorative. Creating or deleting collections is not supported; only the items in an existing collection can be managed.
