--[[ hl2bl: inventory UI (client) --------------------------------------------
	Two panes:
	  * LEFT  - equipment loadout ("paper-doll"): the 4 equipped weapon slots and
	            the 4 HEV armor slots. Click a filled tile to unequip.
	  * RIGHT - category tabs (Weapons / Armor): every backpack item of that kind
	            as a stat card with Equip / Drop.
	Open with `hl2bl_inv` (bound to I). Driven by the synced HL2BL.Inv.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}
HL2BL.Inv = HL2BL.Inv or { slots = {}, armor = {}, items = {} }

-- Fallbacks if the shared armor module hasn't loaded on this client yet (e.g.
-- it was added mid-session and not downloaded). Keeps the net read aligned with
-- the server's fixed 4 armor slots so the rest of the sync doesn't desync.
local ARMOR_SLOTS = HL2BL.ARMOR_SLOTS or { "helmet", "vest", "greaves", "core" }
local ARMOR_NAME  = HL2BL.ArmorSlotName or { helmet = "Helmet", vest = "Vest", greaves = "Greaves", core = "Power Core" }
local MAX_SLOTS   = HL2BL.MAX_SLOTS or 4

net.Receive( "hl2bl_inv_sync", function()
	local sl = {}
	for i = 1, MAX_SLOTS do sl[i] = net.ReadUInt( 6 ) end
	local ar = {}
	for _, key in ipairs( ARMOR_SLOTS ) do ar[ key ] = net.ReadUInt( 6 ) end
	local n = net.ReadUInt( 6 )
	local items = {}
	for i = 1, n do items[i] = HL2BL.NetReadItem() end

	HL2BL.Inv = { slots = sl, armor = ar, items = items }
	if IsValid( HL2BL._InvFrame ) then HL2BL.RebuildInventory() end
	hook.Run( "HL2BL_InvUpdated" )
end )

-- ---- net helpers -----------------------------------------------------------
local function sendEquip( i )
	net.Start( "hl2bl_inv_equip" ); net.WriteUInt( i, 6 ); net.SendToServer()
end
local function sendDrop( i )
	net.Start( "hl2bl_inv_drop" ); net.WriteUInt( i, 6 ); net.SendToServer()
end

local function weaponSlotOf( i )
	for sl = 1, MAX_SLOTS do
		if ( HL2BL.Inv.slots[ sl ] or 0 ) == i then return sl end
	end
end

-- ---- left pane: equipment tiles --------------------------------------------
local function slotTile( parent, label, item, onClick )
	local t = parent:Add( "DButton" )
	t:Dock( TOP ); t:DockMargin( 8, 4, 8, 0 ); t:SetTall( 46 ); t:SetText( "" )
	t.Paint = function( _, w, h )
		local rc = item and ( HL2BL.RarityColor[ item.rarity ] or color_white ) or Color( 80, 80, 90 )
		draw.RoundedBox( 4, 0, 0, w, h, item and Color( rc.r, rc.g, rc.b, 40 ) or Color( 0, 0, 0, 120 ) )
		surface.SetDrawColor( rc.r, rc.g, rc.b, item and 220 or 90 )
		surface.DrawOutlinedRect( 0, 0, w, h, item and 2 or 1 )
		draw.SimpleText( label, "HL2BL.Body", 10, 7, Color( 165, 165, 175 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )
		local name = item and ( ( item.name and item.name ~= "" ) and item.name or "Item" ) or "Empty"
		draw.SimpleText( name, "HL2BL.Body", 10, h - 7, item and rc or Color( 120, 120, 128 ),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM )
		if item then
			draw.SimpleText( "unequip", "HL2BL.Body", w - 8, h * 0.5, Color( 150, 150, 158 ),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		end
	end
	if onClick then t.DoClick = onClick else t:SetCursor( "arrow" ) end
	return t
end

local function buildEquipment( left )
	left:Clear()
	local items = HL2BL.Inv.items or {}

	local h1 = left:Add( "DLabel" )
	h1:Dock( TOP ); h1:DockMargin( 8, 8, 8, 2 ); h1:SetFont( "HL2BL.Title" )
	h1:SetText( "Weapons" ); h1:SetTextColor( color_white )
	for sl = 1, MAX_SLOTS do
		local idx  = HL2BL.Inv.slots[ sl ] or 0
		local item = idx ~= 0 and items[ idx ] or nil
		slotTile( left, "Slot " .. sl, item, item and function() sendEquip( idx ) end or nil )
	end

	local h2 = left:Add( "DLabel" )
	h2:Dock( TOP ); h2:DockMargin( 8, 16, 8, 2 ); h2:SetFont( "HL2BL.Title" )
	h2:SetText( "Armor (HEV Suit)" ); h2:SetTextColor( color_white )
	for _, key in ipairs( ARMOR_SLOTS ) do
		local idx  = ( HL2BL.Inv.armor or {} )[ key ] or 0
		local item = idx ~= 0 and items[ idx ] or nil
		slotTile( left, ARMOR_NAME[ key ] or key, item, item and function() sendEquip( idx ) end or nil )
	end
end

-- ---- right pane: category lists --------------------------------------------
local function buildList( scroll, kind )
	scroll:Clear()
	local items, any = HL2BL.Inv.items or {}, false

	for i, s in ipairs( items ) do
		local isArmor = ( s.kind == "armor" )
		if ( kind == "armor" ) == isArmor then
			any = true
			local row = scroll:Add( "DPanel" )
			row:Dock( TOP ); row:DockMargin( 4, 4, 4, 4 ); row:SetTall( 220 )
			row.Paint = function()
				if isArmor and HL2BL.DrawArmorCard then HL2BL.DrawArmorCard( 0, 0, s ) else HL2BL.DrawStatCard( 0, 0, s ) end
			end

			local equipped = isArmor and ( ( HL2BL.Inv.armor or {} )[ s.slot ] == i ) or weaponSlotOf( i )

			local btn = vgui.Create( "DButton", row )
			btn:SetPos( 292, 72 ); btn:SetSize( 150, 40 )
			btn:SetText( equipped and "Equipped\n(click to unequip)" or "Equip" )
			btn.DoClick = function() sendEquip( i ) end

			local drop = vgui.Create( "DButton", row )
			drop:SetPos( 292, 120 ); drop:SetSize( 150, 30 )
			drop:SetText( "Drop" ); drop:SetTextColor( Color( 235, 120, 120 ) )
			drop.DoClick = function()
				local name = ( s.name and s.name ~= "" ) and s.name or "this item"
				Derma_Query( "Drop " .. name .. "?", "Drop", "Drop",
					function() sendDrop( i ) end, "Cancel" )
			end
		end
	end

	if not any then
		local l = scroll:Add( "DLabel" ); l:Dock( TOP ); l:DockMargin( 8, 8, 0, 0 )
		l:SetText( kind == "armor"
			and "No armor yet - kill enemies to find HEV suit pieces."
			or  "No weapons yet - kill NPCs to find guns." )
	end
end

function HL2BL.RebuildInventory()
	if IsValid( HL2BL._InvLeft )    then buildEquipment( HL2BL._InvLeft ) end
	if IsValid( HL2BL._InvWeapons ) then buildList( HL2BL._InvWeapons, "weapon" ) end
	if IsValid( HL2BL._InvArmor )   then buildList( HL2BL._InvArmor, "armor" ) end
end

function HL2BL.OpenInventory()
	if IsValid( HL2BL._InvFrame ) then HL2BL._InvFrame:Remove(); return end

	local fr = vgui.Create( "DFrame" )
	fr:SetSize( math.min( 980, ScrW() * 0.9 ), math.min( 760, ScrH() * 0.85 ) )
	fr:Center()
	fr:SetTitle( "HL2: Borderlands  -  Inventory" )
	fr:MakePopup()
	HL2BL._InvFrame = fr

	local left = vgui.Create( "DScrollPanel", fr )
	left:Dock( LEFT ); left:DockMargin( 0, 0, 6, 0 ); left:SetWide( 300 )
	HL2BL._InvLeft = left

	local sheet = vgui.Create( "DPropertySheet", fr )
	sheet:Dock( FILL )

	local wScroll = vgui.Create( "DScrollPanel", sheet )
	sheet:AddSheet( "Weapons", wScroll, "icon16/gun.png" )
	HL2BL._InvWeapons = wScroll

	local aScroll = vgui.Create( "DScrollPanel", sheet )
	sheet:AddSheet( "Armor", aScroll, "icon16/shield.png" )
	HL2BL._InvArmor = aScroll

	HL2BL.RebuildInventory()
end

concommand.Add( "hl2bl_inv", HL2BL.OpenInventory, nil, "Open the HL2BL inventory." )

-- Default key: I toggles the inventory (rebind with: bind <key> hl2bl_inv).
hook.Add( "PlayerButtonDown", "hl2bl_inv_key", function( ply, button )
	if ply ~= LocalPlayer() then return end
	if button ~= KEY_I then return end
	if IsValid( vgui.GetKeyboardFocus() ) then return end   -- don't fire while typing
	HL2BL.OpenInventory()
end )

hook.Add( "InitPostEntity", "hl2bl_inv_hint", function()
	timer.Simple( 3, function()
		chat.AddText( Color( 120, 200, 255 ), "[HL2BL] Press ", Color( 255, 255, 255 ), "I",
			Color( 120, 200, 255 ), " for your inventory (weapons + armor). Switch guns with 1-4." )
	end )
end )
