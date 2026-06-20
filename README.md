# HL2: Borderlands

A co-op, Borderlands-style **looter-shooter** for **Garry's Mod**, built on Half-Life 2's
arsenal and enemies. Kill things, grab rolled guns, level up, and push through HL2 maps with
friends.

## Features

- **Procedurally generated guns** — every drop has a rolled rarity (Common → Legendary),
  manufacturer, optional element, and stats (damage, fire rate, accuracy, magazine, reload).
  Five archetypes: pistol, SMG, shotgun, rifle, sniper. Scales across levels 1–60.
- **Elemental effects** — incendiary, shock, corrosive, explosive, cryo, with on-hit FX.
- **Exciting drops** — rarity-colored light beams + glow and a sound that gets grander with
  rarity; epic/legendary finds are announced to everyone.
- **4-slot loadout** — a per-player backpack; equip up to 4 guns and switch with `1`–`4`.
- **Leveling** — kills grant XP; levels raise health and the quality of the loot you find.
- **Enemies & bosses** — a spawn director keeps the action coming; enemies can roll **Badass**
  and other variants, and a **boss** appears every few waves with a health bar and a
  guaranteed legendary.
- **Vending machines** — buy/sell guns for credits (good guns are rare in shops); one is
  placed at each map's spawn.
- **Persistence** — your backpack, loadout, level, and credits are saved between sessions.

## Requirements

- **Garry's Mod** (Steam).
- **Half-Life 2** installed and mounted in GMod (for HL2 maps/content). HL2DM/sandbox maps
  work without it.
- **Git** (only needed for the updater).

## Install

### Linux / Steam Deck
```sh
git clone https://github.com/ambocclusion/hl2-bl.git
cd hl2-bl
scripts/install.sh
```

### Windows
1. Download/clone this repo.
2. Double-click **`scripts/install.bat`**.

The installer auto-detects Garry's Mod across your Steam library folders. If it can't find
it, point it at the folder manually:
- Linux: `GMOD_DIR=/path/to/.../GarrysMod/garrysmod scripts/install.sh`
- Windows (PowerShell): `$env:GMOD_DIR="C:\...\GarrysMod\garrysmod"; scripts\install.ps1`

## Play

1. Launch Garry's Mod.
2. **New Game → Gamemode: "HL2: Borderlands" → pick a map** (e.g. `gm_construct`, or an HL2
   map like `d2_coast_03`). You spawn with no weapons — that's intended.
3. There's a **vending machine at spawn** (press **E**) — you start with credits to buy a gun.

### Controls
- **E** — pick up the gun you're looking at / use the vending machine.
- **I** — open your backpack (equip / unequip / drop guns).
- **1–4** — switch between your 4 equipped guns.

## Update

Grab the latest version anytime:
- Linux: `scripts/update.sh`
- Windows: double-click `scripts/update.bat`

When a newer version exists, in-game the server admins are told to run the updater.

## Useful console commands

| Command | Description |
|---|---|
| `hl2bl_inv` | Open the backpack (also bound to **I**) |
| `hl2bl_spawn_vendor` | Spawn a vending machine where you're looking (superadmin) |
| `hl2bl_campaign_start` / `hl2bl_campaign_next` | Start / advance the HL2 campaign (superadmin) |
| `give hl2bl_smg` | Spawn a gun directly (`_pistol/_shotgun/_rifle/_sniper` too) |

ConVars: `hl2bl_drop_chance`, `hl2bl_badass_chance`, `hl2bl_boss_every`,
`hl2bl_spawn_interval/max/wave`, `hl2bl_campaign_auto`, `hl2bl_update_check`.

## Development

Instead of copying, symlink the addon so repo edits are live:
- Linux: `scripts/deploy.sh` &nbsp; • &nbsp; Windows: `scripts/deploy.bat`

The gameplay is a GMod addon (`addon/`) plus a thin sandbox-derived gamemode
(`gamemodes/hl2bl/`). See `CLAUDE.md` for architecture and module details.
