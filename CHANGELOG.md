# Changelog

All notable changes to Pathfinder are documented here. Version 1.0.0 is reserved for the agreed 1.0 release.

## [0.2.0] - 2026-11-06

### Added
- Flight path layer on the world map. It shows every flight master from `C_TaxiMap.GetTaxiNodesForMap`, de-duplicated by node ID, with a glow ring: green = discovered, yellow = not discovered yet (own faction or neutral), red = unavailable to your faction.
- Per-character cache of discovered flight paths, updated each time a flight master's map is opened.
- Pin tooltips with the flight master's name and status.
- Click conventions for all Pathfinder pins: click sets the waypoint and arrow, shift-click with chat open inserts the map pin link, ctrl-click clears the waypoint. Right-click zooms the map out as usual. On continent maps the waypoint is placed on the zone under the pin.
- Respects the Flight paths toggle and the Pin size slider.
- `/pf taxi` prints the faction mapping, cache state and per-status counts for your continent.
- `docs/ROADMAP.md` with recorded design decisions for later phases.

## [0.1.0] - 2026-11-06

### Added
- Skeleton: `.toc` for WoW Forever (interface 16001), core namespace, event and module system.
- SavedVariables: `PathfinderDB` (account) and `PathfinderCharDB` (per character), with defaults and a schema version.
- Native Settings panel with toggles for the four layers, minimap display, pin size, incoming-share behavior, and debug options.
- `/pathfinder` and `/pf` slash commands.
- API check that probes waypoints, taxi nodes, dungeon entrances, the map pin hyperlink and supporting APIs. It prints a summary on login, and `/pf api` prints the full report. The full data is saved to `PathfinderDB.apiReport`.
- `/pf linktest` to verify the native map pin chat link.
