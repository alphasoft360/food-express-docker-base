. "$PSScriptRoot\lib.ps1"
$t = @($args | ForEach-Object { Svc $_ })
Compose restart @t
