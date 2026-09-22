# Environment diagnostics (Windows/PowerShell). Mirrors doctor.sh.
. "$PSScriptRoot\lib.ps1"
$ErrorActionPreference = 'Continue'
$script:fails = 0
function Ok($n, $m = '') { Write-Host ("  {0,-26} " -f $n) -NoNewline; Write-Host 'OK ' -ForegroundColor Green -NoNewline; Write-Host $m }
function Warn($n, $m) { Write-Host ("  {0,-26} " -f $n) -NoNewline; Write-Host '!  ' -ForegroundColor Yellow -NoNewline; Write-Host $m }
function Bad($n, $m) { Write-Host ("  {0,-26} " -f $n) -NoNewline; Write-Host 'X  ' -ForegroundColor Red -NoNewline; Write-Host $m; $script:fails++ }

Write-Host "Enatega Doctor`n=============="
if (Get-Command docker -ErrorAction SilentlyContinue) { Ok Docker (docker --version) } else { Bad Docker 'not installed: https://docs.docker.com/desktop/'; exit 1 }
docker compose version *> $null; if ($LASTEXITCODE -eq 0) { Ok 'Docker Compose' (docker compose version --short) } else { Bad 'Docker Compose' 'needs Compose v2' }
docker info *> $null
if ($LASTEXITCODE -eq 0) {
  Ok 'Docker daemon' (docker info -f '{{.OperatingSystem}}, {{.Architecture}}, {{.NCPU}} CPU')
  $mem = [math]::Floor([double](docker info -f '{{.MemTotal}}') / 1GB)
  if ($mem -ge 12) { Ok 'Docker memory' "$mem GB" } else { Warn 'Docker memory' "$mem GB - all 6 apps at once need ~12 GB (.wslconfig / Docker Desktop settings)" }
} else { Bad 'Docker daemon' 'not running - start Docker Desktop' }
if ($env:HOST_LAN_IP -ne '127.0.0.1') { Ok 'Host LAN IP' $env:HOST_LAN_IP } else { Bad 'Host LAN IP' 'not detected - set HOST_LAN_IP in .env' }

$repo = Join-Path $Base (EnvOr REPO_DIR '../repositories/food-delivery-multivendor')
if (Test-Path (Join-Path $repo '.git')) {
  Ok Repository "$(git -C $repo rev-parse --abbrev-ref HEAD)@$(git -C $repo rev-parse --short HEAD)"
  $dirty = git -C $repo status --porcelain
  if (-not $dirty) { Ok 'Source clean (git status)' } else { Warn 'Source clean (git status)' "local changes: $($dirty | Select-Object -First 5)" }
  Warn 'File watching' 'Metro cannot poll: for Fast Refresh keep the repo inside WSL (\\wsl$\...) - see README'
} else { Bad Repository "not found at $repo - see README 'Getting the source'" }

$ours = docker ps --filter label=com.docker.compose.project=enatega --format '{{.Ports}}'
foreach ($p in @($Ports.Values) + (EnvOr QR_PAGE_PORT 8090)) {
  if ("$ours" -match ":$p->") { Ok "Port $p" 'in use by enatega' }
  elseif (Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue) { Bad "Port $p" 'taken by another program - change it in .env' }
  else { Ok "Port $p" 'free' }
}
try {
  $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 10 -Method Post -ContentType 'application/json' -Body '{"query":"{__typename}"}' "$(EnvOr API_URL 'https://aws-server-v2.enatega.com/')graphql"
  Ok 'Hosted API' "HTTP $($r.StatusCode)"
} catch { Bad 'Hosted API' "unreachable: $($_.Exception.Message)" }
foreach ($s in $Apps + 'qr') {
  $id = docker compose ps -q $s
  if (-not $id) { Warn "Container $s" 'not started'; continue }
  $st = docker inspect -f '{{.State.Status}}{{if .State.Health}}/{{.State.Health.Status}}{{end}}' $id
  if ($st -eq 'running/healthy') { Ok "Container $s" $st } elseif ($st -eq 'running/starting') { Warn "Container $s" 'starting (first run: npm ci)' } else { Bad "Container $s" "$st - scripts\logs.ps1 $s" }
}
foreach ($s in $Mobile) {
  if (-not (docker compose ps -q --status running $s)) { continue }
  $u = "http://$($env:HOST_LAN_IP):$($Ports[$s])/status"
  try { $c = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 $u).Content } catch { $c = '' }
  if ($c -eq 'packager-status:running') { Ok "Metro $s via LAN" $u } else { Bad "Metro $s via LAN" "$u unreachable - allow inbound TCP $($Ports[$s]) in Windows Firewall" }
}
Write-Host ''; if ($script:fails -eq 0) { 'Environment is ready.' } else { "$script:fails problem(s) found." }
exit $script:fails
