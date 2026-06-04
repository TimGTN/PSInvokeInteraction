@{
    Name = "MessageBox"
    Description = "Configurable message box with custom buttons and status icon."
    Parameters  = @{
        Message     = @{ Type=[string]; Default=$null
                         HelpText="Text content displayed inside the message box." }
        MessageIcon = @{ Type=[string]; Default="Information"
                         HelpText="Sets the status icon. Valid values: 'Inherit' (same as window), 
                         a preset name ('Default','Warning','Information','Help','Error','Success'), 
                         a custom WPF brush (like -IconBrush), or $null to collapse the icon." }
        Buttons     = @{ Type=[string[]]; Default="Ok","Cancel"
                         HelpText="Custom buttons generated right-to-left. First one gets primary styling." }
    }
    Xaml = #INTERACTION_VISUAL
    '' # AUTOMATICALLY INJECTED BY DEV FUNCTION or BUILD
#INTERACTION_VISUAL
    Init = {
        param($Ctx)
        $Ctx.Elements.LBX_Buttons.Add_PreviewMouseLeftButtonDown{
            $Button = $_.OriginalSource.TemplatedParent
            if ($Button -is [System.Windows.Controls.Button]) {
                $Ctx = $_.Source.DataContext
                $Ctx.Sync.PendingOutput = $Button.Content
            }
        }
    }
    Update = {
        param($Ctx)
        # Apply icon
        try {
            $Brush = switch ($Ctx.Params.MessageIcon) {
                $null     { $null ; break }
                "Inherit" { $Ctx.Sync.UI_Icon.Background ; break }
                Default   { 
                    if ($Ctx.Sync.Config.IconPresets.ContainsKey("$_")) {
                         & $LoadXamlObj $Ctx.Sync.Config.IconPresets["$_"] 
                    } else { & $LoadXamlObj $_ }
                }
            }
            $Ctx.Elements.CVS_Icon.Background = $Brush
        } catch {
            $Ctx.Sync.Host.UI.WriteWarningLine("MessageAction Icon configuration failed")       
            $Ctx.Sync.ErrorQueue.Enqueue(@{ Record = $_ ; Source = 'UpdateInteraction' ; Terminating = $false ; Displayed = $false}) 
        }
        # Message
        $Ctx.Elements.TBK_Message.Text = $Ctx.Params.Message
        # Apply buttons
        $FirstFlag = $True
        $Ctx.Elements.LBX_Buttons.ItemsSource = @($Ctx.Params.Buttons | ForEach-Object {
            [PsCustomObject]@{ Content = $_ ; Tag = $FirstFlag }
            $FirstFlag = $false
        })
    }
}