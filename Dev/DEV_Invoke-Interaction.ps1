function Invoke-Interaction {
    <#
        .SYNOPSIS
            Displays interactive WPF dialog windows (input, selection, credentials, progress, and more).
        
        .DESCRIPTION
            Manages a persistent WPF window running in a dedicated STA runspace.
            Supports built-in and custom interaction types, synchronous and asynchronous modes.
            In async mode, parameters carry forward across calls via an interaction handle.

        .PARAMETER Type
            Interaction type to display. Use -Help alone to list all available types,
            or -Type <name> -Help for type-specific parameter details.

        .PARAMETER Help
            Displays help. Combined with -Type, shows parameters specific to that interaction.

        .PARAMETER IconBrush
            Custom WPF brush XAML for the window icon. Overrides -IconPreset when both are specified.

        .PARAMETER IconPreset
            Preset icon style for the window.
            Values : Default | Warning | Information | Help | Error | Success

        .PARAMETER Title
            Title text displayed in the window header.

        .PARAMETER NoCancel
            Disables the close button and any cancel action managed in the interaction.

        .PARAMETER Description
            Descriptive text displayed in the window body, above the interaction content.

        .PARAMETER Async
            Returns the interaction handle immediately without blocking the pipeline.

        .PARAMETER Force
            Forces reinitialization of the interaction UI, even if the type is unchanged.

        .PARAMETER GetHandle
            Returns the active interaction handle without triggering a new display.

        .PARAMETER CustomInteraction
            Hashtable defining a fully custom interaction. Must contain a 'Xaml' key.
        
        .PARAMETER DynamicArgs
            Interaction-specific parameters passed as named arguments after the static parameters.
            Accepts any -Key Value pair declared in the target interaction's parameter definition.
            Example :
                Invoke-Interaction -Type InputText -Title 'Rename' `
                                   -Placeholder 'Enter a name...' # ← Specific to 'InputText'
        
        .PARAMETER Show
            [INTERNAL] - Controls whether the window is displayed after processing the request.
            Used internally to push parameter updates without altering window visibility.
            Defaults to $true.

        .PARAMETER InstanceID
            [INTERNAL] - GUID identifying the shared synchronized state for this function instance.

        .EXAMPLE
            $Result = Invoke-Interaction -Type InputText -Title 'Rename' -Placeholder 'Enter a name...'

        .EXAMPLE
            $Handle = Invoke-Interaction -Type ProgressBar -Message "Processing..." -Minimum 0 -Maximum 100
            1..100 | ForEach-Object { $Handle.Value = $_ ; Start-Sleep -Milliseconds 50 }

        .NOTES
            Author  : Tim GILLOTIN
            Contact : @TimGTN
            Created : 2026-04-30
            Updated : <Updated>
            Version : <Version>
            Repository : https://github.com/TimGTN/PSInvokeInteraction
    #>
    [CmdletBinding()]
    param(
        [Alias('Name')][string]$Type, 
        [switch]$Help,

        [string]$IconBrush,
        [ValidateSet('Default','Warning','Information','Help','Error','Success')]
        [string]$IconPreset = "Information",
        [string]$Title,
        [switch]$NoCancel,
        [string]$Description,

        [switch]$Async,
        [switch]$Force,
        [switch]$GetHandle,

        [ValidateNotNullOrEmpty()]
        [hashtable]$CustomInteraction,

        [Parameter(ValueFromRemainingArguments,DontShow)]
        [array]$DynamicArgs,

        [Parameter(DontShow)]
        [bool]$Show = $True,

        [Parameter(DontShow)]
        [ValidateNotNullOrEmpty()]
        [string]$InstanceID = "d9f1f845-362f-404f-913e-cc07d9b1a990"
    )

    #region Window Definition & Styles
    $WindowLayout   = #WINDOW_LAYOUT
        ''
#WINDOW_LAYOUT
    $WindowStyles   = #WINDOW_STYLES
        ''
#WINDOW_STYLES
    $WindowElements = @{
        UI_Title       = 'TBK_Title'
        UI_Icon        = 'CVS_Icon'
        UI_Close       = 'BTN_Close'
        UI_Description = 'TBK_Description'
        UI_Interaction = 'CTP_Interaction'
    }
    $WindowIcons    = @{
        Warning     = '
            <VisualBrush Stretch="Uniform" xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
                <VisualBrush.Visual>
                    <Canvas>
                        <Path Fill="#f6b93b" Data="M459.58 328.248 293.623 33.497C280.969 12.63 258.965 0 234.483 0s-46.486 12.63-59.14 33.497c0 .272-.273.272-.273.548L9.663 327.7c-12.652 21.69-12.927 47.498-.55 69.188 12.378 21.689 34.657 34.594 59.69 34.594h331.36c25.032 0 47.312-12.904 59.689-34.594 12.379-21.691 12.104-47.499-.272-68.64" />
                        <Path Fill="#FFFFFF" Data="M234.66 272.724a27.88 27.88 0 0 1-26.637-26.636l-8.879-88.788a38.27 38.27 0 0 1 35.516-44.394c21.131 0 37.646 20.599 35.515 44.394l-8.88 88.788a27.88 27.88 0 0 1-26.636 26.636M261.296 343.754a26.636 26.636 0 0 1-26.636 26.637 26.636 26.636 0 0 1-26.637-26.637 26.636 26.636 0 0 1 26.637-26.636 26.636 26.636 0 0 1 26.636 26.636" />
                    </Canvas>
                </VisualBrush.Visual>
            </VisualBrush>'
        Information = '
            <VisualBrush Stretch="Uniform" xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
                <VisualBrush.Visual>
                    <Canvas>
                        <Path Fill="#49adf4" Data="M9.749.044a10.747 10.747 0 0 0-8.414 15.888 1.18 1.18 0 0 1 .048.985l-.618 1.648a1.749 1.749 0 0 0 2.16 2.284l1.97-.615a1.24 1.24 0 0 1 .925.053 10.6 10.6 0 0 0 4.922 1.208 11 11 0 0 0 2.264-.235A10.753 10.753 0 0 0 9.749.044" />
                        <Path Fill="#FFFFFF" Data="M10.749 9.654a1.25 1.25 0 0 0-1.25 1.25v4.75a1.25 1.25 0 0 0 2.5 0v-4.75a1.25 1.25 0 0 0-1.25-1.25M12.499 6.341a1.75 1.75 0 0 1-1.75 1.75 1.75 1.75 0 0 1-1.75-1.75 1.75 1.75 0 0 1 1.75-1.75 1.75 1.75 0 0 1 1.75 1.75" />
                    </Canvas>
                </VisualBrush.Visual>
            </VisualBrush>'
        Help        = '
            <VisualBrush Stretch="Uniform" xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
                <VisualBrush.Visual>
                    <Canvas>
                        <Path Fill="#25b7d3" Data="M496.158 248.085C496.158 111.063 385.089.003 248.083.003 111.07.003 0 111.063 0 248.085c0 137.001 111.07 248.07 248.083 248.07 137.006 0 248.075-111.069 248.075-248.07" />
                        <Path Fill="#FFFFFF" Data="M138.216 173.592q0-20.873 13.403-42.297c8.933-14.282 21.973-26.11 39.111-35.486q25.708-14.06 59.985-14.062c21.238 0 39.99 3.921 56.25 11.755 16.26 7.838 28.818 18.495 37.683 31.97q13.292 20.217 13.293 43.945 0 18.68-7.581 32.739-7.583 14.064-18.018 24.279-10.438 10.218-37.463 34.388-7.473 6.814-11.975 11.976-4.507 5.164-6.702 9.447-2.2 4.285-3.406 8.57c-.807 2.855-2.015 7.875-3.625 15.051q-4.177 22.853-26.147 22.852-11.428.001-19.226-7.471-7.8-7.469-7.8-22.192-.002-18.458 5.713-31.97 5.712-13.515 15.161-23.73 9.446-10.217 25.488-24.28 14.061-12.304 20.325-18.567a63 63 0 0 0 10.547-13.953q4.284-7.688 4.285-16.699-.002-17.576-13.074-29.663c-8.717-8.054-19.961-12.085-33.728-12.085q-24.174 0-35.596 12.195-11.426 12.195-19.336 35.925-7.472 24.83-28.345 24.829-12.309.001-20.764-8.679-8.458-8.679-8.458-18.787m107.226 240.82q-13.405-.001-23.401-8.68-10-8.676-9.998-24.279c0-9.229 3.22-16.991 9.668-23.291q9.666-9.447 23.73-9.448 13.842.001 23.291 9.448 9.446 9.449 9.448 23.291 0 15.383-9.888 24.17t-22.85 8.789" />
                    </Canvas>
                </VisualBrush.Visual>
            </VisualBrush>'
        Error       = '
            <VisualBrush Stretch="Uniform" xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
                <VisualBrush.Visual>
                    <Canvas>
                        <Path Fill="#fd3c4f" Data="M18.225 2.63C16.795 1 13.725 0 10.005 0s-6.79 1-8.22 2.63c-2.38 2.76-2.38 12 0 14.74C3.215 19 6.285 20 10.005 20s6.79-1 8.22-2.63c2.38-2.76 2.38-11.98 0-14.74" />
                        <Path Fill="#FFFFFF" Data="m11.456 10 2.535 2.536a.48.48 0 0 1 0 .679l-.771.771a.48.48 0 0 1-.68 0l-2.535-2.535-2.536 2.535a.48.48 0 0 1-.679 0l-.771-.771a.48.48 0 0 1 0-.68L8.554 10 6.02 7.464a.48.48 0 0 1 0-.679l.771-.771a.48.48 0 0 1 .68 0l2.535 2.535 2.536-2.535a.48.48 0 0 1 .679 0l.771.771a.48.48 0 0 1 0 .68z" />
                    </Canvas>
                </VisualBrush.Visual>
            </VisualBrush>'
        Success     = '
            <VisualBrush Stretch="Uniform" xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
                <VisualBrush.Visual>
                    <Canvas>
                        <Path Fill="#5ad45c" Data="M58 29a29 29 0 0 1-29 29A29 29 0 0 1 0 29 29 29 0 0 1 29 0a29 29 0 0 1 29 29" />
                        <Path Fill="#FFFFFF" Data="m23.262 41.07-6.8-6.642a1.534 1.534 0 0 1 0-2.2l2.255-2.2a1.62 1.62 0 0 1 2.256 0l4.048 3.957 11.353-17.26a1.617 1.617 0 0 1 2.2-.468l2.684 1.686a1.537 1.537 0 0 1 .479 2.154L28.294 40.541a3.3 3.3 0 0 1-5.032.529" />
                    </Canvas>
                </VisualBrush.Visual>
            </VisualBrush>'
    }
    #endregion

    #region Config, Helpers & Interactions - [initialized once, never reset] 
    $Sync = $ExecutionContext.SessionState.PSVariable.GetValue($InstanceID)

    # If an existing instance is found, check whether the function body has changed.
    # If so, dispose it so the updated version is cleanly re-initialized below.
    if ($Sync) {
        $FunctionHash = & $Sync.Config.Helpers.GenerateHash $MyInvocation.MyCommand.ScriptBlock.ToString()
        if ($Sync.FunctionHash -ne $FunctionHash) {
            try { $Sync.Handle.Dispose() } catch {}
            $Sync = $null
        }
    }
    if (-not $Sync) {
        $Sync = (Set-Variable -Name $InstanceID -Scope Global `
                    -Value ([hashtable]::Synchronized(@{})) -PassThru).Value
        $FctParams   = $MyInvocation.MyCommand.ScriptBlock.Ast.Body.ParamBlock.Parameters
        $Sync.Config = @{
            Layout      = $WindowLayout           
            Styles      = $WindowStyles
            Elements    = $WindowElements
            IconPresets = $WindowIcons
            DefaultIconBrush  = $(
                $p = $FctParams.Where({ $_.Name.VariablePath.UserPath -eq 'IconBrush' }, 'First')
                if ($p.DefaultValue) { $p.DefaultValue.SafeGetValue() } else { $null }
            )
            DefaultIconPreset = $(
                $p = $FctParams.Where({ $_.Name.VariablePath.UserPath -eq 'IconPreset' }, 'First')
                if ($p.DefaultValue) { $p.DefaultValue.SafeGetValue() } else { $null }
            )
            FunctionArgs = [System.Collections.Generic.HashSet[string]]::new(
                [string[]]$MyInvocation.MyCommand.Parameters.Keys)
            StaticArgs = [System.Collections.Generic.HashSet[string]]::new(
                [string[]]('Title','Description','NoCancel','IconBrush','IconPreset'))

            Helpers = @{

                XamlToString = {
                    param([xml]$Xaml)
                    $SW = [System.IO.StringWriter]::new()
                    $XW = [System.Xml.XmlTextWriter]::new($SW)
                    $XW.Formatting = [System.Xml.Formatting]::Indented ; $XW.Indentation = 4
                    $Xaml.WriteTo($XW) ; $XW.Flush()
                    return $SW.ToString()
                }

                ValidateXaml = {
                    param($Xaml, [string]$Tag)
                    try { [xml]$X = $Xaml } catch { throw "$Tag is not valid XML : $_" }
                    $NS = 'http://schemas.microsoft.com/winfx/2006/xaml/presentation'
                    if ($X.DocumentElement.NamespaceURI -ne $NS) {
                        throw "$Tag must include the namespace : xmlns=`"$NS`"."
                    }
                }

                GenerateHash = {
                    param([string[]]$Strings)
                    $MD5 = [System.Security.Cryptography.MD5]::Create()
                    $Bs = [System.Collections.Generic.List[byte]]::new()
                    foreach ($S in $Strings) {
                        if ([string]::IsNullOrEmpty($S)) { continue }
                        $Bs.AddRange([System.Text.Encoding]::UTF8.GetBytes($S))
                    }
                    $HB = $MD5.ComputeHash($Bs.ToArray())
                    return [BitConverter]::ToString($HB).Replace('-', '')
                }

                ParseDynArgs = {
                    param([array]$DynamicArgs)
                    $Out  = @{}
                    [regex]$Rx = '^-(?<name>\w[\w-]*):?$'
                    for ($i = 0; $i -lt $DynamicArgs.Count; $i++) {
                        if ($DynamicArgs[$i] -notmatch $Rx) { continue }
                        $Name  = $Matches['name']
                        $Value = $true
                        if ($i+1 -lt $DynamicArgs.Count) {
                            if ($DynamicArgs[$i].EndsWith(':') -or $DynamicArgs[$i+1] -notmatch $Rx) {
                                $Value = $DynamicArgs[$i+1] ; $i++
                            }
                        }
                        if ($Out.ContainsKey($Name)) {
                            Write-Warning "Dynamic argument `"-$Name`" specified multiple times, first value kept."
                        } else { $Out[$Name] = $Value }
                    }
                    return $Out
                }
                
                TitleCaseStr = {
                    param([string]$S)
                    [cultureinfo]::CurrentCulture.TextInfo.ToTitleCase($S.ToLower())
                }

                ReindentText = {
                    param([string]$Text, [int]$Indent = 8)
                    $Lines = $Text -split "`r?\n" | Where-Object { $_ -match '\S' }
                    if (-not $Lines) { return }
                    $Padding = ' ' * $Indent
                    $MinIndent = ($Lines | ForEach-Object { 
                        if ($_ -match '^(\s+)') { $Matches[1].Length } else { 0 }
                    } | Measure-Object -Minimum).Minimum
                    $Lines | ForEach-Object { "$Padding$($_.Substring([Math]::Min($MinIndent, $_.Length)))" }
                }

                FriendlyType = {
                    param([type]$Type)  
                    $Acc = [psobject].Assembly.GetType('System.Management.Automation.TypeAccelerators')::Get
                    if ($R = $Acc.GetEnumerator().Where({ $_.Value -eq $Type}, 'First')) { return $R[0].Key }   
                    if ($Type.IsArray) { return "$(& $MyInvocation.MyCommand.ScriptBlock $Type.GetElementType())[]" }
                    if ($Type.IsGenericType) {
                        $Arg = $Type.GetGenericArguments() | ForEach-Object { & $MyInvocation.MyCommand.ScriptBlock $_ }
                        return "$($Type.Namespace).$($Type.Name -replace '`\d+$','')[$($Arg -join ',')]"
                    }
                }

                EnsureRunUI  = {
                    param([runspace]$RS, [powershell]$PS, [bool]$Throw = $false)
                    if ($null -eq $RS -or $null -eq $PS) { return $False }
                    $Return = $true
                    $S = $PS.InvocationStateInfo.State
                    if ($Return -and $S -ne [System.Management.Automation.PSInvocationState]::Running) {
                        if ($Throw) {
                            throw "PowerShell instance is no longer running (State: $S)."
                        } else { $Return = $False }
                    }
                    $S = $RS.RunspaceStateInfo.State
                    if ($S -ne [System.Management.Automation.Runspaces.RunspaceState]::Opened) {
                        if ($Throw) {
                            throw "Runspace is no longer active (State: $S)."
                        } else { $Return = $False }
                    }
                    return $Return             
                }

                DisposeRunUI = {
                    param([hashtable]$Sync, [string[]]$Keys)
                    foreach ($Key in $Keys) {
                        $Instance = $Sync[$Key]
                        if ($null -eq $Instance) { continue }
                        try {
                            switch ($Instance) {
                                { $_ -is [System.Management.Automation.PowerShell]         } { $Instance.Stop()    }
                                { $_ -is [System.Management.Automation.Runspaces.Runspace] } { $Instance.Close()   }
                                { $_ -is [System.Threading.SemaphoreSlim]                  } { $Instance.Release() }
                                { $_ -is [System.Threading.CancellationTokenSource]        } { $Instance.Cancel()  }
                            }
                        } catch {}
                        try { $Instance.Dispose() } catch {}
                        $Sync.Remove($Key)
                    }
                }   
            }

            Interactions = #BUILTIN_INTERACTIONS
                @{}
            #BUILTIN_INTERACTIONS
        }
        $Sync.Host = $Host
        $Sync.FunctionHash = & $Sync.Config.Helpers.GenerateHash $MyInvocation.MyCommand.ScriptBlock.ToString()
    }
    $Helpers = $Sync.Config.Helpers
    #endregion

    #region DEV (HOT RELOAD)
    $ProjectRoot = $script:PSInvokeInteraction_ROOT
    if (-not (Test-Path $ProjectRoot)) { throw 'Test-Path failed on "$script:PSInvokeInteraction_ROOT"' }

    #-- Layout & Styles --
    $LayoutPath  = Join-Path $ProjectRoot "Dev\PSInvokeInteractionXAML\Layout.xaml"
    $StylesPath  = Join-Path $ProjectRoot "Dev\PSInvokeInteractionXAML\Styles.xaml"
    $RawLayout   = Get-Content -Path $LayoutPath -Encoding UTF8 -Raw
    $RawStyles   = Get-Content -Path $StylesPath -Encoding UTF8 -Raw
    $CleanLayout = $RawLayout `
        -replace '(?s)<ResourceDictionary\.MergedDictionaries>.*?</ResourceDictionary\.MergedDictionaries>', '' `
        -replace '(?s)<ContentPresenter\.Resources>.*?</ContentPresenter\.Resources>', '' `
        -replace '(?s)<ContentPresenter\.Content>.*?</ContentPresenter\.Content>', ''

    # Hash Layout + Styles (Autorefresh)
    $LayoutHash = & $Sync.Config.Helpers.GenerateHash -Strings @($CleanLayout, $RawStyles)
    if ($Sync.DEV_LayoutHash -ne $LayoutHash) {
        $Sync.Config.Layout = $CleanLayout
        $Sync.Config.Styles = $RawStyles
        $Sync.DEV_LayoutHash = $LayoutHash

        # Force current window to close
        if ($null -ne $Sync.UI_Window) {
            $Sync.ForceClose = $true
            $Sync.UI_Window.Dispatcher.Invoke([action]{ $Sync.UI_Window.Close() })
            $Sync.Remove('UI_Window')
            $Sync.InteractionHash = $null # force interaction reinit after window reinit
        }
    }

    #-- Interaction --
    # -Help without -Type : no interaction to reload, fall through to the help handler
    if (-not ($Help.IsPresent -and -not $PSBoundParameters.ContainsKey('Type'))) {
        # Type resolution
        $DevType = if ($Type) {
            $Type
        } elseif ($Sync.CurrentType) {
            $Sync.CurrentType
        } else {
            $null
        }
        if (-not $DevType) {
            Write-Warning "DEV: No interaction type resolved. Pass -Type 'InteractionName' explicitly."
            return
        }

        # Get interaction refs
        $XamlPath = Join-Path $ProjectRoot "Dev\PSInvokeInteractionXAML\Interactions\$DevType.xaml"
        $Ps1Path  = Join-Path $ProjectRoot "Dev\Interactions\$DevType.ps1"
        if (-not (Test-Path $XamlPath)) { throw "DEV: XAML not found : $XamlPath" }
        if (-not (Test-Path $Ps1Path))  { throw "DEV: PS1 not found : $Ps1Path"  }
        $RawXaml = Get-Content -Path $XamlPath -Encoding UTF8 -Raw
        $RawPs1  = Get-Content -Path $Ps1Path  -Encoding UTF8 -Raw

        # Detect changes
        $InteractionDevHash = & $Sync.Config.Helpers.GenerateHash $RawXaml, $RawPs1
        if ($Sync.DEV_InteractionHash -ne $InteractionDevHash) {
            $Sync.DEV_InteractionHash = $InteractionDevHash
            $Sync.InteractionHash     = $null   # mismatch → NeedsLoad = $true → $InitInteraction
        }

        # Strip Border wrapper (WrapperForDEV) and its Border.Resources
        [xml]$XamlDoc = $RawXaml

        # Extract content node (skip Border.Resources)
        $ContentNode = $XamlDoc.DocumentElement.ChildNodes |
                        Where-Object { $_.LocalName -notin @('Border.Resources', 'Border.DataContext') } |
                        Select-Object -First 1

        # Rebuild a standalone XML document with proper namespace declarations
        $NsXaml = 'http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        $NsX    = 'http://schemas.microsoft.com/winfx/2006/xaml'

        $NewDoc  = [System.Xml.XmlDocument]::new()
        $Imported = $NewDoc.ImportNode($ContentNode, $true)
        $NewDoc.AppendChild($Imported) | Out-Null
        $NewDoc.DocumentElement.SetAttribute('xmlns',   $NsXaml)
        $NewDoc.DocumentElement.SetAttribute('xmlns:x', $NsX)
        $NewDoc.DocumentElement.RemoveAttribute('x:Key')

        $CleanXaml = $NewDoc.OuterXml

        # Inject clean XAML into PS1 and evaluate
        $Ps1Injected = $RawPs1 -replace '(?s)#INTERACTION_VISUAL\r?\n.*?\r?\n\s*#INTERACTION_VISUAL', "@`"`n$CleanXaml`n`"@"
        $InteractionDef   = Invoke-Expression $Ps1Injected

        # Register interaction
        $Sync.Config.Interactions[$DevType] = $InteractionDef
        $Interaction = $InteractionDef
    }
    #endregion DEV (HOT RELOAD)

    #region Early returns, Help & Validation
    # Output the current interaction handle (move to async after a sync call)
    if ($GetHandle.IsPresent) {
        if ($null -eq $Sync.Handle) { throw 'No active interaction handle.' }
        return $Sync.Handle
    }

    # -Help : Command help & available interaction types
    if ($Help.IsPresent -and -not $PSBoundParameters.ContainsKey('Type')) {
        $HelpObj  = Get-Help -Name $MyInvocation.MyCommand.Name -Full
        $HighlightColor = "Cyan"
        
        Write-Host "`nNAME`n    $($HelpObj.name)`n"
        Write-Host "SYNOPSIS`n    $($HelpObj.synopsis)`n"
        Write-Host "DESCRIPTION"
        $HelpObj.description | ForEach-Object {
            $_.Text -split "`n" | ForEach-Object { Write-Host "    $_" }
        } ; Write-Host

        Write-Host "SYNTAX"
        $ExcludeSyntax = 'DynamicArgs', 'Show', 'InstanceID'
        $SyntaxParts   = @(
            $HelpObj.syntax.syntaxItem[0].parameter |
                Where-Object { $_.Name -notin $ExcludeSyntax } |
                ForEach-Object {
                    $TypePart = if ($_.parameterValue) { " <$($_.parameterValue)>" } else { '' }
                    "[-$($_.Name)$TypePart]"
                }
        ) + '[<CommonParameters>]'
        Write-Host "    $($HelpObj.name) " -NoNewline
        foreach ($Token in $SyntaxParts) {
            if ($Token -match '^(\[{0,2})(-\w+)(.*)$') {
                Write-Host $Matches[1]       -NoNewline
                Write-Host $Matches[2]       -NoNewline -ForegroundColor $HighlightColor
                Write-Host "$($Matches[3]) " -NoNewline
            } else {
                Write-Host "$Token " -NoNewline
            }
        }
        Write-Host "`n"

        Write-Host "PARAMETERS"
        $Included = 'Type','Help','IconBrush','IconPreset','Title','NoCancel',
        'Description','Async','Force','GetHandle','CustomInteraction'
        $HelpObj.parameters.parameter | Where-Object { $_.Name -in $Included } | ForEach-Object {
            Write-Host "    -$($_.Name)" -ForegroundColor $HighlightColor -NoNewline
            Write-Host " <$($_.type.name)>"
            $_.description.Text -split "`n" | ForEach-Object { Write-Host "        $_" }

            # Inject interaction list under -Type
            if ($_.Name -eq 'Type') {
                $Lines = $Sync.Config.Interactions.GetEnumerator() | Sort-Object Key |
                    Select-Object @{n='Name';e={$_.Key}}, @{n='Sep';e={' - '}}, @{n='Description';e={$_.Value.Description}} |
                    Format-Table -AutoSize -HideTableHeaders | Out-String
                $Lines -split "`r?\n" | Where-Object { $_ -match '\S' } | ForEach-Object {
                    $i = $_.IndexOf(' - ')
                    Write-Host '        ' -NoNewline
                    Write-Host $_.Substring(0, $i) -ForegroundColor $HighlightColor -NoNewline
                    Write-Host $_.Substring($i)
                }
            }
            Write-Host
        }

        # EXAMPLES
        $HelpObj.examples.example | ForEach-Object {
            Write-Host "EXAMPLE $($_.title.Trim('-', ' ').Split(" ")[-1])"
            Write-Host "    $($_.code)"
            $_.remarks | ForEach-Object {
                $_.Text -split "`r?\n" | Where-Object { $_ -match '\S' } | ForEach-Object {
                    Write-Host "    $_"
                }
            }
            Write-Host
        }
        return
    }

    # Fallback to current type if -Type is omitted; required for the first call of any interaction.
    if (-not $PSBoundParameters.ContainsKey('Type')) {
        if ($PSBoundParameters.ContainsKey('CustomInteraction')) {
            throw "A name is required when providing a custom interaction. Please use the '-Name' parameter."
        }
        if (-not $Sync.CurrentType) {
            throw "No active interaction type, specify '-Type'. Available: $($Sync.Config.Interactions.Keys -join ', ')."
        }
        $Type = $Sync.CurrentType
    }

    # Custom interaction validation
    if ($PSBoundParameters.ContainsKey('CustomInteraction')) {
        $Interactions = $Sync.Config.Interactions
        if ($Interactions.ContainsKey($Type) -and $null -eq $Interactions[$Type]._customFlag) {
            throw "The name `"$Type`" is reserved for a built-in interaction. Please choose a different name for your custom interaction."
        }
        #### TBD CHECK FOR CUSTOM Interaction SIGNATURE
        if ($Interactions.ContainsKey($Type) -and $Interactions[$Type]._customFlag -and -not $Force.IsPresent) {
            throw "A custom interaction named `"$Type`" already exists. Use '-Force' to override it."
        }      
        if (-not $CustomInteraction.ContainsKey('Xaml')) { throw "Custom interaction must contain a 'Xaml' key." }
        & $Sync.Config.Helpers.ValidateXaml $CustomInteraction.Xaml "Custom interaction 'Xaml'"

        #### TBD CHECK EVERY PARAM hAS A 'TYPE' KEY

        if (-not $CustomInteraction.ContainsKey('Parameters')) { $CustomInteraction.Parameters = @{} }
        $CustomInteraction._customFlag = $true
        $Interactions[$Type] = $CustomInteraction
        Remove-Variable "Interactions"
    }

    # Throw when interaction type does not exist
    if (-not $Sync.Config.Interactions.ContainsKey($Type)) {
        $BuiltIn = $Sync.Config.Interactions.Keys.Where({-not $Sync.Config.Interactions[$_]._customFlag}) -join ', '
        $Custom  = $Sync.Config.Interactions.Keys.Where({     $Sync.Config.Interactions[$_]._customFlag}) -join ', '
        $Msg = "Unknown interaction type '$Type'."
        if ($BuiltIn) { $Msg += "`nBuilt-in : $BuiltIn" }
        if ($Custom)  { $Msg += "`nCustom   : $Custom" }
        throw $Msg
    } else { $Interaction  = $Sync.Config.Interactions[$Type] }

    # -Type <name> -Help : Specified interaction type help
    if ($Help.IsPresent) {
        $HighlightColor = "Cyan"

        Write-Host "`nINTERACTION " -NoNewline
        Write-Host "$Type" -ForegroundColor $HighlightColor
        Write-Host "    $($Interaction.Description)`n"
        
        Write-Host "SYNTAX"
        $SyntaxParts = @(
            "-Type $Type"
            $Interaction.Parameters.GetEnumerator() |
                Where-Object { $_.Value['HelpText'] -ne $false } |
                ForEach-Object {
                    $Def = $_.Value
                    $TypePart = if ($Def.Type -eq [switch]) { '' } 
                    else { " <$(& $Helpers.TitleCaseStr (& $Helpers.FriendlyType $Def.Type))>" }
                    "[-$($_.Name)$TypePart]"
                }
        ) + '[<StaticParameters>]' + '[<CommonParameters>]'
        Write-Host "    $($MyInvocation.MyCommand.Name) " -NoNewline
        foreach ($Token in $SyntaxParts) {
            if ($Token -match '^(\[{0,2})(-\w+)(.*)$') {
                Write-Host $Matches[1]       -NoNewline
                Write-Host $Matches[2]       -NoNewline -ForegroundColor $HighlightColor
                Write-Host "$($Matches[3]) " -NoNewline
            } else {
                Write-Host "$Token " -NoNewline
            }
        }
        Write-Host "`n"

        Write-Host "PARAMETERS"
        $Interaction.Parameters.GetEnumerator() |
            Where-Object { $_.Value.HelpText -ne $false } | # HelpText=$false = intentionally hidden
            ForEach-Object {
                $Def = $_.Value
                Write-Host "    -$($_.Key)" -ForegroundColor $HighlightColor -NoNewline
                Write-Host " <$(& $Helpers.TitleCaseStr (& $Helpers.FriendlyType $Def.Type))>"
                if (-not [string]::IsNullOrEmpty($Def.HelpText)) { & $Helpers.ReindentText $Def.HelpText | Write-Host }
                $Lines = $Def.GetEnumerator().Where({$_.Name -notin ('Type','HelpText')}) | 
                    Sort-Object Name | Select-Object Name, @{n='S';e={':'}}, @{n='V';e={if ($_.Value -is [string]) { "`"$($_.Value)`"" } else { $_.Value }}} |
                    Format-Table -AutoSize -HideTableHeaders | Out-String
                $Lines -split "`r?\n" | Where-Object { $_ -match '\S' } |ForEach-Object {
                    Write-Host "        $_"
                }
                Write-Host
            }

        # EXAMPLE
        if ($Interaction.ContainsKey('Example')) {
            Write-Host "EXAMPLE"
            if (-not [string]::IsNullOrEmpty($Interaction.Example)) { & $Helpers.ReindentText $Interaction.Example 4 | Write-Host}
        }
        return
    }
    #endregion

    #region Runspace UI - [singleton, initialized once per InstanceID]
    if (-not (& $Sync.Config.Helpers.EnsureRunUI $Sync.STA_RS $Sync.STA_PS)) {
        # Script used in the runspace to handle the UI
        $WindowEngine = {
            Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase         
            # Forces the window to the foreground by briefly attaching the calling thread's
            # input queue to the foreground thread, bypassing Windows' foreground-lock policy.
            if (-not ([System.Management.Automation.PSTypeName]'WinFocus').Type) {
                Add-Type @"
                    using System;
                    using System.Runtime.InteropServices;
                    public class WinFocus {
                        [DllImport("user32.dll")]   static extern IntPtr GetForegroundWindow();
                        [DllImport("user32.dll")]   static extern uint   GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
                        [DllImport("kernel32.dll")] static extern uint   GetCurrentThreadId();
                        [DllImport("user32.dll")]   static extern bool   AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
                        [DllImport("user32.dll")]   static extern bool   SetForegroundWindow(IntPtr hWnd);
                        [DllImport("user32.dll")]   static extern bool   BringWindowToTop(IntPtr hWnd);
                        [DllImport("user32.dll")]   static extern void   keybd_event(byte vk, byte scan, uint flags, int extra);

                        public static void ForceForeground(IntPtr hwnd) {
                            uint pid = 0;
                            uint fgThread = GetWindowThreadProcessId(GetForegroundWindow(), out pid);
                            uint myThread = GetCurrentThreadId();
                            bool attached = fgThread != 0 && fgThread != myThread
                                        && AttachThreadInput(myThread, fgThread, true);
                            keybd_event(0, 0, 0, 0);
                            SetForegroundWindow(hwnd);
                            BringWindowToTop(hwnd);
                            if (attached) AttachThreadInput(myThread, fgThread, false);
                        }
                    }
"@          }
            #region UI Helpers
            $LoadXamlObj = {
                param($Xaml)
                return [Windows.Markup.XamlReader]::Load(
                    [System.Xml.XmlNodeReader]::new([xml]$Xaml)
                )
            }
            #endregion

            # Initial UI load
            $EnsureWindow = {
                if (-not $Sync.UI_Window -or ($Sync.UI_Window.IsLoaded -and
                    # Alt+F4 zeroes the HWND without triggering WPF's Closing event.
                    [System.Windows.Interop.WindowInteropHelper]::new($Sync.UI_Window).Handle -eq [IntPtr]::Zero)
                ) {
                    $Sync.UI_Window = & $LoadXamlObj $Sync.Config.Layout
                    $Sync.UI_Window.Resources.MergedDictionaries.Add((& $LoadXamlObj $Sync.Config.Styles))
                    # Identify base elements
                    foreach ($Entry in $Sync.Config.Elements.GetEnumerator()) {
                        $Element = $Sync.UI_Window.FindName($Entry.Value)
                        if ($Element) { $Sync[$Entry.Key] = $Element }
                        else          { throw "Window element `"$($Entry.Value)`" not found." }
                    }

                    # Events (Drag, Close cancel, Hide on output)
                    $Sync.UI_Title.Parent.Add_MouseLeftButtonDown{ $Sync.UI_Window.DragMove() }
                    $Sync.UI_Close.Add_Click{ $Sync.UI_Window.Close() }
                    $Sync.UI_Window.Add_Closing{
                        if ($Sync.ForceClose) { $Sync.Remove('ForceClose') ; return }
                        $_.Cancel = $true ; $Sync.UI_Window.Hide()
                    }
                    $Sync.UI_Window.Add_IsVisibleChanged{
                        if ($Sync._PreWarming) { return }
                        if (-not $_.NewValue) {
                            # Fix flickering
                            $Sync.UI_Window.Content.Visibility = "Collapsed"
                            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke("Render", [action]{})

                            if (-not $Sync.ContainsKey('Output')) { $Sync.Output = $null }
                        } else {
                            $Sync.UI_Window.Content.Visibility = "Visible"
                            $HWND = [System.Windows.Interop.WindowInteropHelper]::new($Sync.UI_Window).Handle
                            [WinFocus]::ForceForeground($HWND)
                            $Sync.UI_Window.Activate()
                            $Sync.UI_Window.Focus()
                        }
                    }

                    # Force full render pipeline on first window creation
                    $Sync._PreWarming = $true
                    $Sync.UI_Window.Opacity = 0
                    $Sync.UI_Window.Show()
                    $Sync.UI_Window.Hide()
                    $Sync.UI_Window.Opacity = 1
                    $Sync.Remove('_PreWarming')
                }
            }
            try { & $EnsureWindow } 
            catch { $Sync.ErrorQueue.Enqueue(@{ Record = $_ ; Terminating = $true ; Displayed = $false }) }

            # To apply static parameters (Title, IconBrush...) 
            $SetStaticArgs = {
                param([hashtable]$Params)
                try {
                    if ($Params.ContainsKey('IconBrushResolved')) {
                        if (-not [string]::IsNullOrEmpty($Params.IconBrushResolved)) {
                            $Sig = $Params.IconBrushResolved
                        } else { $Sig = "0" }

                        if ($Sig -ne $Sync.UI_Icon.Tag) {
                            if ($Sig -eq "0") {  $Sync.UI_Icon.Background = $null } 
                            else { $Sync.UI_Icon.Background = & $LoadXamlObj $Params.IconBrushResolved }
                            $Sync.UI_Icon.Tag = $Sig
                        }
                    }
                } catch {
                    throw [System.ArgumentException]::new("Provided XAML is not a valid Brush.", 'IconBrush')
                }
                if ($Params.ContainsKey('Title'))    { $Sync.UI_Title.Text = $Params.Title }
                if ($Params.ContainsKey('Description'))    { $Sync.UI_Description.Text = $Params.Description }
                if ($Params.ContainsKey('NoCancel')) { $Sync.UI_Close.IsEnabled = -not $Params.NoCancel }
            }

            # Interaction processing scriptblocks
            $InitInteraction = {
                param([hashtable]$Pending)

                if (-not $Pending.Load -and $null -ne $Sync.UI_Interaction.Content) { return }
                $Interaction = $Pending.Interaction

                # Clean up the outgoing interaction using the current DataContext,
                # which holds the exact interaction definition that is currently running.
                $PrevCtx = $Sync.UI_Window.DataContext
                if ($null -ne $PrevCtx -and $PrevCtx.Interaction.ContainsKey('Dispose')) {
                    try { ([scriptblock]::Create($PrevCtx.Interaction.Dispose.ToString())).Invoke($PrevCtx) }
                    catch { $Sync.ErrorQueue.Enqueue(@{ Record = $_ ; Source = 'DisposeInteraction' ; Terminating = $false ; Displayed = $false }) }
                }

                $Sync.UI_Interaction.Content = $null
                $Sync.UI_Window.DataContext  = $null

                [xml]$Doc  = $Interaction.Xaml
                $Root      = $Doc.DocumentElement
                $RootTag   = $Root.LocalName
                $NsUri     = $Root.NamespaceURI

                # Import style child nodes from the shared Styles block into the current document
                $StylesChildren = ([xml]$Sync.Config.Styles).DocumentElement.ChildNodes

                # Look for an existing Resources node (e.g. <StackPanel.Resources>)
                $ResourcesNode = $Root.ChildNodes |
                                    Where-Object { $_.LocalName -eq "$RootTag.Resources" } |
                                    Select-Object -First 1

                if ($null -eq $ResourcesNode) {
                    # No Resources node found — create one and prepend it to the root
                    $ResourcesNode = $Doc.CreateElement("$RootTag.Resources", $NsUri)
                    $Root.PrependChild($ResourcesNode) | Out-Null
                }

                # Merge each style into the existing or newly created Resources node
                foreach ($StyleNode in $StylesChildren) {
                    $Imported = $Doc.ImportNode($StyleNode, $true)
                    $ResourcesNode.AppendChild($Imported) | Out-Null
                }

                $InteractionRoot             = & $LoadXamlObj $Doc.OuterXml
                $Sync.UI_Interaction.Content = $InteractionRoot

                $Elements = @{}
                if (-not [string]::IsNullOrEmpty($InteractionRoot.Name)) {
                    $Elements[$InteractionRoot.Name] = $InteractionRoot
                }
                foreach ($Node in ([xml]$Interaction.Xaml).SelectNodes(
                        "//*[@*[contains(translate(name(.),'n','N'),'Name')]]")) {
                    $Elements[$Node.Name] = $InteractionRoot.FindName($Node.Name)
                }

                $Ctx = @{ Sync = $Sync; Elements = $Elements; Params = $Pending.Params; Interaction = $Interaction }
                $Sync.UI_Window.DataContext = $Ctx

                if ($Interaction.ContainsKey('Init')) {
                    & ([scriptblock]::Create($Interaction.Init.ToString())) $Ctx
                }
                $Sync.CurrentType = $Pending.Type
            }
            $UpdateInteraction = {
                param([hashtable]$Pending)

                $Ctx = $Sync.UI_Window.DataContext
                if ($null -eq $Ctx) {
                    $Ex = [System.InvalidOperationException]::new('Update called but DataContext is null.')
                    throw [System.Management.Automation.ErrorRecord]::new($Ex, 'NullDataContext', 'InvalidOperation', $null)
                }
                foreach ($Key in @($Pending.Params.Keys)) { $Ctx.Params[$Key] = $Pending.Params[$Key] }
                $Mod = if ($null -ne $Pending.Interaction) { $Pending.Interaction }
                       else { $Sync.Config.Interactions[$Sync.CurrentType] }
                if ($null -ne $Mod -and $Mod.ContainsKey('Update')) {
                    ([scriptblock]::Create($Mod['Update'].ToString())).Invoke($Ctx)
                }
            }

            ## Request contract : @{Params; Interaction; Load; Type; Show}
            # Params  : resolved static & dynamic args (persisted + defaults)
            # Interaction  : interaction definition, always present regardless of Load
            # Load    : whether to (re)initialize the interaction UI
            # Type    : interaction type name (set on init only)
            # Show    : whether to display the window after processing
            $ProcessQueue = {
                $Pending = $null
                while ($Sync.RequestQueue.TryDequeue([ref]$Pending)) {
                    if ([Linq.Enumerable]::Any($Sync.ErrorQueue, [Func[object,bool]]{ $args[0].Terminating })) { continue }

                    # Check window integrity - reload if necessary
                    try { & $EnsureWindow }
                    catch { $Sync.ErrorQueue.Enqueue(@{ Record = $_ ; Source = 'EnsureWindow' ; Terminating = $true ; Displayed = $false }) ; return }

                    # Apply static parameters
                    try { & $SetStaticArgs $Pending.Params }
                    catch { $Sync.ErrorQueue.Enqueue(@{ Record = $_ ; Source = 'SetStaticArgs' ; Terminating = $false ; Displayed = $false }) }

                    # Init the interaction once (returns early when Pending.Interaction is empty)
                    try { & $InitInteraction $Pending }
                    catch { $Sync.ErrorQueue.Enqueue(@{ Record = $_ ; Source = 'InitInteraction' ; Terminating = $false ; Displayed = $false}) }

                    # Update current interaction (apply dynamic args)
                    try { & $UpdateInteraction $Pending }
                    catch { $Sync.ErrorQueue.Enqueue(@{ Record = $_ ; Source = 'UpdateInteraction' ; Terminating = $false ; Displayed = $false}) }

                    # Show the window
                    if ($Pending.Show) { $Sync.UI_Window.Show() }
                }
            }
            $Sync.ProcessQueueAction = [action]$ProcessQueue

            $WaitRS = [runspacefactory]::CreateRunspace()
            $WaitRS.ApartmentState = [System.Threading.ApartmentState]::MTA
            $WaitRS.Open()
            $WaitRS.SessionStateProxy.SetVariable('Sync',       $Sync)
            $WaitRS.SessionStateProxy.SetVariable('Dispatcher', [System.Windows.Threading.Dispatcher]::CurrentDispatcher)
            $Sync.MTA_CTS = [System.Threading.CancellationTokenSource]::new()

            $WaitPS = [powershell]::Create()
            $WaitPS.Runspace = $WaitRS
            [void]$WaitPS.AddScript({
                while ($true) {
                    $Sync.Signal.Wait($Sync.MTA_CTS.Token)
                    $Dispatcher.BeginInvoke($Sync.ProcessQueueAction)
                }
            })
            $WaitPS.BeginInvoke() | Out-Null
            $Sync.MTA_RS = $WaitRS
            $Sync.MTA_PS = $WaitPS

            # Lightweight timer - only used to surface PendingOutput back to the main thread
            $Timer = [System.Windows.Threading.DispatcherTimer]::new()
            $Timer.Interval = [timespan]::FromMilliseconds(50)
            $Timer.Add_Tick{
                foreach ($Err in $Sync.ErrorQueue.Where({ -not $_.Displayed })) {
                    $Sync.Host.UI.WriteWarningLine("UI Engine error ($($Err.Source)):")
                    $Sync.Host.UI.WriteErrorLine(($Err.Record | Out-String))
                    $Err.Displayed = $true
                    if ($Err.Terminating) { $Sync.Output = $null }
                }
                if ($Sync.ContainsKey('PendingOutput')) {
                    $Sync.Output = $Sync.PendingOutput
                    $Sync.Remove('PendingOutput')
                    if ($Sync.UI_Window.IsVisible) { 
                        $Sync.UI_Window.Hide()
                    }
                }
            }
            $Timer.Start()

            [System.Windows.Threading.Dispatcher]::Run()
        }                  
        
        # Launch the instance
        try {
            # Clear last existing instances
            & $Sync.Config.Helpers.DisposeRunUI $Sync 'MTA_CTS','STA_PS','STA_RS','MTA_PS','MTA_RS','Signal'
                   
            $Sync.ErrorQueue   = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
            $Sync.RequestQueue = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
            $Sync.Signal       = [System.Threading.SemaphoreSlim]::new(0)

            $Runspace = [runspacefactory]::CreateRunspace($Host)
            $Runspace.ApartmentState = [System.Threading.ApartmentState]::STA
            $Runspace.Open()
            $Sync.STA_RS = $Runspace
            $Runspace.SessionStateProxy.SetVariable('Sync', $Sync)
            
            $Posh = [powershell]::Create()
            $Posh.Runspace = $Runspace
            [void]$Posh.AddScript($WindowEngine)
            $Sync.STA_PS = $Posh

            $Posh.BeginInvoke() | Out-Null
        } 
        catch {
            & $Sync.Config.Helpers.DisposeRunUI $Sync 'STA_PS','STA_RS','Signal'
            throw $_
        }
    }    
    #endregion

    #region UI Parameters resolution
    $IsSameInteraction = $Type -eq $Sync.CurrentType
    $IsPersisted       = $PSBoundParameters.ContainsKey('Async') -and $PSBoundParameters['Async'] -eq $true

    #== Base params ==
    # Declared from persisted params or empty hashtable
    $Params = if ($IsPersisted -and $null -ne $Sync.SessionParams) {
        $Sync.SessionParams.Clone()
    } else { @{} }

    #== Merge params ==
    # Params ← Static defaults
    foreach ($Name in $Sync.Config.StaticArgs) {
        if ($Params.ContainsKey($Name)) { continue }
        $Value = $ExecutionContext.SessionState.PSVariable.GetValue($Name)
        if ($Value -is [switch]) { $Value = $Value.IsPresent }
        if ($null -ne $Value)    { $Params[$Name] = $Value }    
    }

    # Params ← DynamicArgs
    $DynResolved = & $Helpers.ParseDynArgs $DynamicArgs
    foreach ($Key in $DynResolved.Keys) { $Params[$Key] = $DynResolved[$Key] }

    # Params ← Static bounds
    foreach ($Name in $Sync.Config.StaticArgs) {
        if ($PSBoundParameters.ContainsKey($Name)) {
            $Params[$Name] = $PSBoundParameters[$Name]
        }
    }

    #region Icon resolution
    # When persisted, strip any IconBrush/IconPreset injected by merges that wasn't in SessionParams
    if ($IsPersisted -and $null -ne $Sync.SessionParams) {
        foreach ($Name in 'IconBrush','IconPreset') {
            if ($Params.ContainsKey($Name) -and -not $Sync.SessionParams.ContainsKey($Name) -and
                -not $PSBoundParameters.ContainsKey($Name) -and -not $DynResolved.ContainsKey($Name)) {
                $Params.Remove($Name)
            }
        }
    }

    # 'Default' → restore function defaults
    if ($Params.IconPreset -eq 'Default') {
        $Params.Remove('IconPreset') ; $Params.Remove('IconBrush') ; $Params.Remove('IconBrushResolved')
        if ($Sync.Config.DefaultIconBrush)  { $Params.IconBrush  = $Sync.Config.DefaultIconBrush }
        if ($Sync.Config.DefaultIconPreset) { $Params.IconPreset = $Sync.Config.DefaultIconPreset }
    }

    # Resolve by priority
    $KeyToRemove = $null
    if (-not $PSBoundParameters.ContainsKey('IconPreset') -and -not [string]::IsNullOrEmpty($Params.IconPreset)) {
        $KeyToRemove = 'IconBrush'  ; $Params.IconBrushResolved = $Sync.Config.IconPresets[$Params.IconPreset]
    }
    if (-not $PSBoundParameters.ContainsKey('IconBrush') -and -not [string]::IsNullOrEmpty($Params.IconBrush) ) {
        $KeyToRemove = 'IconPreset' ; $Params.IconBrushResolved = $Params.IconBrush
    }
    if ($PSBoundParameters.ContainsKey('IconBrush')) {
        $KeyToRemove = 'IconPreset' ; $Params.IconBrushResolved = $Params.IconBrush
    }
    if ($PSBoundParameters.ContainsKey('IconPreset') -and $IconPreset -ne 'Default') {
        $KeyToRemove = 'IconBrush'  ; $Params.IconBrushResolved = $Sync.Config.IconPresets[$Params.IconPreset]
    }
    if ($PSBoundParameters.ContainsKey('IconPreset') -and $IconPreset -eq 'Default' -and -not [string]::IsNullOrEmpty($Params.IconBrush)) {
        $KeyToRemove = 'IconPreset' ; $Params.IconBrushResolved = $Params.IconBrush
    }
    if ($PSBoundParameters.ContainsKey('IconPreset') -and $IconPreset -eq 'Default' -and [string]::IsNullOrEmpty($Params.IconBrush)) {
        $KeyToRemove = 'IconBrush'  ; $Params.IconBrushResolved = $Sync.Config.IconPresets[$Params.IconPreset]
    }
    if ($KeyToRemove) { $Params.Remove($KeyToRemove) }

    #endregion

    #== Validation ==
    #-- Statics (Window level)
    if ($Params.ContainsKey('IconBrush') -and -not [string]::IsNullOrEmpty($Params.IconBrush)) {
        & $Helpers.ValidateXaml $Params.IconBrush "Provided Brush XAML"
        $Params.IconBrush = & $Helpers.XamlToString $Params.IconBrush # Formatting for handle
    }

    #-- Dynamics (Interaction level)
    $Errors = [System.Collections.Generic.List[string]]::new()

    # Exclude init only parameters if the interaction is already alive
    if ($IsSameInteraction -and -not $Force.IsPresent -and $IsPersisted) {
        foreach ($Key in @($Params.Keys)) {
            $Def = $Interaction.Parameters[$Key]
            if ($Def -and $Def.InitOnly -and $DynResolved.ContainsKey($Key)) {
                Write-Warning "Parameter '-$Key' is InitOnly, cannot change after interaction init. Use '-Force' to reinitialize."
                # Restore init values to not mutate handle
                $Params[$Key] = $Sync.SessionParams[$Key]
            }
        }
    }

    # Default, Nullable, PSType
    foreach ($Key in $Interaction.Parameters.Keys) {
        $Def = $Interaction.Parameters[$Key]
        $DefType = & $Helpers.FriendlyType $Def.Type
        #== Parameter not specified / persisted
        # Fallback to 'Default' value from interaction signature
        # or NULL if 'Nullable' is not FALSE in definition
        if (-not $Params.ContainsKey($Key)) {
            if ($null -ne $Def.Default)       { $Params[$Key] = $Def.Default }
            elseif ($Def.Type -eq [switch])   { $Params[$Key] = $false }
            elseif ($Def.Nullable -eq $false) { 
                $Errors.Add("Missing required parameter '-$Key' [$DefType].") }
            continue
        }
        #== Attempt coercion, validate types | fallback to default
        # e.g. SwitchParameter → bool, string → int
        if ($null -ne $Params[$Key] -and $Params[$Key] -isnot $Def.Type) {
            $Converted = $Params[$Key] -as $Def.Type
            if ($null -ne $Converted) { $Params[$Key] = $Converted }
            else { $Errors.Add("Parameter `"-$Key`" cannot be coerced to [$DefType].") }
        }
        elseif ($null -eq $Params[$Key] -and $Def.Nullable -eq $false) {
            $Errors.Add("Parameter `"-$Key`" cannot be null.")
            $Params[$Key] = $Sync.SessionParams.$Key # Restore last valid value    
        }
        #== ValidateRange
        if ($null -ne $Def.ValidateRange -and $null -ne $Params[$Key]) {
            $Min, $Max = $Def.ValidateRange
            if ($Params[$Key] -lt $Min -or $Params[$Key] -gt $Max) {
                $Errors.Add("Parameter `"-$Key`" value '$($Params[$Key])' is out of range [$Min..$Max].")
                if ($null -ne $Sync.SessionParams -and $Sync.SessionParams.ContainsKey($Key)) {
                    $Params[$Key] = $Sync.SessionParams[$Key]
                }
            }
        }
        #== ValidateSet
        if ($null -ne $Def.ValidateSet -and $null -ne $Params[$Key]) {
            if ($Params[$Key] -notin $Def.ValidateSet) {
                $Valid = $Def.ValidateSet -join ', '
                $Errors.Add("Parameter `"-$Key`" value '$($Params[$Key])' is not in set [$Valid].")
                if ($null -ne $Sync.SessionParams -and $Sync.SessionParams.ContainsKey($Key)) {
                    $Params[$Key] = $Sync.SessionParams[$Key]
                }
            }
        }
    }

    # Warn on undeclared interaction parameters (one time per parameter)
    foreach ($Key in $Params.Keys) {
        if ($Interaction.Parameters.ContainsKey($Key) -or $Key -in $Sync.Config.StaticArgs -or
            ($null -ne $Sync.SessionParams -and $Sync.SessionParams.ContainsKey($Key)) -or
            -not $DynResolved.ContainsKey($Key) )
        { continue }
        Write-Warning "Parameter '-$Key' is not declared in interaction parameters."
    }

    # Throw if any invalid parameter
    if ($Errors.Count -gt 0) {
        $Errors | ForEach-Object { Write-Warning $_ }
        throw "Interaction '$Type' cannot be invoked: $($Errors.Count) invalid parameter(s)."
    }

    #== Async resolution ==
    if ($Params.ContainsKey('Async') -and $Params['Async']) {
        if (-not $PSBoundParameters.ContainsKey('Async')) { $PSBoundParameters['Async'] = $true }   
    }
    $Params.Remove('Async')
    #endregion

    #region Interaction handle - [rebuilt when interaction type changes or forced]
    if (-not $Sync.ContainsKey('Handle') -or $Type -ne $Sync.CurrentType -or $Force.IsPresent) {
        $Handle   = [PSCustomObject]@{}
        $PSO      = $Handle.PSObject
        $InteractionID = [guid]::NewGuid().ToString()
        $Sync.CurrentInteractionID = $InteractionID       
        # Fix case for type
        $Type = $Sync.Config.Interactions.Keys.Where({ $_ -eq $Type }, 'First')[0]

        #region Readonly properties
        $PSO.Properties.Add([System.Management.Automation.PSScriptProperty]::new(
            'InstanceID', [scriptblock]::Create("return '$InstanceID'")
        ))
        $PSO.Properties.Add([System.Management.Automation.PSScriptProperty]::new(
            'InteractionType', [scriptblock]::Create("return '$Type'")
        ))
        $PSO.Properties.Add([System.Management.Automation.PSScriptProperty]::new(
            'InteractionID', [scriptblock]::Create("return '$InteractionID'")
        ))
        $PSO.Properties.Add([System.Management.Automation.PSScriptProperty]::new(
            'Context', [scriptblock]::Create(
                "return `$ExecutionContext.SessionState.PSVariable.GetValue('$InstanceID')")       
        ))
        $PSO.Properties.Add([System.Management.Automation.PSScriptProperty]::new(
            'IsStale', { $null -eq $this.Context -or $this.InteractionID -ne $this.Context.CurrentInteractionID }
        ))
        $PSO.Properties.Add([System.Management.Automation.PSScriptProperty]::new(
            'IsVisible', { -not $this.IsStale -and $this.Context.UI_Window.IsVisible -eq $true }     
        ))
        $PSO.Properties.Add([System.Management.Automation.PSScriptProperty]::new(
            'HasOutput', { -not $this.IsStale -and $this.Context.ContainsKey('Output') }
        ))
        $PSO.Properties.Add([System.Management.Automation.PSScriptProperty]::new(
            'IsOutputNull', {
                if ($this.HasOutput) { $null -eq $this.Context.Output } else { "N/A" } }
        ))
        $PSO.Members.Add([System.Management.Automation.PSScriptProperty]::new(
            'Errors', {
                return @($this.Context.ErrorQueue | ForEach-Object { $_.Record })
            }))
        #endregion

        #region Static UI properties
        $GetterStr = "if (`$this.IsStale) { return `$null }; return `$this.Context.SessionParams['{0}']"
        $SetterStr = "
            `$this.AssertLive() | Out-Null
            `$this.Update('{0}', `$args[0])"
        foreach ($Name in $Sync.Config.StaticArgs) {
            $Getter = [scriptblock]::Create($GetterStr.Replace('{0}', $Name))
            $Setter = [scriptblock]::Create($SetterStr.Replace('{0}', $Name))
            $PSO.Properties.Add(
                [System.Management.Automation.PSScriptProperty]::new($Name, $Getter, $Setter)
            )
        }
        #endregion
        $Sync.Config.ReservedHandleProperties = @($Handle.PSObject.Properties.Name)

        #region Dynamic UI properties
        $GetterStr = "if (`$this.IsStale) { return `$null }; return `$this.Context.SessionParams['{0}']"
        $SetterStr = "
            `$this.AssertLive() | Out-Null
            `$Def = `$this.Context.Config.Interactions['{1}'].Parameters['{0}']
            if (`$Def['InitOnly']) {
                Write-Warning `"Parameter '-{0}' is InitOnly and cannot be changed after init.`"
                return
            }
            `$this.Update('{0}', `$args[0])
        "
        foreach ($Name in $Interaction.Parameters.Keys) {
            if ($Sync.Config.ReservedHandleProperties -contains $Name) {
                Write-Warning "Interaction `"$Type`" parameter `"-$Name`" conflicts with a reserved property and will not be exposed on the handle."
                continue
            }
            if ($Sync.Config.FunctionArgs.Contains($Name)) { continue } # Skip function-level parameters exposed in interaction definition
            $Getter = [scriptblock]::Create($GetterStr.Replace('{0}', $Name))
            $Setter = [scriptblock]::Create($SetterStr.Replace('{0}', $Name).Replace('{1}', $Type))
            $PSO.Properties.Add(
                [System.Management.Automation.PSScriptProperty]::new($Name, $Getter, $Setter)
            )
        }
        #endregion

        #region Methods
        # Liveness guard, called by setters and methods
        $PSO.Methods.Add([System.Management.Automation.PSScriptMethod]::new(
            'AssertLive', {
                if ($null -eq $this.Context) {
                    throw "Interaction instance '$($this.InstanceID)' no longer exists."
                }
                if ($this.IsStale) {
                    throw "Handle '$($this.InteractionType)#$($this.InteractionID)' is stale.`nCurrent: '$($this.Context.CurrentType)#$($this.Context.CurrentInteractionID)'."
                }
                $true
            }))
        # Re-display with current sessionParams (carry-forward)
        $PSO.Methods.Add([System.Management.Automation.PSScriptMethod]::new(
            'Show', {
                $this.AssertLive() | Out-Null
                Invoke-Interaction -Type $this.InteractionType -Async -InstanceID $this.InstanceID | Out-Null
            }))
        # Push a single param change without changing current window visibility.
        $PSO.Methods.Add([System.Management.Automation.PSScriptMethod]::new(
            'Update', {
                param([string]$Name, [object]$Value)
                $this.AssertLive() | Out-Null
                $Param = @{ $Name = $Value }
                Invoke-Interaction -Type $this.InteractionType @Param -Async -Show $false -InstanceID $this.InstanceID | Out-Null
            }))
        # Block until the user produces output (or dismisses)
        $PSO.Methods.Add([System.Management.Automation.PSScriptMethod]::new(
            'GetOutput', {
                $this.AssertLive() | Out-Null
                $Sync = $this.Context

                # Wait for output
                while (-not $Sync.ContainsKey('Output')) {
                    try { & $Sync.Config.Helpers.EnsureRunUI $Sync.STA_RS $Sync.STA_PS $True | Out-Null }
                    catch {
                        foreach ($StreamErr in $Sync.STA_PS.Streams.Error.ReadAll()) {
                            Write-Error -ErrorRecord $StreamErr
                        }
                        throw $_
                    }
                    Start-Sleep -Milliseconds 50
                }

                $Output = $Sync['Output'] ; $Sync.Remove('Output')
                return $Output
            }))
        # Shut down the runspace and release all resources
        $PSO.Methods.Add([System.Management.Automation.PSScriptMethod]::new(
            'Dispose', {
                $Sync = $this.Context
                if ($null -eq $Sync) { throw "Interaction instance '$($this.InstanceID)' no longer exists." }
                if ($null -ne $Sync.UI_Window) {
                    $Sync.ForceClose = $true
                    $Sync.UI_Window.Dispatcher.InvokeShutdown()
                }
                & $Sync.Config.Helpers.DisposeRunUI $Sync 'MTA_CTS','STA_PS','STA_RS','MTA_PS','MTA_RS','Signal' | Out-Null
                Remove-Variable -Name $this.InstanceID -Scope Global -ErrorAction SilentlyContinue
            }))
        #endregion

        $Sync.Handle = $Handle
    }
    #endregion

    #region Dispatch
    # $Params, $Helpers, $Interaction, $IsPersisted, $IsSameInteraction
    # ↪ Declared in region "UI Parameters resolution"
    $InteractionHash = & $Helpers.GenerateHash ([xml]$Interaction.Xaml).OuterXml, $Interaction.Init, $Interaction.Update
    $NeedsLoad = -not $IsPersisted -or -not $IsSameInteraction -or $InteractionHash -ne $Sync.InteractionHash -or $Force.IsPresent

    # Enqueue RequestItem
    $Pending = @{ 
        Params = $Params
        Interaction = $Interaction
        Load   = $NeedsLoad
        Type   = $Type
        Show   = $Show
    }
    $Sync.RequestQueue.Enqueue($Pending)
    $Sync.Signal.Release() | Out-Null

    # Save state for next call
    $Sync.InteractionHash = $InteractionHash
    $Sync.SessionParams   = $Params
    $Sync.CurrentType     = $Type # Optimistic set to prevent async race condition

    # Discard previous output and errors - skip on internal update calls
    if ($Show) {
        $Sync.Remove('Output')
        $Err = $null
        while ($Sync.ErrorQueue.TryDequeue([ref]$Err)) {}
        if ($Sync.STA_PS) { $Sync.STA_PS.Streams.Error.ReadAll() }
    }
    
    if ($PSBoundParameters.ContainsKey('Async') -and $PSBoundParameters['Async'] -eq $true) { return $Sync.Handle }
    return $Sync.Handle.GetOutput()
    #endregion
}