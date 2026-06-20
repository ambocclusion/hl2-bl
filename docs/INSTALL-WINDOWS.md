# HL2: Borderlands — Windows Install & Update Guide

Step-by-step instructions for installing **HL2: Borderlands** and keeping it up to date on
Windows.

---

## 1. Prerequisites

Install these from Steam / the web first:

- **Garry's Mod** (Steam) — required.
- **Half-Life 2** (Steam) — needed for HL2 maps & content. Then in GMod's main menu, open the
  **wrench/﻿game-mounting** panel and make sure **Half-Life 2** is mounted (checked).
  *(Sandbox / HL2DM maps work without it.)*
- **Git for Windows** — <https://git-scm.com/download/win>. Required to **clone** and to use
  the **auto-updater**. (If you only ever download the ZIP, you can skip it, but updating is
  easier with git.)

---

## 2. Get the files

**Recommended — clone with Git** (makes updating one click):

1. Open **Git Bash** or **PowerShell** in a folder where you keep projects, e.g.
   `C:\Mods`.
2. Run:
   ```powershell
   git clone https://github.com/ambocclusion/hl2-bl.git
   ```
   You'll get a `hl2-bl` folder.

**Alternative — download ZIP:** on the GitHub page click **Code → Download ZIP**, then extract
it somewhere permanent (e.g. `C:\Mods\hl2-bl`). *(To update later you'll either re-download or
let the updater fetch a copy via git — see step 4.)*

---

## 3. Install

1. Open the `hl2-bl\scripts` folder.
2. **Double-click `install.bat`.**

A window opens and reports something like:
```
Found Garry's Mod: C:\Program Files (x86)\Steam\steamapps\common\GarrysMod\garrysmod
Installed addon    -> ...\garrysmod\addons\hl2bl
Installed gamemode -> ...\garrysmod\gamemodes\hl2bl
HL2: Borderlands installed.
```
Press a key to close.

> **"Windows protected your PC" (SmartScreen)?** Click **More info → Run anyway**. The `.bat`
> just runs the bundled PowerShell script.

> **Couldn't find Garry's Mod?** It auto-checks every Steam library. If GMod is on a custom
> drive it still should be found; if not, open **PowerShell** in the `scripts` folder and run:
> ```powershell
> $env:GMOD_DIR = "D:\SteamLibrary\steamapps\common\GarrysMod\garrysmod"
> .\install.ps1
> ```

---

## 4. Play

1. Launch **Garry's Mod**.
2. **New Game** → set **Gamemode** to **"HL2: Borderlands"** → choose a map
   (`gm_construct`, or an HL2 map like `d2_coast_03`).
3. You spawn unarmed — walk to the **vending machine at spawn** (press **E**) and buy a gun
   with your starting credits.

**Controls:** **E** loot/use · **I** backpack · **1–4** switch equipped guns.

---

## 5. Keep it up to date

Whenever a new version is released:

- **Double-click `scripts\update.bat`.**

It pulls the latest from GitHub and reinstalls automatically, then asks you to restart GMod.

How it behaves:
- If you **cloned** the repo, it updates that clone in place (`git pull`).
- If you used the **ZIP**, it keeps a small managed clone under
  `%LOCALAPPDATA%\hl2bl-src` and updates from there (this needs **Git for Windows**).

In-game, server superadmins get a chat notice when an update is available. Disable the check
with `hl2bl_update_check 0` in console.

> **`update.bat` says git isn't found?** Install **Git for Windows** (step 1) and try again.

---

## 6. Uninstall

Delete these two folders inside your GMod `garrysmod` directory:
```
garrysmod\addons\hl2bl
garrysmod\gamemodes\hl2bl
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Gamemode not in the New Game list | Re-run `install.bat`, then fully restart Garry's Mod. |
| "running scripts is disabled on this system" | Use the `.bat` files (they bypass policy). To run a `.ps1` directly: `powershell -ExecutionPolicy Bypass -File .\install.ps1`. |
| HL2 maps/textures missing (errors/pink checkerboard) | Install Half-Life 2 and mount it in GMod's game-mounting menu. |
| Installed but no guns drop | You must be on the **HL2: Borderlands** gamemode (not Sandbox). |
| Update does nothing / errors | Ensure **Git for Windows** is installed and on PATH. |
