#!/bin/zsh
# Copyright (C) 2026 Thomas Meroth, Meroth IT-Service
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

project_dir="${0:A:h:h}"
version="$(tr -d '[:space:]' < "$project_dir/VERSION")"
output="${1:-$project_dir/dist/ChanSort-Mac-$version-Source.zip}"
staging_dir="$(mktemp -d /private/tmp/ChanSortMac-source.XXXXXX)"
source_dir="$staging_dir/ChanSort-Mac-$version-Source"
trap 'rm -rf "$staging_dir"' EXIT

mkdir -p "${output:h}" "$source_dir"
rsync -a \
  --exclude '.DS_Store' \
  --exclude '.git/' \
  --exclude '.build/' \
  --exclude 'dist/' \
  --exclude 'Backend/bin/' \
  --exclude 'Backend/obj/' \
  --exclude 'Backend/Projects/bin/' \
  --exclude 'Backend/Projects/obj/' \
  --exclude 'Backend/.dotnet-home/' \
  --exclude 'Backend/.nuget/' \
  --exclude 'Backend/local-packages/' \
  "$project_dir/" "$source_dir/"

ditto -c -k --keepParent "$source_dir" "$output"
