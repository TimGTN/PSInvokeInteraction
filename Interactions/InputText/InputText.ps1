@{
    Name = "InputText"
    Description = "Simple text input dialog with customization options."
    Parameters  = @{
        Placeholder = @{ Type=[string]; Default="..."
                         HelpText="Temporary hint text displayed inside the empty field." }
        CurrentText = @{ Type=[string]
                         HelpText="Current value of the input field." }
        OkText      = @{ Type=[string]; Default="Ok"
                         HelpText="Label for the confirmation button." }
        CancelText  = @{ Type=[string]; Default="Cancel"
                         HelpText="Label for the cancellation button." }
    }
    Xaml = @"
    <StackPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
        <TextBox x:Name="TBX_Input" Margin="0,0,0,8" Tag="..." />
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="BTN_Cancel" Style="{DynamicResource ST_BTN_Secondary}" Content="Cancel" />
            <Button x:Name="BTN_Ok" Margin="8,0,0,0" DockPanel.Dock="Right" Content="Ok">
                <Button.Style>
                    <Style TargetType="Button" BasedOn="{StaticResource ST_BTN_Primary}">
                        <Style.Triggers>
                            <DataTrigger Binding="{Binding ElementName=TBX_Input,Path=Text.Length}" Value="0">
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
            $Ctx.Sync.PendingOutput = $Ctx.Elements.TBX_Input.Text
        }
        $Ctx.Elements.BTN_Cancel.Add_Click{
            $Ctx = $_.Source.DataContext
            $Ctx.Sync.PendingOutput = $null
        }
        $Ctx.Elements.TBX_Input.Add_PreviewKeyDown{
            if ($_.Key -eq "Enter"){
                $BTN = $_.Source.DataContext.Elements.BTN_Ok
                if ($BTN.IsEnabled) {
                    $BTN.RaiseEvent(
                        [System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)
                    )
                }
            }
        }
        $Ctx.Elements.TBX_Input.Add_IsVisibleChanged{
            param($sender, $e)
            if ($e.NewValue -eq $true) {
                $sender.Focus()
                $sender.CaretIndex = $sender.Text.Length
            }
        }
        $Ctx.Elements.TBX_Input.Add_TextChanged{
            param($sender, $e)
            $sender.DataContext.Sync.SessionParams.CurrentText = $sender.Text
        }
    }
    Update = {
        param($Ctx)
        $Ctx.Elements.TBX_Input.Tag = $Ctx.Params.Placeholder
        $Ctx.Elements.TBX_Input.Text = $Ctx.Params.CurrentText
        $Ctx.Elements.BTN_Ok.Content = $Ctx.Params.OkText
        $Ctx.Elements.BTN_Cancel.Content = $Ctx.Params.CancelText
        $Ctx.Elements.BTN_Cancel.IsEnabled = -not $Ctx.Params.NoCancel
    }
}