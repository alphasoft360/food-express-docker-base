# Print URLs/QR codes for running apps. Usage: .\scripts\device-info.ps1 [app...]
. "$PSScriptRoot\lib.ps1"
$t = if ($args) { @($args | ForEach-Object { Svc $_ }) } else { $Apps }
$labels = @{ customer = 'Customer app'; rider = 'Rider app'; store = 'Restaurant (store) app'; admin = 'Multi-vendor Admin'; web = 'Customer Web'; 'sv-admin' = 'Single-vendor Admin' }
Write-Host "`nEnatega Development Environment`n==============================="
Write-Host "Host LAN IP: $env:HOST_LAN_IP   (phone must be on the same Wi-Fi)"
Write-Host "API:         hosted by Enatega - $(EnvOr API_URL 'https://aws-server-v2.enatega.com/')"
$qp = EnvOr QR_PAGE_PORT 8090
if (docker compose ps -q --status running qr) { Write-Host "QR codes:    http://localhost:$qp   <- open in a browser and scan from the screen" }
else { Write-Host "QR codes:    QR page not running (scripts\start.ps1 qr)" }
foreach ($s in $t) {
  if ($s -eq 'qr') { continue }
  $p = $Ports[$s]; Write-Host "`n--- $($labels[$s])"
  if (-not (docker compose ps -q --status running $s)) { Write-Host "    not running (scripts\start.ps1 $s)"; continue }
  if ($s -notin $Mobile) { Write-Host "    Browser: http://localhost:$p"; continue }
  Write-Host "    Metro:  http://$($env:HOST_LAN_IP):$p   (open on phone browser -> 'packager-status:running' = network OK)"
  $m = (docker compose logs --no-log-prefix $s 2>$null) -replace "`e\[[0-9;]*[A-Za-z]", '' | Select-String -Pattern '(exp(\+[A-Za-z0-9._-]+)?://\S+)' | Select-Object -Last 1
  if (-not $m) { Write-Host "    Expo not ready yet: scripts\logs.ps1 $s"; continue }
  $url = $m.Matches[0].Groups[1].Value
  Write-Host "    Open:   $url"
  Write-Host "    QR:     docker attach enatega-$s   then press c (Expo re-prints its QR). Detach: Ctrl-P Ctrl-Q"
}
Write-Host "`nAttach from a real terminal (Windows Terminal/PowerShell), not the Docker Desktop Logs tab."
Write-Host "Expo keys once attached: c = show QR, s = switch dev build / Expo Go, r = reload, ? = all."
