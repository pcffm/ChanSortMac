# GPLv3 release checklist

- [ ] `VERSION`, `Info.plist`, changelog and archive names identify the same version.
- [ ] All tests pass and `./scripts/check-compliance.sh` succeeds.
- [ ] The app archive contains `LICENSE`, `NOTICE.md`, `COPYRIGHT.md`, `TRADEMARKS.md`, `SOURCE-CODE.md` and `THIRD-PARTY-NOTICES.md`.
- [ ] The app's About & Legal window opens and displays copyright, no-warranty, GPL, source, upstream and third-party information.
- [ ] `THIRD_PARTY/dotnet-runtime-8.0.29` contains the exact runtime licence and third-party notice shipped with the bundled runtime.
- [ ] No DevExpress library, Windows UI binary, vendor firmware, secret key, credential or personal sender list is included.
- [ ] The app uses its independent icon and describes itself as an unofficial port.
- [ ] The app is signed with the intended identity. Public production builds should use Developer ID and Apple notarization; ad-hoc status must be disclosed.
- [ ] The binary ZIP and matching Source ZIP are uploaded to the same release location at no extra charge.
- [ ] `SHA256SUMS.txt` is uploaded and checksums are verified after upload.
- [ ] The release tag points to the exact source used to build the binary.
- [ ] No EULA, DRM or download condition adds restrictions inconsistent with GPLv3.

