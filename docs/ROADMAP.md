# Pathfinder roadmap and design decisions

This file records decisions that apply to later phases, so they don't get lost between sessions.

## Phases

| Version | Phase | Status |
| --- | --- | --- |
| 0.1.0 | Skeleton: TOC, settings, slash command, SavedVariables, API check | Released 2026-11-06 |
| 0.2.0 | Flight path layer on the world map | Released 2026-11-06 |
| 0.3.0 | Icon-shaped glow restyle, Instances layers (dungeons + raids), category-based settings, automatic entrance detection, debug window | Released 2026-11-06 (entrance detection pending in-game verification) |
| 0.4.0 | Minimap rendering for all layers (in range only) | In progress |
| 0.5.0 | Travel additions (zeppelins, boats, portals), Services and Trainers layers with shipped capital data, passive NPC collection | Planned |
| 0.6.0 | Custom pins: right-click and keybind placement, editor, groups, management panel, ctrl-click delete confirmation, public API | Planned |
| 0.7.0 | Sharing: manual share, guild-shared groups, realm world-data sync with the trust rule | Planned |
| 0.8.0 | Polish pass (includes the tracking glow below) | Planned |
| — | Before the 1.0 guild test: GitHub pre-release packaging with `release.json` for WowUp; How to Use, FAQ and What to Test docs; Questie data removal (below) | Planned |
| 1.0.0 | Reserved for the agreed 1.0 | — |

## API findings (WoW Forever 1.60.1, interface 16001)

- `C_Map.SetUserWaypoint` + `C_SuperTrack.SetSuperTrackedUserWaypoint`: work.
- `C_TaxiMap.GetTaxiNodesForMap`: works. Every map on a continent returns that whole continent's nodes, so results are de-duplicated by `nodeID` and filtered to positions inside the map. The faction enum is `Enum.FlightPathFaction` (Neutral = 0, Horde = 1, Alliance = 2). `isUndiscovered` is always `false` and is not used.
- `C_TaxiMap.GetAllTaxiNodes` at a flight master returns exactly the character's known nodes. A single visit caches the whole known network.
- `C_EncounterJournal.GetDungeonEntrancesForMap`: present but returns nothing, so entrances come from a static table. The Encounter Journal has 0 instances.
- **Instance levels:**
  - `C_LFGList` group-browser activities give real suggested ranges. They're the level source wherever one matches, and `Data/Instances.lua` is the fallback.
  - `GetLFGDungeonInfo` gives only one recommended level per instance.
  - Together these two lists decide which Forever-only instances exist (`Core/InstanceInfo.lua`).
- **No raids** appear in the client's LFG or group-browser data.
- **Client name quirks** handled as aliases: "Stormwind Stockades", "Zul'Farak" (Blizzard's typo), "Scarlet Monastery" (wing group), "Stratholme (Main Gate)" / "Stratholme (Service Gate)".
- **New Forever zones** seen in client data (zones, not instances), to cover in Travel/Services later: Riverglades (33–54), Mount Hyjal (55–60).
- Map pin chat link: the native `C_Map.GetUserWaypointHyperlink` and a hand-built `|Hworldmap:mapID:x*10000:y*10000|h` link both work.
- MapCanvas pin templates must not define `OnEnter`/`OnLeave` scripts (`AcquirePin` asserts on this). Put mouse handling in the mixin as `OnMouseEnter`, `OnMouseLeave` and `OnMouseClickAction(button)`; the canvas installs its own scripts that call them.
- `WOW_PROJECT_ID` is the same as Retail's. Detect Forever by an interface version in the 16000–16999 range. Upstream HereBeDragons would load Retail world-map data here, so the minimap layer must not use it unpatched.

## Layer categories

Settings and the map filter are grouped into categories, each with sub-toggles:

| Category | Sub-layers |
| --- | --- |
| Travel | Flight paths, zeppelins, boats, portals |
| Instances | Dungeons, raids |
| Services | Banks, auctioneers, innkeepers, transmog |
| Trainers | Profession trainers, split per profession |
| Custom | The user's own pins and groups |

## Pin glow style (all layers)

- The glow follows the icon's own shape. It is a slightly larger, tinted copy of the icon texture drawn behind the icon with ADD blend mode, colored by status.
- Keep it subtle. It should read as a glow, not a second icon.
- This replaces the circular ring used in 0.2.0.

## Instance sources of truth

### Level ranges, in order of authority

1. **Official:** Blizzard's published ranges for Forever's new dungeons (news.blizzard.com, "Explore the New Dungeons of World of Warcraft: Forever"). These win over client data.
2. **Client:** the group browser's suggested range. Used for the original dungeons, since Blizzard hasn't published Forever ranges for them.
3. **Static:** the Classic table in `Data/Instances.lua`, as fallback.

`/pf levels` shows which source each range came from.

### Forever's new dungeons

All 5-player. The hints are from Blizzard's post and show until an entrance is recorded.

| Dungeon | Levels (official) | Instance map | Where |
| --- | --- | --- | --- |
| The Hall of Thanes | 13–18 | 3065 | Beneath Ironforge, Dun Morogh (Horde travel into Alliance territory) |
| Ruins of Lordaeron | 15–20 | 2999 | The ruined city above the Undercity, Tirisfal Glades |
| Excavation Site: Wetlands | 24–29 | 2998 | Near Thelgen Rock and Dun Algaz, above Whelgar's Excavation |
| City of Dalaran | 28–33 | 2959 | Alterac Mountains, through the sewers. **Attunement:** Alliance "An Alarming Request" (Emissary Jacques, Southshore); Horde "Key to the City" + "Prison Break-In" (Magus Wordeen Voidglare, Tarren Mill) |
| The Drowned City | 35–40 | 2970 | Off the coast of Stranglethorn Vale, west of Grom'gol (underwater entrance) |
| Krol'dok Stronghold | 40–45 | 3039 | Riverglades (new zone) |
| Alcaz Prison | 48–53 | 2994 | Alcaz Island, Dustwallow Marsh |
| Blackmaw Hold | 55–60 | 2974 | Beyond a long-sealed gate in Azshara |
| The Shaper's Terrace | 58–60 | 3001 | Northern hills of Un'Goro Crater |

The Hall of Thanes and Ruins of Lordaeron have physical entrances. They are not queue-only.

### Raids: only what Forever actually has

Blizzard's confirmed launch raids, opening **2026-12-09**, all level 60:

| Raid | Size | Where |
| --- | --- | --- |
| Onyxia's Lair | 40 | Dustwallow Marsh |
| Hyjal Summit | 20 | Mount Hyjal (new zone) |
| The Barrow Deeps | 10 | Reached through Blackmaw Hold, Azshara (shares Blackmaw Hold's pin) |

- Molten Core, Blackwing Lair, Zul'Gurub, Ruins of Ahn'Qiraj, Temple of Ahn'Qiraj and Naxxramas stay in the data with `unreleased = true`. They're hidden everywhere, including Blackrock Mountain's merged pin. Enabling one is a one-line data change.
- `/pf unreleased` (testing only, not in the Settings panel) shows them.
- Raids with no map ID yet (Hyjal Summit, The Barrow Deeps) link to recorded entrances by name.
- **Revisit the raid list whenever Blizzard announces new Forever raids.** Spring and Summer updates are expected.

## Entrance auto-detection (Phase 3)

Pulled forward from Phase 5. This is the first step of replacing Questie's entrance data.

- While outdoors, a throttled sampler (1 s) keeps the last two outdoor positions. A fresh one is taken when the loading screen starts.
- On entering a dungeon or raid, the last outdoor position is recorded as that instance's entrance, keyed by instance map ID (from `GetInstanceInfo`). It is recorded only if:
  - the position is at most 3 s old at loading-screen start;
  - there was no teleport-speed movement just before;
  - there was no group-finder entry (LFG dungeon ID / `IsInLFGDungeon`);
  - no summon was offered in the last 3 minutes;
  - it's within 800 yd of a known static entrance, where one exists;
  - it isn't a login or reload.

  Anything unclear is skipped, and the reason is logged.
- Recordings within 40 yd merge into one entrance cluster. Multi-entrance instances keep one cluster per entrance.
- Instances entered at least twice and only ever through the group finder are listed as **Group finder only** (`/pf entrances`, Settings → Instances). They don't get a map pin.
- Instances with neither a static point nor a recording appear in **Instances without a pin yet** with Blizzard's location hint, in the same places.
- Recorded entrances replace the static point for that site and show immediately with "Recorded by you".
  - Unknown instances found by walking in get pins of their own.
  - Raids included; a recorded Naxxramas replaces the Era point.
- Storage: `PathfinderDB.world.entrances` (account-wide, with reporters per cluster). This is the store Phase 7's realm sync will exchange, so the two-reporter trust rule can apply.
- `/pf entrances` lists recorded entrances, the queue-only list and recent recording attempts. `/pf levels` notes recorded entrances that differ from the static point by more than 30 yd.

## Questie data removal (before 1.0)

- Re-record every entrance through detection or an in-game survey.
- Then delete all Questie-sourced data and the Questie credit in the README.
- Keep GPL-3.0 as the license regardless.

## Tracking glow (polish phase)

- When a Pathfinder pin is the active waypoint, give it a thick white glow and hide Blizzard's waypoint map pin at that spot.
- The on-screen navigation arrow stays.
- Plain Blizzard waypoints the player drops themselves keep their normal pin.

## Licensing

- Pathfinder is GPL-3.0-or-later. The license was chosen because the entrance coordinates came from Questie's database, and it stays GPL-3.0 after that data is removed.
- Credit Questie in the README. Never use the Questie name or logo for Pathfinder itself.

## Click conventions (all Pathfinder pins, matching Blizzard)

| Input | Result |
| --- | --- |
| Click | Set the user waypoint and super-track it (arrow + distance) |
| Shift-click with the chat box open | Insert the map pin link into chat |
| Ctrl-click | Clear the waypoint |

- **Built-in pins** (every layer except Custom) can never be deleted. Ctrl-click only clears the waypoint.
- **Custom pins:**
  - Ctrl-click opens a confirmation ("Remove <pin name>?") and deletes the saved pin only on yes.
  - Plain Blizzard waypoints keep the default instant clear.
  - Right-click opens a menu with Edit, Share and Delete.
- **Right-click on built-in pins** passes through to the map (zoom out to the parent map), like a click on empty map space.

## World data (Services, Trainers, transport)

WoW has no API for NPC locations, and Pathfinder will not scrape Wowhead or Icy Veins. It builds its own database:

- **Shipped static data:** transport (boats, zeppelins, portals) and the six capital cities.
- **Passive collection:** while playing, record service NPCs the player interacts with or mouses over.
  - Detect the type from interaction events (bank, auction house, trainer, innkeeper, transmogrifier and so on) and the NPC title from the tooltip (for example `<Banker>`).
  - Record name, map ID and position.
  - No command needed. Your own observations show on your own map immediately.
- **Realm-wide sync:** Pathfinder users on the same realm sync world data automatically through a hidden addon channel.
  - On login, peers compare and send each other only the missing entries.
  - Re-check periodically while playing, pause during combat, and throttle all traffic.
  - Only NPC location data is ever sent. Never custom pins or anything personal.
- **Trust rule:** a crowdsourced entry from other players only appears once at least two different players have reported it, or it comes from the shipped database.
- **Setting:** "Share world data with the realm", on by default, with opt-out.
- **Release step:** before each release, fold the maintainer's accumulated saved world data into the shipped static database so new users start full.

## Custom pin sharing

Custom pins are never part of realm sync.

- **Manual share** to party, raid, guild or a whisper target. Uses the incoming-share setting (default: popup with Accept / Decline).
  - Addon users receive the full pin. Everyone else gets a native clickable map pin link.
  - Rate-limit and validate all incoming messages.
- **Guild-shared groups:** a custom group can be marked "Guild shared" so it syncs automatically with guildmates.
  - The first time a guildmate's shared group arrives, the incoming-share setting applies to the whole group. Once accepted, updates flow in automatically.
  - Only the creator can edit, add or remove pins in a shared group. Everyone else sees it read-only, but can hide it, unsubscribe, or use "Copy to my pins" to make a private editable copy.
  - If the owner unshares or deletes the group, it disappears for everyone.

## Public API (with custom pins)

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
