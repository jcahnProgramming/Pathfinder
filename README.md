# Pathfinder

A map overlay for **WoW Forever** (the Classic+ client: level 60, Eastern Kingdoms and Kalimdor). It adds clickable pins to the world map and minimap. Click a pin to set the game's own waypoint and super-track it, so you get the built-in arrow and distance.

> **Status:** 0.3.0 adds dungeon and raid entrances and category-based settings. The other layers arrive in later versions (see [CHANGELOG.md](CHANGELOG.md) and [docs/ROADMAP.md](docs/ROADMAP.md)).

## Pin clicks

| Input | Result |
| --- | --- |
| Click | Set the waypoint and arrow |
| Shift-click (chat box open) | Insert the map pin link into chat |
| Ctrl-click | Clear the waypoint |
| Right-click | Zoom the map out, as usual |

## Features (planned for 1.0)

- **Flight paths:** every flight master, with a colored ring:
  - green: discovered by this character
  - yellow: available to this character but not discovered yet (includes neutral ones such as Booty Bay, Gadgetzan and Everlook)
  - red: never available to this character (the other faction's)
- **Dungeon and raid entrances:** tinted by how the instance's level range compares to yours (red, orange, yellow, green, gray). This includes Forever's new dungeons. When you walk into an instance, Pathfinder records its entrance automatically and shows it on your map.
- **Custom pins:** your own pins, each with a name, icon, color and group. Right-click the world map to add one, or use the keybind to drop one where you're standing. Show or hide each group on its own.
- **Sharing:** share a pin with your party, raid or guild, or whisper it to someone. Other Pathfinder users get the full pin. Everyone else gets a normal clickable map pin link.
- **Minimap:** pins show on the minimap only when they're within its visible range.

Each layer can be turned on or off.

## Slash commands

| Command | What it does |
| --- | --- |
| `/pathfinder` or `/pf` | Open the settings panel |
| `/pf debug` | Open or close the debug window (diagnostic output you can select and copy) |
| `/pf api` | API check details |
| `/pf linktest` | Test the map pin chat link. The links go to your own chat only and nothing is sent |
| `/pf taxi` | Flight path check: faction mapping, cached paths and status counts for your continent |
| `/pf levels` | Instance levels and the client's instance list compared with Pathfinder's table |
| `/pf entrances` | Recorded instance entrances, queue-only dungeons and recent recording attempts |

The diagnostic commands write to the debug window, and chat only gets a one-line notice.
| `/pf version` | Print the addon version |
| `/pf help` | List the commands |

## Keybind

**Drop pin at my position** (coming in 0.5.0). You'll find it under *Options → Keybindings → AddOns → Pathfinder*.

## Settings

*Options → AddOns → Pathfinder*, or `/pf`. All settings are account-wide.

## Saved data

| Variable | Scope | Contents |
| --- | --- | --- |
| `PathfinderDB` | Account | Settings, custom pins, groups, last API report |
| `PathfinderCharDB` | Character | Flight paths known to this character (updated each time you open a flight master's map) |

## Installation

Copy or link this folder to `World of Warcraft\_forever_\Interface\AddOns\Pathfinder`.

## Project layout

```
Pathfinder.toc
Core/       namespace, layer categories, saved variables, waypoints, flight path cache,
            client instance info, API check
Settings/   settings panel, slash commands
Data/       static tables (instance entrances and fallback level ranges)
Layers/     shared pin template + one file per layer category
UI/         debug window (pin editor, management panel, share popup later)
UI/         pin editor, management panel, share popup (from 0.5.0)
Sharing/    addon messages and chat links (from 0.6.0)
```

## Credits

- **Dungeon and raid entrance coordinates** come from [Questie](https://github.com/Questie/Questie)'s database (QuestieDB, Forever zone data). Questie is used under the GPL-3.0. Pathfinder is not affiliated with Questie.

## License

Pathfinder is licensed under the [GNU General Public License v3.0](LICENSE) (GPL-3.0-or-later).
