@{
    Name = "ItemSelect"
    Description = "Item selection list supporting both single and multiple selection modes."
    Parameters  = @{
        Multiple   = @{ Type=[switch]
                        HelpText="Enables multi-selection mode." }
        Items      = @{ Type=[string[]]; Default="Exemple1","Exemple2"
                        HelpText="Array of strings to display in the list." }
        OkText     = @{ Type=[string]; Default="Ok"
                        HelpText="Label for the confirmation button." }
        CancelText = @{ Type=[string]; Default="Cancel"
                        HelpText="Label for the cancellation button." }
    }
    Xaml = @"
    <DockPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
        <DockPanel.Resources>
            <CollectionViewSource x:Name="CVS_Items" x:Key="CVS_Items" Source="{DynamicResource DummyItems}" />
        </DockPanel.Resources>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" DockPanel.Dock="Bottom">
            <Button x:Name="BTN_Cancel" Style="{DynamicResource ST_BTN_Secondary}" Content="Cancel" />
            <Button x:Name="BTN_Ok" Margin="8,0,0,0" DockPanel.Dock="Right" Content="Ok">
                <Button.Style>
                    <Style TargetType="Button" BasedOn="{StaticResource ST_BTN_Primary}">
                        <Style.Triggers>
                            <DataTrigger Binding="{Binding ElementName=LBX_Select,Path=SelectedItems.Count}" Value="0">
                                <Setter Property="IsEnabled" Value="False" />
                            </DataTrigger>
                        </Style.Triggers>
                    </Style>
                </Button.Style>
            </Button>
        </StackPanel>
        <ListBox x:Name="LBX_Select" Margin="0,0,0,8" BorderThickness="{DynamicResource BorderThickness}" SelectionMode="Single" DataContext="{StaticResource CVS_Items}" ItemsSource="{Binding IsAsync=True}" ScrollViewer.HorizontalScrollBarVisibility="Disabled" FontSize="{DynamicResource FontSize}" BorderBrush="{DynamicResource BorderBrush.S.Default}" Padding="2">
            <ListBox.Template>
                <ControlTemplate TargetType="ListBox">
                    <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="{DynamicResource CornerRadius}">
                        <ScrollViewer Padding="{TemplateBinding Padding}" Focusable="False">
                            <ItemsPresenter SnapsToDevicePixels="{TemplateBinding SnapsToDevicePixels}" />
                        </ScrollViewer>
                    </Border>
                </ControlTemplate>
            </ListBox.Template>
            <ListBox.ItemsPanel>
                <ItemsPanelTemplate>
                    <VirtualizingStackPanel />
                </ItemsPanelTemplate>
            </ListBox.ItemsPanel>
            <ListBox.ItemContainerStyle>
                <Style TargetType="ListBoxItem">
                    <Setter Property="Margin" Value="3,2,2,2" />
                    <!--RadioButton (SelectionMode = Single)-->
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="ListBoxItem">
                                <RadioButton Content="{TemplateBinding Content}" IsChecked="{Binding IsSelected, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}" Padding="4,2" FontSize="{TemplateBinding FontSize}" />
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                    <Style.Triggers>
                        <!--Switch to CheckBox (SelectionMode = Multiple)-->
                        <DataTrigger Binding="{Binding SelectionMode, RelativeSource={RelativeSource AncestorType=ListBox}}" Value="Multiple">
                            <Setter Property="Template">
                                <Setter.Value>
                                    <ControlTemplate TargetType="ListBoxItem">
                                        <CheckBox Content="{TemplateBinding Content}" IsChecked="{Binding IsSelected, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}" Padding="4,2" FontSize="{TemplateBinding FontSize}" />
                                    </ControlTemplate>
                                </Setter.Value>
                            </Setter>
                        </DataTrigger>
                    </Style.Triggers>
                </Style>
            </ListBox.ItemContainerStyle>
        </ListBox>
    </DockPanel>
"@
    Init = {
        param($Ctx)
        $Ctx.Elements.OBV_Coll = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
        $Ctx.Elements.CVS_Items.Source = $Ctx.Elements.OBV_Coll
        $Ctx.Elements.BTN_Ok.Add_Click{
            $Ctx = $_.Source.DataContext
            $Ctx.Sync.PendingOutput = $Ctx.Elements.LBX_Select.SelectedItems
        }
        $Ctx.Elements.BTN_Cancel.Add_Click{
            $Ctx = $_.Source.DataContext
            $Ctx.Sync.PendingOutput = $null
        }
        $Ctx.Elements.LBX_Select.Add_PreviewKeyDown{
            param($sender, $e)
            $Ctx = $sender.Parent.DataContext
            if ($e.Key -eq "Enter"){
                $BTN = $Ctx.Elements.BTN_Ok
                if ($BTN.IsEnabled) {
                    $BTN.RaiseEvent(
                        [System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)
                    )
                }
            }
        }
    }
    Update = {
        param($Ctx)
        $Ctx.Elements.OBV_Coll.Clear()
        $Ctx.Params.Items | ForEach-Object { $Ctx.Elements.OBV_Coll.Add($_) }
        $Ctx.Elements.LBX_Select.SelectionMode = if ($Ctx.Params.Multiple) { "Multiple" } else { "Single" }
        $Ctx.Elements.BTN_Ok.Content = $Ctx.Params.OkText
        $Ctx.Elements.BTN_Cancel.Content = $Ctx.Params.CancelText
        $Ctx.Elements.BTN_Cancel.IsEnabled = -not $Ctx.Params.NoCancel
    }
}