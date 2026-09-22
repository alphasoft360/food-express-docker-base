#!/usr/bin/env bash
# Follow logs. Usage: logs.sh [app] [extra docker compose logs flags]
source "$(dirname "$0")/lib.sh"
if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then s="$(svc "$1")"; shift; compose logs -f --tail=200 "$@" "$s"
else compose logs -f --tail=100 "$@"; fi
