#Requires -Version 5.1
<#
.SYNOPSIS
    Assembles the production Invoke-Interaction.ps1 from the DEV template,
    XAML assets and selected builtin interactions.

.PARAMETER BuiltinInteractions
    Names of interactions (without extension) to embed.
    Example: -BuiltinInteractions 'Prompt','Confirm'

.EXAMPLE
    .\Build-InvokeInteraction.ps1 -BuiltinInteractions 'Prompt','Confirm'
#>
param(
    [string[]] $BuiltinInteractions = @("InputText","ItemSelect","MessageAction","ProgressBar","Credential")
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = "$PSScriptRoot\..\"

# ---------------------------------------------------------------------------
#region Helpers
# ---------------------------------------------------------------------------

function Format-XmlString {
    <#
    .SYNOPSIS
        Pretty-prints an XML string with 4-space indentation (no XML declaration).
    #>
    param([string] $Xml)

    $Settings                     = [System.Xml.XmlWriterSettings]::new()
    $Settings.Indent              = $true
    $Settings.IndentChars         = '    '
    $Settings.OmitXmlDeclaration  = $true
    $Settings.NewLineChars        = "`n"
    $Settings.NewLineOnAttributes = $false

    $SB     = [System.Text.StringBuilder]::new()
    $Writer = [System.Xml.XmlWriter]::Create($SB, $Settings)
    ([xml] $Xml).Save($Writer)
    $Writer.Flush()
    return $SB.ToString().TrimEnd()
}

function Remove-XamlInteractionWrapper {
    <#
    .SYNOPSIS
        Extracts the visual content from a DEV Border wrapper, stripping
        Border.Resources, and re-declares namespaces on the root element.
    #>
    param([string] $RawXaml)

    [xml] $Doc = $RawXaml

    $NsXaml = 'http://schemas.microsoft.com/winfx/2006/xaml/presentation'
    $NsX    = 'http://schemas.microsoft.com/winfx/2006/xaml'

    $ContentNode = $Doc.DocumentElement.ChildNodes |
        Where-Object { $_.LocalName -notin @('Border.Resources', 'Border.DataContext') } |
        Select-Object -First 1

    $NewDoc   = [System.Xml.XmlDocument]::new()
    $Imported = $NewDoc.ImportNode($ContentNode, $true)
    $NewDoc.AppendChild($Imported) | Out-Null
    $NewDoc.DocumentElement.SetAttribute('xmlns',   $NsXaml)
    $NewDoc.DocumentElement.SetAttribute('xmlns:x', $NsX)

    return $NewDoc.OuterXml
}

function New-HereString {
    <#
    .SYNOPSIS
        Wraps content in a PowerShell here-string (@"..."@).
        - Each content line is prefixed with $LineIndent (for readability).
        - The closing "@ always stays at column 0 (PowerShell requirement).
    #>
    param(
        [string] $Content,
        [string] $LineIndent = '    '
    )

    $Lines = ($Content.Trim() -split '\n') |
             ForEach-Object { "$LineIndent$_" }

    return "@`"`n$($Lines -join "`n")`n`"@"
}

function Set-Placeholder {
    <#
    .SYNOPSIS
        Replaces a placeholder block:
            #NAME
                ...
            #NAME   (or #NAME at column 0)
        with $Value.

        Dollar signs in $Value are escaped so -replace does not
        interpret them as back-references.
    #>
    param(
        [string] $Text,
        [string] $Name,
        [string] $Value
    )

    $Pattern   = "(?s)#$Name\r?\n.*?\r?\n[ \t]*#$Name"
    $SafeValue = $Value.Replace('$', '$$')   # escape $ for .NET regex replacement
    return $Text -replace $Pattern, $SafeValue
}

function Get-PlaceholderIndent {
    <#
    .SYNOPSIS
        Returns the leading whitespace of the line containing #NAME in $Text.
        Used to derive indentation levels dynamically instead of hardcoding them.
    #>
    param([string] $Text, [string] $Name)
    $Line = ($Text -split '\r?\n') |
                Where-Object { $_ -match "^(\s*).*#$Name" } |
                Select-Object -First 1
    if ($Line -match '^(\s*)') { return $Matches[1] } else { return '' }
}

#endregion

# ---------------------------------------------------------------------------
#region 1 - Read template
# ---------------------------------------------------------------------------

$TemplatePath = Join-Path $ProjectRoot 'Dev\DEV_Invoke-Interaction.ps1'
if (-not (Test-Path $TemplatePath)) {
    throw "Template not found: $TemplatePath"
}

Write-Host "Reading template: $TemplatePath"
$Output = Get-Content $TemplatePath -Raw -Encoding UTF8

# Strip the DEV (HOT RELOAD) region and the optional blank line that follows
$Output = $Output -replace '(?s)[ \t]*#region DEV \(HOT RELOAD\).+?#endregion DEV \(HOT RELOAD\)[ \t]*\r?\n(\r?\n)?', ''
#endregion

# ---------------------------------------------------------------------------
#region 2 - Window Layout  (#WINDOW_LAYOUT)
# ---------------------------------------------------------------------------

$LayoutPath = Join-Path $ProjectRoot 'Dev\PSInvokeInteractionXAML\Layout.xaml'
if (-not (Test-Path $LayoutPath)) { throw "Layout not found: $LayoutPath" }

Write-Host 'Processing Layout.xaml...'

$RawLayout   = Get-Content $LayoutPath -Raw -Encoding UTF8
$CleanLayout = $RawLayout `
    -replace '(?s)<ResourceDictionary\.MergedDictionaries>.*?</ResourceDictionary\.MergedDictionaries>', '' `
    -replace '(?s)<ContentPresenter\.Resources>.*?</ContentPresenter\.Resources>',                       '' `
    -replace '(?s)<ContentPresenter\.Content>.*?</ContentPresenter\.Content>',                           ''

$LayoutHereString = New-HereString -Content (Format-XmlString $CleanLayout)
$Output = Set-Placeholder -Text $Output -Name 'WINDOW_LAYOUT' -Value $LayoutHereString

#endregion

# ---------------------------------------------------------------------------
#region 3 - Window Styles  (#WINDOW_STYLES)
# ---------------------------------------------------------------------------

$StylesPath = Join-Path $ProjectRoot 'Dev\PSInvokeInteractionXAML\Styles.xaml'
if (-not (Test-Path $StylesPath)) { throw "Styles not found: $StylesPath" }

Write-Host 'Processing Styles.xaml...'

$RawStyles = Get-Content $StylesPath -Raw -Encoding UTF8
$StylesHereString = New-HereString -Content $RawStyles
$Output = Set-Placeholder -Text $Output -Name 'WINDOW_STYLES' -Value $StylesHereString

#endregion

# ---------------------------------------------------------------------------
#region 4 - Build all interactions → Interactions\<Name>\<Name>.ps1
# ---------------------------------------------------------------------------
#
#  Every interaction found in Dev\Interactions\*.ps1 is built (XAML injected) and
#  saved under its own folder in Interactions\ at the project root.
#  The built content is also cached for the builtin-embedding step below.
# ---------------------------------------------------------------------------
 
$DevInteractionsPs1Dir  = Join-Path $ProjectRoot 'Dev\Interactions'
$DevInteractionsXamlDir = Join-Path $ProjectRoot 'Dev\PSInvokeInteractionXAML\Interactions'
$InteractionsDir   = Join-Path $ProjectRoot 'Interactions'
 
Write-Host 'Building interactions...'
 
# $BuiltInteractions : Name → built PS1 string  (reused for builtin embedding)
$BuiltInteractions = @{}
 
foreach ($Ps1File in (Get-ChildItem $DevInteractionsPs1Dir -Filter '*.ps1')) {
 
    $InteractionName = $Ps1File.BaseName
    $XamlPath   = Join-Path $DevInteractionsXamlDir "$InteractionName.xaml"
 
    if (-not (Test-Path $XamlPath)) {
        throw "XAML not found for interaction '$InteractionName': $XamlPath"
    }
 
    # Clean + format XAML, wrap as here-string
    $RawXaml  = Get-Content $XamlPath -Raw -Encoding UTF8
    $XamlHere = New-HereString -Content (Format-XmlString (Remove-XamlInteractionWrapper $RawXaml))
 
    # Inject XAML into PS1
    $RawPs1   = Get-Content $Ps1File.FullName -Raw -Encoding UTF8

    # Skip interactions flagged as work-in-progress (# DEV) 
    if ($RawPs1 -match '^\s*#\s*DEV\b') {
        Write-Host "  [skip] $InteractionName (# DEV)"
        continue
    }

    $BuiltPs1 = Set-Placeholder -Text $RawPs1 -Name 'INTERACTION_VISUAL' -Value $XamlHere
 
    # Save to Interactions\<Name>\<Name>.ps1  (create folder if needed)
    $InteractionOutDir = Join-Path $InteractionsDir $InteractionName
    if (-not (Test-Path $InteractionOutDir)) {
        New-Item -ItemType Directory -Path $InteractionOutDir | Out-Null
    }
    $OutPath = Join-Path $InteractionOutDir "$InteractionName.ps1"
    [System.IO.File]::WriteAllText($OutPath, $BuiltPs1, [System.Text.Encoding]::UTF8)
    Write-Host "  [interaction] $InteractionName → Interactions\$InteractionName\$InteractionName.ps1"
 
    $BuiltInteractions[$InteractionName] = $BuiltPs1
}
 
#endregion
 
# ---------------------------------------------------------------------------
#region 5 - Embed builtins into function  (#BUILTIN_INTERACTIONS)
# ---------------------------------------------------------------------------
#
#  Only interactions listed in $BuiltinInteractions are inlined in the function.
#  They must all have been built in region 4 (i.e. exist in Dev\Interactions\).
#
#  Target shape (Interactions key sits at 12-space indent):
#
#              Interactions = @{
#                  'Type name' = @{           ← 16 spaces
#                      Description = "..."  ← 20 spaces (16 + original 4)
#                      Xaml = @"
#                      <Grid .../>
#  "@                                       ← col 0  (PowerShell hard requirement)
#                      Init = { ... }
#                  }
#              }
#
#  Indent constants:
#    $I16  key line + closing brace of each interaction entry
#    $I20  body lines of each interaction entry
#    col 0 for every "@ delimiter
# ---------------------------------------------------------------------------
 
$KeyIndent   = Get-PlaceholderIndent -Text $Output -Name 'BUILTIN_INTERACTIONS'
$EntryIndent = $KeyIndent + '    '   # one level deeper than the Interactions key
 
# Validate builtins before touching the template
foreach ($InteractionName in $BuiltinInteractions) {
    if (-not $BuiltInteractions.ContainsKey($InteractionName)) {
        throw "Builtin '$InteractionName' was not found in '$DevInteractionsPs1Dir'."
    }
}
 
$InteractionEntries = foreach ($InteractionName in $BuiltinInteractions) {
 
    $Lines = $BuiltInteractions[$InteractionName].Trim() -split '\r?\n'
 
    if ($Lines.Count -lt 2) { throw "Interaction '$InteractionName': built PS1 is unexpectedly short." }
 
    # First line is "@{", last is "}" — handled separately for alignment
    $OpenBrace  = $Lines[0].Trim()
    $CloseBrace = $Lines[-1].Trim()
    $BodyLines  = if ($Lines.Count -gt 2) { $Lines[1..($Lines.Count - 2)] } else { @() }
 
    $IndentedBody = ($BodyLines | ForEach-Object {
        if ($_ -match '^"@') { $_ }   # here-string closing delimiter → must stay at col 0
        else                 { "$EntryIndent$_" }
    }) -join "`n"
 
    "$EntryIndent'$InteractionName' = $OpenBrace`n$IndentedBody`n$EntryIndent$CloseBrace"
}
 
$InteractionsBlock = if ($InteractionEntries) {
    "@{`n$($InteractionEntries -join "`n`n")`n            }"
} else {
    '@{}'
}
 
$Output = Set-Placeholder -Text $Output -Name 'BUILTIN_INTERACTIONS' -Value $InteractionsBlock
 
Write-Host "Builtins embedded: $(if ($BuiltinInteractions) { $BuiltinInteractions -join ', ' } else { '(none)' })"
 
#endregion
 
# ---------------------------------------------------------------------------
#region 6 - Write function output
# ---------------------------------------------------------------------------
 
$OutPath = Join-Path $ProjectRoot 'Invoke-Interaction.ps1'
[System.IO.File]::WriteAllText($OutPath, $Output, [System.Text.Encoding]::UTF8)
 
Write-Host ''
Write-Host "Built → $OutPath" -ForegroundColor Green
 
#endregion