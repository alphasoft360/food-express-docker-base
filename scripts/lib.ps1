# Dot-sourced by every .ps1 script: cd to docker-base, ensure .env, set HOST_LAN_IP.
$ErrorActionPreference = 'Stop'
$Base = Split-Path -Parent $PSScriptRoot
Set-Location $Base
if (-not (Test-Path .env)) { Copy-Item .env.example .env; Write-Host 'Created docker-base/.env from .env.example' }

function Get-EnvValue($name) {
  $line = Get-Content .env | Where-Object { $_ -match "^$name=" } | Select-Object -Last 1
  if ($line) { return ($line -split '=', 2)[1].Trim() } else { return '' }
}
function EnvOr($name, $default) { $v = Get-EnvValue $name; if ($v) { $v } else { $default } }

# First run on a fresh workspace: fetch the upstream monorepo (untouched, default branch).
$RepoDir = EnvOr REPO_DIR '../repositories/food-delivery-multivendor'
if (-not (Test-Path (Join-Path $RepoDir '.git'))) {
  Write-Host "Cloning upstream Enatega source into $RepoDir ..."
  git -c core.autocrlf=false clone (EnvOr UPSTREAM_REPO 'https://github.com/enatega/food-delivery-multivendor.git') $RepoDir
  if ($LASTEXITCODE) { throw 'git clone failed' }
}

if (-not $env:HOST_LAN_IP) { $env:HOST_LAN_IP = Get-EnvValue 'HOST_LAN_IP' }
if (-not $env:HOST_LAN_IP) {
  if ($IsMacOS) { $if = (route -n get default | Select-String 'interface:').ToString().Split(':')[1].Trim(); $env:HOST_LAN_IP = (ipconfig getifaddr $if) }
  elseif ($IsLinux) { $env:HOST_LAN_IP = ((ip -4 route get 1.1.1.1) -split ' ')[((ip -4 route get 1.1.1.1) -split ' ').IndexOf('src') + 1] }
  else {
    $env:HOST_LAN_IP = (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } |
      Select-Object -First 1).IPv4Address.IPAddress
  }
}
if (-not $env:HOST_LAN_IP) { Write-Warning 'Could not detect LAN IP; set HOST_LAN_IP in docker-base/.env'; $env:HOST_LAN_IP = '127.0.0.1' }

$Apps = 'customer', 'rider', 'store', 'admin', 'web', 'sv-admin'
$Mobile = 'customer', 'rider', 'store'
$Ports = @{ customer = EnvOr CUSTOMER_METRO_PORT 8081; rider = EnvOr RIDER_METRO_PORT 8082; store = EnvOr STORE_METRO_PORT 8083
            admin = EnvOr ADMIN_PORT 3001; web = EnvOr WEB_PORT 3002; 'sv-admin' = EnvOr SV_ADMIN_PORT 3003 }

function Svc($name) {
  switch ($name) {
    { $_ -in 'user', 'customer', 'app' } { return 'customer' }
    { $_ -in 'rider', 'driver' } { return 'rider' }
    { $_ -in 'store', 'restaurant', 'vendor' } { return 'store' }
    'admin' { return 'admin' }
    'web' { return 'web' }
    { $_ -in 'sv-admin', 'singlevendor-admin', 'single-admin' } { return 'sv-admin' }
    { $_ -in 'qr', 'qr-page' } { return 'qr' }
    default { throw "unknown app '$name' (use: user rider restaurant admin web sv-admin qr)" }
  }
}
function Compose { & docker compose @args; if ($LASTEXITCODE) { throw "docker compose $args failed" } }

function Wait-Healthy([string[]]$services) {
  foreach ($s in $services) {
    Write-Host -NoNewline ("Waiting for {0,-9}" -f $s)
    while ($true) {
      $id = docker compose ps -q $s
      $st = if ($id) { docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' $id } else { 'missing' }
      if ($st -eq 'healthy') { Write-Host ' ready'; break }
      if ($st -in 'unhealthy', 'exited', 'dead', 'missing') { Write-Host " $st - see: scripts\logs.ps1 $s"; break }
      Write-Host -NoNewline '.'; Start-Sleep 5
    }
  }
}
