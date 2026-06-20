--[[ hl2bl: debug menu backend (server) --------------------------------------
	Handles debug actions. "reset" wipes only the caller's own save and is always
	allowed; the rest are cheats gated behind sv_cheats / superadmin / singleplayer.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

util.AddNetworkString( "hl2bl_debug" )

local function canCheat( ply )
	return game.SinglePlayer() or ply:IsSuperAdmin()
		or ( GetConVar( "sv_cheats" ) and GetConVar( "sv_cheats" ):GetBool() )
end

local function resetSave( ply )
	for _, k in ipairs( { "hl2bl_inv", "hl2bl_level", "hl2bl_xp", "hl2bl_credits" } ) do
		ply:RemovePData( k )
	end
	for i = 1, HL2BL.MAX_SLOTS do ply:StripWeapon( "hl2bl_slot" .. i ) end

	ply.HL2BL_Inv      = {}
	ply.HL2BL_Slots    = {}
	ply.HL2BL_Equipped = nil

	ply:SetNWInt( "hl2bl_level", 1 )
	ply:SetNWInt( "hl2bl_xp", 0 )
	ply:SetNWInt( "hl2bl_credits", 150 )
	ply:SetMaxHealth( 100 )
	if ply:Alive() then ply:SetHealth( 100 ) end

	if HL2BL.SyncInventory then HL2BL.SyncInventory( ply ) end
	if HL2BL.GiveStarterCrowbar then
		HL2BL.GiveStarterCrowbar( ply )
		ply:SelectWeapon( "hl2bl_crowbar" )
	end
	ply:ChatPrint( "[HL2BL] Your save has been reset." )
end

net.Receive( "hl2bl_debug", function( _, ply )
	local action = net.ReadString()
	local arg    = net.ReadFloat()

	if action == "reset" then resetSave( ply ); return end   -- own data, always allowed

	if not canCheat( ply ) then
		ply:ChatPrint( "[HL2BL] Debug actions require sv_cheats 1 or admin." )
		return
	end

	if action == "credits" then
		HL2BL.AddCredits( ply, 1000 )

	elseif action == "setlevel" then
		local lvl = math.Clamp( math.floor( arg ), 1, HL2BL.MaxLevel )
		ply:SetNWInt( "hl2bl_level", lvl )
		ply:SetNWInt( "hl2bl_xp", 0 )
		ply:SetMaxHealth( 100 + ( lvl - 1 ) * 10 )
		if HL2BL.SaveLevel then HL2BL.SaveLevel( ply ) end

	elseif action == "spawngun" then
		local rarity = math.Clamp( math.floor( arg ), 0, HL2BL.RARITY_COUNT - 1 )
		local w = ents.Create( HL2BL.LootClasses[ math.random( #HL2BL.LootClasses ) ] )
		if IsValid( w ) then
			w:SetPos( ply:GetEyeTrace().HitPos + Vector( 0, 0, 24 ) )
			w.HL2BL_IsLoot = true
			w:Spawn()
			if w.ApplyStats then w:ApplyStats( HL2BL.RollStats( ply:GetNWInt( "hl2bl_level", 1 ), 0, rarity ) ) end
		end

	elseif action == "vendor" then
		local v = ents.Create( "hl2bl_vendor" )
		if IsValid( v ) then v:SetPos( ply:GetEyeTrace().HitPos ); v:Spawn() end

	elseif action == "togglespawn" then
		local on = GetConVar( "hl2bl_spawn_enabled" ):GetBool()
		RunConsoleCommand( "hl2bl_spawn_enabled", on and "0" or "1" )
		ply:ChatPrint( "[HL2BL] Enemy spawning " .. ( on and "OFF" or "ON" ) )
	end
end )
