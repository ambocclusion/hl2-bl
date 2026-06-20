--[[ hl2bl: credits economy (server) -----------------------------------------
	Currency for vendors. Earned from kills and selling guns; spent buying guns.
	Persisted per-SteamID (PData), saved on every change.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

local START_CREDITS = 150

function HL2BL.GetCredits( ply ) return ply:GetNWInt( "hl2bl_credits", 0 ) end

function HL2BL.SaveCredits( ply )
	if IsValid( ply ) and ply:IsPlayer() then
		ply:SetPData( "hl2bl_credits", HL2BL.GetCredits( ply ) )
	end
end

function HL2BL.AddCredits( ply, amount )
	if not ( IsValid( ply ) and ply:IsPlayer() ) then return end
	ply:SetNWInt( "hl2bl_credits", math.max( 0, HL2BL.GetCredits( ply ) + amount ) )
	HL2BL.SaveCredits( ply )
end

function HL2BL.TakeCredits( ply, amount )
	if HL2BL.GetCredits( ply ) < amount then return false end
	HL2BL.AddCredits( ply, -amount )
	return true
end

hook.Add( "PlayerInitialSpawn", "hl2bl_credits_load", function( ply )
	local saved = ply:GetPData( "hl2bl_credits", nil )
	ply:SetNWInt( "hl2bl_credits", saved and ( tonumber( saved ) or 0 ) or START_CREDITS )
end )

hook.Add( "OnNPCKilled", "hl2bl_credits_kill", function( npc, attacker )
	local ply = attacker
	if IsValid( attacker ) and attacker:IsWeapon() and IsValid( attacker:GetOwner() ) then
		ply = attacker:GetOwner()
	end
	if not ( IsValid( ply ) and ply:IsPlayer() ) then return end
	local base = math.random( 3, 8 ) + ply:GetNWInt( "hl2bl_level", 1 )
	local mult = 1 + ( ( ply.HL2BL_Passive and ply.HL2BL_Passive.creditPct or 0 ) / 100 )   -- Greed artifact
	HL2BL.AddCredits( ply, math.Round( base * mult ) )
end )
