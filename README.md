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
- **HEV armor** — rolled suit pieces in 4 slots (Helmet, Vest, Greaves, Power Core) from
  HL2 factions (Black Mesa, Combine, Resistance…). They buff your **suit-armor bar**,
  **max health**, or **health regen**. Manage them in a paper-doll inventory (press `I`).
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
**Vanguard** manufacturer. Individual drops vary around the mean, and that spread **widens with
rarity** (a Legendary can roll great or merely good), so no two guns feel the same. The other
six manufacturers then push the stats into distinct identities — each is effectively its own
weapon class with real tradeoffs:

| Manufacturer | Damage | Fire rate | Spread | Magazine | Reload | Recoil | Element | Identity |
|---|---|---|---|---|---|---|---|---|
| Vanguard | ×1.00 | ×1.00 | ×1.00 | ×1.00 | ×1.00 | ×1.00 | ×1.00 | balanced baseline |
| Ironclad | ×1.35 | ×0.70 | ×0.85 | ×0.85 | ×1.15 | ×1.35 | ×0.90 | hard-hitting, slow, kicks hard |
| Volt | ×0.80 | ×1.45 | ×1.25 | ×1.25 | ×1.00 | ×0.85 | ×1.00 | hyper fire-rate spray |
| Precision | ×1.18 | ×0.85 | ×0.55 | ×0.85 | ×0.95 | ×0.65 | ×1.00 | laser-accurate, low recoil |
| Surplus | ×0.85 | ×1.10 | ×1.30 | ×1.85 | ×1.20 | ×1.15 | ×1.00 | huge mags, sloppy |
| Elementech | ×0.85 | ×1.00 | ×0.95 | ×1.05 | ×1.00 | ×0.95 | ×1.85 | elemental specialist |
| Rapidax | ×0.95 | ×1.12 | ×0.95 | ×0.90 | ×0.55 | ×0.80 | ×1.00 | snappy reload + handling |

(Spread / reload / recoil are **lower = better**, so a ×<1 bias improves them.)

**Base stats per archetype** (before any roll):

| Weapon | Dmg | RPM | Spread | Pellets | Reload s | Clip | Recoil | Reserve |
|---|---|---|---|---|---|---|---|---|
| Pistol | 16 | 360 | 0.015 | 1 | 1.2 | 18 | 0.5 | 108 |
| SMG | 11 | 720 | 0.05 | 1 | 1.5 | 30 | 0.4 | 180 |
| Shotgun | 8 | 80 | 0.09 | 8 | 2.2 | 6 | 1.4 | 48 |
| Rifle | 18 | 450 | 0.03 | 1 | 2.0 | 30 | 0.6 | 180 |
| Sniper | 90 | 50 | 0.002 | 1 | 2.5 | 5 | 1.2 | 50 |

**Rarity scaling** — mean multipliers per tier (spread / reload / recoil are lower = better).
Higher rarity also rolls **wider** (roll spread ≈ ±(10 + 5×rarity)%), so the values below are
the average, not a guarantee:

| Rarity | Dmg × | FireRate × | Spread × | Reload × | Mag × | Recoil × | Elem chance |
|---|---|---|---|---|---|---|---|
| Common | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 10% |
| Uncommon | 1.18 | 1.04 | 0.94 | 0.95 | 1.10 | 0.96 | 28% |
| Rare | 1.36 | 1.08 | 0.88 | 0.90 | 1.20 | 0.92 | 46% |
| Epic | 1.54 | 1.12 | 0.82 | 0.85 | 1.30 | 0.88 | 64% |
| Legendary | 1.72 | 1.16 | 0.76 | 0.80 | 1.40 | 0.84 | 82% |

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
| Common | 16 | 29 | 43 | 58 | 72 | 87 | 101 |
| Uncommon | 19 | 34 | 51 | 68 | 85 | 102 | 119 |
| Rare | 22 | 39 | 59 | 79 | 98 | 118 | 137 |
| Epic | 25 | 45 | 67 | 89 | 111 | 133 | 155 |
| Legendary | 28 | 50 | 75 | 99 | 124 | 149 | 174 |

**SMG** (base 11)
| Rarity \ Level | 1 | 10 | 20 | 30 | 40 | 50 | 60 |
|---|---|---|---|---|---|---|---|
| Common | 11 | 20 | 30 | 40 | 50 | 60 | 69 |
| Uncommon | 13 | 23 | 35 | 47 | 59 | 70 | 82 |
| Rare | 15 | 27 | 41 | 54 | 67 | 81 | 94 |
| Epic | 17 | 31 | 46 | 61 | 76 | 92 | 107 |
| Legendary | 19 | 34 | 51 | 68 | 85 | 102 | 119 |

**Shotgun** (base 8 — per pellet, ×8 pellets per shot)
| Rarity \ Level | 1 | 10 | 20 | 30 | 40 | 50 | 60 |
|---|---|---|---|---|---|---|---|
| Common | 8 | 14 | 22 | 29 | 36 | 43 | 50 |
| Uncommon | 9 | 17 | 26 | 34 | 43 | 51 | 60 |
| Rare | 11 | 20 | 29 | 39 | 49 | 59 | 69 |
| Epic | 12 | 22 | 33 | 44 | 56 | 67 | 78 |
| Legendary | 14 | 25 | 37 | 50 | 62 | 74 | 87 |

*(Full hit on one target ≈ these × 8, e.g. Legendary L60 ≈ 696.)*

**Rifle** (base 18)
| Rarity \ Level | 1 | 10 | 20 | 30 | 40 | 50 | 60 |
|---|---|---|---|---|---|---|---|
| Common | 18 | 33 | 49 | 65 | 81 | 97 | 114 |
| Uncommon | 21 | 38 | 58 | 77 | 96 | 115 | 134 |
| Rare | 24 | 44 | 66 | 88 | 110 | 132 | 154 |
| Epic | 28 | 50 | 75 | 100 | 125 | 150 | 175 |
| Legendary | 31 | 56 | 84 | 112 | 140 | 167 | 195 |

**Sniper** (base 90)
| Rarity \ Level | 1 | 10 | 20 | 30 | 40 | 50 | 60 |
|---|---|---|---|---|---|---|---|
| Common | 90 | 163 | 244 | 325 | 406 | 487 | 568 |
| Uncommon | 106 | 192 | 288 | 383 | 479 | 575 | 670 |
| Rare | 122 | 222 | 332 | 442 | 552 | 662 | 772 |
| Epic | 139 | 251 | 376 | 500 | 625 | 750 | 875 |
| Legendary | 155 | 280 | 420 | 559 | 698 | 837 | 977 |

</details>

**Element damage** (only if the gun rolled an element; procs on hit at the Elem chance above) —
`elemDmg = (4 + level × 0.75) × (1 + rarityBonus)`:

| Rarity | L1 | L10 | L20 | L30 | L40 | L50 | L60 |
|---|---|---|---|---|---|---|---|
| Common | 5 | 12 | 19 | 27 | 34 | 42 | 49 |
| Uncommon | 6 | 14 | 22 | 31 | 40 | 49 | 58 |
| Rare | 6 | 16 | 26 | 36 | 46 | 56 | 67 |
| Epic | 7 | 18 | 29 | 41 | 52 | 64 | 75 |
| Legendary | 8 | 20 | 33 | 46 | 58 | 71 | 84 |

## Development

Instead of copying, symlink the addon so repo edits are live:
- Linux: `scripts/deploy.sh` &nbsp; • &nbsp; Windows: `scripts/deploy.bat`

The gameplay is a GMod addon (`addon/`) plus a thin sandbox-derived gamemode
(`gamemodes/hl2bl/`). See `CLAUDE.md` for architecture and module details.
