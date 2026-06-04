@{
    Name = "PieChart"
    Description = "Pie chart rendered from a named numeric dataset, with optional unit suffix."
    Example = @'
        # Live pie chart updated as data accumulates
        $Handle = Invoke-Interaction -Type PieChart -Datas $null -Async
        $Datas = @{}
        1..1000 | ForEach-Object {
            $Key = Get-Random -Minimum 1 -Maximum 9
            $Value = if ($Datas[$Key]) { $Datas[$Key] } else { 0 }
            $Datas[$Key] = $Value + 1
            $Handle.Datas = $Datas
        }
'@
    Parameters  = @{
        Datas = @{ Type=[hashtable]; Default=@{'Data 1'=5; 'Data 2'=10}
                   HelpText="Hashtable of named numeric values to display as pie slices. Format: @{ 'Label' = Value }." }
        Unit  = @{ Type=[string];
                   HelpText="Optional unit suffix appended to each slice label (e.g. 'GB', 'ms', '%')." }
    }
    Xaml = @"
    <Image x:Name="IMG_Chart" xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" />
"@
    Init = {
        param($Ctx)
        Add-Type -AssemblyName System.Windows.Forms,System.Windows.Forms.DataVisualization

        # Create the chart object
        $Chart = [System.Windows.Forms.DataVisualization.Charting.Chart]::new()
        $Chart.Width = 400 ; $Chart.Height = 300
        $Chart.ChartAreas.Add([System.Windows.Forms.DataVisualization.Charting.ChartArea]::new())
        [void]$Chart.Series.Add("Data") 

        # Configure pie look
        $Chart.Series["Data"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Pie
        $Chart.Series["Data"]["PieLabelStyle"] = "Outside"
        $Chart.Series["Data"]["PieLineColor"] = "Black"

        # Reference the chart in the image tag property
        $Ctx.Elements.IMG_Chart.Tag = $Chart
        $Ctx.Elements.IMG_Chart.Width  = $Chart.Width
        $Ctx.Elements.IMG_Chart.Height = $Chart.Height
    }
    Update = {
        param($Ctx)

        $Chart = $Ctx.Elements.IMG_Chart.Tag
        if (-not $Ctx.Params.Datas) { return }
        $Datas = $Ctx.Params.Datas.Clone()
        
        # Index existing points by Tag
        $Points = @{}
        foreach ($Point in $Chart.Series["Data"].Points) {
            $Points[$Point.Tag] = $Point
        }

        # Remove points no longer in Datas
        foreach ($Key in @($Points.Keys)) {
            if (-not $Datas.ContainsKey($Key)) {
                $Chart.Series["Data"].Points.Remove($Points[$Key])
            }
        }

        # Update or create datapoints
        foreach ($Entry in $Datas.GetEnumerator()) {
            $Value = [double]$Entry.Value
            $Label = if ($Ctx.Params.Unit) { "$($Entry.Name): $Value $($Ctx.Params.Unit)" } else { "$($Entry.Name): $Value" }
            if ($Points.ContainsKey($Entry.Name)) {
                $Points[$Entry.Name].YValues  = $Value
                $Points[$Entry.Name].AxisLabel = $Label
            } else {
                $Point = [System.Windows.Forms.DataVisualization.Charting.DataPoint]::new(0, $Value)
                $Point.Tag       = $Entry.Name
                $Point.AxisLabel = $Label
                $Chart.Series["Data"].Points.Add($Point)
            }
        }

        # Render chart to MemoryStream and push to WPF Image
        $Stream = [System.IO.MemoryStream]::new()
        $Chart.SaveImage($Stream,"png")
        $Ctx.Elements.IMG_Chart.Source = $Stream.GetBuffer()
        $Stream.Dispose()
    }
}