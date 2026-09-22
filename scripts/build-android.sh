#!/usr/bin/env bash
# Build an Android dev-client APK in Docker (no Android Studio).
# Usage: build-android.sh <user|rider|restaurant>  -> docker-base/build-output/*.apk
source "$(dirname "$0")/lib.sh"
case "$(svc "${1:-}")" in
  customer) app=enatega-multivendor-app;; rider) app=enatega-multivendor-rider;; store) app=enatega-multivendor-store;;
  *) echo "only mobile apps: user rider restaurant"; exit 2;;
esac
compose --profile android build android-builder
compose --profile android run --rm android-builder "$app"
