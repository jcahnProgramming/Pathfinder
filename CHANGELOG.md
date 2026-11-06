# Changelog

All notable changes to Pathfinder are documented here. Version 1.0.0 is reserved for the agreed 1.0 release.

## [0.1.0] - 2026-11-06

### Added
- Skeleton: `.toc` for WoW Forever (interface 16001), core namespace, event and module system.
- SavedVariables: `PathfinderDB` (account) and `PathfinderCharDB` (per character), with defaults and a schema version.
- Native Settings panel with toggles for the four layers, minimap display, pin size, incoming-share behavior, and debug options.
- `/pathfinder` and `/pf` slash commands.
- API check that probes waypoints, taxi nodes, dungeon entrances, the map pin hyperlink and supporting APIs. It prints a summary on login, and `/pf api` prints the full report. The full data is saved to `PathfinderDB.apiReport`.
- `/pf linktest` to verify the native map pin chat link.
