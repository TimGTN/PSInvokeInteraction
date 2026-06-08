@{
    Name = "ProgressBar"
    Description = "Configurable asynchronous progress bar."
    Parameters  = @{
        Message = @{ Type=[string]
                     HelpText="Status message above the bar." }
        Color   = @{ Type=[string] ; Default="#5ad45c"
                     HelpText="Progress fill color. Supports Hex codes or WPF literal names (e.g. Red, Green)." }
        Minimum = @{ Type=[double] ; Default=0
                     HelpText="Minimum progress value." }
        Maximum = @{ Type=[double] ; Default=100
                     HelpText="Maximum progress value." }
        Value   = @{ Type=[double]
                     HelpText="The current progress value." }
        Indeterminate = @{ Type=[switch]
                     HelpText="Enables continuous infinite animation." }
        # Implicit async (function-level parameter)
        Async = @{ Type=[switch] ; Default=$true; HelpText=$false }
    }
    Xaml = @"
        <DockPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
            <ProgressBar Name="PBG_Progress" DockPanel.Dock="Bottom" />
            <TextBlock Name="TBK_Message" TextWrapping="Wrap" TextAlignment="Left" VerticalAlignment="Center" HorizontalAlignment="Center" Text="Message" FontSize="13" Margin="0,0,0,4" />
        </DockPanel>
"@
    Init = {
        param($Ctx)
        $Ctx.Sync.SessionParams.Value = $Ctx.Elements.PBG_Progress.Value
        $Ctx.Elements.PBG_Progress.Add_ValueChanged{
            param($sender, $e)
            $Ctx = $sender.DataContext
            $Ctx.Sync.SessionParams.Value = $sender.Value
            if ($e.NewValue -ge $sender.Maximum){
                $Ctx.Sync.PendingOutput = $null
            }
        }
    }
    Update = {
        param($Ctx)
        $Ctx.Elements.TBK_Message.Text = $Ctx.Params.Message
        if ($Ctx.Params.ContainsKey('Color')) { 
            $Ctx.Elements.PBG_Progress.Foreground = $Ctx.Params.Color }
        $Ctx.Elements.PBG_Progress.Minimum = $Ctx.Params.Minimum
        $Ctx.Elements.PBG_Progress.Maximum = $Ctx.Params.Maximum
        $Ctx.Elements.PBG_Progress.Value = $Ctx.Params.Value
        $Ctx.Elements.PBG_Progress.IsIndeterminate = $Ctx.Params.Indeterminate
    }
}