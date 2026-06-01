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
    Xaml = #INTERACTION_VISUAL
    '' # AUTOMATICALLY INJECTED BY DEV FUNCTION or BUILD
#INTERACTION_VISUAL
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