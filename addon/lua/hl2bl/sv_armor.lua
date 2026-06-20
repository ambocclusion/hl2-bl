--[[ hl2bl: armor effects + equip (server) -----------------------------------
	Equipped armor pieces (one per HEV slot) aggregate into ply.HL2BL_ArmorAgg
	{ maxhp, maxarmor, regen }, then fold into HL2BL.RecomputePassive (the single
	stat authority in sv_artifacts) so level + artifacts + armor all stack.

	Armor lives in the shared backpack (ply.HL2BL_Inv) as kind="armor" items;
	the equip slot map is ply.HL2BL_Armor[slotKey] = backpackIndex. Backpack
	sync + persistence is owned by sv_inventory (it reads HL2BL_Armor too).

	Anti-abuse: the blue suit bar is refilled ONLY on spawn, never on equip, so
	you can't hot-swap pieces to top it up mid-fight.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

local function armorSlots( ply ) ply.HL2BL_Armor = ply.HL2BL_Armor or {}; return ply.HL2BL_Armor end

-- Sum equipped armor into the aggregate, then re-lay all derived stats.
function HL2BL.RecomputeArmor( ply )
	if not ( IsValid( ply ) and ply:IsPlayer() ) then return end
	local agg = { maxhp = 0, maxarmor = 0, regen = 0 }
	local inv = ply.HL2BL_Inv or {}
	for _, slotKey in ipairs( HL2BL.ARMOR_SLOTS ) do
		local idx = armorSlots( ply )[ slotKey ]
		local a   = idx and inv[ idx ] or nil
		if a and a.kind == "armor" then
			agg.maxhp    = agg.maxhp    + ( a.maxHealth or 0 )
			agg.maxarmor = agg.maxarmor + ( a.maxArmor or 0 )
			agg.regen    = agg.regen    + ( a.regen or 0 )
		end
	end
	ply.HL2BL_ArmorAgg = agg
	-- RecomputePassive reads HL2BL_ArmorAgg to set max health / max suit armor /
	-- and is the source the regen timer reads.
	if HL2BL.RecomputePassive then HL2BL.RecomputePassive( ply ) end
end

-- Toggle an armor backpack item into its slot (replacing whatever's there).
-- Does NOT refill the suit bar (anti-abuse) -- RecomputePassive only sets the
-- new max and clamps current armor down if it now exceeds it.
function HL2BL.EquipArmor( ply, invIndex )
	local inv = ply.HL2BL_Inv or {}
	local a   = inv[ invIndex ]
	if not ( a and a.kind == "armor" and HL2BL.ArmorSlotName[ a.slot ] ) then return end

	local sl = armorSlots( ply )
	if sl[ a.slot ] == invIndex then
		sl[ a.slot ] = nil                                  -- toggle off
		ply:EmitSound( "items/ammo_pickup.wav", 55, 90, 0.4 )
	else
		sl[ a.slot ] = invIndex                             -- replaces this slot
		ply:EmitSound( "items/suitchargeok1.wav", 55, 110, 0.5 )
	end

	HL2BL.RecomputeArmor( ply )
	if HL2BL.SaveInventory then HL2BL.SaveInventory( ply ) end
	if HL2BL.SyncInventory then HL2BL.SyncInventory( ply ) end
end

-- Keep armor slot indices valid after a backpack item is removed (drop/sell).
-- Called by sv_inventory.InventoryRemove.
function HL2BL.ArmorSlotFixup( ply, removedIndex )
	local sl = armorSlots( ply )
	for _, slotKey in ipairs( HL2BL.ARMOR_SLOTS ) do
		local idx = sl[ slotKey ]
		if idx == removedIndex then sl[ slotKey ] = nil
		elseif idx and idx > removedIndex then sl[ slotKey ] = idx - 1 end
	end
	HL2BL.RecomputeArmor( ply )
end

-- Add a rolled armor piece to the backpack (pickup / vendor / debug).
function HL2BL.GiveArmor( ply, a )
	if not ( IsValid( ply ) and ply:IsPlayer() ) then return false end
	if not HL2BL.InventoryAdd( ply, a ) then ply:ChatPrint( "[HL2BL] Backpack full." ); return false end
	ply:EmitSound( "items/ammo_pickup.wav", 60, 90 )
	ply:ChatPrint( "[HL2BL] Found armor: " .. ( a.name or "?" ) )
	return true
end

-- Spawn an armor world pickup at pos.
function HL2BL.SpawnArmor( pos, a )
	local e = ents.Create( "hl2bl_armor" )
	if not IsValid( e ) then return end
	e:SetPos( pos )
	e.HL2BL_Armor = a
	e:Spawn()
	local phys = e:GetPhysicsObject()
	if IsValid( phys ) then phys:SetVelocity( VectorRand() * 50 + Vector( 0, 0, 90 ) ) end
	return e
end

-- The ONLY place the suit bar is refilled: on (re)spawn, after the aggregate is
-- applied. Equipping/looting never tops it up.
hook.Add( "PlayerSpawn", "hl2bl_armor_spawn", function( ply )
	timer.Simple( 0.45, function()
		if not ( IsValid( ply ) and ply:Alive() ) then return end
		HL2BL.RecomputeArmor( ply )
		ply:SetArmor( ply:GetMaxArmor() )
	end )
end )

-- Superadmin test spawn: hl2bl_give_armor [slot] [level]
concommand.Add( "hl2bl_give_armor", function( ply, _, args )
	if not ( IsValid( ply ) and ply:IsPlayer() ) then return end
	if not ply:IsSuperAdmin() then ply:ChatPrint( "[HL2BL] superadmin only." ); return end
	local slot = ( args[1] and args[1] ~= "" ) and args[1] or nil
	local lvl  = tonumber( args[2] ) or ply:GetNWInt( "hl2bl_level", 1 )
	HL2BL.GiveArmor( ply, HL2BL.RollArmorStats( lvl, 0.3, slot ) )
end, nil, "hl2bl: give yourself a rolled armor piece. Usage: hl2bl_give_armor [helmet|vest|greaves|core] [level] (superadmin)" )
