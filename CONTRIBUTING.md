# Contributing

Contributions are welcome. By submitting a contribution, you certify that you have the right to submit it and agree to license it under GNU GPL version 3 only (`GPL-3.0-only`). Preserve existing copyright, authorship, licence and provenance notices.

Do not contribute firmware, manufacturer binaries, confidential specifications, personal channel-list exports, access keys, credentials, broadcaster logos or other material that you are not authorised to redistribute. Test fixtures should be synthetic and must not contain personal data.

For new source files, use this header with your own name where appropriate:

```text
Copyright (C) <year> <author>
SPDX-License-Identifier: GPL-3.0-only
```

Run the test and compliance checks before submitting changes:

```bash
swift test --disable-sandbox
./scripts/check-compliance.sh
./scripts/audit-release.sh
```

Changes to vendored upstream code must be documented in `UPSTREAM.md` and should remain easy to compare with the recorded upstream release.
