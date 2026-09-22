# Start app(s), wait until ready, print URLs + QR codes. Usage: .\scripts\start.ps1 <app...>
. "$PSScriptRoot\lib.ps1"
if (-not $args) { throw 'usage: start.ps1 <app...>  (user rider restaurant admin web sv-admin)' }
$t = @($args | ForEach-Object { Svc $_ })
& "$PSScriptRoot\up.ps1" @t
Wait-Healthy $t
& "$PSScriptRoot\device-info.ps1" @t
