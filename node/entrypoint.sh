#!/bin/sh
# Installs dependencies into the node_modules named volume when the lockfile
# changes, then runs the app's own start command as the host user.
set -e

HOST_UID="${HOST_UID:-1000}"
HOST_GID="${HOST_GID:-1000}"

# Named volumes are created root-owned; hand them to the host user so files
# written into the bind-mounted source (.expo/, next-env.d.ts) keep host ownership.
if [ "$(id -u)" = "0" ]; then
  for d in node_modules .next /npm-cache; do
    [ -d "$d" ] && chown "$HOST_UID:$HOST_GID" "$d"
  done
  exec setpriv --reuid="$HOST_UID" --regid="$HOST_GID" --clear-groups "$0" "$@"
fi

stamp=node_modules/.enatega-lock.sha256
want="$(sha256sum package-lock.json | cut -d' ' -f1)"
if [ "$(cat "$stamp" 2>/dev/null)" != "$want" ]; then
  echo "[enatega] package-lock.json changed or first run -> npm ci ($(pwd))"
  npm ci
  echo "$want" > "$stamp"
fi

exec "$@"
