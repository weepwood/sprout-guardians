#!/usr/bin/env bash
# Pin the official engine and templates to verified release asset digests.
set -euo pipefail
version=4.7.1
release=stable
case "${1:-}" in
  editor)
    platform=linux.64
    asset=linux.x86_64.zip
    digest=c7ff14fd28472c8d4f193043de30278dcf7e5241a1dcf7566b02e27addaa33ba
    ;;
  templates)
    platform=templates
    asset=export_templates.tpz
    digest=86409db6200b6f8fd3230989c2d2002851f3dd18acf11d7bdbafddf5a0dd0f72
    ;;
  *) echo "Usage: $0 editor|templates OUTPUT" >&2; exit 2 ;;
esac
out="${2:?Output path required}"
if [[ "${GODOT_VERSION:-$version}" != "$version" || "${GODOT_RELEASE:-$release}" != "$release" ]]; then
  echo 'Engine version differs from pinned release digests' >&2
  exit 2
fi
cache_dir="${GODOT_ASSET_CACHE:-}"
cache_file=""
if [[ -n "$cache_dir" ]]; then
  mkdir -p "$cache_dir"
  cache_file="$cache_dir/$digest-$asset"
  if [[ -f "$cache_file" ]] && printf '%s  %s\n' "$digest" "$cache_file" | sha256sum -c -; then
    cp "$cache_file" "$out"
    echo "Using verified cached $asset"
    exit 0
  fi
fi
primary="https://github.com/godotengine/godot-builds/releases/download/$version-$release/Godot_v${version}-${release}_$asset"
fallback="https://downloads.godotengine.org/?flavor=$release&platform=$platform&slug=$asset&version=$version"
tmp="$(mktemp "$out.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
for url in "$primary" "$fallback"; do
  echo "Downloading verified $asset from $url"
  if curl --fail --location --retry 2 --retry-all-errors --connect-timeout 20 --max-time 300 --silent --show-error "$url" -o "$tmp"; then
    if printf '%s  %s\n' "$digest" "$tmp" | sha256sum -c -; then
      mv -f "$tmp" "$out"
      if [[ -n "$cache_file" ]]; then
        cp "$out" "$cache_file.tmp"
        mv -f "$cache_file.tmp" "$cache_file"
      fi
      exit 0
    fi
    echo 'Downloaded asset failed SHA256 verification' >&2
  fi
done
echo "No verified Godot asset available: $asset" >&2
exit 1
