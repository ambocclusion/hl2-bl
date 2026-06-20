--[[ hl2bl: backpack + 4 equipped slots (server) -----------------------------
	Each player has their own backpack (all looted rolls) and up to
	HL2BL.MAX_SLOTS (4) equipped weapons. Equipping assigns a backpack item to a
	free slot weapon (hl2bl_slot1..4), reconfigured to that gun's archetype/roll;
	you can't exceed 4. Backpack + slots persist per-SteamID across maps.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

util.AddNetworkString( "hl2bl_inv_sync" )
util.AddNetworkString( "hl2bl_inv_equip" )   -- toggle equip/unequip by backpack index
util.AddNetworkString( "hl2bl_inv_drop" )    -- drop a backpack gun into the world

local MAX_INV   = 32
local MAX_SLOTS = HL2BL.MAX_SLOTS

local function inv( ply )      ply.HL2BL_Inv   = ply.HL2BL_Inv   or {}; return ply.HL2BL_Inv end
local function slots( ply )    ply.HL2BL_Slots = ply.HL2BL_Slots or {}; return ply.HL2BL_Slots end
local function armorMap( ply ) ply.HL2BL_Armor = ply.HL2BL_Armor or {}; return ply.HL2BL_Armor end

-- ---- persistence -----------------------------------------------------------
local function saveInv( ply )
	if not IsValid( ply ) then return end
	local sl, ar = slots( ply ), armorMap( ply )
	local arr = {}
	for i = 1, MAX_SLOTS do arr[i] = sl[i] or 0 end
	local armap = {}
	for _, key in ipairs( HL2BL.ARMOR_SLOTS ) do armap[ key ] = ar[ key ] or 0 end
	ply:SetPData( "hl2bl_inv", util.TableToJSON( { items = inv( ply ), slots = arr, armor = armap } ) )
end

local function loadInv( ply )
	local json = ply:GetPData( "hl2bl_inv", nil )
	if not json then return end
	local t = util.JSONToTable( json ); if not t then return end
	ply.HL2BL_Inv   = t.items or {}
	ply.HL2BL_Slots = {}
	if t.slots then
		for i = 1, MAX_SLOTS do
			local idx = t.slots[i]
			if idx and idx ~= 0 then ply.HL2BL_Slots[i] = idx end
		end
	end
	ply.HL2BL_Armor = {}
	if t.armor then
		for _, key in ipairs( HL2BL.ARMOR_SLOTS ) do
			local idx = t.armor[ key ]
			if idx and idx ~= 0 then ply.HL2BL_Armor[ key ] = idx end
		end
	end
end

-- ---- sync ------------------------------------------------------------------
-- Writes the 4 weapon slots, then the 4 armor slots (HL2BL.ARMOR_SLOTS order),
-- then the mixed backpack (each item kind-tagged via NetWriteItem).
local function syncInventory( ply )
	local items, sl, ar = inv( ply ), slots( ply ), armorMap( ply )
	net.Start( "hl2bl_inv_sync" )
		for i = 1, MAX_SLOTS do net.WriteUInt( sl[i] or 0, 6 ) end
		for _, key in ipairs( HL2BL.ARMOR_SLOTS ) do net.WriteUInt( ar[ key ] or 0, 6 ) end
		net.WriteUInt( #items, 6 )
		for _, s in ipairs( items ) do HL2BL.NetWriteItem( s ) end
	net.Send( ply )
end
HL2BL.SyncInventory = syncInventory

-- Add a gun (stat table) to the backpack. Returns false if full.
function HL2BL.InventoryAdd( ply, stats )
	local items = inv( ply )
	if #items >= MAX_INV then return false end
	items[ #items + 1 ] = stats
	saveInv( ply ); syncInventory( ply )
	return true
end

-- Remove backpack item at index (fixing slot mappings + stripping if equipped).
-- Returns the removed stat table or nil.
function HL2BL.InventoryRemove( ply, index )
	local items = inv( ply )
	if not items[ index ] then return nil end
	local removed = items[ index ]

	local sl, stripSlot = slots( ply ), nil
	for s = 1, MAX_SLOTS do
		if sl[ s ] == index then stripSlot = s
		elseif sl[ s ] and sl[ s ] > index then sl[ s ] = sl[ s ] - 1 end
	end
	table.remove( items, index )
	if stripSlot then
		sl[ stripSlot ] = nil
		local class = "hl2bl_slot" .. stripSlot
		if IsValid( ply:GetWeapon( class ) ) then ply:StripWeapon( class ) end
	end

	-- Keep armor slot indices valid too (decrement/clear), then re-apply effects.
	if HL2BL.ArmorSlotFixup then HL2BL.ArmorSlotFixup( ply, index ) end

	saveInv( ply ); syncInventory( ply )
	return removed
end

-- ---- equip / unequip -------------------------------------------------------
local function slotOf( ply, invIndex )
	for sl, idx in pairs( slots( ply ) ) do if idx == invIndex then return sl end end
end

-- Give+configure slot N to backpack item (no select/save). Returns ok.
local function giveSlot( ply, slotIndex, invIndex )
	local item = inv( ply )[ invIndex ]; if not item then return false end
	local class = "hl2bl_slot" .. slotIndex
	local wep = ply:GetWeapon( class )
	if not IsValid( wep ) then wep = ply:Give( class ) end
	if not IsValid( wep ) or not wep.Configure then return false end
	wep:Configure( item.archetype or "smg", item )
	slots( ply )[ slotIndex ] = invIndex
	return true
end

local function unequipSlot( ply, slotIndex )
	slots( ply )[ slotIndex ] = nil
	local class = "hl2bl_slot" .. slotIndex
	if IsValid( ply:GetWeapon( class ) ) then ply:StripWeapon( class ) end
	saveInv( ply ); syncInventory( ply )
end

-- Click behaviour: equipped item -> unequip; else equip to first free slot.
local function toggleEquip( ply, invIndex )
	if not inv( ply )[ invIndex ] then return end

	local existing = slotOf( ply, invIndex )
	if existing then unequipSlot( ply, existing ); return end

	for sl = 1, MAX_SLOTS do
		if not slots( ply )[ sl ] then
			if giveSlot( ply, sl, invIndex ) then
				ply:SelectWeapon( "hl2bl_slot" .. sl )
				saveInv( ply ); syncInventory( ply )
			end
			return
		end
	end
	ply:ChatPrint( "[HL2BL] All " .. MAX_SLOTS .. " weapon slots are full - unequip one first." )
end

local function reEquipAll( ply )
	for sl = 1, MAX_SLOTS do
		local idx = slots( ply )[ sl ]
		if idx then giveSlot( ply, sl, idx ) end
	end
	syncInventory( ply )
end

-- ---- pickup -> backpack (press E) ------------------------------------------
local function pickupLoot( ply, wep )
	local s = HL2BL.GetEntStats( wep )
	local items = inv( ply )
	if not s then return end
	if #items >= MAX_INV then ply:ChatPrint( "[HL2BL] Backpack full." ); return end

	s.kind = "weapon"
	items[ #items + 1 ] = s
	ply:EmitSound( "items/ammo_pickup.wav" )
	ply:ChatPrint( "[HL2BL] Looted: " .. ( s.name ~= "" and s.name or "a gun" ) )
	saveInv( ply )

	-- auto-equip into a free slot, if any
	for sl = 1, MAX_SLOTS do
		if not slots( ply )[ sl ] then
			local idx = #items
			timer.Simple( 0, function()
				if IsValid( ply ) then giveSlot( ply, sl, idx ); saveInv( ply ); syncInventory( ply ) end
			end )
			break
		end
	end
	syncInventory( ply )
	SafeRemoveEntity( wep )
end

-- Weapon pickup rules:
--   * HL2BL loot           -> blocked here (picked up only via +use, below)
--   * our slot weapons     -> allowed (given by the inventory system)
--   * vanilla NPC/map guns -> blocked entirely (only random loot is acquirable)
hook.Add( "PlayerCanPickupWeapon", "hl2bl_pickup_rules", function( ply, wep )
	if not IsValid( wep ) then return end
	if wep.HL2BL_IsLoot then return false end
	if string.StartWith( wep:GetClass(), "hl2bl_" ) then return end
	return false
end )

-- ...pick it up only on +use (look at the gun, press E).
hook.Add( "PlayerUse", "hl2bl_loot_use", function( ply, ent )
	if IsValid( ent ) and ent.HL2BL_IsLoot then
		pickupLoot( ply, ent )
		return false
	end
end )

-- Extended reach: look at a loot beacon within ~2 m and press E to grab it,
-- even if your crosshair isn't on the small model. Idempotent vs PlayerUse/ENT:Use
-- above (a picked-up ent becomes invalid, so a second handler this frame no-ops).
hook.Add( "KeyPress", "hl2bl_loot_reach", function( ply, key )
	if key ~= IN_USE then return end
	if not ( IsValid( ply ) and ply:IsPlayer() and ply:Alive() ) then return end
	local ent = HL2BL.LootBeaconTarget( ply )
	if not IsValid( ent ) then return end
	if ent:IsWeapon() then
		pickupLoot( ply, ent )            -- dropped gun
	else
		ent:Use( ply, ply, USE_ON, 0 )    -- armor world pickup (ENT:Use -> GiveArmor)
	end
end )

-- Equip toggle: armor routes to the armor system (its own slot), weapons to the
-- 4 weapon slots. The same message drives the left paper-doll's click-to-unequip.
net.Receive( "hl2bl_inv_equip", function( _, ply )
	local idx  = net.ReadUInt( 6 )
	local item = inv( ply )[ idx ]
	if item and item.kind == "armor" then
		if HL2BL.EquipArmor then HL2BL.EquipArmor( ply, idx ) end
	else
		toggleEquip( ply, idx )
	end
end )

-- Drop a backpack item in front of the player as world loot (armor -> armor
-- pickup ent; weapon -> its SWEP).
net.Receive( "hl2bl_inv_drop", function( _, ply )
	local removed = HL2BL.InventoryRemove( ply, net.ReadUInt( 6 ) )
	if not removed then return end

	local fwd = ply:GetAimVector()
	local pos = ply:GetShootPos() + fwd * 40

	if removed.kind == "armor" then
		local e = HL2BL.SpawnArmor and HL2BL.SpawnArmor( pos, removed )
		if IsValid( e ) then
			local phys = e:GetPhysicsObject()
			if IsValid( phys ) then phys:SetVelocity( fwd * 150 + Vector( 0, 0, 80 ) ) end
		end
		return
	end

	local w = ents.Create( "hl2bl_" .. ( removed.archetype or "smg" ) )
	if not IsValid( w ) then return end
	w:SetPos( pos )
	w:SetAngles( AngleRand() )
	w.HL2BL_IsLoot = true
	w:Spawn()
	if w.ApplyStats then w:ApplyStats( removed ) end

	local phys = w:GetPhysicsObject()
	if IsValid( phys ) then phys:SetVelocity( fwd * 150 + Vector( 0, 0, 80 ) ) end
end )

hook.Add( "PlayerInitialSpawn", "hl2bl_inv_init", function( ply )
	loadInv( ply )
	timer.Simple( 1, function() if IsValid( ply ) then syncInventory( ply ) end end )
end )

-- Starter melee: a Common, level-1 crowbar, equipped (held), not dropped.
function HL2BL.StarterCrowbarStats()
	return {
		archetype = "crowbar", manufacturer = "vanguard",
		rarity = HL2BL.Rarity.COMMON, itemLevel = 1, element = HL2BL.Element.NONE,
		damageMult = 1, fireRateMult = 1, spreadMult = 1, reloadMult = 1, magMult = 1,
		elementChance = 0, elementDamage = 0,
	}
end

function HL2BL.GiveStarterCrowbar( ply )
	if not ( IsValid( ply ) and ply:Alive() ) then return end
	local w = ply:GetWeapon( "hl2bl_crowbar" )
	if not IsValid( w ) then w = ply:Give( "hl2bl_crowbar" ) end
	if IsValid( w ) and w.Configure then w:Configure( "crowbar", HL2BL.StarterCrowbarStats() ) end
end

hook.Add( "PlayerSpawn", "hl2bl_inv_reequip", function( ply )
	timer.Simple( 0.3, function()
		if not ( IsValid( ply ) and ply:Alive() ) then return end
		reEquipAll( ply )
		HL2BL.GiveStarterCrowbar( ply )
		-- Hold the crowbar if no gun is equipped in a slot.
		local hasSlot = false
		for s = 1, MAX_SLOTS do if slots( ply )[ s ] then hasSlot = true break end end
		if not hasSlot then ply:SelectWeapon( "hl2bl_crowbar" ) end
	end )
end )

HL2BL.SaveInventory = saveInv

-- Save everything persistent for a player (backpack + slots + level/xp).
local function savePlayer( ply )
	saveInv( ply )
	if HL2BL.SaveLevel then HL2BL.SaveLevel( ply ) end
end
HL2BL.SavePlayer = savePlayer

hook.Add( "PlayerDisconnected", "hl2bl_save", savePlayer )
hook.Add( "ShutDown", "hl2bl_save_all", function()
	for _, ply in ipairs( player.GetAll() ) do savePlayer( ply ) end
end )

-- Periodic autosave so progress survives a crash between events.
timer.Create( "hl2bl_autosave", 60, 0, function()
	for _, ply in ipairs( player.GetAll() ) do savePlayer( ply ) end
end )
