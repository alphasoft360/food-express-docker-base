#!/usr/bin/env bash
# Build the dev image and start apps (default: all six). Usage: up.sh [app...]
source "$(dirname "$0")/lib.sh"
targets=(); for a in "$@"; do targets+=("$(svc "$a")"); done
compose build ${targets[@]+"${targets[@]}"}
compose up -d ${targets[@]+"${targets[@]}"}
echo "Started. First run installs npm dependencies (several minutes): scripts/logs.sh <app>"
