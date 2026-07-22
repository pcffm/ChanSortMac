#!/bin/zsh
# Copyright (C) 2026 Thomas Meroth, Meroth IT-Service
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

project_dir="${0:A:h:h}"
version="$(tr -d '[:space:]' < "$project_dir/VERSION")"
app_archive="${1:-$project_dir/dist/ChanSort-Mac-$version-arm64.zip}"
source_archive="${2:-$project_dir/dist/ChanSort-Mac-$version-Source.zip}"
audit_dir="$(mktemp -d /private/tmp/ChanSortMac-audit.XXXXXX)"
trap 'rm -rf "$audit_dir"' EXIT

fail() {
  print -u2 "RELEASE AUDIT ERROR: $1"
  exit 1
}

[[ -s "$app_archive" ]] || fail "application archive is missing"
[[ -s "$source_archive" ]] || fail "source archive is missing"
unzip -q "$app_archive" -d "$audit_dir/app"
unzip -q "$source_archive" -d "$audit_dir/source"

app="$audit_dir/app/ChanSort Mac.app"
source_root="$audit_dir/source/ChanSort-Mac-$version-Source"
[[ -d "$app" ]] || fail "application bundle is missing from its archive"
[[ -d "$source_root" ]] || fail "source archive has the wrong root directory"
codesign --verify --deep --strict "$app" || fail "code signature validation failed"

bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
bundle_identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")"
[[ "$bundle_version" == "$version" ]] || fail "bundle and source versions differ"
[[ "$bundle_identifier" == "de.pcffm.chansortmac" ]] || fail "unexpected bundle identifier"

for legal_file in LICENSE AUTHORS.md COPYRIGHT.md NOTICE.md PRIVACY.md SOURCE-CODE.md THIRD-PARTY-NOTICES.md TRADEMARKS.md UPSTREAM.md SBOM.spdx.json; do
  [[ -s "$app/Contents/Resources/$legal_file" ]] || fail "app is missing $legal_file"
  [[ -s "$source_root/$legal_file" ]] || fail "source is missing $legal_file"
done

plugin_count="$("$app/Contents/Resources/Backend/ChanSort.Backend" plugins | grep -o '"pluginName"' | wc -l | tr -d '[:space:]')"
[[ "$plugin_count" == "25" ]] || fail "expected 25 device loaders, found $plugin_count"

if find "$source_root" -type d \( -name .build -o -name bin -o -name obj -o -name .nuget -o -name local-packages \) -print | grep -q .; then
  fail "source archive contains generated build or package-cache directories"
fi

(
  cd "${app_archive:h}"
  shasum -a 256 -c SHA256SUMS.txt >/dev/null
) || fail "release checksum validation failed"

print "Release audit passed for ChanSort Mac $version ($plugin_count device loaders)."

