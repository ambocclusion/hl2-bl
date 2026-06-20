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

📖 **Full Windows walkthrough (install, play, updating, troubleshooting):
[docs/INSTALL-WINDOWS.md](docs/INSTALL-WINDOWS.md)**

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

## Weapon stats & scaling

How guns roll and grow. All multiplier values below are the **mean roll** with a neutral
**Vanguard** manufacturer — individual drops vary ±, and the other six manufacturers bias the
stats further (e.g. Ironclad ×1.25 damage, Volt ×1.30 fire rate, Precision ×0.70 spread,
Surplus ×1.60 magazine, Rapidax ×0.65 reload).

**Base stats per archetype** (before any roll):

| Weapon | Dmg | RPM | Spread | Pellets | Reload s | Clip | Recoil | Reserve |
|---|---|---|---|---|---|---|---|---|
| Pistol | 16 | 360 | 0.015 | 1 | 1.2 | 18 | 0.5 | 108 |
| SMG | 11 | 720 | 0.05 | 1 | 1.5 | 30 | 0.4 | 180 |
| Shotgun | 8 | 80 | 0.09 | 8 | 2.2 | 6 | 1.4 | 48 |
| Rifle | 18 | 450 | 0.03 | 1 | 2.0 | 30 | 0.6 | 180 |
| Sniper | 90 | 50 | 0.002 | 1 | 2.5 | 5 | 1.2 | 50 |

**Rarity scaling** — the same stat multipliers apply to *every* weapon (spread & reload are
lower = better):

| Rarity | Dmg × | FireRate × | Spread × | Reload × | Mag × | Elem chance |
|---|---|---|---|---|---|---|
| Common | 1.02 | 1.00 | 0.95 | 0.95 | 1.00 | 10% |
| Uncommon | 1.17 | 1.02 | 0.92 | 0.93 | 1.07 | 28% |
| Rare | 1.32 | 1.04 | 0.89 | 0.91 | 1.15 | 46% |
| Epic | 1.47 | 1.07 | 0.86 | 0.88 | 1.23 | 64% |
| Legendary | 1.62 | 1.09 | 0.83 | 0.86 | 1.30 | 82% |

**Level scaling** — character/item level multiplies **damage only** (fire rate, spread,
magazine, etc. do not scale with level):

| Level | 1 | 10 | 20 | 30 | 40 | 50 | 60 |
|---|---|---|---|---|---|---|---|
| Dmg × | 1.00 | 1.81 | 2.71 | 3.61 | 4.51 | 5.41 | 6.31 |

So `final damage = base × rarityDmg × levelScale`. The grids below show mean per-shot damage
(rarity = rows, level = columns):

<details>
<summary><b>Per-weapon damage grids (rarity × level)</b></summary>

**Pistol** (base 16)
| Rarity \ Level | 1 | 10 | 20 | 30 | 40 | 50 | 60 |
|---|---|---|---|---|---|---|---|
| Common | 16 | 30 | 44 | 59 | 74 | 88 | 103 |
| Uncommon | 19 | 34 | 51 | 68 | 84 | 101 | 118 |
| Rare | 21 | 38 | 57 | 76 | 95 | 114 | 133 |
| Epic | 24 | 43 | 64 | 85 | 106 | 127 | 148 |
| Legendary | 26 | 47 | 70 | 94 | 117 | 140 | 164 |

**SMG** (base 11)
| Rarity \ Level | 1 | 10 | 20 | 30 | 40 | 50 | 60 |
|---|---|---|---|---|---|---|---|
| Common | 11 | 20 | 30 | 41 | 51 | 61 | 71 |
| Uncommon | 13 | 23 | 35 | 46 | 58 | 70 | 81 |
| Rare | 15 | 26 | 39 | 52 | 65 | 79 | 92 |
| Epic | 16 | 29 | 44 | 58 | 73 | 87 | 102 |
| Legendary | 18 | 32 | 48 | 64 | 80 | 96 | 112 |

**Shotgun** (base 8 — per pellet, ×8 pellets per shot)
| Rarity \ Level | 1 | 10 | 20 | 30 | 40 | 50 | 60 |
|---|---|---|---|---|---|---|---|
| Common | 8 | 15 | 22 | 29 | 37 | 44 | 51 |
| Uncommon | 9 | 17 | 25 | 34 | 42 | 51 | 59 |
| Rare | 11 | 19 | 29 | 38 | 48 | 57 | 67 |
| Epic | 12 | 21 | 32 | 42 | 53 | 64 | 74 |
| Legendary | 13 | 23 | 35 | 47 | 58 | 70 | 82 |

*(Full hit on one target ≈ these × 8, e.g. Legendary L60 ≈ 656.)*

**Rifle** (base 18)
| Rarity \ Level | 1 | 10 | 20 | 30 | 40 | 50 | 60 |
|---|---|---|---|---|---|---|---|
| Common | 18 | 33 | 50 | 66 | 83 | 99 | 116 |
| Uncommon | 21 | 38 | 57 | 76 | 95 | 114 | 133 |
| Rare | 24 | 43 | 64 | 86 | 107 | 129 | 150 |
| Epic | 26 | 48 | 72 | 96 | 119 | 143 | 167 |
| Legendary | 29 | 53 | 79 | 105 | 132 | 158 | 184 |

**Sniper** (base 90)
| Rarity \ Level | 1 | 10 | 20 | 30 | 40 | 50 | 60 |
|---|---|---|---|---|---|---|---|
| Common | 92 | 166 | 249 | 331 | 414 | 497 | 579 |
| Uncommon | 105 | 191 | 285 | 380 | 475 | 570 | 664 |
| Rare | 119 | 215 | 322 | 429 | 536 | 643 | 750 |
| Epic | 132 | 239 | 359 | 478 | 597 | 716 | 835 |
| Legendary | 146 | 264 | 395 | 526 | 658 | 789 | 920 |

</details>

**Element damage** (only if the gun rolled an element; procs on hit at the Elem chance above) —
`elemDmg = (4 + level × 0.75) × (1 + rarityBonus)`:

| Rarity | L1 | L10 | L20 | L30 | L40 | L50 | L60 |
|---|---|---|---|---|---|---|---|
| Common | 5 | 12 | 19 | 26 | 34 | 42 | 49 |
| Uncommon | 5 | 13 | 22 | 30 | 39 | 48 | 56 |
| Rare | 6 | 15 | 25 | 34 | 44 | 54 | 64 |
| Epic | 7 | 17 | 28 | 38 | 49 | 60 | 71 |
| Legendary | 8 | 18 | 30 | 42 | 54 | 66 | 78 |

## Development

Instead of copying, symlink the addon so repo edits are live:
- Linux: `scripts/deploy.sh` &nbsp; • &nbsp; Windows: `scripts/deploy.bat`

The gameplay is a GMod addon (`addon/`) plus a thin sandbox-derived gamemode
(`gamemodes/hl2bl/`). See `CLAUDE.md` for architecture and module details.
