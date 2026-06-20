--[[ hl2bl: backpack + 4 equipped slots (server) -----------------------------
	Each player has their own backpack (all looted rolls) and up to
	HL2BL.MAX_SLOTS (4) equipped weapons. Equipping assigns a backpack item to a
	free slot weapon (hl2bl_slot1..4), reconfigured to that gun's archetype/roll;
	you can't exceed 4. Backpack + slots persist per-SteamID across maps.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

util.AddNetworkString( "hl2bl_inv_sync" )
util.AddNetworkString( "hl2bl_inv_equip" )   -- toggle equip/unequip by backpack index

local MAX_INV   = 32
local MAX_SLOTS = HL2BL.MAX_SLOTS

local function inv( ply )   ply.HL2BL_Inv   = ply.HL2BL_Inv   or {}; return ply.HL2BL_Inv end
local function slots( ply ) ply.HL2BL_Slots = ply.HL2BL_Slots or {}; return ply.HL2BL_Slots end

-- ---- persistence -----------------------------------------------------------
local function saveInv( ply )
	if not IsValid( ply ) then return end
	local sl = slots( ply )
	local arr = {}
	for i = 1, MAX_SLOTS do arr[i] = sl[i] or 0 end
	ply:SetPData( "hl2bl_inv", util.TableToJSON( { items = inv( ply ), slots = arr } ) )
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
end

-- ---- sync ------------------------------------------------------------------
local function syncInventory( ply )
	local items, sl = inv( ply ), slots( ply )
	net.Start( "hl2bl_inv_sync" )
		for i = 1, MAX_SLOTS do net.WriteUInt( sl[i] or 0, 6 ) end
		net.WriteUInt( #items, 6 )
		for _, s in ipairs( items ) do HL2BL.NetWriteStats( s ) end
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

-- Never auto-pick-up loot by walking over it...
hook.Add( "PlayerCanPickupWeapon", "hl2bl_block_autopickup", function( ply, wep )
	if IsValid( wep ) and wep.HL2BL_IsLoot then return false end
end )

-- ...pick it up only on +use (look at the gun, press E).
hook.Add( "PlayerUse", "hl2bl_loot_use", function( ply, ent )
	if IsValid( ent ) and ent.HL2BL_IsLoot then
		pickupLoot( ply, ent )
		return false
	end
end )

net.Receive( "hl2bl_inv_equip", function( _, ply )
	toggleEquip( ply, net.ReadUInt( 6 ) )
end )

hook.Add( "PlayerInitialSpawn", "hl2bl_inv_init", function( ply )
	loadInv( ply )
	timer.Simple( 1, function() if IsValid( ply ) then syncInventory( ply ) end end )
end )

hook.Add( "PlayerSpawn", "hl2bl_inv_reequip", function( ply )
	timer.Simple( 0.3, function() if IsValid( ply ) and ply:Alive() then reEquipAll( ply ) end end )
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
