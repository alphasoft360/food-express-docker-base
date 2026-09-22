#!/usr/bin/env bash
# Print the URLs/QR codes to open each running app. Usage: device-info.sh [app...]
source "$(dirname "$0")/lib.sh"
targets=(); for a in "$@"; do targets+=("$(svc "$a")"); done
[ ${#targets[@]} -gt 0 ] || targets=($APPS)

label() { case "$1" in customer) echo "Customer app";; rider) echo "Rider app";; store) echo "Restaurant (store) app";;
  admin) echo "Multi-vendor Admin";; web) echo "Customer Web";; sv-admin) echo "Single-vendor Admin";; esac; }
port() { case "$1" in customer) env_or CUSTOMER_METRO_PORT 8081;; rider) env_or RIDER_METRO_PORT 8082;; store) env_or STORE_METRO_PORT 8083;;
  admin) env_or ADMIN_PORT 3001;; web) env_or WEB_PORT 3002;; sv-admin) env_or SV_ADMIN_PORT 3003;; esac; }
env_or() { local v; v="$(env_get "$1")"; echo "${v:-$2}"; }
running() { [ -n "$(compose ps -q --status running "$1" 2>/dev/null)" ]; }

echo
echo "Enatega Development Environment"
echo "==============================="
echo "Host LAN IP: $HOST_LAN_IP   (phone must be on the same Wi-Fi)"
echo "API:         hosted by Enatega - $(env_or API_URL https://aws-server-v2.enatega.com/)"
qp="$(env_or QR_PAGE_PORT 8090)"
if running qr; then echo "QR codes:    http://localhost:$qp   <- open in a browser and scan from the screen"
else echo "QR codes:    QR page not running (scripts/start.sh qr)"; fi

for s in "${targets[@]}"; do
  [ "$s" = qr ] && continue
  p="$(port "$s")"
  echo; echo "--- $(label "$s")"
  if ! running "$s"; then echo "    not running (scripts/start.sh $s)"; continue; fi
  case " $MOBILE " in
    *" $s "*)
      # Expo prints the exact deep link it serves (exp://... or exp+<slug>://...).
      url="$(compose logs --no-log-prefix "$s" 2>/dev/null | tr -d '\r' | sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g' \
             | grep -oE 'exp(\+[A-Za-z0-9._-]+)?://[^[:space:]]+' | tail -1 || true)"
      echo "    Metro:  http://$HOST_LAN_IP:$p   (open on phone browser -> 'packager-status:running' = network OK)"
      if [ -z "$url" ]; then echo "    Expo not ready yet (still installing/bundling?): scripts/logs.sh $s"; continue; fi
      echo "    Open:   $url"
      echo "    QR:     docker attach enatega-$s   then press c (Expo re-prints its QR). Detach: Ctrl-P Ctrl-Q"
      ;;
    *) echo "    Browser: http://localhost:$p";;
  esac
done
echo
echo "Attach from a real terminal (Terminal/iTerm/Windows Terminal), not the Docker Desktop Logs tab."
echo "Expo keys once attached: c = show QR, s = switch dev build / Expo Go, r = reload, ? = all."
