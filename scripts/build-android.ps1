# Build an Android dev-client APK in Docker. Usage: .\scripts\build-android.ps1 <user|rider|restaurant>
. "$PSScriptRoot\lib.ps1"
$app = @{ customer = 'enatega-multivendor-app'; rider = 'enatega-multivendor-rider'; store = 'enatega-multivendor-store' }[(Svc $args[0])]
if (-not $app) { throw 'only mobile apps: user rider restaurant' }
Compose --profile android build android-builder
Compose --profile android run --rm android-builder $app
