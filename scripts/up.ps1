# Build the dev image and start apps (default: all six). Usage: .\scripts\up.ps1 [app...]
. "$PSScriptRoot\lib.ps1"
$t = @($args | ForEach-Object { Svc $_ })
Compose build @t
Compose up -d @t
Write-Host 'Started. First run installs npm dependencies (several minutes): scripts\logs.ps1 <app>'
