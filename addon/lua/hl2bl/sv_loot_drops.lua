--[[ hl2bl: loot + ammo drops (server) ---------------------------------------
	NPC death rolls for a gun drop (rarity/level scaled, better for elites) or,
	failing that, an ammo top-up for the killer's active gun.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

HL2BL.DropChance = CreateConVar( "hl2bl_drop_chance", "0.4", FCVAR_ARCHIVE,
	"Base chance (0-1) an NPC drops a gun on death." )
HL2BL.AmmoChance = CreateConVar( "hl2bl_ammo_chance", "0.35", FCVAR_ARCHIVE,
	"Chance an NPC that didn't drop a gun tops up the killer's ammo." )

-- Sound played at the drop, by rarity (louder/grander for higher tiers).
local RARITY_SOUND = {
	[0] = nil,
	[1] = "items/ammo_pickup.wav",
	[2] = "buttons/bell1.wav",
	[3] = "items/suitchargeok1.wav",
	[4] = "ambient/levels/labs/electric_explosion4.wav",
}

-- Drop fanfare: sound at the item + a server-wide shout for epic/legendary.
function HL2BL.AnnounceDrop( ent, stats, finder )
	local snd = RARITY_SOUND[ stats.rarity ]
	if snd then ent:EmitSound( snd, 80, 100 ) end

	if stats.rarity >= HL2BL.Rarity.EPIC then
		local who  = IsValid( finder ) and finder:Nick() or "Someone"
		local name = ent:GetNWString( "hl2bl_name", "a gun" )
		for _, p in ipairs( player.GetAll() ) do
			p:ChatPrint( string.format( "[HL2BL] %s found a %s: %s!",
				who, HL2BL.RarityName[ stats.rarity ], name ) )
			-- Legendary gets a ping everyone can hear.
			if stats.rarity >= HL2BL.Rarity.LEGENDARY then
				p:EmitSound( "ambient/levels/labs/teleport_postblast_thunder1.wav", 75, 120 )
			end
		end
	end
end

-- Resolve the player credited with a kill (attacker may be their weapon).
local function killerPlayer( attacker )
	if not IsValid( attacker ) then return nil end
	if attacker:IsPlayer() then return attacker end
	if attacker:IsWeapon() and IsValid( attacker:GetOwner() ) and attacker:GetOwner():IsPlayer() then
		return attacker:GetOwner()
	end
	return nil
end

hook.Add( "OnNPCKilled", "hl2bl_loot_drops", function( npc, attacker, inflictor )
	if not IsValid( npc ) then return end

	local ply  = killerPlayer( attacker )
	local lvl  = ( ply and ply:GetNWInt( "hl2bl_level", 1 ) ) or 1
	local hp   = npc:GetMaxHealth()

	-- Elite / boss scaling off the NPC's toughness.
	local elite, boss = hp >= 80, hp >= 200
	local dropChance = HL2BL.DropChance:GetFloat() * ( boss and 4 or elite and 2 or 1 )
	local luck       = ( boss and 0.25 or elite and 0.12 or 0 ) + ( npc.HL2BL_LootLuck or 0 )
	local itemLevel  = lvl + ( boss and 3 or elite and 1 or 0 )

	-- Badass / forced-drop variants always drop.
	if npc.HL2BL_ForceDrop then dropChance = 1 end

	-- Spawn one rolled gun at the corpse.
	local function dropGun( forceRarity )
		local pool  = HL2BL.LootClasses
		local class = pool[ math.random( #pool ) ]
		local w = ents.Create( class )
		if not IsValid( w ) then return end

		w:SetPos( npc:WorldSpaceCenter() + Vector( 0, 0, 8 ) )
		w:SetAngles( AngleRand() )
		w.HL2BL_IsLoot = true
		w:Spawn()

		local stats = HL2BL.RollStats( itemLevel, luck, forceRarity )
		if w.ApplyStats then w:ApplyStats( stats ) end

		local phys = w:GetPhysicsObject()
		if IsValid( phys ) then phys:SetVelocity( VectorRand() * 60 + Vector( 0, 0, 100 ) ) end

		HL2BL.AnnounceDrop( w, stats, ply )
	end

	-- Bosses burst a pile of loot, one guaranteed legendary.
	if npc.HL2BL_IsBoss then
		dropGun( HL2BL.Rarity.LEGENDARY )
		for _ = 1, 3 do dropGun() end
		return
	end

	if math.random() <= dropChance then
		dropGun( npc.HL2BL_ForceRarity )
		return
	end

	-- No gun: chance to top up the killer's active gun ammo.
	if ply and math.random() <= HL2BL.AmmoChance:GetFloat() then
		local wep = ply:GetActiveWeapon()
		if IsValid( wep ) and wep.AddReserve then
			wep:AddReserve( math.Round( ( wep.HL2BL_BaseClip or 20 ) * 2 ) )
			ply:EmitSound( "items/ammo_pickup.wav", 55, 120, 0.5 )
		end
	end
end )
