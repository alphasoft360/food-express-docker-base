// Enatega QR page: one browser page with a scannable QR code per Expo app.
// Terminal QR codes (Expo's half-block output) break in Docker Desktop's Logs
// tab; a browser renders a real image instead.
//
// Links are built exactly the way Expo builds them:
//   dev build: <scheme>://expo-development-client/?url=<encoded http://HOST:PORT>
//              (@expo/cli start/server/UrlCreator.js, constructDevClientUrl)
//   scheme:    expo-dev-client/plugin/build/getDefaultScheme.js (see devClientScheme)
//   Expo Go:   exp://HOST:PORT
// The slug is read live from each running Metro manifest, so upstream renames
// are picked up without changing this file.
const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const QRCode = require("qrcode");

const HOST = process.env.HOST_LAN_IP;
const PORT = Number(process.env.PORT);
const APK_DIR = "/apks";

const APPS = [
  { name: "Customer app", service: "customer", port: process.env.CUSTOMER_METRO_PORT, apk: "enatega-multivendor-app-dev-client.apk", buildArg: "user" },
  { name: "Rider app", service: "rider", port: process.env.RIDER_METRO_PORT, apk: "enatega-multivendor-rider-dev-client.apk", buildArg: "rider" },
  { name: "Restaurant app", service: "store", port: process.env.STORE_METRO_PORT, apk: "enatega-multivendor-store-dev-client.apk", buildArg: "restaurant" },
];

// Same rules as expo-dev-client's getDefaultScheme(): keep [A-Za-z0-9+-.], lowercase, prefix exp+.
function devClientScheme(slug) {
  return `exp+${slug.replace(/[^A-Za-z0-9+\-.]/g, "").toLowerCase()}`;
}

// Ask the app's own Metro server for its manifest (docker network name, not the LAN IP).
async function readSlug(app) {
  const res = await fetch(`http://${app.service}:${app.port}/`, {
    headers: { "expo-platform": "android", accept: "application/expo+json,application/json" },
    signal: AbortSignal.timeout(15000),
  });
  if (!res.ok) throw new Error(`Metro answered HTTP ${res.status}`);
  return (await res.json()).extra.expoClient.slug;
}

const qr = (text) => QRCode.toString(text, { type: "svg", margin: 4, errorCorrectionLevel: "M" });
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

async function card(title, hint, link) {
  return `<figure><figcaption><b>${esc(title)}</b><small>${esc(hint)}</small></figcaption>${await qr(link)}<code>${esc(link)}</code></figure>`;
}

async function appSection(app) {
  const server = `http://${HOST}:${app.port}`;
  let slug;
  try {
    slug = await readSlug(app);
  } catch (e) {
    return `<section><h2>${esc(app.name)}</h2><p class="warn">Metro is not reachable (${esc(e.message)}). Start it: <code>./scripts/start.sh ${esc(app.buildArg)}</code></p></section>`;
  }
  const hasApk = fs.existsSync(path.join(APK_DIR, app.apk));
  const cards = [
    await card("Development build", `Scan with the phone camera. Opens the installed ${app.name} (APK).`,
      `${devClientScheme(slug)}://expo-development-client/?url=${encodeURIComponent(server)}`),
    hasApk
      ? await card("Install the app (APK)", "Scan, download, allow 'install unknown apps'.", `http://${HOST}:${PORT}/apk/${app.apk}`)
      : `<figure><figcaption><b>Install the app (APK)</b><small>Not built yet: <code>./scripts/build-android.sh ${esc(app.buildArg)}</code></small></figcaption></figure>`,
    await card("Expo Go", "Only if the app supports Expo Go and the SDK matches.", `exp://${HOST}:${app.port}`),
  ];
  return `<section><h2>${esc(app.name)} <small>slug ${esc(slug)} · manual URL <code>${esc(server)}</code></small></h2><div class="row">${cards.join("")}</div></section>`;
}

async function page() {
  const sections = await Promise.all(APPS.map(appSection));
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Enatega QR codes</title><style>
body{margin:0;padding:24px;font-family:system-ui,sans-serif;background:#f4f4f5;color:#18181b}
h1{margin:0 0 4px}h2{margin:32px 0 12px}h2 small,figcaption small{display:block;font-weight:400;color:#52525b;font-size:13px;margin-top:4px}
.row{display:flex;flex-wrap:wrap;gap:16px}figure{margin:0;background:#fff;border:1px solid #e4e4e7;border-radius:12px;padding:16px;width:260px}
figure svg{width:228px;height:228px;display:block;margin:12px auto}code{font-size:11px;word-break:break-all}.warn{color:#b45309}
</style></head><body><h1>Enatega QR codes</h1>
<p>Phone on the same Wi-Fi as this computer (<code>${esc(HOST)}</code>). Reload this page after restarting an app.</p>
${sections.join("")}</body></html>`;
}

function sendApk(res, name) {
  // Only plain *.apk file names from the read-only build-output mount.
  if (!/^[\w.-]+\.apk$/.test(name)) return res.writeHead(404).end();
  const file = path.join(APK_DIR, name);
  fs.stat(file, (err, st) => {
    if (err || !st.isFile()) return res.writeHead(404).end("APK not found");
    res.writeHead(200, {
      "content-type": "application/vnd.android.package-archive",
      "content-length": st.size,
      "content-disposition": `attachment; filename="${name}"`,
    });
    fs.createReadStream(file).pipe(res);
  });
}

http
  .createServer(async (req, res) => {
    const url = new URL(req.url, "http://x");
    if (url.pathname.startsWith("/apk/")) return sendApk(res, decodeURIComponent(url.pathname.slice(5)));
    if (url.pathname !== "/") return res.writeHead(404).end();
    try {
      res.writeHead(200, { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" }).end(await page());
    } catch (e) {
      res.writeHead(500, { "content-type": "text/plain" }).end(`QR page error: ${e.message}`);
    }
  })
  .listen(PORT, () => console.log(`Enatega QR page: http://localhost:${PORT}  (phones: http://${HOST}:${PORT})`));
