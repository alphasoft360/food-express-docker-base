# docker-base — Enatega development environment

Everything Docker-related for Enatega lives here. The upstream source in
`../repositories/food-delivery-multivendor` is mounted into containers and never
edited. After any amount of use, `git status` in that repo stays clean (verified).

- [Repositories](#1-repositories) · [Architecture](#2-architecture) · [Prerequisites & platform setup](#3-prerequisites--platform-setup)
- [Environment variables](#4-environment-variables) · [Commands](#5-commands) · [Port map](#6-port-map)
- [Phones: Android](#7-android-phone) · [Phones: iPhone](#8-iphone) · [Hot reload](#9-hot-reload--file-watching)
- [Updating the source](#10-updating-upstream) · [Resetting](#11-reset-containers--volumes) · [Troubleshooting](#12-troubleshooting) · [Limitations](#13-known-limitations-upstream)

---

## 1. Repositories

Enatega publishes **one** public monorepo, `https://github.com/enatega/food-delivery-multivendor`
(branch `main`). It holds six apps and no backend:

| Directory | Role | Stack | Package manager | Start command (upstream) |
|---|---|---|---|---|
| `enatega-multivendor-app` | Customer mobile app | Expo SDK 53, RN 0.79, React Navigation, `expo-dev-client` | npm (`package-lock.json`) | `npm start` → `expo start` |
| `enatega-multivendor-rider` | Rider/driver mobile app | Expo SDK 53, RN 0.79, Expo Router, NativeWind, `expo-dev-client` | npm | `npm start` |
| `enatega-multivendor-store` | Restaurant/vendor mobile app | Expo SDK 54, RN 0.81, Expo Router, NativeWind, `expo-dev-client` | npm | `npm start` |
| `enatega-multivendor-admin` | Multi-vendor admin dashboard | Next.js 14, React 18 | npm | `npm run dev` |
| `enatega-multivendor-web` | Customer website | Next.js 16 (webpack), React 19 | npm | `npm run dev` |
| `enatega-singlevendor-admin` | Single-vendor admin dashboard | Next.js 14, React 18 | npm | `npm run dev` |

- **Backend/API:** not public. The upstream README says: *"the backend and API are
  proprietary and can be licensed"*. The apps call Enatega's hosted API
  (`https://aws-server-v2.enatega.com/graphql`, single-vendor:
  `https://enatega-multivendor-api-production-9b09.up.railway.app/graphql`).
  So there is **no API, database or Redis container** — there is nothing to run in one.
- **Shared packages:** none. There are no workspaces; each app is standalone. The
  root `lib/` folder isn't imported by any app. `enatega-multivendor-web/ios-app` is a Capacitor stub (not used in dev).
- **Node:** every app's `.nvmrc` says `v20.16.0`. The store app (Expo SDK 54 / RN 0.81 / Metro 0.83)
  needs ≥ 20.19.4, so the image uses **Node 20.19.5**. That still satisfies every `engines` field
  (`>=20.0.0`, npm `>=10`).

## 2. Architecture

```text
 Phone (Android / iPhone)                 Browser on this computer
   │  Wi-Fi: http://<HOST_LAN_IP>:808x        │  http://localhost:300x
   ▼                                          ▼
 ┌──────────── development computer (macOS / Windows / Linux) ─────────────┐
 │  published ports                                                         │
 │  8081 ─ enatega-customer  (Metro/Expo)  ┐                                │
 │  8082 ─ enatega-rider     (Metro/Expo)  │  network: enatega-network      │
 │  8083 ─ enatega-store     (Metro/Expo)  │  image:   enatega-dev-node     │
 │  3001 ─ enatega-admin     (next dev)    │  source:  bind mount (rw)      │
 │  3002 ─ enatega-web       (next dev)    │  node_modules, .next: volumes  │
 │  3003 ─ enatega-sv-admin  (next dev)    ┘                                │
 │  (optional) enatega-android-builder → build-output/*.apk                 │
 └──────────────────────────────────────────────────────────────────────────┘
   │  the phone app and the browser call the API directly over HTTPS/WSS
   ▼
 Enatega hosted API (aws-server-v2.enatega.com)
```

- **Metro/Expo** listens on all interfaces. `REACT_NATIVE_PACKAGER_HOSTNAME=<HOST_LAN_IP>`
  makes Expo put the host's LAN IP (not the container IP) in the manifest and QR code. Metro ports are
  published 1:1 because the port is part of the URL the phone gets.
- **The API** is not proxied through this computer. The phone reaches the hosted HTTPS API
  directly, so `localhost` is never used as an API URL.
- **Dependencies** install with `npm ci` into a named volume per app, so host and container
  `node_modules` never mix (macOS/Windows binaries ≠ Linux). The entrypoint re-runs `npm ci` only when
  `package-lock.json` changes (checked by SHA-256).
- **Ownership (Linux):** containers start as root only long enough to `chown` their volumes, then drop to
  your UID/GID (`HOST_UID`/`HOST_GID`). Files Expo/Next write into the repo (`.expo/`, `next-env.d.ts`, all
  gitignored upstream) stay yours.
- **Upstream `git+ssh` dependency:** the customer app's lockfile pins
  `git+ssh://git@github.com/enatega/activity-controller.git`. The image rewrites GitHub SSH URLs to HTTPS
  (`git config --system url.insteadOf`), so you don't need an SSH key.

Files:

```text
docker-base/
├── docker-compose.yml        all services, network, volumes, health checks
├── .env.example / .env       settings (.env is gitignored)
├── node/                     shared dev image (node:20.19.5-bookworm-slim, amd64+arm64) + entrypoint
├── android-builder/          optional headless Android SDK/JDK image for dev-client APKs
├── build-output/             APKs land here
└── scripts/                  *.sh (macOS/Linux/WSL/Git Bash) and matching *.ps1 (Windows PowerShell)
```

No nginx, TLS certificates, API, database or Redis: nothing in the upstream code needs them locally.

## 3. Prerequisites & platform setup

All platforms: Docker with Compose v2 (`docker compose`) and git. You don't need Node, Android
Studio or Xcode on the host. Set Docker memory to **12 GB for all six apps at once**. Three Metro servers
plus three Next dev servers peak at about 8 GB, and the customer web app alone takes ~2 GB while compiling.
With 8 GB, run the apps you need (e.g. `start-user` + `start-admin`). If memory runs out, the kernel kills
a process and the container restarts itself.

**macOS (Apple Silicon or Intel):** Docker Desktop. Settings → Resources → Memory ≥ 12 GB. The dev
image is native arm64/amd64. The Android builder runs as amd64 (Google ships Linux build-tools for x86_64 only).
On Apple Silicon, enable *Settings → General → Use Rosetta for x86_64/amd64 emulation*. When macOS asks
whether Docker may accept incoming network connections, click *Allow*. Phones need that.

**Windows 10/11:** Docker Desktop with the WSL 2 backend.
- Best setup: clone this workspace **inside WSL** (e.g. `~/enatega-workspace` in Ubuntu) and run the `.sh`
  scripts from a WSL shell. Files on `C:\` (`/mnt/c`) are slow through Docker, and Linux doesn't get file-change
  events for them, so **Metro Fast Refresh won't fire**. Metro has no polling mode.
- Or use PowerShell: `cd docker-base; .\scripts\start-all.ps1` (if scripts are blocked, run
  `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`). If the repo is on `C:\`, set
  `FILE_WATCH_POLLING=true`. That fixes Next.js; Metro still needs WSL for Fast Refresh.
- Memory: Docker Desktop → Resources, or `%UserProfile%\.wslconfig` → `[wsl2] memory=12GB`.
- **Firewall:** allow inbound TCP 8081–8083 on *Private* networks, or phones can't connect:
  `New-NetFirewallRule -DisplayName "Enatega Metro" -Direction Inbound -Protocol TCP -LocalPort 8081-8083 -Action Allow -Profile Private`
- LAN IP detection asks Windows (not WSL, which has a NAT address) via `powershell.exe`.

**Linux:** Docker Engine + the `docker-compose-plugin` package. Docker Desktop isn't needed. Add yourself to
the `docker` group or run the scripts with sudo. If `ufw` is on: `sudo ufw allow 8081:8083/tcp`.

**Line endings:** `.gitattributes` keeps `*.sh`, Dockerfiles and compose files LF on every OS.
The images also strip CRs from their entrypoints as a second guard.

## 4. Environment variables

`docker-base/.env` (copied from `.env.example` on first run). Compose also reads real environment variables,
and those win over `.env`.

| Variable | Category | Default | Purpose |
|---|---|---|---|
| `HOST_LAN_IP` | LOCAL | auto-detect | IP that goes into the QR code / manifest. Set it if you have several NICs or a VPN. |
| `REPO_DIR` / `UPSTREAM_REPO` | LOCAL | `../repositories/food-delivery-multivendor` / GitHub URL | Source location, cloned automatically if missing. |
| `CUSTOMER_METRO_PORT` `RIDER_METRO_PORT` `STORE_METRO_PORT` | LOCAL | 8081 8082 8083 | Metro ports (published 1:1). |
| `ADMIN_PORT` `WEB_PORT` `SV_ADMIN_PORT` | LOCAL | 3001 3002 3003 | Host ports for the Next.js apps. |
| `NODE_VERSION` | LOCAL | 20.19.5 | Dev image Node version. |
| `FILE_WATCH_POLLING` | LOCAL | false | `true` → `WATCHPACK_POLLING`/`CHOKIDAR_USEPOLLING` (Next.js on Windows drives). |
| `CUSTOMER_EXPO_FLAGS` etc. | LOCAL | empty | Extra `expo start` flags. Empty = upstream behaviour (auto development build). `--go` forces Expo Go. |
| `HOST_UID` `HOST_GID` | LOCAL | `id -u` / `id -g` | Linux file ownership. |
| `API_URL` `API_WS_URL` | PUBLIC | hosted multi-vendor API | → `NEXT_PUBLIC_SERVER_URL` / `NEXT_PUBLIC_WS_SERVER_URL` for admin + web. Upstream has no default, so these are required. |
| `SV_API_URL` `SV_API_WS_URL` | PUBLIC | hosted single-vendor API | → web (single-vendor mode) and sv-admin. |
| `RIDER_GRAPHQL_URL` `RIDER_WS_GRAPHQL_URL` | PUBLIC | hosted API | → `EXPO_PUBLIC_GRAPHQL_URL` (only the rider app reads an API env var). |
| `GOOGLE_MAPS_API_KEY_WEB/_ANDROID/_IOS` | SECRET, OPTIONAL | empty | Maps render blank without these. |
| `CUSTOMER_GOOGLE_*_CLIENT_ID` | SECRET, OPTIONAL | empty | Customer app Google sign-in (`EXPO_PUBLIC_GOOGLE_*`). |
| `ADMIN_ENCRYPTION_KEY` | SECRET, OPTIONAL | empty | `NEXT_PUBLIC_ENCRYPTION_KEY` in admin. Comes with an Enatega backend licence. |
| `ANDROID_ARCHS`, `GRADLE_JVMARGS`, `GRADLE_WORKERS` | LOCAL | `arm64-v8a`, 3 GB heap, 2 | Android builder (peak ~4.5 GB RAM). |

Values go into the containers as environment variables. No `.env` file is ever written into the app folders.
Leave secrets out of `.env.example`. `.env` is gitignored.

## 5. Commands

Run from `docker-base/`. Every `.sh` has a `.ps1` twin with the same arguments (`.\scripts\up.ps1`). App names:
`user` (customer), `rider`, `restaurant` (store), `admin`, `web`, `sv-admin`.

| Task | Command |
|---|---|
| Start everything, wait, show URLs + QR | `./scripts/start-all.sh` |
| Start one/some apps | `./scripts/start-user.sh`, `start-rider.sh`, `start-restaurant.sh`, `start-admin.sh`, `start-web.sh`, `start-sv-admin.sh`, or `./scripts/start.sh user admin` |
| Start in background, no waiting | `./scripts/up.sh [app...]` |
| Stop everything | `./scripts/down.sh` |
| Restart | `./scripts/restart.sh [app...]` |
| Logs (follow) | `./scripts/logs.sh` / `./scripts/logs.sh rider` |
| Status table | `./scripts/status.sh` |
| Diagnostics | `./scripts/doctor.sh` |
| URLs + QR codes again | `./scripts/device-info.sh [app...]` |
| **QR codes for phones (easiest)** | Open **http://localhost:8090** in a browser and scan from the screen. It shows the development-build QR, APK download QR and Expo Go QR per app (`enatega-qr` service). |
| **Expo terminal: QR code + keys** | From a real terminal (not Docker Desktop's Logs tab): `docker attach enatega-customer` (or `-rider`, `-store`), then press **`c`** to show the QR code, **`s`** to switch development build ↔ Expo Go, `r` reload, `?` all keys. Detach with **Ctrl-P Ctrl-Q** (Ctrl-C stops the container). |
| Build Android dev-client APK | `./scripts/build-android.sh user` (or `rider`, `restaurant`) |

The first start runs `npm ci` for each app (about 2–5 minutes). Later starts take seconds.

## 6. Port map

| Service | Container | Host port | URL |
|---|---|---|---|
| Customer app Metro | `enatega-customer` | 8081 | `http://<HOST_LAN_IP>:8081` |
| Rider app Metro | `enatega-rider` | 8082 | `http://<HOST_LAN_IP>:8082` |
| Restaurant app Metro | `enatega-store` | 8083 | `http://<HOST_LAN_IP>:8083` |
| Multi-vendor Admin | `enatega-admin` | 3001 (1:1) | http://localhost:3001 |
| Customer Web | `enatega-web` | 3002 (1:1) | http://localhost:3002 |
| Single-vendor Admin | `enatega-sv-admin` | 3003 (1:1) | http://localhost:3003 |
| QR page + APK downloads | `enatega-qr` | 8090 (1:1) | http://localhost:8090 (phones: `http://<HOST_LAN_IP>:8090`) |
| API / DB / Redis | — | — | hosted by Enatega |

The admin apps link to each other through these localhost URLs. Node's `--inspect` (from the upstream `dev`
script) listens on 127.0.0.1 inside the container and isn't published. For Next debugging, use the browser
devtools.

## 7. Android phone

All three mobile apps include `expo-dev-client`, so upstream `expo start` serves them to a
**development build** of the app (Expo's term). The customer app can **only** run that way (see §13). Nothing
below needs Android Studio.

**A. Build the dev-client APK in Docker (once per app, and again when native dependencies change):**

```bash
./scripts/down.sh                     # on a Docker VM with < 12 GB, free memory for Gradle
./scripts/build-android.sh user       # → build-output/enatega-multivendor-app-dev-client.apk
```

This copies the app into a Docker volume, runs `npm ci`, `expo prebuild --platform android` and
`gradlew assembleDebug` for `arm64-v8a`. The upstream folder never gets an `android/` directory. The first
build downloads the SDK/Gradle caches (~20–40 min). Later builds reuse the volumes. For an old 32-bit phone,
set `ANDROID_ARCHS=armeabi-v7a,arm64-v8a`.

**B. Install it:** copy the APK to the phone (USB, Drive, `adb install` if you have platform-tools) and
open it. Allow "install unknown apps" when Android asks.

**C. Develop:**
1. Put the phone on the same Wi-Fi as the computer (not a guest/isolated network).
2. Open a terminal, run `docker attach enatega-customer` and press `c`. Expo prints its QR code for `exp+enategamultivendor://expo-development-client/?url=http%3A%2F%2F<IP>%3A8081`.
3. Scan it with the phone camera, or open the app and enter `http://<HOST_LAN_IP>:8081`.
4. Edit code on the computer and Fast Refresh updates the phone. Shake the phone for the dev menu.

Check the network first: open `http://<HOST_LAN_IP>:8081/status` in the phone's browser. You should see
`packager-status:running`.

**Expo Go instead (rider, restaurant only):** the Play Store version of Expo Go supports only the latest
SDK (57). These apps are SDK 53 / 54. Install the matching Expo Go from https://expo.dev/go (choose SDK 53 for
rider, SDK 54 for restaurant, Android). Then press `s` in the attached Expo terminal (or set `RIDER_EXPO_FLAGS=--go` / `STORE_EXPO_FLAGS=--go` in `.env`),
run `./scripts/restart.sh rider`, and scan the new `exp://…` QR code with Expo Go. In Expo Go, native modules that it
doesn't bundle won't work, e.g. Bluetooth receipt printing in the restaurant app.

## 8. iPhone

Metro, networking and Fast Refresh work the same as on Android: the QR/URL, `http://<HOST_LAN_IP>:808x`.
The blocker is getting an Enatega dev-client **app** onto the iPhone:

- **Expo Go:** the App Store version runs only the latest SDK (57). Apple doesn't allow installing older
  versions. SDK 53/54 projects can't open in it, and the customer app can't run in any Expo Go (§13).
- **Dev-client build:** requires either Xcode on a Mac (`npx expo run:ios --device`) or EAS Build in the cloud
  **plus** a paid Apple Developer account for device provisioning. EAS builds from the upstream config target
  Enatega's Expo account (`owner: 'ninjas_code'`, fixed `projectId`s in `app.config.js`/`app.json`), and
  `eas.json`'s `development` profile builds for the *simulator*. Building under your own account means editing
  those upstream files. This setup doesn't do that.

What works today: once you have an iOS dev-client build from any of those routes, `./scripts/start-*.sh`
serves it exactly like Android. Scan the QR with the iPhone camera.

## 9. Hot reload / file watching

- Source is a bind mount, so edits on the host show up in the container immediately. Verified: an edit to
  a rider file was in Metro's next bundle ~3 s later, and an admin page edit triggered a Next.js recompile.
- macOS (VirtioFS) and Linux deliver file events natively. Windows: keep the repo in the WSL filesystem (§3).
- Metro uses Node's file watcher (the customer app disables Watchman itself, and the image has no Watchman).
- Source maps and the JS debugger work as usual (`j` in `docker attach`, or the dev menu).

## 10. Updating upstream

```bash
cd ../repositories/food-delivery-multivendor
git pull
cd ../../docker-base && ./scripts/restart.sh
```

If a `package-lock.json` changed, that app runs `npm ci` again automatically on restart. Rebuild dev-client
APKs when native dependencies or `app.config.js` plugins change.

## 11. Reset containers / volumes

| Goal | Command |
|---|---|
| Recreate containers (keeps installed deps) | `./scripts/down.sh && ./scripts/up.sh` |
| Reinstall one app's deps | `./scripts/down.sh && docker volume rm enatega_customer_node_modules` |
| Clear Metro cache | set `CUSTOMER_EXPO_FLAGS=--clear` in `.env`, `./scripts/restart.sh user`, then empty it again |
| Wipe everything (deps, .next, gradle/SDK caches) | `./scripts/down.sh --volumes` |
| Remove images | `docker image rm enatega-dev-node:20.19.5 enatega-android-builder:1` |

## 12. Troubleshooting

| Symptom | Fix |
|---|---|
| Phone: "Could not connect to development server" / timeout | Same Wi-Fi? Check `http://<IP>:8081/status` in the phone browser. Check the firewall (§3). Is `HOST_LAN_IP` right? (`./scripts/doctor.sh`). Turn off client isolation / VPN. |
| QR code won't scan / looks distorted | Docker Desktop's **Logs** tab adds line spacing that tears Expo's half-block terminal QR (`qrcode-terminal` `small: true`) into strips. Fixed on Expo's side only in SDK 55+ (Enatega is 53/54). **Use the QR page: http://localhost:8090**. It renders real QR images whose links are identical to Expo's. Other options: `docker attach enatega-<app>` in a real terminal and press `c`, or **Enter URL manually** in the app. |
| Expo Go closes / nothing happens after scanning | Expected. Upstream depends on `expo-dev-client`, so `expo start` targets the development build and the QR is an `exp+<slug>://` link that only the **Enatega dev-client app** opens. Install the APK (§7), then scan with the phone camera or the dev-client app. The customer app never runs in Expo Go (§13). |
| `Color conflicts with the splash.backgroundColor`, `Unknown option "useWatchman"` | Harmless upstream config warnings (`app.config.js`, `metro.config.js`). Left alone because the source isn't changed. |
| QR code has the wrong IP | Set `HOST_LAN_IP` in `.env`, then `./scripts/restart.sh`. |
| Container keeps restarting, `Killed` in logs | Docker VM ran out of memory (§3). Raise the memory limit or run fewer apps. |
| `health: starting` for a long time | First `npm ci`. Watch `./scripts/logs.sh <app>`. |
| `HOST_LAN_IP not set` from a raw `docker compose` command | Use the scripts, or put the IP in `.env`. |
| Port already allocated | Change the `*_PORT` in `.env`. `doctor` shows which one is taken. |
| Edits don't reload (Windows) | Repo on `C:\` → move it into WSL. |
| `permission denied` on files in the repo (Linux) | Check `HOST_UID`/`HOST_GID` (they default to your user). |
| `Unable to resolve module` after `git pull` | `./scripts/restart.sh <app>` (reinstalls if the lockfile changed), then clear the Metro cache. |

## 13. Known limitations (upstream)

These come from the upstream code, not from Docker:

1. **No backend source.** The API is proprietary, so the apps use Enatega's hosted API. Data, logins and
   uptime are theirs.
2. **Customer app can't run in Expo Go.** `App.js` imports `src/utils/liveActivityService.js`, which imports
   `@react-native-firebase/messaging` at startup. Expo Go doesn't include that native module, so the app fails
   when it launches. It also uses other native modules Expo Go lacks (Clarity, Google Sign-In,
   activity-controller). Only a dev-client build works (§7).
3. **Old Expo SDKs vs. store Expo Go.** SDK 53 (customer, rider) and 54 (restaurant) vs. Expo Go's SDK 57.
   On Android, sideload the matching Expo Go. On iPhone, you can't.
4. **iPhone dev client needs Xcode or EAS + an Apple account**, and EAS config is bound to Enatega's Expo
   account (§8).
5. **Customer & restaurant API URLs are hardcoded** (`environment.config.js`, `environment.ts`) with no env
   override for the multi-vendor API. Pointing them at another backend requires a source change. The rider
   app and all web apps are configurable.
6. **`.nvmrc` (20.16.0) is below the store app's minimum (20.19.4)**, so 20.19.5 is used everywhere.
7. Upstream READMEs mention `.env.example` files that aren't in the repo. This setup passes the variables
   from `docker-base/.env` instead.
