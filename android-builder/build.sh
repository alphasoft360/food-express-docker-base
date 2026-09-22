#!/bin/sh
# build-apk <app-dir>  -> /output/<app-dir>-dev-client.apk
# Copies the app out of the (read-only) repo mount so `expo prebuild` never
# writes android/ into the upstream source tree.
set -eu
app="$1"
src="/workspace/$app"
dst="/build/$app"
[ -f "$src/package.json" ] || { echo "no such app: $app"; exit 1; }

echo "[android] syncing $app source -> build volume"
mkdir -p "$dst"
rsync -a --delete --exclude node_modules --exclude android --exclude ios --exclude .expo --exclude .git "$src/" "$dst/"

cd "$dst"
want="$(sha256sum package-lock.json | cut -d' ' -f1)"
if [ "$(cat node_modules/.enatega-lock.sha256 2>/dev/null)" != "$want" ]; then
  echo "[android] npm ci"
  npm ci
  echo "$want" > node_modules/.enatega-lock.sha256
fi

echo "[android] expo prebuild (android)"
CI=1 npx expo prebuild --platform android --clean --no-install

# Gradle-user-home properties override the project's gradle.properties: cap the
# daemon heap and compile Kotlin in-process so the build fits a small Docker VM.
cat > /root/.gradle/gradle.properties <<PROPS
org.gradle.jvmargs=${GRADLE_JVMARGS:--Xmx3g -XX:MaxMetaspaceSize=1g}
org.gradle.workers.max=${GRADLE_WORKERS:-2}
kotlin.compiler.execution.strategy=in-process
PROPS

echo "[android] gradle assembleDebug (archs: $ANDROID_ARCHS)"
cd android
./gradlew --no-daemon assembleDebug -PreactNativeArchitectures="$ANDROID_ARCHS" --console=plain

out="/output/$app-dev-client.apk"
cp app/build/outputs/apk/debug/app-debug.apk "$out"
chown "${HOST_UID:-1000}:${HOST_GID:-1000}" "$out" 2>/dev/null || true
echo "[android] done -> docker-base/build-output/$app-dev-client.apk"
