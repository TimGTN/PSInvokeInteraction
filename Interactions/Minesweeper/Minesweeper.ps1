@{
    Name = "MineSweeper"
    Description = "A Minesweeper game built as a proof-of-concept for 'Invoke-Interaction'. Fair warning: not guessing-free :)."
    Parameters  = @{
        GridSize   = @{ Type=[int]; Default=10; ValidateRange=(10,30); InitOnly=$True
                        HelpText="Number of rows and columns (square grid). Range: 10–30." }
        Difficulty = @{ Type=[string]; Default="Easy"; ValidateSet=("Easy","Medium","Hard"); InitOnly=$True
                        HelpText="Mine density - Easy: 12%, Medium: 16%, Hard: 20%." }
    }
    Xaml = @"
        <Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
            <Grid.Resources>
                <SolidColorBrush x:Key="Field.Background" Color="#FFECECEC" />
                <Color x:Key="Color.Field.BorderBrush.Light">#F6F6F6</Color>
                <Color x:Key="Color.Field.BorderBrush.Dark">#E1E1E1</Color>
                <SolidColorBrush x:Key="Field.BorderBrush.Dark" Color="{StaticResource Color.Field.BorderBrush.Dark}" />
                <SolidColorBrush x:Key="Field.Background.Used" Color="#FCFCFC" />
                <Style x:Key="ST_Field" TargetType="ContentControl">
                    <Setter Property="Background" Value="{StaticResource Field.Background}" />
                    <Setter Property="BorderThickness" Value="5" />
                    <Setter Property="Focusable" Value="False" />
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="ContentControl">
                                <Border x:Name="PART_Border" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4" Background="{TemplateBinding Background}" SnapsToDevicePixels="true">
                                    <Border.BorderBrush>
                                        <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                                            <GradientStop Color="{StaticResource Color.Field.BorderBrush.Light}" Offset="0" />
                                            <GradientStop Color="{StaticResource Color.Field.BorderBrush.Light}" Offset="0.5" />
                                            <GradientStop Color="{StaticResource Color.Field.BorderBrush.Dark}" Offset="0.5" />
                                            <GradientStop Color="{StaticResource Color.Field.BorderBrush.Dark}" Offset="1" />
                                        </LinearGradientBrush>
                                    </Border.BorderBrush>
                                    <Grid>
                                        <TextBlock x:Name="PART_Type" Height="22" Text="{Binding Type}" FontSize="16" FontWeight="Bold" Opacity="0" TextAlignment="Center" />
                                        <TextBlock x:Name="PART_Flag" Height="18" Text="🚩" Foreground="Red" Opacity="0" TextAlignment="Center" />
                                    </Grid>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <!--Type content-->
                                    <DataTrigger Binding="{Binding Type}" Value="Bomb">
                                        <Setter TargetName="PART_Type" Property="Text" Value="💣" />
                                        <Setter Property="Foreground" Value="Black" />
                                    </DataTrigger>
                                    <DataTrigger Binding="{Binding Type}" Value="0">
                                        <Setter TargetName="PART_Type" Property="Text" Value="{x:Null}" />
                                    </DataTrigger>
                                    <DataTrigger Binding="{Binding Type}" Value="1">
                                        <Setter Property="Foreground" Value="#66ccff" />
                                    </DataTrigger>
                                    <DataTrigger Binding="{Binding Type}" Value="2">
                                        <Setter Property="Foreground" Value="#a0e65c" />
                                    </DataTrigger>
                                    <DataTrigger Binding="{Binding Type}" Value="3">
                                        <Setter Property="Foreground" Value="#ff5555" />
                                    </DataTrigger>
                                    <DataTrigger Binding="{Binding Type}" Value="4">
                                        <Setter Property="Foreground" Value="#b380ff" />
                                    </DataTrigger>
                                    <DataTrigger Binding="{Binding Type}" Value="5">
                                        <Setter Property="Foreground" Value="#d35f5f" />
                                    </DataTrigger>
                                    <DataTrigger Binding="{Binding Type}" Value="6">
                                        <Setter Property="Foreground" Value="#87decd" />
                                    </DataTrigger>
                                    <DataTrigger Binding="{Binding Type}" Value="7">
                                        <Setter Property="Foreground" Value="#ffbe40" />
                                    </DataTrigger>
                                    <DataTrigger Binding="{Binding Type}" Value="8">
                                        <Setter Property="Foreground" Value="#ac9393" />
                                    </DataTrigger>
                                    <!--Hover when not flagged-->
                                    <MultiDataTrigger>
                                        <MultiDataTrigger.Conditions>
                                            <Condition Binding="{Binding RelativeSource={RelativeSource Self}, Path=IsMouseOver}" Value="True" />
                                            <Condition Binding="{Binding Flagged}" Value="False" />
                                        </MultiDataTrigger.Conditions>
                                        <Setter Property="Cursor" Value="Hand" />
                                    </MultiDataTrigger>
                                    <!--Uncover Field-->
                                    <DataTrigger Binding="{Binding Used}" Value="True">
                                        <Setter TargetName="PART_Type" Property="Opacity" Value="1" />
                                        <Setter Property="BorderThickness" Value="1" />
                                        <Setter Property="Background" Value="{StaticResource Field.Background.Used}" />
                                        <Setter TargetName="PART_Border" Property="BorderBrush" Value="{StaticResource Field.BorderBrush.Dark}" />
                                    </DataTrigger>
                                    <!--Show flag-->
                                    <DataTrigger Binding="{Binding Flagged}" Value="True">
                                        <Setter TargetName="PART_Flag" Property="Opacity" Value="1" />
                                    </DataTrigger>
                                    <!--ENDGAME-->
                                    <!--LOSE : Blank or Number field was flagged-->
                                    <MultiDataTrigger>
                                        <MultiDataTrigger.Conditions>
                                            <Condition Binding="{Binding Used}" Value="False" />
                                            <Condition Binding="{Binding RelativeSource={RelativeSource Mode=FindAncestor, AncestorType=ItemsControl}, Path=IsHitTestVisible}" Value="False" />
                                            <Condition Binding="{Binding Flagged}" Value="True" />
                                            <Condition Binding="{Binding Type.Length}" Value="1" />
                                        </MultiDataTrigger.Conditions>
                                        <Setter Property="BorderThickness" Value="1" />
                                        <Setter Property="Background" Value="{StaticResource Field.Background.Used}" />
                                        <Setter TargetName="PART_Border" Property="BorderBrush" Value="{StaticResource Field.BorderBrush.Dark}" />
                                        <Setter TargetName="PART_Flag" Property="Text" Value="╳" />
                                        <Setter TargetName="PART_Flag" Property="FontSize" Value="18" />
                                        <Setter TargetName="PART_Flag" Property="Background" Value="#55ECECEC" />
                                        <Setter TargetName="PART_Flag" Property="Height" Value="35" />
                                        <Setter TargetName="PART_Type" Property="Opacity" Value="1" />
                                        <Setter TargetName="PART_Type" Property="Text" Value="💣" />
                                        <Setter Property="Foreground" Value="Black" />
                                    </MultiDataTrigger>
                                    <!--LOSE : Bomb was hit-->
                                    <MultiDataTrigger>
                                        <MultiDataTrigger.Conditions>
                                            <Condition Binding="{Binding Used}" Value="True" />
                                            <Condition Binding="{Binding Flagged}" Value="False" />
                                            <Condition Binding="{Binding Type}" Value="Bomb" />
                                        </MultiDataTrigger.Conditions>
                                        <Setter TargetName="PART_Border" Property="Background" Value="#ff7f7f" />
                                        <Setter TargetName="PART_Type" Property="Opacity" Value="1" />
                                    </MultiDataTrigger>
                                    <!--LOSE : Bomb was not flagged-->
                                    <MultiDataTrigger>
                                        <MultiDataTrigger.Conditions>
                                            <Condition Binding="{Binding Used}" Value="False" />
                                            <Condition Binding="{Binding RelativeSource={RelativeSource Mode=FindAncestor, AncestorType=ItemsControl}, Path=IsHitTestVisible}" Value="False" />
                                            <Condition Binding="{Binding Flagged}" Value="False" />
                                            <Condition Binding="{Binding Type}" Value="Bomb" />
                                        </MultiDataTrigger.Conditions>
                                        <Setter Property="BorderThickness" Value="1" />
                                        <Setter Property="Background" Value="{StaticResource Field.Background.Used}" />
                                        <Setter TargetName="PART_Border" Property="BorderBrush" Value="{StaticResource Field.BorderBrush.Dark}" />
                                        <Setter TargetName="PART_Type" Property="Opacity" Value="1" />
                                    </MultiDataTrigger>
                                    <!--WIN : Bomb was flagged-->
                                    <MultiDataTrigger>
                                        <MultiDataTrigger.Conditions>
                                            <Condition Binding="{Binding Used}" Value="False" />
                                            <Condition Binding="{Binding RelativeSource={RelativeSource Mode=FindAncestor, AncestorType=ItemsControl}, Path=IsHitTestVisible}" Value="True" />
                                            <Condition Binding="{Binding RelativeSource={RelativeSource Mode=FindAncestor, AncestorType=ItemsControl}, Path=IsEnabled}" Value="False" />
                                            <Condition Binding="{Binding Flagged}" Value="True" />
                                            <Condition Binding="{Binding Type}" Value="Bomb" />
                                        </MultiDataTrigger.Conditions>
                                        <Setter TargetName="PART_Flag" Property="Foreground" Value="#49d049" />
                                    </MultiDataTrigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                </Style>
                <CollectionViewSource x:Name="CVS_Fields" x:Key="CVS_Fields" />
                <Style x:Key="ST_Counter" TargetType="ContentControl">
                    <Setter Property="Background" Value="{DynamicResource Field.Background}" />
                    <Setter Property="BorderBrush" Value="{DynamicResource BorderBrush.S.Default}" />
                    <Setter Property="Foreground" Value="{DynamicResource Foreground.Default}" />
                    <Setter Property="FontSize" Value="28" />
                    <Setter Property="FontFamily" Value="Consolas" />
                    <Setter Property="BorderThickness" Value="1" />
                    <Setter Property="Padding" Value="2,0" />
                    <Setter Property="Template">
                        <Setter.Value>
                            <ControlTemplate TargetType="ContentControl">
                                <Border BorderThickness="{TemplateBinding BorderThickness}" BorderBrush="{TemplateBinding BorderBrush}" Padding="{TemplateBinding Padding}" CornerRadius="{DynamicResource CornerRadius}" Background="{TemplateBinding Background}" SnapsToDevicePixels="true">
                                    <TextBlock Text="{TemplateBinding Content}" />
                                </Border>
                            </ControlTemplate>
                        </Setter.Value>
                    </Setter>
                </Style>
            </Grid.Resources>
            <DockPanel>
                <UniformGrid Columns="3" DockPanel.Dock="Top" Margin="0,0,0,8" Height="35">
                    <ContentControl x:Name="CTC_Remaining" Style="{StaticResource ST_Counter}" HorizontalAlignment="Left" Content="000" />
                    <Button x:Name="BTN_Reload" DockPanel.Dock="Top">
                        <Grid>
                            <Ellipse Width="26" Height="26" Fill="Yellow" />
                            <TextBlock FontSize="25" TextAlignment="Center" VerticalAlignment="Center" Height="36.5" Foreground="black">
                                <TextBlock.Style>
                                    <Style TargetType="TextBlock">
                                        <Setter Property="Text" Value="🙂" />
                                        <Style.Triggers>
                                            <DataTrigger Binding="{Binding ElementName=ITC_Board, Path=IsHitTestVisible}" Value="False">
                                                <Setter Property="Text" Value="😵" />
                                            </DataTrigger>
                                            <DataTrigger Binding="{Binding ElementName=ITC_Board, Path=IsEnabled}" Value="False">
                                                <Setter Property="Text" Value="😎" />
                                            </DataTrigger>
                                            <DataTrigger Binding="{Binding ElementName=BTN_Reload, Path=IsPressed}" Value="True">
                                                <Setter Property="Text" Value="😖" />
                                            </DataTrigger>
                                        </Style.Triggers>
                                    </Style>
                                </TextBlock.Style>
                            </TextBlock>
                        </Grid>
                    </Button>
                    <ContentControl x:Name="CTC_Timer" Style="{StaticResource ST_Counter}" HorizontalAlignment="Right" Content="000" />
                </UniformGrid>
                <ItemsControl x:Name="ITC_Board" DataContext="{StaticResource CVS_Fields}" ItemsSource="{Binding IsAsync=True}">
                    <ItemsControl.ItemsPanel>
                        <ItemsPanelTemplate>
                            <UniformGrid Columns="{Binding RelativeSource={RelativeSource Mode=FindAncestor, AncestorType=ItemsControl}, Path=Tag.X}" Rows="{Binding RelativeSource={RelativeSource Mode=FindAncestor, AncestorType=ItemsControl}, Path=Tag.Y}" />
                        </ItemsPanelTemplate>
                    </ItemsControl.ItemsPanel>
                    <ItemsControl.ItemTemplate>
                        <DataTemplate>
                            <ContentControl Style="{StaticResource ST_Field}" Width="30" Height="30" />
                        </DataTemplate>
                    </ItemsControl.ItemTemplate>
                </ItemsControl>
            </DockPanel>
        </Grid>
"@
    Init = {
        param($Ctx)

        # Compile custom observable object
        if (-not ([System.Management.Automation.PSTypeName]'MineSweeperField').Type) {
            $Class = @"
                using System.ComponentModel;
                using System.Collections.Generic;
                using System.Runtime.CompilerServices;

                public class MineSweeperField : INotifyPropertyChanged
                {
                    public event PropertyChangedEventHandler PropertyChanged;

                    private void SetProperty<T>(ref T field, T value, [CallerMemberName] string name = "")
                    {
                        if (field == null && value == null) return;
                        if (field != null && field.Equals(value)) return;
                        field = value;
                        if (PropertyChanged != null)
                            PropertyChanged(this, new PropertyChangedEventArgs(name));
                    }
                    public int   Index     { get; set; }
                    public int[] Neighbors { get; set; }

                    private string _Type = "0";
                    public string Type
                    {
                        get { return _Type; }
                        set { SetProperty(ref _Type, value); }
                    }

                    private bool _Used;
                    public bool Used
                    {
                        get { return _Used; }
                        set { SetProperty(ref _Used, value); }
                    }

                    private bool _Flagged;
                    public bool Flagged
                    {
                        get { return _Flagged; }
                        set { SetProperty(ref _Flagged, value); }
                    }
                }
"@
            $Assemblies = 'PresentationCore', 'WindowsBase', 'System.Xaml','System.ObjectModel' | ForEach-Object {
                [System.Reflection.Assembly]::LoadWithPartialName($_)
            } | Select-Object -ExpandProperty Location
            Add-Type -TypeDefinition $Class -Language 'CSharp' -ReferencedAssemblies $Assemblies
        }

        # Reload the board
        $Ctx.Elements.BTN_Reload.Add_Click{
            param($sender, $e) 
            if (-not $Ctx) { $Ctx = $sender.DataContext }

            # Reset game state
            $Ctx.Interaction._Started = $False
            $Ctx.Elements.ITC_Board.ToolTip = $null
            $Ctx.Elements.ITC_Board.IsHitTestVisible = $True
            $Ctx.Elements.ITC_Board.IsEnabled = $True
            if ($Ctx.Interaction._Timer) {
                $Ctx.Interaction._Timer.Stop()
                $Ctx.Interaction._Timer.Tag = 0
            }
            $Ctx.Elements.CTC_Timer.Content = '000'

            # Define board size
            $Columns = $Ctx.Params.GridSize
            $Rows    = $Ctx.Params.GridSize
            $Ctx.Elements.ITC_Board.Tag = [System.Windows.Point]::new($Columns, $Rows)

            # Adjacent fields map
            $FieldOffsets = @(
                (-1,-1), (0,-1), (1,-1)
                (-1, 0),         (1, 0)
                (-1, 1), (0, 1), (1, 1)
            )
            # Generate empty fields
            $FieldsCollection = [System.Collections.Generic.List[MineSweeperField]]::new($Columns * $Rows)
            for ($y = 0; $y -lt $Rows; $y++) {
                for ($x = 0; $x -lt $Columns; $x++) {
                    $Field = [MineSweeperField]::new()
                    $Field.Index = $y * $Columns + $x

                    # Get adjacent indexes
                    $Field.Neighbors = foreach ($Offset in $FieldOffsets) {
                        $xOffset = $x + $Offset[0]
                        $yOffset = $y + $Offset[1]
                        if ($xOffset -ge 0 -and $xOffset -lt $Columns -and $yOffset -ge 0 -and $yOffset -lt $Rows) {
                            $yOffset * $Columns + $xOffset
                        }
                    }
                    $FieldsCollection.Add($Field)
                }
            }
            # Display empty fields
            $FieldsObvCollection = [System.Collections.ObjectModel.ObservableCollection[MineSweeperField]]::new($FieldsCollection)
            $Ctx.Elements.CVS_Fields.Source = $FieldsObvCollection

            # Define bomb quantity
            $BombPourcent = @{ Easy = 0.12 ; Medium = 0.16 ; Hard = 0.2 }
            $BombCount    = [math]::Round($FieldsCollection.Count * $BombPourcent[$Ctx.Params.Difficulty])
            $Ctx.Elements.CTC_Remaining.Content = '{0:D3}' -f [int]$BombCount
            $Ctx.Interaction._BombCount = $BombCount  
        }

        # Manage the clicked field
        $Ctx.Elements.ITC_Board.Add_PreviewMouseDown{
            param($sender, $e)
            $Ctx    = $Sender.Parent.DataContext
            $Button = $e.OriginalSource.TemplatedParent
            $Field  = $Button.DataContext
            $FieldsCollection = $Ctx.Elements.CVS_Fields.Source

            # Left click, reveal
            if ($_.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) {
                if (-not $Field.Flagged) {
                    $Field.Used = $True

                    # First click, ensure safe start and place bombs
                    if (-not $Ctx.Interaction._Started) {
                        
                        # Exclude first field and adjacent from bomb picking (ensure blank)
                        $SafeIndexes = [System.Collections.Generic.HashSet[int]]::new()
                        $null = $SafeIndexes.UnionWith([int[]]($Field.Neighbors + $Field.Index))

                        # Build available indexes excluding safe zone
                        [object[]]$AvailableIndexes = [System.Linq.Enumerable]::Except(
                            [System.Linq.Enumerable]::Range(0, $FieldsCollection.Count),
                            $SafeIndexes
                        )
                        
                        # Pick bombs from available indexes
                        $BombCount   = $Ctx.Interaction._BombCount
                        $BombIndexes = [System.Collections.Generic.HashSet[int]]::new(
                            [int[]](Get-Random $AvailableIndexes -Count $BombCount)
                        )
                        foreach ($bIndex in $BombIndexes) {
                            $FieldsCollection[$bIndex].Type = 'Bomb'
                            # Increment neighbor fields
                            foreach ($nIndex in $FieldsCollection[$bIndex].Neighbors) {
                                if ($BombIndexes.Contains($nIndex)) { continue }
                                $FieldsCollection[$nIndex].Type = [string]([int]$FieldsCollection[$nIndex].Type + 1)
                            }
                        }
                        $Ctx.Interaction._Started = $True

                        # Start or restart timer on first click
                        if ($Ctx.Interaction._Timer) {
                            $Ctx.Interaction._Timer.Stop()
                            $Ctx.Interaction._Timer.Tag = 0
                            $Ctx.Interaction._Timer.Start()
                        } else {
                            $Timer = [System.Windows.Threading.DispatcherTimer]::new()
                            $Timer.Interval = [TimeSpan]::FromSeconds(1)
                            $Timer.Tag = 0
                            $Timer.Add_Tick{
                                $Ctx = $Sync.UI_Window.DataContext
                                $Ctx.Interaction._Timer.Tag++
                                $Elapsed = $Ctx.Interaction._Timer.Tag
                                $Ctx.Elements.CTC_Timer.Content = '{0:D3}' -f [math]::Min($Elapsed, 999)
                                if ($Elapsed -ge 999) { $Ctx.Interaction._Timer.Stop() }
                            }
                            $Ctx.Interaction._Timer = $Timer
                            $Timer.Start()
                        }
                    }

                    # Clicked field is blank -> expand
                    if ($Field.Type -eq 0) {

                        $DiscoverQueue = [System.Collections.Generic.Queue[int]]::new()
                        $DiscoverQueue.Enqueue($Field.Index)
                        $Visited = [System.Collections.Generic.HashSet[int]]::new()

                        while ($DiscoverQueue.Count -gt 0) {
                            $CurrentIndex = $DiscoverQueue.Dequeue()
                            $CurrentField = $FieldsCollection[$CurrentIndex]
                            # Enqueue adjacent fields (number or blank)
                            if ($CurrentField.Type -eq 0) {
                                foreach ($nIndex in $CurrentField.Neighbors) {
                                    if (-not $Visited.Contains($nIndex)) {
                                        $Visited.Add($nIndex)
                                        $DiscoverQueue.Enqueue($nIndex)
                                    }
                                }
                            }
                        }
                        foreach ($vIndex in $Visited) {
                            $vField = $FieldsCollection[$vIndex]
                            if (-not $vField.Used -and -not $vField.Flagged) {
                                $vField.Used = $True
                            }
                        }          
                    }

                    # ENDGAME
                    if ($Field.Type -eq "Bomb") {
                        $sender.IsHitTestVisible = $False
                        $Ctx.Interaction._Timer.Stop()
                    } else {
                        $UsedCount = [System.Linq.Enumerable]::Count(
                            $FieldsCollection,
                            [System.Func[MineSweeperField, bool]]{ $args[0].Used }
                        )
                        if ($Ctx.Interaction._BombCount -eq $FieldsCollection.Count - $UsedCount) {
                            $sender.IsEnabled = $False
                            $Ctx.Interaction._Timer.Stop()
                        }
                    }


                }
            }
            # Right click, set / unset flag
            if ($_.ChangedButton -eq [System.Windows.Input.MouseButton]::Right) {
                if (-not $Field.Used) { 
                    $Field.Flagged = -not $Field.Flagged 
                             
                    # Update counter
                    $FlagCount = [System.Linq.Enumerable]::Count(
                        $FieldsCollection,
                        [System.Func[MineSweeperField, bool]]{ $args[0].Flagged }
                    )
                    $Ctx.Elements.CTC_Remaining.Content = '{0:D3}' -f [int]($Ctx.Interaction._BombCount - $FlagCount)
                }
            }
        }

        # Quick uncover neighbors when double clicked and adjacent flag count matches field number
        $Ctx.Elements.ITC_Board.Add_PreviewMouseDoubleClick{
            param($sender, $e)
            $Ctx    = $Sender.Parent.DataContext
            $Button = $e.OriginalSource.TemplatedParent
            $Field  = $Button.DataContext
            $FieldsCollection = $Ctx.Elements.CVS_Fields.Source

            # Fix to PreviewMouseDoubleClick triggering with another interaction type
            if ($Sync.CurrentType -ne 'MineSweeper') { $e.Handled = $True ; return } 

            # Only handle used number fields
            $Type = $Field.Type
            if (-not $Field.Used -or $Type -eq "0" -or $Type -eq "Bomb") { return }

            # Count adjacent flags, then quick uncover
            $FlagCount = 0
            foreach ($nIndex in $Field.Neighbors) {
                if ($FieldsCollection[$nIndex].Flagged) { $FlagCount++ }
            }
            if ($FlagCount -eq [int]$Type) {
                foreach ($nIndex in $Field.Neighbors) {
                    $nField = $FieldsCollection[$nIndex]
                    if (-not $nField.Used -and -not $nField.Flagged) {
                        # Raise PreviewMouseDown on the neighbor's visual
                        $nContainer = $Ctx.Elements.ITC_Board.ItemContainerGenerator.ContainerFromItem($nField)
                        $nButton = [System.Windows.Media.VisualTreeHelper]::GetChild($nContainer, 0)
                        $args = [System.Windows.Input.MouseButtonEventArgs]::new(
                            $e.MouseDevice,
                            $e.Timestamp,
                            [System.Windows.Input.MouseButton]::Left
                        )
                        $args.RoutedEvent = [System.Windows.UIElement]::PreviewMouseDownEvent
                        $nButton.RaiseEvent($args)
                    }
                }
            }
        }

        # Trigger first load
        $Ctx.Elements.BTN_Reload.RaiseEvent(
            [System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)
        )
    }
    Dispose = {
        param($Ctx)
        # Stop and release the DispatcherTimer to prevent it from running
        # after the interaction has been replaced or the window closed
        if ($null -ne $Ctx.Interaction._Timer) {
            $Ctx.Interaction._Timer.Stop()
            $Ctx.Interaction._Timer = $null
        }
    }
}