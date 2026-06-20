--[[ hl2bl: addon entry point ------------------------------------------------
	Runs in both realms (server + each client). Loads the hl2bl modules with
	correct realm handling. File-name convention: sh_ shared, sv_ server-only,
	cl_ client-only.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}
HL2BL.Version = "0.1.0"

-- include() searches the lua/ path, so module paths are relative to lua/.
local function loadShared( path )
	if SERVER then AddCSLuaFile( path ) end
	include( path )
end

local function loadClient( path )
	if SERVER then AddCSLuaFile( path ) return end
	include( path )
end

local function loadServer( path )
	if SERVER then include( path ) end
end

-- Shared
loadShared( "hl2bl/sh_archetypes.lua" )
loadShared( "hl2bl/sh_progression.lua" )
loadShared( "hl2bl/sh_loot.lua" )

-- Server
loadServer( "hl2bl/sv_variants.lua" )
loadServer( "hl2bl/sv_spawner.lua" )
loadServer( "hl2bl/sv_loot_drops.lua" )
loadServer( "hl2bl/sv_leveling.lua" )
loadServer( "hl2bl/sv_inventory.lua" )
loadServer( "hl2bl/sv_economy.lua" )
loadServer( "hl2bl/sv_vendor.lua" )
loadServer( "hl2bl/sv_campaign.lua" )
loadServer( "hl2bl/sv_updatecheck.lua" )

-- Client
loadClient( "hl2bl/cl_statcard.lua" )
loadClient( "hl2bl/cl_leveling_hud.lua" )
loadClient( "hl2bl/cl_inventory.lua" )
loadClient( "hl2bl/cl_loot_beam.lua" )
loadClient( "hl2bl/cl_ammo_hud.lua" )
loadClient( "hl2bl/cl_slotbar.lua" )
loadClient( "hl2bl/cl_variant_tag.lua" )
loadClient( "hl2bl/cl_boss_hud.lua" )
loadClient( "hl2bl/cl_vendor.lua" )

print( "[HL2BL] v" .. HL2BL.Version .. " loaded (" .. ( SERVER and "server" or "client" ) .. ")" )

-- Quick verification command (registered in both realms so it works from the
-- client console in-game). Note: addon Lua only loads once a map is running,
-- so this command won't exist at the main menu.
concommand.Add( "hl2bl_rolltest", function( ply, cmd, args )
	local lvl = tonumber( args[1] ) or 1
	local realm = SERVER and "server" or "client"
	for i = 1, 3 do
		local s = HL2BL.RollStats( lvl )
		print( string.format(
			"[HL2BL/%s] roll %d: %s (Lv %d) element=%s  dmg x%.2f rof x%.2f spread x%.2f reload x%.2f mag x%.2f",
			realm, i, HL2BL.RarityName[s.rarity], s.itemLevel, HL2BL.ElementName[s.element],
			s.damageMult, s.fireRateMult, s.spreadMult, s.reloadMult, s.magMult ) )
	end
end, nil, "hl2bl: roll and print sample gun stats. Usage: hl2bl_rolltest [itemLevel]" )
