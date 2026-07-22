#!/bin/zsh
# Copyright (C) 2026 Thomas Meroth, Meroth IT-Service
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

project_dir="${0:A:h}"
version="$(tr -d '[:space:]' < "$project_dir/VERSION")"
build_number="${BUILD_NUMBER:-4}"
architecture="${ARCHITECTURE:-arm64}"
runtime_id="osx-$architecture"
build_dir="$project_dir/.build"
dist_dir="$project_dir/dist"
staging_dir="$(mktemp -d /private/tmp/ChanSortMac-build.XXXXXX)"
app_dir="$staging_dir/ChanSort Mac.app"
package_name="ChanSort-Mac-$version-$architecture.zip"
package_file="$dist_dir/$package_name"
staging_package="$staging_dir/$package_name"
source_package="$dist_dir/ChanSort-Mac-$version-Source.zip"
backend_dir="$project_dir/Backend"
backend_publish="$backend_dir/bin/publish/$runtime_id"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
codesign_identity="${CODESIGN_IDENTITY:--}"
entitlements="$project_dir/Resources/ChanSortMac.entitlements"
trap 'rm -rf "$staging_dir"' EXIT

export DEVELOPER_DIR="$developer_dir"
export CLANG_MODULE_CACHE_PATH="$build_dir/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$build_dir/swiftpm-cache"
swiftpm_cache="$build_dir/swiftpm-cache"
swiftpm_config="$build_dir/swiftpm-config"
swiftpm_security="$build_dir/swiftpm-security"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$swiftpm_cache" "$swiftpm_config" "$swiftpm_security"
swiftpm_paths=(--cache-path "$swiftpm_cache" --config-path "$swiftpm_config" --security-path "$swiftpm_security")

cd "$project_dir"
"$project_dir/scripts/check-compliance.sh"

dotnet_bin="${DOTNET_BIN:-$project_dir/../dotnet-sdk/dotnet}"
if [[ ! -x "$dotnet_bin" ]]; then
  dotnet_bin="$(command -v dotnet || true)"
fi
if [[ -z "$dotnet_bin" || ! -x "$dotnet_bin" ]]; then
  print -u2 "The backend build requires .NET SDK 8 (set DOTNET_BIN or install dotnet)."
  exit 1
fi

publish_args=(publish "$backend_dir/ChanSort.Backend.csproj" -c Release -r "$runtime_id" --self-contained true -p:PublishSingleFile=false -o "$backend_publish")
if [[ -f "$backend_dir/local-packages/microsoft.netcore.app.runtime.$runtime_id.8.0.29.nupkg" ]]; then
  publish_args+=(--source "$backend_dir/local-packages")
fi
DOTNET_CLI_HOME="$backend_dir/.dotnet-home" \
NUGET_PACKAGES="$backend_dir/.nuget" \
DOTNET_CLI_TELEMETRY_OPTOUT=1 \
  "$dotnet_bin" "${publish_args[@]}"
xattr -cr "$backend_publish"

swift test -c release --disable-sandbox "${swiftpm_paths[@]}"
swift build -c release --disable-sandbox "${swiftpm_paths[@]}"

binary_dir="$(swift build -c release --show-bin-path --disable-sandbox "${swiftpm_paths[@]}")"
binary="$binary_dir/ChanSortMac"
mkdir -p "$dist_dir" "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources/Backend"
cp "$binary" "$app_dir/Contents/MacOS/ChanSortMac"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleGetInfoString ChanSort Mac $version — GPLv3 — Meroth IT-Service" "$app_dir/Contents/Info.plist"
cp -R "$binary_dir/ChanSortMac_ChanSortMac.bundle" "$app_dir/Contents/Resources/ChanSortMac_ChanSortMac.bundle"
cp -R "$backend_publish/." "$app_dir/Contents/Resources/Backend/"

legal_files=(
  LICENSE AUTHORS.md COPYRIGHT.md NOTICE.md SOURCE-CODE.md
  THIRD-PARTY-NOTICES.md TRADEMARKS.md UPSTREAM.md PRIVACY.md SBOM.spdx.json
)
for legal_file in "${legal_files[@]}"; do
  cp "$project_dir/$legal_file" "$app_dir/Contents/Resources/$legal_file"
done
cp -R "$project_dir/LICENSES" "$app_dir/Contents/Resources/LICENSES"
cp -R "$project_dir/THIRD_PARTY" "$app_dir/Contents/Resources/THIRD_PARTY"
cp "$project_dir/Backend/Upstream/CHANSORT-README.md" "$app_dir/Contents/Resources/CHANSORT-README.md"
cp "$project_dir/Resources/AppIcon.png" "$app_dir/Contents/Resources/AppIcon.png"

xattr -cr "$app_dir"
sign_args=(--force --sign "$codesign_identity")
if [[ "$codesign_identity" != "-" ]]; then
  sign_args+=(--options runtime --timestamp)
fi

# Sign embedded Mach-O files from the inside out, then the app executable and bundle.
while IFS= read -r -d '' nested_file; do
  if file -b "$nested_file" | grep -q 'Mach-O'; then
    if [[ "${nested_file:t}" == "ChanSort.Backend" ]]; then
      codesign "${sign_args[@]}" --entitlements "$entitlements" "$nested_file"
    else
      codesign "${sign_args[@]}" "$nested_file"
    fi
  fi
done < <(find "$app_dir/Contents/Resources/Backend" -type f -print0)
codesign "${sign_args[@]}" "$app_dir/Contents/MacOS/ChanSortMac"
codesign "${sign_args[@]}" "$app_dir"
codesign --verify --deep --strict --verbose=2 "$app_dir"

ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$staging_package"
cp "$staging_package" "$package_file"
"$project_dir/scripts/package-source.sh" "$source_package"

(
  cd "$dist_dir"
  shasum -a 256 "$package_name" "ChanSort-Mac-$version-Source.zip" > SHA256SUMS.txt
)
"$project_dir/scripts/audit-release.sh" "$package_file" "$source_package"

print "Application: $package_file"
print "Source:      $source_package"
print "Checksums:   $dist_dir/SHA256SUMS.txt"
if [[ "$codesign_identity" == "-" ]]; then
  print "Signature:   ad-hoc (set CODESIGN_IDENTITY for a production Developer ID build)"
else
  print "Signature:   $codesign_identity (notarization remains a separate release step)"
fi
