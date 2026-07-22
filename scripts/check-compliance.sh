#!/bin/zsh
# Copyright (C) 2026 Thomas Meroth, Meroth IT-Service
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

project_dir="${0:A:h:h}"
version="$(tr -d '[:space:]' < "$project_dir/VERSION")"
failures=0

fail() {
  print -u2 "COMPLIANCE ERROR: $1"
  failures=$((failures + 1))
}

required_files=(
  LICENSE AUTHORS.md COPYRIGHT.md NOTICE.md SOURCE-CODE.md
  THIRD-PARTY-NOTICES.md TRADEMARKS.md UPSTREAM.md
  RELEASE-CHECKLIST.md CONTRIBUTING.md SECURITY.md PRIVACY.md REUSE.toml CITATION.cff SBOM.spdx.json
  LICENSES/MIT.txt LICENSES/Apache-2.0.txt
  THIRD_PARTY/dotnet-runtime-8.0.29/LICENSE.TXT
  THIRD_PARTY/dotnet-runtime-8.0.29/THIRD-PARTY-NOTICES.TXT
  THIRD_PARTY/Newtonsoft.Json-13.0.3/LICENSE.md
  THIRD_PARTY/System.Memory-4.5.3/LICENSE.TXT
  THIRD_PARTY/System.Memory-4.5.3/THIRD-PARTY-NOTICES.TXT
)
for required_file in "${required_files[@]}"; do
  [[ -s "$project_dir/$required_file" ]] || fail "missing $required_file"
done

grep -q '<string>de.pcffm.chansortmac</string>' "$project_dir/Resources/Info.plist" || fail "publisher bundle identifier is missing"
grep -q "<string>$version</string>" "$project_dir/Resources/Info.plist" || fail "Info.plist version does not match VERSION"
grep -q 'Thomas Meroth' "$project_dir/NOTICE.md" || fail "publisher copyright notice is missing"
grep -q 'Horst Beham' "$project_dir/NOTICE.md" || fail "upstream author notice is missing"
grep -q 'GPL-3.0-only' "$project_dir/README.md" || fail "README licence declaration is missing"
grep -q 'no warranty' "$project_dir/NOTICE.md" || fail "no-warranty notice is missing"
grep -q '"spdxVersion": "SPDX-2.3"' "$project_dir/SBOM.spdx.json" || fail "SBOM SPDX version is missing"
grep -q "\"versionInfo\": \"$version\"" "$project_dir/SBOM.spdx.json" || fail "SBOM has the wrong project version"

while IFS= read -r source_file; do
  grep -q 'SPDX-License-Identifier: GPL-3.0-only' "$source_file" || fail "SPDX header missing: ${source_file#$project_dir/}"
done < <(find "$project_dir/Sources" "$project_dir/Tests" "$project_dir/Tools" -type f -name '*.swift' -print)
grep -q 'SPDX-License-Identifier: GPL-3.0-only' "$project_dir/Backend/Program.cs" || fail "SPDX header missing: Backend/Program.cs"

for dependency in 'Microsoft.Data.Sqlite.*8.0.13' 'Newtonsoft.Json.*13.0.3' 'SQLitePCLRaw.*2.1.6' 'System.Memory.*4.5.3' 'Microsoft.NETCore.App Runtime.*8.0.29'; do
  grep -Eq "$dependency" "$project_dir/THIRD-PARTY-NOTICES.md" || fail "dependency inventory incomplete: $dependency"
done

if find "$project_dir" -path "$project_dir/Backend/Upstream" -prune -o -type f -iname '*DevExpress*.dll' -print | grep -q .; then
  fail "a DevExpress binary is present"
fi

if (( failures > 0 )); then
  print -u2 "$failures compliance check(s) failed."
  exit 1
fi

print "Compliance checks passed for ChanSort Mac $version."
