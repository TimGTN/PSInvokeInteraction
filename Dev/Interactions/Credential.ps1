@{
    Name = "Credential"
    Description = "Secure credential prompt returning a standard PSCredential object."
    Parameters  = @{
        UsernameLabel       = @{ Type=[string]; Default="Login :"
                                 HelpText="Title for the username field." }
        UsernamePlaceholder = @{ Type=[string]; Default="..."
                                 HelpText="Temporary hint text displayed inside the username field." }
        UsernameCurrentText = @{ Type=[string]
                                 HelpText="Current value of the username field." }
        PasswordLabel       = @{ Type=[string]; Default="Password :"
                                 HelpText="Title for the password field." }
        PasswordPlaceholder = @{ Type=[string]; Default="..."
                                 HelpText="Temporary hint text displayed inside the password field." }
        OkText              = @{ Type=[string]; Default="Ok" 
                                 HelpText="Label for the confirmation button." }
        CancelText          = @{ Type=[string]; Default="Cancel" 
                                 HelpText="Label for the cancellation button." }
    }
    Xaml = #INTERACTION_VISUAL
    '' # AUTOMATICALLY INJECTED BY DEV FUNCTION or BUILD
#INTERACTION_VISUAL
    Init = {
        param($Ctx)
        $Ctx.Elements.BTN_Ok.Add_Click{
            $Ctx = $_.Source.DataContext
            $Ctx.Sync.PendingOutput = [pscredential]::new(
                $Ctx.Elements.TBX_UserName.Text,
                $Ctx.Elements.PBX_Password.SecurePassword
            )
        }
        $Ctx.Elements.BTN_Cancel.Add_Click{
            $Ctx = $_.Source.DataContext
            $Ctx.Sync.PendingOutput = $null
        }
        $Ctx.Elements.TBX_UserName.Add_PreviewKeyDown{
            if ($_.Key -eq "Enter"){
                $BTN = $_.Source.DataContext.Elements.BTN_Ok
                if ($BTN.IsEnabled) {
                    $BTN.RaiseEvent(
                        [System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)
                    )
                }
            }
        }
        $Ctx.Elements.TBX_UserName.Add_IsVisibleChanged{
            param($sender, $e)
            if ($e.NewValue -eq $true) {
                $sender.Focus()
                $sender.CaretIndex = $sender.Text.Length
            }
        }
        $Ctx.Elements.TBX_UserName.Add_TextChanged{
            param($sender, $e)
            $sender.DataContext.Sync.SessionParams.UsernameCurrentText = $sender.Text
        }
        $Ctx.Elements.PBX_Password.Add_PreviewKeyDown{
            if ($_.Key -eq "Enter"){
                $BTN = $_.Source.DataContext.Elements.BTN_Ok
                if ($BTN.IsEnabled) {
                    $BTN.RaiseEvent(
                        [System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)
                    )
                }
            }
        }
        $Ctx.Elements.PBX_Password.Add_PasswordChanged{ 
            $_.Source.Tag = $_.Source.SecurePassword.Length
        }
    }
    Update = {
        param($Ctx)
        $Ctx.Elements.TBK_UserName.Text = $Ctx.Params.UsernameLabel
        $Ctx.Elements.TBX_UserName.Text = $Ctx.Params.UsernameCurrentText
        $Ctx.Elements.TBX_UserName.Tag  = $Ctx.Params.UsernamePlaceholder
        $Ctx.Elements.TBK_Password.Text = $Ctx.Params.PasswordLabel
        $Ctx.Elements.PBX_Password.Tooltip = $Ctx.Params.PasswordPlaceholder
        $Ctx.Elements.BTN_Ok.Content = $Ctx.Params.OkText
        $Ctx.Elements.BTN_Cancel.Content = $Ctx.Params.CancelText
        $Ctx.Elements.BTN_Cancel.IsEnabled = -not $Ctx.Params.NoCancel
    }
}