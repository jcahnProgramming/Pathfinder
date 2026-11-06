# Pathfinder roadmap and design decisions

This file records decisions that apply to later phases, so they don't get lost between sessions.

## Phases

| Version | Phase | Status |
| --- | --- | --- |
| 0.1.0 | Skeleton: TOC, settings, slash command, SavedVariables, API check | Released 2026-11-06 |
| 0.2.0 | Flight path layer on the world map | In progress |
| 0.3.0 | Dungeon and raid entrance layers (level-range tint) | Planned |
| 0.4.0 | Minimap rendering for all layers (in range only) | Planned |
| 0.5.0 | Custom pins: placement, keybind, editor, groups, management panel, public API | Planned |
| 0.6.0 | Sharing: addon messages, chat link fallback, incoming-share setting | Planned |
| 0.7.0 | Polish pass | Planned |
| 1.0.0 | Reserved for the agreed 1.0 | — |

## API findings (WoW Forever 1.60.1, interface 16001)

- `C_Map.SetUserWaypoint` + `C_SuperTrack.SetSuperTrackedUserWaypoint`: work.
- `C_TaxiMap.GetTaxiNodesForMap`: works. Every map on a continent returns that whole continent's nodes, so results are de-duplicated by `nodeID` and filtered to positions inside the map. The faction enum is `Enum.FlightPathFaction` (Neutral = 0, Horde = 1, Alliance = 2). `isUndiscovered` is always `false` and is not used.
- `C_EncounterJournal.GetDungeonEntrancesForMap`: present but returns nothing, so entrances come from a static table.
- Map pin chat link: the native `C_Map.GetUserWaypointHyperlink` and a hand-built `|Hworldmap:mapID:x*10000:y*10000|h` link both work.
- MapCanvas pin templates must not define `OnEnter`/`OnLeave` scripts (`AcquirePin` asserts on this). Put mouse handling in the mixin as `OnMouseEnter`, `OnMouseLeave` and `OnMouseClickAction(button)`; the canvas installs its own scripts that call them.
- `WOW_PROJECT_ID` is the same as Retail's. Detect Forever by an interface version in the 16000–16999 range. Upstream HereBeDragons would load Retail world-map data here, so the minimap layer must not use it unpatched.

## Click conventions (all Pathfinder pins, matching Blizzard)

| Input | Result |
| --- | --- |
| Click | Set the user waypoint and super-track it (arrow + distance) |
| Shift-click with the chat box open | Insert the map pin link into chat |
| Ctrl-click | Clear the waypoint |

- **Built-in pins** (flight paths, dungeons, raids) can never be deleted. Ctrl-click only clears the waypoint.
- **Custom pins:**
  - Ctrl-click opens a confirmation ("Remove <pin name>?") and deletes the saved pin only on yes.
  - Plain Blizzard waypoints keep the default instant clear.
  - Right-click opens a menu with Edit, Share and Delete.
- **Right-click on built-in pins** passes through to the map (zoom out to the parent map), like a click on empty map space.

## Phase 5: public API

Expose pin, group and share functions as a clean public API (for example a global `Pathfinder.API`) so a future companion addon can hook in without changes to Pathfinder. It should cover at least:

- Creating, updating, deleting and querying pins
- Creating, renaming and toggling groups
- Sharing a pin to a channel or target
- Callbacks for pin and group changes

Treat it as a stable contract from the version it ships in.

## Post-1.0: "Pathfinder: Instances" companion addon (working name)

- A separate addon with hand-made dungeon and raid maps (Forever has no native instance maps).
- Lists `Pathfinder` as a required dependency and reuses its pin, group and sharing system through the public API.
- Load-on-demand.

## Before the 1.0 guild test round

- **Distribution:** publish test builds as GitHub pre-releases.
  - Each release includes a zip with a single `Pathfinder/` folder at its root, plus a `release.json`, so WowUp (CurseForge edition) can install from the repo URL and auto-update.
  - Check how WowUp handles WoW Forever as a game version (flavor/TOC detection, which `release.json` metadata it needs).
- **Docs:** draft three documents.
  1. **How to Use**, including how to install through WowUp from the GitHub URL.
  2. **FAQ**.
  3. **What to Test**: a feature checklist and how to report bugs.
