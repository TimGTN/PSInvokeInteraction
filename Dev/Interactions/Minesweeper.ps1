@{
    Name = "Minesweeper"
    Description = "A Minesweeper game built as a proof-of-concept for 'Invoke-Interaction'. Fair warning: not guessing-free :)."
    Parameters  = @{
        GridSize   = @{ Type=[int]; Default=10; ValidateRange=(10,30); InitOnly=$True
                        HelpText="Number of rows and columns (square grid). Range: 10–30." }
        Difficulty = @{ Type=[string]; Default="Easy"; ValidateSet=("Easy","Medium","Hard"); InitOnly=$True
                        HelpText="Mine density - Easy: 12%, Medium: 16%, Hard: 20%." }
    }
    Xaml = #INTERACTION_VISUAL
    '' # AUTOMATICALLY INJECTED BY DEV FUNCTION or BUILD
#INTERACTION_VISUAL
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
                    $Field.Type = "0" # Fix to ISE

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
                    if ($Field.Type -eq "0") {

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