# macOS Finder, Spotlight and File Index Diagnostics

A macOS support toolkit for diagnosing and repairing Finder, Quick Look and Spotlight indexing problems.

## Diagnostic script

```bash
chmod +x src/finder_spotlight_diagnostics.sh
./src/finder_spotlight_diagnostics.sh --hours 24
```

The diagnostic script checks Finder and metadata processes, Spotlight indexing state, Finder extensions, mounted volumes, filesystem information, search behaviour and recent events.

## Repair script

Preview the repair:

```bash
chmod +x src/finder_spotlight_repair.sh
./src/finder_spotlight_repair.sh --repair --dry-run
```

Apply the standard repair:

```bash
./src/finder_spotlight_repair.sh --repair
```

Enable indexing for a volume:

```bash
./src/finder_spotlight_repair.sh --enable /Volumes/External
```

Rebuild the Spotlight index for a selected path:

```bash
./src/finder_spotlight_repair.sh --reindex /
```

## What the repair does

- Restarts Finder, Quick Look helpers and the Spotlight metadata service.
- Refreshes Quick Look generator registration and its thumbnail cache.
- Can enable Spotlight indexing for a selected path.
- Can request a targeted Spotlight index rebuild.
- Supports dry-run, confirmations, logging and post-repair verification.
- Returns clear success, warning and invalid-argument exit codes.

## Safety and limitations

A Spotlight reindex can cause temporary CPU, disk and battery usage and therefore requires confirmation. The tool does not delete user documents or remove Spotlight privacy exclusions. Filesystem damage and failing storage hardware require separate disk diagnostics.

## Author

Dewald Pretorius — L2 IT Support Engineer
