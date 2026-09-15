# IISAdministrationDsc

Welcome to the IIS Administration DSC Resource project.
This extends the [WebAdministrationDsc](https://github.com/dsccommunity/WebAdministrationDsc) resource module for PowerShell Desired State Configuration.

Its purpose is to provide extended functionality and greater ease of use.

## Resources

|Name|Description|
|---|---|
|[IISConfigAttribute](docs/IISConfigAttribute.md)|DSC Resource that defines a configuration entry in an IIS config.|

## Installation

To install this PowerShell module, run the following command in a PowerShell console:

```powershell
Install-Module IISAdministrationDsc
```

## Composite Resource

This project also offers a [composite resource](https://learn.microsoft.com/en-us/powershell/dsc/resources/authoringresourcecomposite?view=dsc-1.1) to simplify its use in a [DSC Community Workshop](https://github.com/dsccommunity/DscWorkshop) setup.
You can find that under the `CompositeResource` folder.
