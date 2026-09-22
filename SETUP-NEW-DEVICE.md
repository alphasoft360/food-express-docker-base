# Setting up Food Express on a new device

This is the verified, tested setup path for this project — confirmed working end-to-end
on macOS. It replaces guesswork: every step and gotcha below was actually hit and solved
during development, not assumed.

## What this project actually is

Two separate GitHub repos, both under the `alphasoft360` account:

- **`git@github.com:alphasoft360/food-express-docker-base.git`** — the Docker dev
  environment (Compose file, scripts, QR/install page). This is infrastructure, not
  the app itself.
- **`git@github.com:alphasoft360/food-express-frontend.git`** — the actual app source:
  6 apps (3 Expo/React Native mobile apps, 3 Next.js web apps), rebranded from the
  upstream open-source "Enatega" project to "Food Express". No backend lives here —
  all 6 apps talk to a hosted GraphQL API over HTTPS (already configured, nothing to
  stand up locally).

**Critical gotcha:** `docker-base`'s own setup scripts, if run standalone, will
auto-clone the **original upstream Enatega repo** (`github.com/enatega/food-delivery-multivendor`)
into `repositories/food-delivery-multivendor` — NOT our rebranded fork. To get the
Food Express branding, you must clone `food-express-frontend` into that exact path
yourself, or edit `docker-base/.env`'s `UPSTREAM_REPO` before first run.

## Prerequisites

1. **Git SSH access.** Generate an SSH key on the new device (`ssh-keygen -t ed25519`),
   add the public key to the GitHub account that has collaborator access to both
   `alphasoft360` repos (Settings → SSH and GPG keys), then verify with
   `ssh -T git@github.com`. Per this project's own rule: **git push/commit authorization
   is granted per-device explicitly by the project owner** — don't assume it carries
   over from another machine.
2. **Docker Desktop.** Needs to actually be running (`docker info` succeeds) before
   anything else. On an older macOS (13 Ventura), the *current* Docker Desktop release
   refuses to install — the last version supporting Ventura is **4.48.0**
   (`https://desktop.docker.com/mac/main/amd64/207573/Docker.dmg` for Intel,
   swap `amd64` for `arm64` on Apple Silicon). On macOS 14+ or Windows/Linux, just
   install the current Docker Desktop / Docker Engine + Compose normally.
3. No Xcode / Android Studio is required for the default path — Android dev-client
   APKs are built entirely inside Docker.

## Clone

```bash
mkdir -p ~/food-express && cd ~/food-express
git clone git@github.com:alphasoft360/food-express-docker-base.git docker-base
git clone git@github.com:alphasoft360/food-express-frontend.git repositories/food-delivery-multivendor
```

The second path is deliberate — it matches what `docker-base/.env`'s `REPO_DIR`
(`../repositories/food-delivery-multivendor`) expects by default, so the scripts use
your already-cloned rebranded copy instead of auto-cloning upstream.

## Start the 6 apps

```bash
cd docker-base
./scripts/start-all.sh
```

First run creates `.env` from `.env.example`, builds the shared Node dev image, and
runs `npm ci` for all 6 apps (several minutes). Known first-run issues and fixes:

- **`docker compose build` fails with `"image ... already exists"`.** All 6 app
  services share one image tag and Compose builds them in parallel, which races on
  the image export. Fix: build sequentially instead —
  `for s in customer rider store admin web sv-admin qr; do docker compose build "$s"; done`
  then `docker compose up -d <same list>`.
- **Port conflict on 3001 (admin).** If something else on the host already uses it,
  set `ADMIN_PORT=<free port>` in `docker-base/.env` — it's built for exactly this.
- **`HOST_LAN_IP` errors.** Leave it blank in `.env`; the scripts auto-detect the
  machine's current LAN IP on every run (don't hardcode it — it's not portable
  between devices or networks).

Once up, all 6 services are reachable at (default ports, override via `.env`):

| Service | Port | Notes |
|---|---|---|
| Customer web | 3002 | Next.js |
| Multivendor admin | 3001 (or overridden) | Next.js |
| Single-vendor admin | 3003 | Next.js |
| Customer app Metro | 8081 | Expo dev server |
| Rider app Metro | 8082 | Expo dev server |
| Store app Metro | 8083 | Expo dev server |
| QR/install page | 8090 | Browser page with per-app QR codes + APK downloads |

## Mobile apps (Android)

All 3 mobile apps (customer, rider, store) require a **custom Expo dev-client build**,
not Expo Go — they use native modules (`react-native-maps`, `expo-notifications`, etc.)
that Expo Go doesn't support, and Expo Go additionally requires an exact Expo SDK match
which this project won't have. Opening via Expo Go produces
`Project is incompatible with this version of Expo Go` — that's expected; use the
dev-client APK instead.

Build APKs entirely in Docker (no Android Studio):

```bash
./scripts/build-android.sh user        # customer
./scripts/build-android.sh rider
./scripts/build-android.sh restaurant  # store
```

Each is a full native Gradle build (~15–50 min depending on cache state). Run them
**sequentially**, not in parallel — a single build can peak around 4.5GB RAM, and
running 3 at once on an 8–12GB Docker VM risks OOM/thrashing that ends up slower than
sequential, not faster.

Known build issues:
- A transient `curl: (18) HTTP/2 stream ... not closed cleanly` while downloading
  Android SDK tools from Google's CDN — just retry the build, it's a flaky download,
  not a real error.
- If a mobile app's `expo start` hangs repeatedly printing
  `An Expo user account is required to proceed` (stuck asking for an EAS login,
  never actually serving), add `--offline` to that app's `*_EXPO_FLAGS` in `.env`
  (e.g. `RIDER_EXPO_FLAGS=--offline`) and restart that one container — this forces
  the Expo CLI to skip all EAS/network calls.
- The store app needs `"largeHeap": true` under `android` in its `app.json` (already
  committed) to avoid an `OutOfMemoryError` crash on first launch on memory-constrained
  phones — if this regresses, that's the fix.

Install on a phone (same Wi-Fi as the host machine): open `http://<host-LAN-IP>:8090`
in the phone's browser, or scan its QR codes. Use the **"Install the app (APK)"**
link/QR to sideload the dev-client, then the **"Development build"** QR/link (not
"Expo Go") each time you want to connect it to the running Metro server.

## Testing

- Web apps: open the URLs above in a browser: golden path is browsing → cart → checkout.
- Mobile apps: install the dev-client APK, open it, use "Enter URL manually" with
  `http://<host-LAN-IP>:<port>` if auto-discovery doesn't find the server (Docker's
  network namespace breaks Expo's normal mDNS auto-discovery — this is why the QR
  page exists instead of relying on it).
- `./scripts/doctor.sh` checks Docker, ports, LAN IP, repo state, and container health
  in one pass — run this first on a new device if anything seems off.

## What's intentionally NOT touched

Deep-link schemes/slugs, package/bundle identifiers, EAS project IDs, and internal
HTTP User-Agent strings were left as the upstream project defined them — changing
those would break the QR page's deep links and the existing EAS project linkage, for
no user-visible benefit.
