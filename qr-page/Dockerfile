# Small web page with scannable QR codes for the Enatega Expo apps (see server.js).
FROM node:20.19.5-bookworm-slim
WORKDIR /srv
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund
COPY server.js ./
USER node
CMD ["node", "server.js"]
