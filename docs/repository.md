# Repository conventions

## Structure

```text
.
├── Package.swift
├── README.md
├── third-party-notices.md
├── sources/
│   ├── surf-meter-app/
│   ├── surf-meter-core/
│   │   └── resources/
│   ├── surf-meter-native-host/
│   └── surf-meter-verification/
├── tests/
│   └── surf-meter-core-tests/
├── extensions/
│   ├── chrome/
│   └── safari/
├── prototype/
├── scripts/
└── docs/
    ├── archive/
    ├── diagrams/
    └── media/
```

Project-owned folders and Markdown filenames use lowercase kebab-case. `README.md`, `Package.swift`, Swift type/module names, and upstream license filenames retain their conventional spelling. Swift Package targets use explicit paths, so module imports and executable names remain stable.

Generated or platform-required paths are separate: SwiftPM uses `.build`, npm uses `node_modules`, and macOS app bundles require `Contents/MacOS`, `Contents/Resources`, and related casing. Do not rename these tool-managed structures or commit them.

## Publication hygiene

Keep credentials, signing keys/profiles, local agent state, build/install backups, generated extension bundles, logs, real activity databases, and user-specific native-host configuration out of Git. The ignore rules cover these categories. Use documented placeholders for extension IDs and account-specific values. Documentation images must use synthetic activity, empty isolated stores, or attributed public example screenshots.

Preserve upstream license text and vendored data. Public repository links, product hostnames, and third-party attribution are intentional public content.

Run from the repository root:

```sh
python3 scripts/check-repo.py
python3 scripts/check-repo.py --history
```

The check validates tracked/project files, kebab-case paths, Markdown links and heading targets, private runtime/signing filenames, common credential formats, and machine-specific home/temp paths. `--history` also scans text blobs reachable from local Git refs. Findings show locations and rule names without printing suspected credentials. Pattern checks complement manual review; they do not inspect external repositories or untracked ignored caches.

## Documentation maintenance

- Keep [the documentation index](README.md) current when adding or moving a guide.
- Use [validation](validation.md) for current results and open gates; keep detailed audit evidence in [the audit](qa-audit.md).
- Keep the five task IDs in [implementation](implementation.md) stable and update its current handoff instead of appending session transcripts.
- Use relative documentation/image links so the checkout works offline. Root marketing images may use the repository's public raw URLs.
- Refresh screenshots with the native exporter and adjust setup annotation coordinates when controls move. Keep public source attribution alongside reused assets.
- Run the repository check and relevant native/extension checks before committing structural changes.
