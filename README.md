# Pathfinder

A map overlay for **WoW Forever** (the Classic+ client: level 60, Eastern Kingdoms and Kalimdor). It adds clickable pins to the world map and minimap. Click a pin to set the game's own waypoint and super-track it, so you get the built-in arrow and distance.

> **Status:** 0.1.0 is the skeleton: settings, slash commands, saved data and an API check. The map layers arrive in later versions (see [CHANGELOG.md](CHANGELOG.md)).

## Features (planned for 1.0)

- **Flight paths:** every flight master, with a colored ring:
  - green: discovered by this character
  - yellow: available to this character but not discovered yet (includes neutral ones such as Booty Bay, Gadgetzan and Everlook)
  - red: never available to this character (the other faction's)
- **Dungeon and raid entrances:** tinted by how the instance's level range compares to yours (red, orange, yellow, green, gray).
- **Custom pins:** your own pins, each with a name, icon, color and group. Right-click the world map to add one, or use the keybind to drop one where you're standing. Show or hide each group on its own.
- **Sharing:** share a pin with your party, raid or guild, or whisper it to someone. Other Pathfinder users get the full pin. Everyone else gets a normal clickable map pin link.
- **Minimap:** pins show on the minimap only when they're within its visible range.

Each layer can be turned on or off.

## Slash commands

| Command | What it does |
| --- | --- |
| `/pathfinder` or `/pf` | Open the settings panel |
| `/pf api` | Run the API check and print the details |
| `/pf linktest` | Test the map pin chat link (prints it to your own chat only and sends nothing) |
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
Core/       namespace, events, saved variables, API check
Settings/   settings panel, slash commands
Data/       static tables: flight masters, entrances, level ranges (from 0.2.0)
Layers/     one file per pin layer (from 0.2.0)
UI/         pin editor, management panel, share popup (from 0.5.0)
Sharing/    addon messages and chat links (from 0.6.0)
```
