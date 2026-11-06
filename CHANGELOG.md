# Changelog

All notable changes to Pathfinder are documented here. Version 1.0.0 is reserved for the agreed 1.0 release.

## [0.3.0] - 2026-11-06

> **Note:** automatic entrance detection is included in this release but is still pending in-game verification.

### Added
- Instances category with Dungeons and Raids layers. Entrances for Eastern Kingdoms and Kalimdor come from a static table (`Data/Instances.lua`), since the client's entrance API returns nothing. Pins show on zone maps and on continent maps.
- Level-range tint by classic difficulty colors: red = well above you, orange = a bit above, yellow = at level, green = a bit below, gray = trivial. Pins update on level up.
- Shared entrances use one pin with every instance listed in the tooltip, each with its own colored level range: Blackrock Mountain, the Gates of Ahn'Qiraj and Scarlet Monastery's wings. Multi-entrance instances (Uldaman, Stratholme) get a pin per entrance.
- Instance level ranges come from the client's group-browser activities where available, with the static table as fallback.
- Forever's nine new dungeons, with Blizzard's officially published level ranges: The Hall of Thanes, Ruins of Lordaeron, Excavation Site: Wetlands, City of Dalaran, The Drowned City, Krol'dok Stronghold, Alcaz Prison, Blackmaw Hold and The Shaper's Terrace.
  - Each has Blizzard's location hint, shown in the tooltip and in "Instances without a pin yet" until an entrance is recorded.
  - City of Dalaran shows its attunement quests.
- Level range authority: official (Blizzard's published) > client (group browser) > static (Classic table). `/pf levels` shows the source of each.
- The raid layer shows only Forever's launch raids: Onyxia's Lair, Hyjal Summit and The Barrow Deeps (reached through Blackmaw Hold, so it shares that pin).
  - Molten Core, Blackwing Lair, Zul'Gurub, both Ahn'Qiraj raids and Naxxramas are kept but hidden as "not yet in Forever", including on Blackrock Mountain's merged pin.
  - `/pf unreleased` (testing only) shows them.
- Client name aliases: Stormwind Stockades, Zul'Farak, Scarlet Monastery (wing group), Stratholme (Main Gate) / (Service Gate).
- Automatic entrance detection: walking into a dungeon or raid records your last outdoor position as its entrance. Group-finder entries, summons, teleports and stale positions are skipped.
  - Recorded entrances replace the static point, show "Recorded by you" in the tooltip, and are stored account-wide with the reporter for later realm sync.
  - Instances only ever entered through the group finder are listed as "Group finder only".
- `/pf entrances` lists recorded entrances, queue-only dungeons and recent recording attempts. There's also a button for it under Settings → Instances.
- Questie-listed Forever areas the client doesn't confirm stay hidden unless an entrance is recorded for them.
- `/pf levels` compares the client's instance data with the static table: the ranges in use, differences over 3 levels, Forever candidates, and unmatched client entries split into likely real instances and variants. LFG zones (type 4) and battlegrounds (type 5) are counted as non-instances.
- Debug window (`/pf debug`): movable and resizable, with selectable, copyable text and Clear, Select All and Close buttons. `/pf api`, `/pf taxi`, `/pf levels` and `/pf linktest` write to it instead of chat.
- Licensed under GPL-3.0-or-later. Questie is credited for the entrance coordinates.
- Category-based settings: Travel, Instances, Services, Trainers and Custom, each with a master toggle and sub-toggles. Layers that aren't built yet are shown greyed out as "coming soon".

### Changed
- Pin glow now follows the icon's own shape (tinted, additive copies of the icon) instead of a circular ring.

### Removed
- `Media/` ring and glow textures (no longer used).

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
