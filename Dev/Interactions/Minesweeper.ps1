# DEV
@{
    Name = "InputText"
    Description = "Simply minesweeper"
    Parameters  = @{
        GridSize   = @{ Type=[int]; Default="15"; ValidateRange=(5,30); InitOnly=$True }
        Difficulty = @{ Type=[int]; Default="Easy"; ValidateSet=("Easy","Medium","Hard"); InitOnly=$True }
    }
    Xaml = #INTERACTION_VISUAL
    '' # AUTOMATICALLY INJECTED BY DEV FUNCTION or BUILD
#INTERACTION_VISUAL
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
    }
}