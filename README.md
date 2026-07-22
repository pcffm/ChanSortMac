# ChanSort Mac

An unofficial, native macOS port of the GPLv3 channel-list editor [ChanSort](https://github.com/PredatH0r/ChanSort).

**Publisher and maintainer:** Thomas Meroth, Meroth IT-Service — https://www.pcffm.de  
**Original ChanSort:** Horst Beham (`PredatH0r`) and contributors  
**Licence:** GNU General Public License version 3 only (`GPL-3.0-only`)  
**Languages:** English base UI; automatic German localization  
**German documentation:** [README.de.md](README.de.md)

ChanSort Mac is independent and is not an official release of the upstream author or any device manufacturer. Manufacturer names are used only to identify compatible export formats. See [TRADEMARKS.md](TRADEMARKS.md).

## Features

- Open, search, rename, renumber and save television channel lists.
- Stable native macOS table with persistent headers, resizable/reorderable columns and multi-selection.
- One-list and two-list sorting modes, drag and drop, direct target positions, swap and alphabetical sorting.
- TV, radio, data and favourite lists, with device-specific options shown only when supported.
- Delete/restore, favourites A–H, lock, skip and hide where the format supports them.
- Undo/redo and an automatic backup before overwriting the original export.
- English default localization and automatic German localization.
- Native SwiftUI interface without Wine, a VM, DevExpress or the original Windows Forms UI.
- In-app About & Legal centre with copyright, source, GPL, no-warranty, library and trademark notices.

Native text formats include M3U/M3U8, Enigma2 bouquets, VDR `channels.conf`, CSV and TSV. A bundled headless .NET backend compiles the 25 platform-neutral loaders from ChanSort 2025-03-08 and therefore recognizes the same broad family of Samsung, LG, Philips, Sony, Panasonic, Hisense, Toshiba, TCL, Grundig, TechniSat, Sharp, Loewe, Medion, Android, AMDB, CMDB, DBM and related exports supported by that upstream release.

“Supported” means recognized by the included loader snapshot; it does not promise compatibility with every model, firmware or future encrypted format. Always retain the original television export.

## Build

Requirements:

- macOS 13 or newer
- Xcode / Apple Command Line Tools with Swift 5.9 or newer
- .NET SDK 8

Build the app, matching source archive and checksums:

```bash
./build-app.sh
```

Outputs are written to `dist/`:

```text
ChanSort-Mac-<version>-arm64.zip
ChanSort-Mac-<version>-Source.zip
SHA256SUMS.txt
```

Run tests and the legal/package audit:

```bash
swift test --disable-sandbox
./scripts/check-compliance.sh
./scripts/audit-release.sh
```

The default local build is ad-hoc signed and is not notarized. A production publisher can set `CODESIGN_IDENTITY` to a Developer ID Application identity and notarize the resulting archive. Signing does not change the GPL rights of recipients.

## Licence, source and redistribution

The combined work is distributed under GNU GPL version 3 only. The full licence is in [LICENSE](LICENSE). Copyright and provenance are recorded in [COPYRIGHT.md](COPYRIGHT.md), [AUTHORS.md](AUTHORS.md), [NOTICE.md](NOTICE.md) and [UPSTREAM.md](UPSTREAM.md).

Every binary release must be offered with the exact matching Corresponding Source at the same download location and at no additional charge. See [SOURCE-CODE.md](SOURCE-CODE.md) and [RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md).

Third-party dependencies and their exact resolved versions are documented in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md); required licence and notice texts are included in `LICENSES/` and `THIRD_PARTY/` and are copied into the application bundle.

There is no warranty, to the extent permitted by applicable law. The GPL permits commercial distribution and paid support, but recipients retain the GPL freedoms to inspect, modify and redistribute the software.

## Privacy and security

The application processes channel-list files locally. This release contains no analytics, advertising, account system or telemetry implemented by ChanSort Mac. See [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md) for details.
