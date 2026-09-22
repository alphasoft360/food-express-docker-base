. "$PSScriptRoot\lib.ps1"
Write-Host "Host LAN IP: $env:HOST_LAN_IP"
docker ps -a --filter label=com.docker.compose.project=enatega --format 'table {{.Label "com.docker.compose.service"}}\t{{.Status}}\t{{.Ports}}'
