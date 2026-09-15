---
name: dsc-resource-documentation
description: 'Document PowerShell DSC class resources in IISAdministrationDsc. Use when adding, updating, reviewing, or completing a resource PS1 file, about_*.txt concept help, docs/*.md page, or root README resource link.'
argument-hint: 'Resource class name, or all resources'
---

# DSC Resource Documentation

Document every DSC resource consistently across its implementation, concept help, public documentation, and root resource index.

## Required Artifact Map

For a resource named `<ResourceName>`, maintain all four artifacts:

| Purpose | Path |
|---|---|
| Source of truth | `IISAdministrationDsc/resources/<ResourceName>.ps1` |
| Concept help | `IISAdministrationDsc/en-us/about_<ResourceName>.txt` |
| Public documentation | `docs/<ResourceName>.md` |
| Documentation index | Resource table in `readme.md` |

Use `IISConfigAttribute` as the repository's formatting reference. Use the templates in [concept-help-template.txt](./assets/concept-help-template.txt) and [resource-documentation-template.md](./assets/resource-documentation-template.md) as starting points, but replace every placeholder and remove irrelevant optional text.

## Source-of-Truth Rules

Read the resource class before writing documentation. Do not infer behavior from another resource.

1. Confirm the class is marked `[DscResource()]`.
2. Inventory properties in declaration order.
3. Document configurable properties marked `[DscProperty(...)]`.
4. Omit properties marked `NotConfigurable`, such as `Reasons`, because users cannot set them in a DSC configuration.
5. Record metadata literally from the declaration:
   - `Mandatory` is True only when the attribute explicitly contains `Mandatory`.
   - `Key` is True only when the attribute contains `Key`.
   - Do not change `Mandatory` to True merely because a property is a Key; this repository documents the flags independently.
6. Convert implementation types to documentation names consistently:
   - `[string]` → `String`
   - `[bool]` → `Boolean`
   - `[int]` → `Integer`
   - Arrays retain `[]`.
   - `[Ensure]` → `String | [Present|Absent]`.
7. Record declared defaults, such as `Ensure = 'Present'` or `ExactMatch = $true`.
8. Read `Get()`, `Set()`, `Test()`, and helper methods to explain actual behavior, matching logic, creation/deletion support, errors, and limitations.
9. Treat JSON and PowerShell scriptblock strings precisely. Ensure examples survive both PowerShell quoting and the conversion performed by the implementation.

## Procedure

### 1. Assess Coverage

Enumerate `IISAdministrationDsc/resources/*.ps1`. For every class resource, check that its concept-help file, public documentation page, and README link exist. If asked to document all resources, complete every missing artifact rather than only reporting gaps.

### 2. Write Concept Help

Create or update `IISAdministrationDsc/en-us/about_<ResourceName>.txt` using the concept-help template.

Requirements:

- Keep the section order `TOPIC`, `SHORT DESCRIPTION`, `LONG DESCRIPTION`, then `# Settings`.
- Set TOPIC to `about_<ResourceName>`.
- Use one `## <PropertyName>` section per configurable property, in code declaration order.
- Include Type, Mandatory, and Key for every property.
- Explain defaults, formats, matching semantics, side effects, and unsupported operations.
- Include realistic examples for non-obvious values.
- For resources with `SectionPath`, `Site`, and `Path`, explain server-default behavior and preserve the IIS caveat when supported by `GetElement()`:

  `> Note: Sections under 'system.applicationHost' ignore the Site setting, other than those under 'system.applicationHost/sites'.`

- Match the repository's tab-indented about-help layout.
- Preserve the repository convention of UTF-8 with BOM and do not add trailing whitespace.

### 3. Write Public Markdown Documentation

Create or update `docs/<ResourceName>.md` using the Markdown template.

Requirements:

- Start with `# Resource: <ResourceName>`.
- Keep the short and long descriptions semantically aligned with concept help.
- Add `## Example Configuration Entry` with a complete, realistic PowerShell DSC resource block.
- Make the example executable: include all mandatory and key properties, represent JSON correctly, and quote embedded filter expressions safely.
- Add `## Settings` and one `### <PropertyName>` section per configurable property, in code declaration order.
- Keep Type, Mandatory, Key, descriptions, defaults, examples, caveats, and limitations synchronized with concept help.
- Use fenced `powershell` blocks for configuration examples and blockquotes for notes.

### 4. Update the Root README

In the `## Resources` table in `readme.md`, add or update exactly one row per DSC resource:

`|[<ResourceName>](docs/<ResourceName>.md)|<Short description>.|`

Keep resource names in implementation order or alphabetical order, preserve the existing compact table style, and ensure every link target exists. Use the same short description as the resource page, without the leading article when that matches surrounding rows.

### 5. Cross-Check Consistency

Compare all artifacts against the implementation:

- Every configurable property appears once in both documentation files.
- No implementation-only or `NotConfigurable` property appears as a user setting.
- Property spelling, order, type, Mandatory, and Key values agree.
- Defaults and `Ensure` behavior agree with the code.
- Filters are described according to what receives pipeline input.
- JSON examples match `ConvertFrom-Json` expectations.
- Limitations such as unsupported collection creation/deletion are explicit.
- The README contains one valid link for every resource.
- Short descriptions do not contradict each other.

Do not copy inaccurate behavior from an older documentation file. Correct all affected documentation artifacts when the source code proves the existing text wrong.

### 6. Validate

Before finishing:

1. Search generated resource artifacts (excluding this skill's templates) for unreplaced placeholders such as `{{ResourceName}}`, `{{Description}}`, and `TODO`.
2. Run `git diff --check` to catch trailing whitespace.
3. Confirm new files are tracked by `git status --short`.
4. Verify every README link resolves to an existing file.
5. Verify concept-help files use UTF-8 with BOM, matching the existing repository files.
6. If implementation code changed, import the workspace module manifest and run the relevant Pester tests from the repository test entry point. Documentation-only changes do not require claiming that Help.Tests validates DSC concept help; it tests command help, not these resource pages.

## Completion Report

Report the resource artifacts created or updated and the validation performed. Call out implementation/documentation discrepancies that could not be resolved without changing resource behavior.
