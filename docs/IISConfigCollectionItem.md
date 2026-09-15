# Resource: IISConfigCollectionItem

A DSC Resource that manages an item in an IIS configuration collection.

The resource creates, updates, or removes a collection item. It identifies the item by matching the attributes in `Data` or by evaluating a PowerShell `Filter`, and expects no more than one item to match.

## Example Configuration Entry

```powershell
IISConfigCollectionItem JsonFileExtension {
    SectionPath = 'system.webServer/security/requestFiltering'
    Site = 'Default Web Site'
    Path = ''
    CollectionName = 'fileExtensions'
    Data = '{ "fileExtension": ".json", "allowed": true }'
    ItemID = 'JsonFileExtension'
    ExactMatch = $false
    Filter = '$_.fileExtension -eq ".json"'
    Ensure = 'Present'
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

The site to which the collection item applies.
If not specified, the item will be managed in the server default settings.

> Note: Sections under 'system.applicationHost' ignore the Site setting, other than those under 'system.applicationHost/sites'.

### Path

- Type: String
- Mandatory: False
- Key: True

Relative sub-path under the section specified.
Each path segment is separated by a slash.
Example: 'siteDefaults/logFile'

### CollectionName

- Type: String
- Mandatory: True
- Key: True

The name of the collection containing the item.
Example: 'fileExtensions'

### Data

- Type: String
- Mandatory: True
- Key: False

The desired attributes of the collection item.
The value must be a legal JSON object that can be converted with `ConvertFrom-Json`.

When `Filter` is not specified, `Data` is also used to find the existing item.
Example: '{ "fileExtension": ".json", "allowed": true }'

### ItemID

- Type: String
- Mandatory: True
- Key: True

A unique identifier for this DSC resource instance.
`ItemID` distinguishes configuration declarations and is not used to identify the item in IIS.
Example: 'JsonFileExtension'

### ExactMatch

- Type: Boolean
- Mandatory: False
- Key: False

Whether an item must have exactly the attributes specified in `Data` to match the desired state.
Defaults to True.
When False, additional attributes on the IIS collection item are allowed.

### Filter

- Type: String
- Mandatory: False
- Key: False

PowerShell filter code used to identify the existing collection item instead of matching by `Data`.
The filter is evaluated against each item's raw attributes hashtable through `Where-Object`.
The filter must match no more than one item.

Example: '$_.fileExtension -eq ".json"'

### Ensure

- Type: String | [Present|Absent]
- Mandatory: False
- Key: False

Whether the collection item should be present or absent.
Defaults to Present.
A present item is created or updated to match `Data`; an absent matching item is removed.
