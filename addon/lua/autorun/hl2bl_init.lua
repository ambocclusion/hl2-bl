--[[ hl2bl: addon entry point ------------------------------------------------
	Runs in both realms (server + each client). Loads the hl2bl modules with
	correct realm handling. File-name convention: sh_ shared, sv_ server-only,
	cl_ client-only.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}
HL2BL.Version = "0.1.0"

-- Module manifest, in load order. Realm is one of "shared"/"server"/"client";
-- include() searches the lua/ path, so paths are relative to lua/. This list is
-- the single source of truth for both initial load and hot reload (hl2bl_reload).
HL2BL.Modules = {
	-- Shared
	{ "shared", "hl2bl/sh_archetypes.lua" },
	{ "shared", "hl2bl/sh_progression.lua" },
	{ "shared", "hl2bl/sh_enemies.lua" },
	{ "shared", "hl2bl/sh_loot.lua" },
	{ "shared", "hl2bl/sh_armor.lua" },
	{ "shared", "hl2bl/sh_artifacts.lua" },
	-- Server
	{ "server", "hl2bl/sv_variants.lua" },
	{ "server", "hl2bl/sv_spawner.lua" },
	{ "server", "hl2bl/sv_loot_drops.lua" },
	{ "server", "hl2bl/sv_boxloot.lua" },
	{ "server", "hl2bl/sv_leveling.lua" },
	{ "server", "hl2bl/sv_inventory.lua" },
	{ "server", "hl2bl/sv_artifacts.lua" },
	{ "server", "hl2bl/sv_armor.lua" },
	{ "server", "hl2bl/sv_economy.lua" },
	{ "server", "hl2bl/sv_vendor.lua" },
	{ "server", "hl2bl/sv_vehicle_seats.lua" },
	{ "server", "hl2bl/sv_campaign.lua" },
	{ "server", "hl2bl/sv_updatecheck.lua" },
	{ "server", "hl2bl/sv_debug.lua" },
	-- Client
	{ "client", "hl2bl/cl_statcard.lua" },
	{ "client", "hl2bl/cl_artifacts.lua" },
	{ "client", "hl2bl/cl_leveling_hud.lua" },
	{ "client", "hl2bl/cl_inventory.lua" },
	{ "client", "hl2bl/cl_loot_beam.lua" },
	{ "client", "hl2bl/cl_ammo_hud.lua" },
	{ "client", "hl2bl/cl_slotbar.lua" },
	{ "client", "hl2bl/cl_variant_tag.lua" },
	{ "client", "hl2bl/cl_playernames.lua" },
	{ "client", "hl2bl/cl_health_bars.lua" },
	{ "client", "hl2bl/cl_boss_hud.lua" },
	{ "client", "hl2bl/cl_vendor.lua" },
	{ "client", "hl2bl/cl_debug.lua" },
}

-- Load one module for the current realm. On the server, "shared"/"client" files
-- are also AddCSLuaFile'd so clients receive them.
local function loadModule( realm, path )
	if realm == "shared" then
		if SERVER then AddCSLuaFile( path ) end
		include( path )
	elseif realm == "client" then
		if SERVER then AddCSLuaFile( path ) else include( path ) end
	elseif realm == "server" then
		if SERVER then include( path ) end
	end
end

-- (Re)load every module in the manifest for the current realm. Re-running an
-- include() simply re-executes the file, so this picks up edits on disk; modules
-- use stable hook/net/concommand identifiers, so re-registering replaces in place.
function HL2BL.LoadModules()
	for _, m in ipairs( HL2BL.Modules ) do
		loadModule( m[1], m[2] )
	end
end

HL2BL.LoadModules()

print( "[HL2BL] v" .. HL2BL.Version .. " loaded (" .. ( SERVER and "server" or "client" ) .. ")" )

-- Hot reload --------------------------------------------------------------------
-- hl2bl_reload re-executes every module from disk without a map change. On a
-- listen server the host's client realm reads the same symlinked files, so the
-- server reloads its realm then tells connected clients to reload theirs.
if SERVER then
	util.AddNetworkString( "HL2BL_Reload" )

	concommand.Add( "hl2bl_reload", function( ply )
		-- Allow from the dedicated/listen console (ply == NULL) or a superadmin.
		if IsValid( ply ) and not ply:IsSuperAdmin() then
			ply:ChatPrint( "[HL2BL] hl2bl_reload requires superadmin." )
			return
		end
		HL2BL.LoadModules()
		print( "[HL2BL] reloaded server + shared modules" )
		net.Start( "HL2BL_Reload" )
		net.Broadcast()
	end, nil, "hl2bl: re-execute all modules from disk (server + connected clients)." )
else
	net.Receive( "HL2BL_Reload", function()
		HL2BL.LoadModules()
		print( "[HL2BL] reloaded client + shared modules" )
	end )

	-- Let a client trigger a reload locally too (useful on a listen-server host).
	concommand.Add( "hl2bl_reload_cl", function()
		HL2BL.LoadModules()
		print( "[HL2BL] reloaded client + shared modules (local)" )
	end, nil, "hl2bl: re-execute client + shared modules locally." )
end

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
