# Stop everything. `down.ps1 --volumes` also deletes node_modules/.next/gradle caches.
. "$PSScriptRoot\lib.ps1"
Compose --profile android down @args
