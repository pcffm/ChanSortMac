# Third-party software notices

This document identifies third-party software included in, linked by, or used to build the distributed ChanSort Mac application. The inventory is based on the resolved `ChanSort.Backend.deps.json` for version 0.4.0. Inclusion here does not change the GPL-3.0-only licence of ChanSort Mac as a whole. Each component remains available under its stated licence.

A machine-readable SPDX 2.3 inventory is provided as `SBOM.spdx.json`.

## Original ChanSort loader components

| Component | Version/origin | Copyright / author | Licence | Source |
|---|---|---|---|---|
| ChanSort API and device loaders | ChanSort 2025-03-08 | Horst Beham and ChanSort contributors | GPL-3.0-only | https://github.com/PredatH0r/ChanSort |

The corresponding imported source is included under `Backend/Upstream`. The upstream README is preserved as `Backend/Upstream/CHANSORT-README.md`.

## Bundled .NET runtime

| Component | Resolved version | Copyright / author | Licence | Source |
|---|---:|---|---|---|
| Microsoft.NETCore.App Runtime for macOS arm64 | 8.0.29 | .NET Foundation, Microsoft and contributors | MIT plus third-party terms | https://github.com/dotnet/runtime |

The application is self-contained and bundles runtime files. The exact runtime licence and the runtime's comprehensive transitive notices are distributed verbatim in:

- `THIRD_PARTY/dotnet-runtime-8.0.29/LICENSE.TXT`
- `THIRD_PARTY/dotnet-runtime-8.0.29/THIRD-PARTY-NOTICES.TXT`

Those runtime notices cover third-party material incorporated into the .NET runtime and are an integral part of this distribution.

## Resolved NuGet runtime dependencies

| Package | Resolved version | Copyright / author | Licence | Project/source |
|---|---:|---|---|---|
| Microsoft.Data.Sqlite | 8.0.13 | © Microsoft Corporation | MIT | https://github.com/dotnet/efcore |
| Microsoft.Data.Sqlite.Core | 8.0.13 | © Microsoft Corporation | MIT | https://github.com/dotnet/efcore |
| Newtonsoft.Json | 13.0.3 | Copyright © James Newton-King 2008 | MIT | https://github.com/JamesNK/Newtonsoft.Json |
| SQLitePCLRaw.bundle_e_sqlite3 | 2.1.6 | Copyright 2014–2023 SourceGear, LLC | Apache-2.0 | https://github.com/ericsink/SQLitePCL.raw |
| SQLitePCLRaw.core | 2.1.6 | Copyright 2014–2023 SourceGear, LLC | Apache-2.0 | https://github.com/ericsink/SQLitePCL.raw |
| SQLitePCLRaw.lib.e_sqlite3 | 2.1.6 | Copyright 2014–2023 SourceGear, LLC | Apache-2.0 | https://github.com/ericsink/SQLitePCL.raw |
| SQLitePCLRaw.provider.e_sqlite3 | 2.1.6 | Copyright 2014–2023 SourceGear, LLC | Apache-2.0 | https://github.com/ericsink/SQLitePCL.raw |
| System.Memory | 4.5.3 | © Microsoft Corporation and contributors | MIT plus third-party terms | https://github.com/dotnet/runtime |

Licence texts and component-specific notices are distributed in:

- `LICENSES/MIT.txt`
- `LICENSES/Apache-2.0.txt`
- `THIRD_PARTY/Newtonsoft.Json-13.0.3/LICENSE.md`
- `THIRD_PARTY/System.Memory-4.5.3/LICENSE.TXT`
- `THIRD_PARTY/System.Memory-4.5.3/THIRD-PARTY-NOTICES.TXT`

The native SQLite engine included through `SQLitePCLRaw.lib.e_sqlite3` is supplied as part of that package. SQLite itself is dedicated to the public domain by its authors; see https://www.sqlite.org/copyright.html. SQLite and SQLitePCLRaw are distinct works with distinct licensing statements.

## Apple system components and build tools

The Swift language, Swift standard libraries supplied by the operating system, SwiftUI, AppKit, Foundation, Xcode and macOS are Apple technologies. They are system libraries or development tools and are not relicensed by this project. No Apple SDK or Xcode component is included in the Corresponding Source archive. Use of these names is descriptive; see `TRADEMARKS.md`.

## Build-only tools

The .NET SDK, Swift compiler, Xcode command-line tools and standard macOS command-line utilities are used to build or package the software but are not redistributed in the source archive. The self-contained application does redistribute the .NET runtime listed above.

## Licence text locations

- ChanSort Mac and upstream ChanSort loader code: `LICENSE` (GNU GPL version 3)
- MIT-licensed dependencies: `LICENSES/MIT.txt` and component-specific copies where supplied
- Apache-2.0 SQLitePCLRaw packages: `LICENSES/Apache-2.0.txt`
- .NET transitive notices: `THIRD_PARTY/dotnet-runtime-8.0.29/THIRD-PARTY-NOTICES.TXT`

If a packaged dependency changes, regenerate the release, inspect the resolved `.deps.json`, update this inventory, and include the licence/notice files from the exact package version before distribution.
