#!/usr/bin/env bash
# Start app(s), wait until ready, print phone/browser URLs + QR codes.
# Usage: start.sh <app...>   (user rider restaurant admin web sv-admin)
source "$(dirname "$0")/lib.sh"
[ $# -gt 0 ] || { echo "usage: $0 <app...>"; exit 2; }
targets=(); for a in "$@"; do targets+=("$(svc "$a")"); done
"$BASE/scripts/up.sh" "${targets[@]}"
wait_healthy "${targets[@]}"
exec "$BASE/scripts/device-info.sh" "${targets[@]}"
