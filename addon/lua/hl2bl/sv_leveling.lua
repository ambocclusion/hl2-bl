--[[ hl2bl: leveling (server) ------------------------------------------------
	Kills grant XP; leveling raises max health and the level used for loot rolls.
	Persisted per-SteamID via PData so progress survives reconnects.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

local function applyLevelStats( ply )
	local lvl = ply:GetNWInt( "hl2bl_level", 1 )
	ply:SetMaxHealth( 100 + ( lvl - 1 ) * 10 )
	-- Let artifacts re-add their bonuses (e.g. Vitality max-HP) on top.
	if HL2BL.RecomputePassive then HL2BL.RecomputePassive( ply ) end
end

local function store( ply, lvl, xp )
	ply:SetNWInt( "hl2bl_level", lvl )
	ply:SetNWInt( "hl2bl_xp", xp )
	ply:SetPData( "hl2bl_level", lvl )
	ply:SetPData( "hl2bl_xp", xp )
	applyLevelStats( ply )
end

function HL2BL.GiveXP( ply, amount )
	if not ( IsValid( ply ) and ply:IsPlayer() ) then return end

	local lvl     = ply:GetNWInt( "hl2bl_level", 1 )
	local xp      = ply:GetNWInt( "hl2bl_xp", 0 ) + amount
	local leveled = false

	while lvl < HL2BL.MaxLevel and xp >= HL2BL.XPForLevel( lvl ) do
		xp = xp - HL2BL.XPForLevel( lvl )
		lvl = lvl + 1
		leveled = true
	end
	if lvl >= HL2BL.MaxLevel then xp = 0 end

	store( ply, lvl, xp )

	if leveled then
		ply:SetHealth( ply:GetMaxHealth() )
		ply:ChatPrint( string.format( "[HL2BL] Level up! You are now level %d.", lvl ) )
		ply:EmitSound( "buttons/bell1.wav" )
	end
end

-- Persist current level/xp (PData -> sv.db). Safe to call any time.
function HL2BL.SaveLevel( ply )
	if not ( IsValid( ply ) and ply:IsPlayer() ) then return end
	ply:SetPData( "hl2bl_level", ply:GetNWInt( "hl2bl_level", 1 ) )
	ply:SetPData( "hl2bl_xp",    ply:GetNWInt( "hl2bl_xp", 0 ) )
end

hook.Add( "PlayerInitialSpawn", "hl2bl_level_load", function( ply )
	ply:SetNWInt( "hl2bl_level", tonumber( ply:GetPData( "hl2bl_level", "1" ) ) or 1 )
	ply:SetNWInt( "hl2bl_xp",    tonumber( ply:GetPData( "hl2bl_xp", "0" ) ) or 0 )
end )

hook.Add( "PlayerDisconnected", "hl2bl_level_save", HL2BL.SaveLevel )

hook.Add( "PlayerSpawn", "hl2bl_level_apply", function( ply )
	applyLevelStats( ply )
	timer.Simple( 0.1, function()
		if IsValid( ply ) and ply:Alive() then ply:SetHealth( ply:GetMaxHealth() ) end
	end )
end )

hook.Add( "OnNPCKilled", "hl2bl_xp", function( npc, attacker, inflictor )
	if not IsValid( attacker ) then return end

	-- OnNPCKilled's attacker is the killing entity; resolve weapon -> owner.
	local ply = attacker
	if attacker:IsWeapon() and IsValid( attacker:GetOwner() ) then ply = attacker:GetOwner() end
	if not ( IsValid( ply ) and ply:IsPlayer() ) then return end

	local hp = npc:GetMaxHealth()
	local xp   = math.max( 5, math.Round( ( hp > 0 and hp or 30 ) * 0.5 ) )
	local mult = 1 + ( ( ply.HL2BL_Passive and ply.HL2BL_Passive.xpPct or 0 ) / 100 )   -- Scholar artifact
	HL2BL.GiveXP( ply, math.Round( xp * mult ) )
end )
