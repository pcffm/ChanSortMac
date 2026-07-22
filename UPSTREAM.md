# Upstream provenance and modifications

- Upstream project: ChanSort
- Upstream author/maintainer: Horst Beham (`PredatH0r`)
- Upstream repository: https://github.com/PredatH0r/ChanSort
- Imported release: `ChanSort 2025-03-08`
- Imported code location: `Backend/Upstream`
- Upstream licence: GNU GPL version 3

## Fork modifications

The fork adds a native SwiftUI macOS application and a headless .NET 8 adapter around the original format loaders. Build-only project files under `Backend/Projects` compile the vendored loader source on macOS. UI-specific Windows/DevExpress files are not compiled or distributed as components of the macOS application.

The upstream source snapshot is retained in a dedicated directory to preserve provenance. Changes required for headless/macOS operation should be documented here when they directly modify a file under `Backend/Upstream`. New integration code belongs outside that directory whenever practical.

Initial macOS fork modifications: 2026, Thomas Meroth / Meroth IT-Service.

