@{
    Name = "MessageBox"
    Description = "Configurable message box with custom buttons and status icon."
    Parameters  = @{
        Message     = @{ Type=[string]; Default=$null
                         HelpText="Text content displayed inside the message box." }
        MessageIcon = @{ Type=[string]; Default="Information"
                         HelpText=@'
                            Sets the status icon. Valid values: 'Inherit' (same as window), 
                            a preset name ('Default','Warning','Information','Help','Error','Success'), 
                            a custom WPF brush (like -IconBrush), or $null to collapse the icon." 
'@ }
        Buttons     = @{ Type=[string[]]; Default="Ok","Cancel"
                         HelpText="Custom buttons generated right-to-left. First one gets primary styling." }
    }
    Xaml = @"
        <DockPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
            <!--Button panel-->
            <ListBox x:Name="LBX_Buttons" BorderThickness="0" SelectionMode="Single" ItemsSource="{Binding}" DockPanel.Dock="Bottom" ScrollViewer.HorizontalScrollBarVisibility="Disabled" FontSize="{DynamicResource FontSize}" BorderBrush="{DynamicResource BorderBrush.S.Default}">
                <ListBox.ItemsPanel>
                    <ItemsPanelTemplate>
                        <WrapPanel FlowDirection="RightToLeft" />
                    </ItemsPanelTemplate>
                </ListBox.ItemsPanel>
                <ListBox.ItemContainerStyle>
                    <Style TargetType="ListBoxItem">
                        <Setter Property="Template">
                            <Setter.Value>
                                <ControlTemplate TargetType="ListBoxItem">
                                    <Button Name="PART_Btn" Content="{Binding Content}" Style="{DynamicResource ST_BTN_Secondary}" Margin="0,0,8,0" />
                                    <ControlTemplate.Triggers>
                                        <DataTrigger Binding="{Binding Tag}" Value="True">
                                            <Setter TargetName="PART_Btn" Property="Style" Value="{DynamicResource ST_BTN_Primary}" />
                                        </DataTrigger>
                                    </ControlTemplate.Triggers>
                                </ControlTemplate>
                            </Setter.Value>
                        </Setter>
                    </Style>
                </ListBox.ItemContainerStyle>
            </ListBox>
            <!--Message-->
            <Grid Margin="0,0,0,8">
                <DockPanel>
                    <Canvas Name="CVS_Icon" Style="{DynamicResource ST_Icon}" Margin="0,0,12,0" Width="32" Height="32" DockPanel.Dock="Left" />
                    <TextBlock Name="TBK_Message" TextWrapping="Wrap" TextAlignment="Left" VerticalAlignment="Center" HorizontalAlignment="Center" Text="Message" FontSize="13" />
                </DockPanel>
            </Grid>
        </DockPanel>
"@
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