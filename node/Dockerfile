# Shared development image for all six Enatega apps (3 Expo, 3 Next.js).
# Official node image is multi-arch (linux/amd64 + linux/arm64).
ARG NODE_VERSION=20.19.5
FROM node:${NODE_VERSION}-bookworm-slim

# git: customer app has a git dependency (activity-controller).
# ca-certificates: git over HTTPS.
RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Upstream lockfile pins git+ssh://git@github.com/... ; the repo is public, so
# rewrite to HTTPS instead of needing an SSH key inside the container.
RUN git config --system url."https://github.com/".insteadOf "ssh://git@github.com/" \
 && git config --system --add url."https://github.com/".insteadOf "git@github.com:"

# Writable HOME for whichever host UID the entrypoint drops to.
RUN mkdir -p /home/dev /npm-cache && chmod 1777 /home/dev /npm-cache
ENV HOME=/home/dev \
    NPM_CONFIG_CACHE=/npm-cache \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false \
    HUSKY=0 \
    EXPO_NO_TELEMETRY=1 \
    NEXT_TELEMETRY_DISABLED=1

COPY entrypoint.sh /usr/local/bin/enatega-entrypoint
RUN sed -i 's/\r$//' /usr/local/bin/enatega-entrypoint && chmod +x /usr/local/bin/enatega-entrypoint
ENTRYPOINT ["enatega-entrypoint"]
