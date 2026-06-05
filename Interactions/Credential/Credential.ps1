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
    Xaml = @"
    <StackPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
        <StackPanel.Resources>
            <Style x:Key="ST_TBK" TargetType="TextBlock">
                <Setter Property="Foreground" Value="{DynamicResource Foreground.Default}" />
                <Setter Property="Margin" Value="0,0,0,4" />
                <Setter Property="FontSize" Value="13" />
                <Style.Triggers>
                    <DataTrigger Binding="{Binding RelativeSource={RelativeSource Mode=Self},Path=Text.Length}" Value="0">
                        <Setter Property="Visibility" Value="Collapsed" />
                    </DataTrigger>
                </Style.Triggers>
            </Style>
        </StackPanel.Resources>
        <TextBlock x:Name="TBK_UserName" Text="Login :" Style="{StaticResource ST_TBK}" />
        <TextBox x:Name="TBX_UserName" Margin="0,0,0,8" Tag="..." />
        <TextBlock x:Name="TBK_Password" Text="Password :" Style="{StaticResource ST_TBK}" />
        <PasswordBox x:Name="PBX_Password" Margin="0,0,0,8" ToolTip="..." Tag="0" />
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="BTN_Cancel" Style="{DynamicResource ST_BTN_Secondary}" Content="Cancel" />
            <Button x:Name="BTN_Ok" Margin="8,0,0,0" DockPanel.Dock="Right" Content="Ok">
                <Button.Style>
                    <Style TargetType="Button" BasedOn="{StaticResource ST_BTN_Primary}">
                        <Style.Triggers>
                            <DataTrigger Binding="{Binding ElementName=TBX_Username, Path=Text.Length}" Value="0">
                                <Setter Property="IsEnabled" Value="False" />
                            </DataTrigger>
                            <DataTrigger Binding="{Binding ElementName=PBX_Password, Path=Tag}" Value="0">
                                <Setter Property="IsEnabled" Value="False" />
                            </DataTrigger>
                        </Style.Triggers>
                    </Style>
                </Button.Style>
            </Button>
        </StackPanel>
    </StackPanel>
"@
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
            $Sync.SessionParams.UsernameCurrentText = $sender.Text
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