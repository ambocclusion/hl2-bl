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

- **`main`** — ACTIVE and published to `origin` (git@github.com:ambocclusion/hl2-bl.git).
  Clean project-only history (orphan root); this is where work happens and what's pushed.
- `gmod` — local-only; the granular development history (commit-by-commit), built atop a
  shallow `source-sdk-2013` clone so it **can't be pushed**. Kept for reference.
- `hl2bl-coop` — local-only; the abandoned C++ HL2MP exploration (the `src/`, `game/` SDK
  tree lives here, gitignored elsewhere).
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
scripts/install.sh         # END-USER install: COPIES addon+gamemode into GMod
                           #   (auto-detects GMod across Steam libraries; survives
                           #    moving/deleting the repo). Override: GMOD_DIR=...
scripts/update.sh          # pull latest from git + reinstall (auto-updater)
scripts/install-hooks.sh   # one-time: core.hooksPath=.githooks
scripts/deploy.sh          # DEV: symlink addon/ -> addons/hl2bl AND gamemodes/ (live edits)
# Windows: each script has a .ps1 equivalent (+ double-click .bat wrapper):
#   install.ps1/.bat, update.ps1/.bat, deploy.ps1/.bat, run.ps1/.bat, install-hooks.ps1/.bat
# In-game: sv_updatecheck.lua warns superadmins (via GitHub version.txt) when an
#   update is available; hl2bl_update_check 0 to disable.
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
- `sv_variants.lua` — every hostile NPC gets a **derived enemy level** = nearest
  player level +1 (boss +3), stored on `npc.HL2BL_Level` and networked as
  `hl2bl_npclevel`. That single value is the parent both its health
  (`EnemyHealthScale`) and its outgoing damage (`LevelScale`, via an
  `EntityTakeDamage` hook scaled by `hl2bl_npc_dmg_scale`) derive from — neither
  reads player level directly. NPCs may also roll a variant: Badass (5x hp, big,
  guaranteed great loot), Armored, Runner; tints/scales/speeds + chat announce.
  Sets `HL2BL_LootLuck`/`HL2BL_ForceDrop`. The level math lives in
  `sh_progression.lua` (`EnemyLevel`/`EnemyHealthScale`).
- `sv_spawner.lua` — **encounter director**: moving into a new area spawns a finite
  budget of enemies (with variance) over a few ticks at traced floor spots out of
  sight, then STOPS once cleared; next area starts the next encounter after a
  cooldown. Clear performance (deaths/health/speed) drives `HL2BL.Difficulty`,
  which sizes future encounters. Boss every N encounters. `cl_variant_tag` shows
  variant nameplates.
- `sv_loot_drops.lua` — NPC death rolls a gun drop (elite/boss by max-health +
  variant luck/forced-drop) or an ammo top-up; rarity-scaled drop fanfare.
- `sv_inventory.lua` — per-player backpack of **mixed items** (each `kind`-tagged
  "weapon"/"armor") + up to 4 equipped weapon slots and 4 HEV armor slots; loot is
  picked up on **+use**; `hl2bl_inv_equip` routes armor to `EquipArmor`, weapons to
  the slot system; backpack + both slot maps PData-persisted. Sync writes weapon
  slots + armor slots + items via `HL2BL.NetWriteItem` (kind dispatch).
- `sh_armor.lua` + `sv_armor.lua` + `entities/hl2bl_armor.lua` — **HEV armor** loot.
  4 slots (Helmet/Vest/Greaves/Power Core); pieces roll a variety of `maxArmor`
  (blue suit bar), `maxHealth`, `regen` (HP/s, scales off level), biased by slot +
  HL2-faction source (Black Mesa / Combine / Civil Protection / Resistance / Synth).
  Effects fold into `HL2BL.RecomputePassive` (the single max-hp/armor/regen
  authority in sv_artifacts) so level + artifacts + armor stack. The blue bar
  refills **only on spawn** (anti-abuse: equipping never tops it up). World pickup
  is the suit-battery model, +use → `GiveArmor`.
- `sv_leveling.lua` — kills grant XP (NPC-hp scaled), level raises max health,
  PData-persisted; loot rolls at the killer's level.
- `sv_economy.lua` — credits currency (kills/sell earn, buy spends), persisted.
- `sv_vendor.lua` + `entities/hl2bl_vendor.lua` + `cl_vendor.lua` — vending machine
  (+use): Buy a rotating low-rarity-skewed stock (legendary ~0.2%, so good guns
  are rare to buy) / Sell backpack guns. `RollVendorStats`, `GunPrice/GunSellPrice`
  in sh_loot. Spawn via spawn menu or `hl2bl_spawn_vendor` (superadmin).
- `sv_campaign.lua` — HL2 campaign map order + start/next commands + auto-advance.
- `sv_vehicle_seats.lua` — bolts up to 3 passenger seats (`prop_vehicle_prisoner_pod`,
  parented + local offsets per class) onto HL2 airboats/buggies so co-op players ride
  along and **fire their handheld weapons** from the seats (pods, unlike the locked
  driver seat, allow weapon use). Attaches on `OnEntityCreated` + a startup sweep.
- `cl_statcard.lua` — look-at card + reusable `HL2BL.DrawStatCard` / `DrawArmorCard`.
- `cl_inventory.lua` — two-pane inventory (`hl2bl_inv`): left equipment paper-doll
  (4 weapon + 4 armor slot tiles, click to unequip), right category tabs
  (Weapons / Armor) of stat cards with Equip / Drop.
- `cl_leveling_hud.lua` — level/XP bar. `cl_ammo_hud.lua` — clip/reserve + gun name.
  `cl_loot_beam.lua` — rarity loot beams.

### Console commands / cvars
- `hl2bl_inv` — open the inventory (weapons + armor; suggest `bind i hl2bl_inv`).
- `hl2bl_give_armor [helmet|vest|greaves|core] [level]` — spawn a rolled armor piece
  into your backpack (superadmin; random slot if omitted).
- `hl2bl_debug` — debug menu: **Reset my save** (own data, always allowed) + cheats
  (credits, set level, spawn gun by rarity, spawn vendor, toggle spawning).
- Pickup rule (sv_inventory `PlayerCanPickupWeapon`): only HL2BL loot (via +use) and
  our slot weapons are pickable; vanilla NPC/map weapons are blocked.
- `hl2bl_rolltest [itemLevel]` — print sample rolls.
- `give hl2bl_smg` (or `_pistol/_shotgun/_rifle/_sniper`) — spawn a gun.
- `hl2bl_drop_chance <0..1>` (0.4), `hl2bl_ammo_chance <0..1>` (0.35),
  `hl2bl_armor_chance <0..1>` (0.12) — armor drop chance (boss/elite boosted).
- `hl2bl_spawn_enabled` + encounter director: `hl2bl_encounter_base/max/cooldown/
  travel`, `hl2bl_director_tick`, `hl2bl_spawn_wave` (per-tick), `hl2bl_spawn_max`
  (concurrent cap), `hl2bl_boss_every <N>` (boss every N encounters).
- `hl2bl_badass_chance <0..1>` (0.08) — variant roll chance.
- `hl2bl_npc_dmg_scale <0..>` (1) — how strongly enemy damage scales with enemy
  level (1 = full `LevelScale` curve, 0 = enemies deal base damage).
- `hl2bl_campaign_start` / `hl2bl_campaign_next` (superadmin) — campaign maps.
- `hl2bl_campaign_auto <0|1>` (1) — auto-advance at level transitions.
- `hl2bl_vehicle_seats <0|1>` (1) — bolt 3 passenger seats onto airboats/buggies
  (co-op riders can sit and shoot their handheld weapon).

### Adding a new gun
Add `lua/weapons/hl2bl_<x>.lua` (`SWEP.Base="hl2bl_gun_base"`, set `HL2BL_Kind`,
models, `HL2BL_Base*`, `HoldType`, `Primary.Automatic`), then add its class to
`HL2BL.LootClasses` in `sh_loot.lua`.

## Conventions

- Match GMod Lua idiom: `sh_/sv_/cl_` file prefixes, `HL2BL` global table namespace,
  `AddCSLuaFile` for client-sent files (handled by the loader in `hl2bl_init.lua`).
- Commit frequently in small units (see the hooks). No compiled artifacts are tracked.
- **Balance tables are duplicated docs — keep them in sync.** The "Weapon stats &
  scaling" tables in `README.md` are hand-computed means from the roll/scaling
  formulas. If you change base stats (`sh_archetypes.lua`), rarity/element rolls or
  manufacturer biases (`sh_loot.lua` `buildStats`/`Manufacturers`), or the level
  curve (`sh_progression.lua` `LevelScale`/`XPForLevel`), recompute and update those
  README tables in the same change. (Better long-term: emit the tables from the
  formulas so there's a single source of truth.)
