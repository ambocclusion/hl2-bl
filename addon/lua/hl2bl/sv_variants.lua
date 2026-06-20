--[[ hl2bl: enemy variants (server) ------------------------------------------
	Every hostile NPC that spawns is scaled to player level and has a chance to
	become a special variant (Badass, Armored, Runner). Variants are tankier/
	bigger/faster, tinted, and drop better loot (via HL2BL_LootLuck / ForceDrop
	read by sv_loot_drops; their high max-health also triggers elite/boss loot).
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

HL2BL.BadassChance = CreateConVar( "hl2bl_badass_chance", "0.08", FCVAR_ARCHIVE,
	"Chance a hostile NPC becomes a Badass." )

-- Hostile classes we augment (friendlies like citizens/vortigaunts excluded).
HL2BL.EnemyClasses = {
	npc_combine_s = true, npc_metropolice = true, npc_manhack = true,
	npc_antlion = true, npc_antlionguard = true, npc_stalker = true, npc_hunter = true,
	npc_zombie = true, npc_fastzombie = true, npc_poisonzombie = true, npc_zombine = true,
	npc_headcrab = true, npc_headcrab_fast = true, npc_headcrab_black = true,
}

-- Variant definitions (rolled after the Badass check).
local VARIANTS = {
	badass  = { id = "Badass",  hp = 5.0, scale = 1.4, speed = 1.0, luck = 0.25, force = true,
	            color = Color( 255, 80, 80 ),  announce = true },
	armored = { id = "Armored", hp = 2.4, scale = 1.2, speed = 0.85, luck = 0.10, force = false,
	            color = Color( 170, 170, 185 ) },
	runner  = { id = "Runner",  hp = 0.8, scale = 0.9, speed = 1.45, luck = 0.05, force = false,
	            color = Color( 120, 230, 230 ) },
}

local function nearestPlayerLevel( ent )
	local best, bestd = 1, math.huge
	for _, ply in ipairs( player.GetAll() ) do
		local d = ply:GetPos():DistToSqr( ent:GetPos() )
		if d < bestd then bestd, best = d, ply:GetNWInt( "hl2bl_level", 1 ) end
	end
	return best
end

function HL2BL.ApplyVariant( npc )
	if not IsValid( npc ) or npc.HL2BL_Variant then return end
	npc.HL2BL_Variant = "normal"

	local lvl     = nearestPlayerLevel( npc )
	local baseHP  = npc:GetMaxHealth(); if baseHP <= 0 then baseHP = math.max( 1, npc:Health() ) end
	local lvlMult = 1 + ( lvl - 1 ) * 0.05

	-- Roll a variant.
	local r = math.random()
	local v
	if r < HL2BL.BadassChance:GetFloat() then       v = VARIANTS.badass
	elseif r < HL2BL.BadassChance:GetFloat() + 0.06 then v = VARIANTS.armored
	elseif r < HL2BL.BadassChance:GetFloat() + 0.18 then v = VARIANTS.runner end

	local hp = math.ceil( baseHP * lvlMult * ( v and v.hp or 1 ) )
	npc:SetMaxHealth( hp )
	npc:SetHealth( hp )

	if v then
		npc.HL2BL_Variant   = v.id
		npc.HL2BL_LootLuck  = v.luck
		npc.HL2BL_ForceDrop = v.force
		npc:SetNWString( "hl2bl_variant", v.id )   -- for the client nameplate
		npc:SetModelScale( v.scale, 0 )
		if v.color then npc:SetColor( v.color ) end
		if v.speed then npc:SetLaggedMovementValue( v.speed ) end

		if v.announce then
			for _, ply in ipairs( player.GetAll() ) do
				ply:ChatPrint( "[HL2BL] A Badass " .. npc:GetClass():gsub( "npc_", "" ) .. " has appeared!" )
			end
		end
	end
end

-- ---- bosses ----------------------------------------------------------------
-- Turn an NPC into the wave boss: huge health, big, gold, guaranteed legendary
-- drops, networked health bar. Called by the spawn director.
function HL2BL.MakeBoss( npc, level )
	if not IsValid( npc ) then return end
	npc.HL2BL_Variant = "Boss"

	local baseHP = npc:GetMaxHealth(); if baseHP <= 0 then baseHP = math.max( 1, npc:Health() ) end
	local hp = math.ceil( baseHP * ( 12 + level * 0.5 ) )
	npc:SetMaxHealth( hp )
	npc:SetHealth( hp )
	npc:SetModelScale( 1.8, 0 )
	npc:SetColor( Color( 255, 210, 90 ) )

	npc.HL2BL_IsBoss     = true
	npc.HL2BL_ForceDrop  = true
	npc.HL2BL_ForceRarity = HL2BL.Rarity.LEGENDARY
	npc.HL2BL_LootLuck   = 0.5

	local name = "Boss " .. npc:GetClass():gsub( "npc_", "" ):gsub( "^%l", string.upper )
	npc:SetNWBool( "hl2bl_isboss", true )
	npc:SetNWString( "hl2bl_boss_name", name )
	npc:SetNWInt( "hl2bl_boss_maxhp", hp )
	npc:SetNWInt( "hl2bl_boss_hp", hp )

	HL2BL._Boss = npc
	for _, ply in ipairs( player.GetAll() ) do
		ply:ChatPrint( "[HL2BL] *** " .. name .. " has entered the fight! ***" )
		ply:EmitSound( "ambient/levels/labs/electric_explosion4.wav", 80, 90 )
	end
end

-- Keep the boss's networked health current for the client bar.
hook.Add( "Think", "hl2bl_boss_hp", function()
	local b = HL2BL._Boss
	if IsValid( b ) and b:Health() > 0 then
		if ( b.HL2BL_NextHP or 0 ) < CurTime() then
			b.HL2BL_NextHP = CurTime() + 0.2
			b:SetNWInt( "hl2bl_boss_hp", math.max( 0, b:Health() ) )
		end
	end
end )

hook.Add( "OnNPCKilled", "hl2bl_boss_death", function( npc, attacker )
	if IsValid( npc ) and npc.HL2BL_IsBoss then
		HL2BL._Boss = nil
		npc:SetNWBool( "hl2bl_isboss", false )
		npc:SetNWInt( "hl2bl_boss_hp", 0 )
		for _, ply in ipairs( player.GetAll() ) do
			ply:ChatPrint( "[HL2BL] *** Boss defeated! ***" )
		end
	end
end )

hook.Add( "OnEntityCreated", "hl2bl_variants", function( ent )
	timer.Simple( 0, function()
		if not IsValid( ent ) or not ent:IsNPC() then return end
		if not HL2BL.EnemyClasses[ ent:GetClass() ] then return end
		HL2BL.ApplyVariant( ent )
	end )
end )

-- Badass kill feed.
hook.Add( "OnNPCKilled", "hl2bl_variant_killfeed", function( npc, attacker )
	if IsValid( npc ) and npc.HL2BL_Variant == "Badass" then
		local who = ( IsValid( attacker ) and attacker:IsPlayer() ) and attacker:Nick()
			or ( IsValid( attacker ) and IsValid( attacker:GetOwner() ) and attacker:GetOwner():Nick() ) or nil
		for _, ply in ipairs( player.GetAll() ) do
			ply:ChatPrint( "[HL2BL] Badass down!" .. ( who and ( " (" .. who .. ")" ) or "" ) )
		end
	end
end )
