# macOS Finder, Spotlight and File Index Diagnostics

A read-only Bash toolkit for collecting Finder, Spotlight, metadata-index, Finder extension, mounted-volume, and recent search-event evidence.

## Usage

```bash
chmod +x src/finder_spotlight_diagnostics.sh
./src/finder_spotlight_diagnostics.sh --hours 24
```

## Checks performed

- Finder and metadata service processes
- Spotlight indexing status for all mounted volumes
- Finder Sync extensions and plug-ins
- Mounted volumes, capacity, and filesystem types
- Basic metadata search test
- Recent Finder, mds, mdworker, and Spotlight events
- Text, CSV, and JSON reports

## Safety

The script does not rebuild indexes, enable or disable Spotlight, restart Finder, remove exclusions, or modify volumes.

## Author

Dewald Pretorius — L2 IT Support Engineer
