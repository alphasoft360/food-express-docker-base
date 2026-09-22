#!/usr/bin/env bash
# Sourced by every script: cd to docker-base, ensure .env, export HOST_LAN_IP/UID.
set -euo pipefail
BASE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BASE"

if [ ! -f .env ]; then cp .env.example .env; echo "Created docker-base/.env from .env.example"; fi

env_get() { grep -E "^$1=" .env 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '\r' || true; }

# First run on a fresh workspace: fetch the upstream monorepo (untouched, default branch).
REPO_DIR="$(env_get REPO_DIR)"; REPO_DIR="${REPO_DIR:-../repositories/food-delivery-multivendor}"
if [ ! -d "$REPO_DIR/.git" ]; then
  echo "Cloning upstream Enatega source into $REPO_DIR ..."
  git clone "$(env_get UPSTREAM_REPO || true)" "$REPO_DIR" 2>/dev/null || git clone https://github.com/enatega/food-delivery-multivendor.git "$REPO_DIR"
fi

is_windows() { case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) return 0;; esac; grep -qi microsoft /proc/version 2>/dev/null; }

detect_lan_ip() {
  if is_windows; then
    # WSL/Git Bash see a NAT'd address; the phone needs the Windows host's LAN IP.
    powershell.exe -NoProfile -Command \
      "(Get-NetIPConfiguration | Where-Object { \$_.IPv4DefaultGateway -and \$_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1).IPv4Address.IPAddress" \
      2>/dev/null | tr -d '\r'
  elif [ "$(uname -s)" = Darwin ]; then
    ipconfig getifaddr "$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')" 2>/dev/null
  else
    ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}'
  fi
}

HOST_LAN_IP="${HOST_LAN_IP:-$(env_get HOST_LAN_IP)}"
[ -n "$HOST_LAN_IP" ] || HOST_LAN_IP="$(detect_lan_ip || true)"
if [ -z "$HOST_LAN_IP" ]; then
  echo "WARN: could not detect LAN IP; set HOST_LAN_IP in docker-base/.env. Using 127.0.0.1 (phones won't connect)." >&2
  HOST_LAN_IP=127.0.0.1
fi
export HOST_LAN_IP
if ! is_windows; then
  export HOST_UID="${HOST_UID:-$(env_get HOST_UID)}" HOST_GID="${HOST_GID:-$(env_get HOST_GID)}"
  [ -n "$HOST_UID" ] || HOST_UID="$(id -u)"; [ -n "$HOST_GID" ] || HOST_GID="$(id -g)"
fi

APPS="customer rider store admin web sv-admin"
MOBILE="customer rider store"

# Friendly names -> compose service.
svc() {
  case "$1" in
    user|customer|app) echo customer;;
    rider|driver) echo rider;;
    store|restaurant|vendor) echo store;;
    admin) echo admin;;
    web) echo web;;
    sv-admin|singlevendor-admin|single-admin) echo sv-admin;;
    qr|qr-page) echo qr;;
    *) echo "unknown app '$1' (use: user rider restaurant admin web sv-admin qr)" >&2; exit 2;;
  esac
}

compose() { docker compose "$@"; }

# Block until services are healthy (first run includes npm ci, so be patient).
wait_healthy() {
  local s id st
  for s in "$@"; do
    printf 'Waiting for %-9s' "$s"
    while :; do
      id="$(compose ps -q "$s")"
      st="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$id" 2>/dev/null || echo missing)"
      case "$st" in
        healthy) echo " ready"; break;;
        unhealthy|exited|dead|missing) echo " $st - see: scripts/logs.sh $s"; break;;
      esac
      printf '.'; sleep 5
    done
  done
}
