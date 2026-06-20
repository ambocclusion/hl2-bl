--[[ hl2bl: breakable loot (server) ------------------------------------------
	Destroyable boxes/crates have a chance to contain loot. When a breakable is
	about to be destroyed, roll for a gun (mostly) or, rarely, an artifact.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

HL2BL.BoxLootChance = CreateConVar( "hl2bl_box_loot_chance", "0.35", FCVAR_ARCHIVE,
	"Chance a destroyed breakable box/crate contains loot." )

-- Entity classes treated as "destroyable boxes".
local BREAKABLE = {
	func_breakable          = true,
	func_physbox            = true,
	prop_physics            = true,
	prop_physics_multiplayer = true,
	prop_physics_override    = true,
	item_item_crate          = true,
}

local function lootLevel( attacker )
	if IsValid( attacker ) and attacker:IsWeapon() and IsValid( attacker:GetOwner() ) then
		attacker = attacker:GetOwner()
	end
	if IsValid( attacker ) and attacker:IsPlayer() then return attacker:GetNWInt( "hl2bl_level", 1 ) end
	local best = 1
	for _, ply in ipairs( player.GetAll() ) do best = math.max( best, ply:GetNWInt( "hl2bl_level", 1 ) ) end
	return best
end

local function dropBoxLoot( pos, lvl )
	-- Rarely an artifact, otherwise a (low-skewed) gun.
	if HL2BL.SpawnArtifact and HL2BL.RollArtifact and math.random() < 0.06 then
		HL2BL.SpawnArtifact( pos, HL2BL.RollArtifact( lvl, -0.1 ) )
		return
	end
	local class = HL2BL.LootClasses[ math.random( #HL2BL.LootClasses ) ]
	local w = ents.Create( class )
	if not IsValid( w ) then return end
	w:SetPos( pos )
	w:SetAngles( AngleRand() )
	w.HL2BL_IsLoot = true
	w:Spawn()
	if w.ApplyStats then w:ApplyStats( HL2BL.RollVendorStats( lvl ) ) end
	local phys = w:GetPhysicsObject()
	if IsValid( phys ) then phys:SetVelocity( VectorRand() * 40 + Vector( 0, 0, 80 ) ) end
end

hook.Add( "EntityTakeDamage", "hl2bl_box_loot", function( ent, dmg )
	if not IsValid( ent ) or ent.HL2BL_BoxChecked then return end
	if not BREAKABLE[ ent:GetClass() ] then return end

	local hp = ent:Health()
	if hp <= 0 then return end                 -- non-breakable prop (no health)
	if dmg:GetDamage() < hp then return end     -- not a killing blow yet

	ent.HL2BL_BoxChecked = true                 -- only roll once
	if math.random() > HL2BL.BoxLootChance:GetFloat() then return end

	local pos = ent:WorldSpaceCenter() + Vector( 0, 0, 8 )
	local lvl = lootLevel( dmg:GetAttacker() )
	timer.Simple( 0, function() dropBoxLoot( pos, lvl ) end )   -- after the break resolves
end )
