# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project goal

`hl2bl` ("HL2 Borderlands") is a **co-op Borderlands-style looter-shooter** for Half-Life 2,
built as a **Garry's Mod (Lua) addon**. Features:

- **Procedural guns** with rolled stats (damage, fire rate, accuracy, magazine, reload).
- **Elemental modifiers** (incendiary / shock / corrosive / explosive / cryo).
- **World stat cards** — a panel shown when looking at a dropped gun.
- **Equip/inventory UI** for comparing and equipping guns.
- **Character progression** — XP, leveling, stats that scale combat.
- **Co-op on HL2 campaign maps**.

## Why Garry's Mod (read this before "fixing" the engine elsewhere)

The project first tried a C++ `source-sdk-2013` HL2MP mod. That path got maps loading and
co-op PvE rules working, but reproducing the HL2 **singleplayer campaign** in multiplayer
(NPC animations, scripted sequences, choreographed scenes, level transitions) is the
"Synergy problem" — years of work, and Synergy itself is closed-source/not forkable. The
open-source solutions for HL2 campaign co-op are all **Garry's Mod**, which already solves
all of that natively. So we pivoted: GMod handles HL2 maps + co-op + NPCs; we write the
Borderlands systems in Lua on top. Do not try to revive the C++ co-op approach.

## Branches

- **`gmod`** — ACTIVE. The Garry's Mod addon (this branch's `addon/`).
- `hl2bl-coop` — the abandoned C++ HL2MP exploration (Phases 1–2, gun data model). Kept for
  reference/history; the C++ source tree (`src/`, `game/`) lives there, not on `gmod`.
- `hl2bl`, `singleplayer`, `upstream-mp` — earlier SDK branches; ignore.

## Gamemode vs addon

Play via the **"HL2: Borderlands" gamemode** (`gamemodes/hl2bl/`, derives from
`sandbox`): its `GM:PlayerLoadout` strips the default sandbox arsenal so players
spawn with **no** weapons and use looted/bought guns (their saved 4-slot loadout is
re-given on spawn by the addon). The gamemode is kept at the repo top level (not
inside the addon mount) to avoid a duplicate-gamemode clash; `deploy.sh` symlinks
it into `garrysmod/gamemodes/`. All gameplay systems live in the addon and run in
any gamemode, so the gamemode itself is intentionally thin (loadout control).

## Repository layout (gmod branch)

- `gamemodes/hl2bl/` — the gamemode (loadout control); symlinked to `gamemodes/`.
- `addon/` — the GMod addon (mounted into `addons/`); all gameplay systems.
  - `addon.json` — addon manifest.
  - `lua/autorun/hl2bl_init.lua` — entry point (runs both realms); loads modules with realm
    handling and the file-name convention **sh_** shared / **sv_** server / **cl_** client.
  - `lua/hl2bl/` — gameplay modules (e.g. `sh_loot.lua` = rarity/element/stat-roll model).
  - `lua/weapons/`, `lua/entities/` — SWEPs and loot/pickup entities (as they land).
- `scripts/` — automation. `.githooks/` — version-controlled hooks.

## Workflow (no build step — Lua is interpreted)

```sh
scripts/install-hooks.sh   # one-time: core.hooksPath=.githooks
scripts/deploy.sh          # symlink addon/ -> addons/hl2bl AND gamemodes/hl2bl -> gamemodes/
scripts/run.sh [map]       # launch GMod via Steam (default gm_construct;
                           #   pass an HL2 map like d1_trainstation_02 to test co-op campaign)
```

- **Requires Garry's Mod installed** (Steam AppId 4000). HL2 content must be mounted in
  GMod (it is, if Half-Life 2 is installed and mounted in GMod's main menu) for HL2 maps.
- **Live iteration:** the addon is symlinked, so editing `addon/lua/**` then reloading
  (changelevel, or `lua_reloadents` / re-run the file) reflects changes without redeploy.
- Verify load: GMod console shows `[HL2BL] v<ver> loaded`. Test the model with the
  `hl2bl_rolltest [itemLevel]` console command.

## Architecture notes (GMod/Lua)

- **Realms:** server authoritative; clients render UI/predict. Cross-realm state goes through
  the `net` library (messages) or networked entity vars (`SetNW*`/`Entity:SetNWInt` or, for
  perf, `net` + caching). Gun rolls are server-authoritative; sync rolled stats to clients
  for stat cards / inventory.
- **Loot model:** `lua/hl2bl/sh_loot.lua` — `HL2BL.RollStats(itemLevel)` returns a stat
  table; `HL2BL.Rarity/Element`, `HL2BL.RarityName/Color`, `HL2BL.ElementName` for UI. This
  is the single source of truth; ported from the C++ prototype.
- **Weapons:** SWEPs (`lua/weapons/`) derive from a gun base that reads its rolled stat
  table to set damage/spread/firerate/reload/clip and apply elemental effects on hit.
- **Loot drops:** hook `OnNPCKilled` server-side to spawn a dropped-gun entity carrying a
  roll; pickup gives the SWEP with those stats.
- **UI:** Derma/VGUI panels (client) for the world stat card and the equip/inventory screen,
  fed from networked stat tables.
- **Progression:** player XP/level via networked vars; kills grant XP; stats scale per level.

## Implemented gameplay (core loop complete)

Kill NPCs → rolled guns drop (rarity-colored beams) → loot into your backpack →
equip → stats drive combat → earn XP / level → loot scales with level.

Modules in `addon/lua/hl2bl/`:
- `sh_loot.lua` — rarity/element model, 7 `Manufacturers` (stat biases + name
  flavor), `RollStats(itemLevel, luck)`, `GetEntStats`, net (de)serialize,
  `LootClasses`. Archetype x manufacturer x element x rarity x continuous rolls
  x item level = effectively unlimited procedurally-generated guns per rarity.
- `sh_progression.lua` — XP curve, level cap (60), and `LevelScale(level)` damage
  power curve (~1x at L1 -> ~6.3x at L60), applied at fire time.
- `sh_archetypes.lua` — per-type tuning/models (`HL2BL.Archetypes`); the gun base
  is archetype-driven so generic slot weapons can become any gun (incl. dupes).
  `HL2BL.MAX_SLOTS` = 4.
- `weapons/hl2bl_gun_base.lua` — archetype-driven SWEP base (rolled stats +
  multi-pellet + recoil + reserve-ammo + element procs; dynamic viewmodel in
  Deploy). Droppable/spawnable wrappers: `hl2bl_pistol/smg/shotgun/rifle/sniper`;
  equipped slots: `hl2bl_slot1..4`.
- `sv_variants.lua` — every hostile NPC (`EnemyClasses`) is level-scaled and may
  roll a variant: Badass (5x hp, big, guaranteed great loot), Armored, Runner;
  tints/scales/speeds + chat announce. Sets `HL2BL_LootLuck`/`HL2BL_ForceDrop`.
- `sv_spawner.lua` — spawn director: steady waves of enemies at traced floor
  spots near players, out of sight (no navmesh needed). `cl_variant_tag` shows
  variant nameplates.
- `sv_loot_drops.lua` — NPC death rolls a gun drop (elite/boss by max-health +
  variant luck/forced-drop) or an ammo top-up; rarity-scaled drop fanfare.
- `sv_inventory.lua` — per-player backpack + up to 4 equipped slots (capped);
  loot is picked up on **+use** (PlayerUse), not automatically; equip assigns an
  item to a free slot (toggle to unequip), re-equips on spawn; backpack + slots
  PData-persisted across maps. `InventoryAdd/Remove` helpers (slot-index fixup).
- `sv_leveling.lua` — kills grant XP (NPC-hp scaled), level raises max health,
  PData-persisted; loot rolls at the killer's level.
- `sv_economy.lua` — credits currency (kills/sell earn, buy spends), persisted.
- `sv_vendor.lua` + `entities/hl2bl_vendor.lua` + `cl_vendor.lua` — vending machine
  (+use): Buy a rotating low-rarity-skewed stock (legendary ~0.2%, so good guns
  are rare to buy) / Sell backpack guns. `RollVendorStats`, `GunPrice/GunSellPrice`
  in sh_loot. Spawn via spawn menu or `hl2bl_spawn_vendor` (superadmin).
- `sv_campaign.lua` — HL2 campaign map order + start/next commands + auto-advance.
- `cl_statcard.lua` — look-at stat card + reusable `HL2BL.DrawStatCard`.
- `cl_inventory.lua` — Derma backpack (`hl2bl_inv`) of stat cards + Equip.
- `cl_leveling_hud.lua` — level/XP bar. `cl_ammo_hud.lua` — clip/reserve + gun name.
  `cl_loot_beam.lua` — rarity loot beams.

### Console commands / cvars
- `hl2bl_inv` — open the backpack (suggest `bind i hl2bl_inv`).
- `hl2bl_rolltest [itemLevel]` — print sample rolls.
- `give hl2bl_smg` (or `_pistol/_shotgun/_rifle/_sniper`) — spawn a gun.
- `hl2bl_drop_chance <0..1>` (0.4), `hl2bl_ammo_chance <0..1>` (0.35).
- `hl2bl_spawn_enabled/interval/max/wave` — spawn director (waves scale with
  player count + avg level). `hl2bl_boss_every <N>` (5) — boss every N waves.
- `hl2bl_badass_chance <0..1>` (0.08) — variant roll chance.
- `hl2bl_campaign_start` / `hl2bl_campaign_next` (superadmin) — campaign maps.
- `hl2bl_campaign_auto <0|1>` (1) — auto-advance at level transitions.

### Adding a new gun
Add `lua/weapons/hl2bl_<x>.lua` (`SWEP.Base="hl2bl_gun_base"`, set `HL2BL_Kind`,
models, `HL2BL_Base*`, `HoldType`, `Primary.Automatic`), then add its class to
`HL2BL.LootClasses` in `sh_loot.lua`.

## Conventions

- Match GMod Lua idiom: `sh_/sv_/cl_` file prefixes, `HL2BL` global table namespace,
  `AddCSLuaFile` for client-sent files (handled by the loader in `hl2bl_init.lua`).
- Commit frequently in small units (see the hooks). No compiled artifacts are tracked.
