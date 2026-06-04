@{
    Name        = "Countdown"
    Description = "Displays a countdown timer from a given TimeSpan, closing automatically on completion."
    Parameters  = @{
        Duration = @{ Type=[timespan]; Nullable=$false; InitOnly=$true
            HelpText="Total duration of the countdown. Required." }
        Message  = @{ Type=[string]; 
            HelpText="Status message displayed above the countdown." }
        Color    = @{ Type=[string]; Default="#49adf4"
            HelpText="Progress fill color. Supports Hex codes or WPF literal names." }
        # Implicit async (function-level parameter)
        Async    = @{ Type=[switch]; Default=$true; HelpText=$false }
    }
    Xaml = @"
    <DockPanel xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
        <ProgressBar x:Name="PBG_Progress" DockPanel.Dock="Bottom" />
        <TextBlock x:Name="TBK_Remaining" FontSize="15" FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,4,0,8" Foreground="{DynamicResource Foreground.Default}" DockPanel.Dock="Bottom" />
        <TextBlock Name="TBK_Message" TextWrapping="Wrap" TextAlignment="Left" VerticalAlignment="Center" HorizontalAlignment="Center" Text="Message" FontSize="13" Margin="0,0,0,4" />
    </DockPanel>
"@
    Init = {
        param($Ctx)

        # DispatcherTimer runs on the STA thread that owns the window
        $Timer = [System.Windows.Threading.DispatcherTimer]::new()
        $Timer.Interval = [timespan]::FromSeconds(1)

        $Timer.Add_Tick{
            $Ctx  = $Sync.UI_Window.DataContext
            $Elem = $Ctx.Elements

            $Ctx._Remaining -= [timespan]::FromSeconds(1)
            if ($Ctx._Remaining -lt [timespan]::Zero) { $Ctx._Remaining = [timespan]::Zero }

            # Adaptive formatting — show hours only when needed
            $Elem.TBK_Remaining.Text = $Ctx._Remaining.ToString("dd\.hh\:mm\:ss") -replace '^00[\.:]' -replace '^00[\.:]'
            $Elem.PBG_Progress.Value = $Ctx.Params.Duration.TotalSeconds - $Ctx._Remaining.TotalSeconds

            if ($Ctx._Remaining -eq [timespan]::Zero) {
                $Ctx._Timer.Stop()
                $Ctx.Sync.PendingOutput = "Timeout"  # non-null output = completed naturally
            }
        }

        # Store the timer and runtime data in $Ctx so the Tick closure can reach them
        $Ctx._Timer     = $Timer
        $Ctx._Remaining = $Ctx.Params.Duration

        # Render initial state immediately
        $Ctx.Elements.PBG_Progress.Minimum = 0
        $Ctx.Elements.PBG_Progress.Maximum = $Ctx.Params.Duration.TotalSeconds
        $Ctx.Elements.PBG_Progress.Value   = $Ctx.Params.Duration.TotalSeconds - $Ctx._Remaining.TotalSeconds
        $Ctx.Elements.TBK_Remaining.Text   = $Ctx.Params.Duration.ToString("dd\.hh\:mm\:ss") -replace '^00[\.:]' -replace '^00[\.:]'

        $Timer.Start()
    }
    Update = {
        param($Ctx)
        $Ctx.Elements.TBK_Message.Text = $Ctx.Params.Message
        if ($Ctx.Params.ContainsKey('Color')) { 
            $Ctx.Elements.PBG_Progress.Foreground = $Ctx.Params.Color }
    }
    Dispose = {
        param($Ctx)
        # Stop and release the DispatcherTimer to prevent it from running
        # after the interaction has been replaced or the window closed
        if ($null -ne $Ctx._Timer) {
            $Ctx._Timer.Stop()
            $Ctx._Timer = $null
        }
    }
}