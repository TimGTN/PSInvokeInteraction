# Invoke-Interaction

![Version](https://img.shields.io/badge/dynamic/regex?url=https://raw.githubusercontent.com/TimGTN/PSInvokeInteraction/main/VERSION&label=Version&search=(.%2B)&color=green)
![PowerShell 5.1](https://img.shields.io/badge/PowerShell-5.1-5391FE?logo=powershell)
![PowerShell 7+](https://img.shields.io/badge/PowerShell-7%2B-5391FE?logo=powershell)
![Windows](https://img.shields.io/badge/Windows-0078D4?logo=windows11)

A standalone PowerShell function that displays interactive WPF dialog windows - input prompts, selection lists, progress bars, and more...
 
Built on a persistent WPF runspace with async support, `Invoke-Interaction` lets you build rich interactive scripts without wrestling with WPF boilerplate.

![Invoke-Interaction demo](https://github.com/user-attachments/assets/b9f96701-7d51-4a6c-a3ee-04894907ffd2)

## Features
 
- **Multiple built-in interaction types** — text input, item selection, message box, and more
- **Persistent WPF runspace** — one window instance reused across calls, no flicker
- **Sync & async modes** — block until the user responds, or get a handle to update the UI and track output while your script keeps running
- **Custom interactions** — bring your own XAML, parameter definitions, and UI logic
- **Built-in modern styles** — consistent look out of the box, fully inheritable in custom interactions
- **Self-documenting** — [`-Help`](#help) at any level surfaces syntax, parameters, and examples

## Requirements
 
- Windows PowerShell 5.1+ or PowerShell 7+ on Windows
- .NET WPF assemblies (`PresentationFramework`, `PresentationCore`, `WindowsBase`)

## Quick Start
 
Install the module from PowerShell Gallery, or copy the standalone function `Invoke-Interaction.ps1` into your project.

```powershell
Install-Module PSInvokeInteraction
Import-Module PSInvokeInteraction
```

Then, you can simply call the features :

```powershell
# Text input — blocks until the user confirms or cancels
$Name = Invoke-Interaction -Type InputText -Title "Rename" -Placeholder "Enter a name..."
 
# Item selection
$Choices = Invoke-Interaction -Type ItemSelect -Title "Select items" -Items "A","B","C" -Multiple
 
# Simple message box
$Button = Invoke-Interaction -Type MessageBox -Title "Confirm" -Message "Proceed?" -Buttons "Yes","No"
 
# And more... Use -Help to explore all available types and parameters
```

## Built-in Interaction Types

All interaction types are included out of the box (e.g., `InputText`, `ItemSelect`, `MessageBox`, `ProgressBar`, `Credential`, and more). Each one is fully documented directly in the source - use the built-in help system to explore them from your terminal (see [Help](#help) below).

If you need a specific behavior not covered by the built-in types, you can still register your own interaction using the [`-CustomInteraction`](#custom-interactions) parameter.

## Window-Level Parameters
 
These apply to all interaction types and control the window frame:
 
| Parameter | Type | Description |
|---|---|---|
| `-Title` | `string` | Window header text |
| `-Description` | `string` | Secondary text displayed above the interaction |
| `-IconPreset` | `string` | Preset icon: `Default`, `Information`, `Warning`, `Help`, `Error`, `Success` |
| `-IconBrush` | `string` | Custom WPF brush XAML, overrides `-IconPreset` — [see example](#custom-icon) |
| `-NoCancel` | `switch` | Disables the close button and cancel actions |
 
## Async Mode & Handles
 
Pass `-Async` to return immediately with a handle object instead of blocking. `ProgressBar` is implicitly async.
 
```powershell
$Handle = Invoke-Interaction -Type ProgressBar -Title "Processing" -Message "Working..." -Maximum 100
 
foreach ($i in 1..100) {
    $Handle.Message = "Step $i of 100"
    $Handle.Value   = $i
    Start-Sleep -Milliseconds 30
}
```

### Handle Properties
 
| Property | Description |
|---|---|
| `.InteractionType` | Name of the current interaction type |
| `.InteractionID` | GUID uniquely identifying this interaction instance |
| `.IsStale` | `$true` if the handle has been superseded by a newer call |
| `.IsVisible` | `$true` if the window is currently shown |
| `.HasOutput` | `$true` if user output is available |
| `.Errors` | Array of error records from the UI engine |
| `.<ParamName>` | Read/write access to any interaction parameter |

### Handle Methods
 
| Method | Description |
|---|---|
| `.Show()` | Re-displays the window with current parameters |
| `.GetOutput()` | Blocks until the user produces output |
| `.Update(Name, Value)` | Pushes a single parameter change without changing visibility |
| `.Dispose()` | Shuts down the runspace and releases all resources |

## Help
 
The function is self-documenting. Use `-Help` at any level to explore available types and their parameters directly from your terminal.
 
```powershell
# List all available types and general usage
Invoke-Interaction -Help
```
 
```
NAME
    Invoke-Interaction
 
SYNOPSIS
    Displays interactive WPF dialog windows (input, selection, credentials, progress, and more).
 
...
 
PARAMETERS
    -Type <String>
        Interaction type to display.
 
        Credential  - Secure credential prompt returning a standard PSCredential object.
        InputText   - Simple text input dialog with customization options.
        ItemSelect  - Item selection list supporting both single and multiple selection modes.
        MessageBox  - Configurable message box with custom buttons and status icon.
        ProgressBar - Configurable asynchronous progress bar.
        ...
    ...
```
 
```powershell
# Show parameters specific to one type
Invoke-Interaction -Type InputText -Help
```
 
```
INTERACTION InputText
    Simple text input dialog with customization options.
 
SYNTAX
    Invoke-Interaction -Type InputText [-Placeholder <String>] [-CurrentText <String>]
                       [-OkText <String>] [-CancelText <String>] [<StaticParameters>] [<CommonParameters>]
 
PARAMETERS
    -Placeholder <String>
        Temporary hint text displayed inside the empty field.
        Default : "..."
 
    -CurrentText <String>
        Current value of the input field.
 
    -OkText <String>
        Label for the confirmation button.
        Default : "Ok"
 
    -CancelText <String>
        Label for the cancellation button.
        Default : "Cancel"
```

## Advanced Examples

### Custom Icon
 
```powershell
$CustomHeartIcon = @'
<DrawingBrush xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
    <DrawingBrush.Drawing>
        <GeometryDrawing Brush="Red">
            <GeometryDrawing.Geometry>
                <GeometryGroup>
                    <PathGeometry Figures="M 12,21.35 L 10.55,20.03 C 5.4,15.36 2,12.27 2,8.5 C 2,5.41 4.42,3 7.5,3 C 9.24,3 10.91,3.81 12,5.08 C 13.09,3.81 14.76,3 16.5,3 C 19.58,3 22,5.41 22,8.5 C 22,12.27 18.6,15.36 13.45,20.03 L 12,21.35 Z" />
                </GeometryGroup>
            </GeometryDrawing.Geometry>
        </GeometryDrawing>
    </DrawingBrush.Drawing>
</DrawingBrush>
'@

Invoke-Interaction -Type MessageBox -Title "Custom Icon" -Message "Look at this heart!" `
    -MessageIcon "Inherit" -IconBrush $CustomHeartIcon
```
You can also set it as default across all calls using `$PSDefaultParameterValues`:
```powershell
$PSDefaultParameterValues["Invoke-Interaction:IconBrush"] = $CustomHeartIcon

Invoke-Interaction -Type MessageBox -Title "Custom Icon" -Message "Look at this heart!" -MessageIcon "Inherit"
```
 
### Confirmation with a timeout (Async)
 
```powershell
$Handle = Invoke-Interaction -Type MessageBox -Title "Confirmation" -IconPreset Warning `
    -Async -MessageIcon "Inherit" -Buttons "Yes","No" -Message "Confirm deletion?" -NoCancel
 
# Simple 5 seconds timeout
$SW = [System.Diagnostics.Stopwatch]::StartNew()
while (-not $Handle.HasOutput -and $SW.ElapsedMilliseconds -lt 5000) { Start-Sleep -Milliseconds 50 }
$SW.Stop()

# Check the output
if (-not $Handle.HasOutput -or $Handle.GetOutput() -ne "Yes") {
    $Handle.Dispose()
    # Exit
}
# Proceed with the next script step
```

## Custom Interactions
 
A custom interaction is a hashtable passed via `-CustomInteraction` that defines the layout, parameters, and behavior of your interaction. The entire hashtable is forwarded to the STA runspace, so you can include any additional keys (`Helpers`, `Config`, ...) your interaction needs.
 
### Xaml
 
The `Xaml` key (required) defines the WPF layout of your interaction. It automatically inherits all built-in styles (buttons, textboxes, checkboxes, etc.) — no extra setup needed. If you use a WPF control that doesn't have a built-in style, define its style directly inside your XAML.
 
### Parameters
 
The `Parameters` key is a hashtable where each entry defines a typed, documented parameter exposed on the interaction. Each parameter definition supports the following keys:
 
| Key | Required | Description |
|---|---|---|
| `Type` | ✅ | The expected .NET type (e.g. `[string]`, `[int]`, `[switch]`) |
| `Default` | | Default value used when the parameter is omitted |
| `Nullable` | | When set to `$false`, the parameter cannot be `$null` |
| `InitOnly` | | When `$true`, the parameter can only be set on first init — changing it later requires `-Force` |
| `ValidateRange` | | Restricts the value to a minimum and maximum (e.g., `1, 100`) |
| `ValidateSet`   | | Restricts the value to a predefined set of acceptable values |
| `HelpText` | | Description shown by `-Help`. Set to `$false` to hide the parameter from help output |
 
### Init
 
The `Init` scriptblock runs **once** when the interaction is first loaded. This is where you wire up event handlers, initialize collections, and set up any one-time state. In async scenarios, `Init` is not re-executed on subsequent calls — only `Update` is.
 
### Update
 
The `Update` scriptblock runs on every call (init and parameter updates via handle). Its role is to reflect the current parameter values onto the UI. It should stay focused on visual updates and avoid embedding business logic.

### Dispose

The `Dispose` scriptblock (optional) runs automatically when the interaction is replaced by another one (or reinitialized via `-Force`). Use it to clean up any resources created in `Init` that would otherwise keep running in the background - timers, event subscriptions, threads, etc.

---
 
```powershell
$MyInteraction = @{
    Xaml = @'
        <StackPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
            <TextBlock x:Name="TBK_Label" Margin="0,0,0,8" />
            <Button x:Name="BTN_Confirm" Content="Done" />
        </StackPanel>
'@
    Parameters = @{
        LabelText = @{ Type = [string]; Default = "Hello!"; HelpText = "Text shown in the label." }
    }
    Init = {
        param($Ctx)
        # Wired once - runs on first load only
        $Ctx.Elements.BTN_Confirm.Add_Click{
            $_.Source.DataContext.Sync.PendingOutput = "Confirmed"
        }
    }
    Update = {
        param($Ctx)
        # Runs on every call - keep this visual only
        $Ctx.Elements.TBK_Label.Text = $Ctx.Params.LabelText
    }
    Dispose = {
        param($Ctx)
        # Runs when the interaction is replaced or reinitialized via -Force
        # Clean up any persistent resources created in Init (timers, subscriptions, etc.)
    }
}
 
$Result = Invoke-Interaction -Type MyCustomDialog -CustomInteraction $MyInteraction -LabelText "Ready?"
```
 
Use `-Force` to override an existing custom interaction with the same name.

## Notes
 
- The WPF window runs in a dedicated STA runspace and is reused across calls for the same `InstanceID`. It is automatically reinitialized if the function body changes (detected via MD5 hash).
- The `InstanceID` parameter is internal and should not be set manually.