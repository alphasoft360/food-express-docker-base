# Follow logs. Usage: .\scripts\logs.ps1 [app]
. "$PSScriptRoot\lib.ps1"
if ($args -and -not "$($args[0])".StartsWith('-')) { docker compose logs -f --tail=200 @($args | Select-Object -Skip 1) (Svc $args[0]) }
else { docker compose logs -f --tail=100 @args }
