#!/usr/bin/env bash
# Restart app(s) (default: all running). Usage: restart.sh [app...]
source "$(dirname "$0")/lib.sh"
targets=(); for a in "$@"; do targets+=("$(svc "$a")"); done
compose restart ${targets[@]+"${targets[@]}"}
