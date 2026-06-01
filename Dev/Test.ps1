# Root directory of the project.
# Used in DEV mode function to dynamically resolve and inject XAML layouts, styles and test interaction.
$script:PSInvokeInteraction_ROOT = ""

# Load DEV function
# "DEV_Invoke-Interaction.ps1" redefines Invoke-Interaction with hot reload logic built-in
# automatically refreshes Layout, Styles and Interaction on each call if source files have changed
. $(Join-Path $script:PSInvokeInteraction_ROOT -ChildPath "Dev\DEV_Invoke-Interaction.ps1")

# Test the interaction
$Result = Invoke-Interaction -Type ""

$Handle = Invoke-Interaction -Type "" -Async
$Handle.Show()
$Handle.Dispose()