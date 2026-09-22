#!/usr/bin/env bash
# Environment diagnostics. Exit code = number of failed checks.
source "$(dirname "$0")/lib.sh"
fails=0
ok()   { printf '  %-26s \033[32m✓\033[0m %s\n' "$1" "${2:-}"; }
warn() { printf '  %-26s \033[33m!\033[0m %s\n' "$1" "$2"; }
bad()  { printf '  %-26s \033[31m✗\033[0m %s\n' "$1" "$2"; fails=$((fails+1)); }
r="$(env_get REPO_DIR)"; r="${r:-../repositories/food-delivery-multivendor}"
REPO="$(cd "$BASE" && cd "$r" 2>/dev/null && pwd || echo "$r")"

echo "Enatega Doctor"; echo "=============="
command -v docker >/dev/null && ok Docker "$(docker --version | cut -d, -f1)" || { bad Docker "not installed: https://docs.docker.com/get-docker/"; exit 1; }
docker compose version >/dev/null 2>&1 && ok "Docker Compose" "$(docker compose version --short)" || bad "Docker Compose" "needs Compose v2 (docker compose)"
if docker info >/dev/null 2>&1; then
  ok "Docker daemon" "$(docker info -f '{{.OperatingSystem}}, {{.Architecture}}, {{.NCPU}} CPU')"
  mem=$(( $(docker info -f '{{.MemTotal}}') / 1024 / 1024 / 1024 ))
  [ "$mem" -ge 12 ] && ok "Docker memory" "${mem} GB" || warn "Docker memory" "${mem} GB - all 6 apps at once need ~12 GB (Docker Desktop > Settings > Resources)"
else bad "Docker daemon" "not running - start Docker Desktop / systemctl start docker"; fi

[ -f .env ] && ok "Environment file" "docker-base/.env" || bad "Environment file" "missing"
[ "$HOST_LAN_IP" != 127.0.0.1 ] && ok "Host LAN IP" "$HOST_LAN_IP" || bad "Host LAN IP" "not detected - set HOST_LAN_IP in .env"
case "$HOST_LAN_IP" in 172.1[6-9].*|172.2[0-9].*|172.3[01].*) warn "Host LAN IP" "$HOST_LAN_IP looks like a Docker/WSL NAT address; phones can't reach it";; esac

if [ -d "$REPO/.git" ]; then
  ok "Repository" "$(git -C "$REPO" rev-parse --abbrev-ref HEAD)@$(git -C "$REPO" rev-parse --short HEAD)"
  for a in enatega-multivendor-app enatega-multivendor-rider enatega-multivendor-store enatega-multivendor-admin enatega-multivendor-web enatega-singlevendor-admin; do
    [ -f "$REPO/$a/package-lock.json" ] || bad "  $a" "missing (upstream layout changed?)"
  done
  dirty="$(git -C "$REPO" status --porcelain | head -5)"
  [ -z "$dirty" ] && ok "Source clean (git status)" || warn "Source clean (git status)" "local changes: $(echo "$dirty" | tr '\n' ' ')"
  case "$REPO" in /mnt/[a-z]/*) warn "Repo location" "on a Windows drive: slow + no file-change events. Clone inside WSL (~/...)";; esac
else bad "Repository" "not found at $REPO - see README 'Getting the source'"; fi

running_ports="$(docker ps --filter label=com.docker.compose.project=enatega --format '{{.Ports}}')"
for v in CUSTOMER_METRO_PORT:8081 RIDER_METRO_PORT:8082 STORE_METRO_PORT:8083 ADMIN_PORT:3001 WEB_PORT:3002 SV_ADMIN_PORT:3003 QR_PAGE_PORT:8090; do
  p="$(env_get "${v%%:*}")"; p="${p:-${v#*:}}"
  if echo "$running_ports" | grep -q ":$p->"; then ok "Port $p" "in use by enatega"
  elif (echo >"/dev/tcp/127.0.0.1/$p") 2>/dev/null; then bad "Port $p" "taken by another program - change ${v%%:*} in .env"
  else ok "Port $p" "free"; fi
done

docker network inspect enatega-network >/dev/null 2>&1 && ok "Docker network" enatega-network || warn "Docker network" "not created yet (scripts/up.sh)"

code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' -X POST -H 'content-type: application/json' --data '{"query":"{__typename}"}' "$(env_get API_URL)graphql" || true)
[ "$code" = 200 ] && ok "Hosted API" "$(env_get API_URL) (HTTP 200)" || bad "Hosted API" "$(env_get API_URL) returned '$code' - internet/firewall?"

for s in $APPS qr; do
  id="$(compose ps -q "$s" 2>/dev/null)"
  if [ -z "$id" ]; then warn "Container $s" "not started"; continue; fi
  st="$(docker inspect -f '{{.State.Status}}{{if .State.Health}}/{{.State.Health.Status}}{{end}}' "$id")"
  case "$st" in running/healthy) ok "Container $s" "$st";; running/starting) warn "Container $s" "starting (first run: npm ci)";; *) bad "Container $s" "$st - scripts/logs.sh $s";; esac
done

# Phone path: host LAN IP -> published port -> Metro. Tests the same URL a phone uses.
for v in customer:CUSTOMER_METRO_PORT:8081 rider:RIDER_METRO_PORT:8082 store:STORE_METRO_PORT:8083; do
  IFS=: read -r s var def <<<"$v"; p="$(env_get "$var")"; p="${p:-$def}"
  [ -n "$(compose ps -q --status running "$s" 2>/dev/null)" ] || continue
  r="$(curl -s -m 5 "http://$HOST_LAN_IP:$p/status" || true)"
  [ "$r" = "packager-status:running" ] && ok "Metro $s via LAN" "http://$HOST_LAN_IP:$p" \
    || bad "Metro $s via LAN" "http://$HOST_LAN_IP:$p unreachable - firewall must allow inbound TCP $p"
done

echo; [ $fails -eq 0 ] && echo "Environment is ready." || echo "$fails problem(s) found."
exit $fails
