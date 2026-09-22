#!/usr/bin/env bash
# Stop everything. `down.sh --volumes` also deletes node_modules/.next/gradle caches.
source "$(dirname "$0")/lib.sh"
compose --profile android down "$@"
