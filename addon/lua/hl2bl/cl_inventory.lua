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
surface.CreateFont( "HL2BL.InvTiny", { font = "Roboto", size = 13, weight = 500 } )

local function fitText( text, font, maxw )
	surface.SetFont( font )
	if surface.GetTextSize( text ) <= maxw then return text end
	while #text > 1 and surface.GetTextSize( text .. "..." ) > maxw do
		text = string.sub( text, 1, #text - 1 )
	end
	return text .. "..."
end

-- Manufacturer (guns) / source faction (armor) display name, or nil.
local function makerOf( item )
	if item.kind == "armor" then
		local src = HL2BL.ArmorSources and HL2BL.ArmorSources[ item.source ]
		return src and src.name or nil
	end
	return HL2BL.ManufacturerName and HL2BL.ManufacturerName( item.manufacturer ) or nil
end

-- Item display name, rebuilt from parts when the rolled name is missing (e.g.
-- vendor-bought guns), so a tile is never blank.
local function displayName( item )
	if item.name and item.name ~= "" then return item.name end
	if item.kind == "armor" then return ARMOR_NAME[ item.slot ] or "Armor" end
	local arch = ( HL2BL.GetArchetype and HL2BL.GetArchetype( item.archetype ).name ) or ( item.archetype or "Gun" )
	local maker = makerOf( item )
	return ( maker and ( maker .. " " ) or "" ) .. arch
end

-- An equipment slot tile: slot label, item name, and its manufacturer/source.
-- opts = { name=, sub=, color=, onClick= }; a nil onClick = empty/inert tile.
local function slotTile( parent, label, opts )
	local has = opts.onClick ~= nil
	local t = parent:Add( "DButton" )
	t:Dock( TOP ); t:DockMargin( 8, 4, 8, 0 ); t:SetTall( 54 ); t:SetText( "" )
	t.Paint = function( _, w, h )
		local col = opts.color or Color( 100, 100, 110 )
		draw.RoundedBox( 4, 0, 0, w, h, has and Color( col.r, col.g, col.b, 40 ) or Color( 0, 0, 0, 120 ) )
		surface.SetDrawColor( col.r, col.g, col.b, has and 220 or 90 )
		surface.DrawOutlinedRect( 0, 0, w, h, has and 2 or 1 )

		draw.SimpleText( label, "HL2BL.InvTiny", 10, 6, Color( 160, 160, 170 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )
		if has then
			draw.SimpleText( "unequip", "HL2BL.InvTiny", w - 8, 6, Color( 140, 140, 150 ), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP )
		end

		draw.SimpleText( fitText( opts.name or "Empty", "HL2BL.Body", w - 20 ), "HL2BL.Body",
			10, 22, has and col or Color( 120, 120, 128 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )
		if opts.sub and opts.sub ~= "" then
			draw.SimpleText( fitText( opts.sub, "HL2BL.InvTiny", w - 20 ), "HL2BL.InvTiny",
				10, h - 6, Color( 165, 165, 175 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM )
		end
	end
	if opts.onClick then t.DoClick = opts.onClick else t:SetCursor( "arrow" ) end
	return t
end

local function tileOpts( item, onClick )
	if not item then return { name = "Empty" } end
	return {
		name    = displayName( item ),
		sub     = makerOf( item ),
		color   = HL2BL.RarityColor[ item.rarity ] or color_white,
		onClick = onClick,
	}
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
		slotTile( left, "Slot " .. sl, tileOpts( item, item and function() sendEquip( idx ) end or nil ) )
	end

	local h2 = left:Add( "DLabel" )
	h2:Dock( TOP ); h2:DockMargin( 8, 16, 8, 2 ); h2:SetFont( "HL2BL.Title" )
	h2:SetText( "Armor (HEV Suit)" ); h2:SetTextColor( color_white )
	for _, key in ipairs( ARMOR_SLOTS ) do
		local idx  = ( HL2BL.Inv.armor or {} )[ key ] or 0
		local item = idx ~= 0 and items[ idx ] or nil
		slotTile( left, ARMOR_NAME[ key ] or key, tileOpts( item, item and function() sendEquip( idx ) end or nil ) )
	end

	local h3 = left:Add( "DLabel" )
	h3:Dock( TOP ); h3:DockMargin( 8, 16, 8, 2 ); h3:SetFont( "HL2BL.Title" )
	h3:SetText( "Artifact" ); h3:SetTextColor( color_white )
	local arts = HL2BL.Arts or { slot = 0, items = {} }
	local aidx = arts.slot or 0
	local art  = aidx ~= 0 and ( arts.items or {} )[ aidx ] or nil
	slotTile( left, "Relic", {
		name    = art and ( art.name or "Artifact" ) or "Empty",
		sub     = art and ( art.kind == "active" and "Active" or "Passive" ) or nil,
		color   = art and ( HL2BL.RarityColor[ art.rarity ] or color_white ) or nil,
		onClick = art and function() net.Start( "hl2bl_art_equip" ); net.WriteUInt( aidx, 6 ); net.SendToServer() end or nil,
	} )

	local h4 = left:Add( "DLabel" )
	h4:Dock( TOP ); h4:DockMargin( 8, 16, 8, 2 ); h4:SetFont( "HL2BL.Title" )
	h4:SetText( "Grenade" ); h4:SetTextColor( color_white )
	local grens = HL2BL.Grenades or { slot = 0, items = {} }
	local gidx  = grens.slot or 0
	local gren  = gidx ~= 0 and ( grens.items or {} )[ gidx ] or nil
	slotTile( left, "Grenade Mod", {
		name    = gren and ( gren.name or "Grenade" ) or "Standard Grenade",
		sub     = gren and ( ( HL2BL.GrenadeTypes[ gren.type ] or {} ).name ) or "Base frag",
		color   = gren and ( HL2BL.RarityColor[ gren.rarity ] or color_white ) or nil,
		onClick = gren and function() net.Start( "hl2bl_gren_equip" ); net.WriteUInt( gidx, 6 ); net.SendToServer() end or nil,
	} )
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

-- Artifacts live in their own bag (HL2BL.Arts) with a single equip slot; reuse
-- the artifact card + the artifact net messages rather than the weapon/armor path.
local function buildArtifactList( scroll )
	scroll:Clear()
	local arts  = HL2BL.Arts or { slot = 0, items = {} }
	local items = arts.items or {}
	if #items == 0 then
		local l = scroll:Add( "DLabel" ); l:Dock( TOP ); l:DockMargin( 8, 8, 0, 0 )
		l:SetText( "No artifacts yet - kill enemies to find them." )
		return
	end
	for i, art in ipairs( items ) do
		local row = scroll:Add( "DPanel" )
		row:Dock( TOP ); row:DockMargin( 4, 4, 4, 4 ); row:SetTall( 190 )
		row.Paint = function() if HL2BL.DrawArtifactCard then HL2BL.DrawArtifactCard( 0, 0, art ) end end

		local eq  = ( i == arts.slot )
		local btn = vgui.Create( "DButton", row )
		btn:SetPos( 292, 72 ); btn:SetSize( 150, 40 )
		btn:SetText( eq and "Equipped\n(click to unequip)" or "Equip" )
		btn.DoClick = function() net.Start( "hl2bl_art_equip" ); net.WriteUInt( i, 6 ); net.SendToServer() end

		local drop = vgui.Create( "DButton", row )
		drop:SetPos( 292, 120 ); drop:SetSize( 150, 30 )
		drop:SetText( "Drop" ); drop:SetTextColor( Color( 235, 120, 120 ) )
		drop.DoClick = function()
			Derma_Query( "Drop " .. ( art.name or "this artifact" ) .. "?", "Drop", "Drop",
				function() net.Start( "hl2bl_art_drop" ); net.WriteUInt( i, 6 ); net.SendToServer() end, "Cancel" )
		end
	end
end

-- Grenade mods: their own bag (HL2BL.Grenades), single equip slot, own net path.
local function buildGrenadeList( scroll )
	scroll:Clear()
	local grens = HL2BL.Grenades or { slot = 0, items = {} }
	local items = grens.items or {}
	if #items == 0 then
		local l = scroll:Add( "DLabel" ); l:Dock( TOP ); l:DockMargin( 8, 8, 0, 0 )
		l:SetText( "No grenade mods yet - kill enemies to find them. You always carry a basic grenade (throw with G)." )
		l:SetWrap( true ); l:SetAutoStretchVertical( true ); l:SetWide( 430 )
		return
	end
	for i, g in ipairs( items ) do
		local row = scroll:Add( "DPanel" )
		row:Dock( TOP ); row:DockMargin( 4, 4, 4, 4 ); row:SetTall( 200 )
		row.Paint = function() if HL2BL.DrawGrenadeCard then HL2BL.DrawGrenadeCard( 0, 0, g ) end end

		local eq  = ( i == grens.slot )
		local btn = vgui.Create( "DButton", row )
		btn:SetPos( 292, 72 ); btn:SetSize( 150, 40 )
		btn:SetText( eq and "Equipped\n(click to unequip)" or "Equip" )
		btn.DoClick = function() net.Start( "hl2bl_gren_equip" ); net.WriteUInt( i, 6 ); net.SendToServer() end

		local drop = vgui.Create( "DButton", row )
		drop:SetPos( 292, 120 ); drop:SetSize( 150, 30 )
		drop:SetText( "Drop" ); drop:SetTextColor( Color( 235, 120, 120 ) )
		drop.DoClick = function()
			Derma_Query( "Drop " .. ( g.name or "this grenade mod" ) .. "?", "Drop", "Drop",
				function() net.Start( "hl2bl_gren_drop" ); net.WriteUInt( i, 6 ); net.SendToServer() end, "Cancel" )
		end
	end
end

function HL2BL.RebuildInventory()
	if IsValid( HL2BL._InvLeft )      then buildEquipment( HL2BL._InvLeft ) end
	if IsValid( HL2BL._InvWeapons )   then buildList( HL2BL._InvWeapons, "weapon" ) end
	if IsValid( HL2BL._InvArmor )     then buildList( HL2BL._InvArmor, "armor" ) end
	if IsValid( HL2BL._InvArtifacts ) then buildArtifactList( HL2BL._InvArtifacts ) end
	if IsValid( HL2BL._InvGrenades )  then buildGrenadeList( HL2BL._InvGrenades ) end
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
	HL2BL._InvSheet = sheet

	local wScroll = vgui.Create( "DScrollPanel", sheet )
	sheet:AddSheet( "Weapons", wScroll, "icon16/gun.png" )
	HL2BL._InvWeapons = wScroll

	local aScroll = vgui.Create( "DScrollPanel", sheet )
	sheet:AddSheet( "Armor", aScroll, "icon16/shield.png" )
	HL2BL._InvArmor = aScroll

	local artScroll = vgui.Create( "DScrollPanel", sheet )
	HL2BL._InvArtTab = sheet:AddSheet( "Artifacts", artScroll, "icon16/wand.png" ).Tab
	HL2BL._InvArtifacts = artScroll

	local grenScroll = vgui.Create( "DScrollPanel", sheet )
	sheet:AddSheet( "Grenades", grenScroll, "icon16/bomb.png" )
	HL2BL._InvGrenades = grenScroll

	HL2BL.RebuildInventory()
end

-- Open the inventory focused on the Artifacts tab (used by the O key / command).
function HL2BL.OpenInventoryArtifacts()
	if not IsValid( HL2BL._InvFrame ) then HL2BL.OpenInventory() end
	if IsValid( HL2BL._InvSheet ) and IsValid( HL2BL._InvArtTab ) then
		HL2BL._InvSheet:SetActiveTab( HL2BL._InvArtTab )
	end
end

concommand.Add( "hl2bl_inv", HL2BL.OpenInventory, nil, "Open the HL2BL inventory." )

-- Default key: I toggles the inventory (rebind with: bind <key> hl2bl_inv).
hook.Add( "PlayerButtonDown", "hl2bl_inv_key", function( ply, button )
	if ply ~= LocalPlayer() then return end
	if button ~= KEY_I then return end
	if IsValid( vgui.GetKeyboardFocus() ) then return end   -- don't fire while typing
	HL2BL.OpenInventory()
end )

-- Refresh the Artifacts tab when the artifact bag changes (it syncs separately).
hook.Add( "HL2BL_ArtsUpdated", "hl2bl_inv_arts", function()
	if IsValid( HL2BL._InvFrame ) then HL2BL.RebuildInventory() end
end )

-- Refresh the Grenades tab when the grenade-mod bag changes (syncs separately).
hook.Add( "HL2BL_GrenadesUpdated", "hl2bl_inv_grens", function()
	if IsValid( HL2BL._InvFrame ) then HL2BL.RebuildInventory() end
end )

hook.Add( "InitPostEntity", "hl2bl_inv_hint", function()
	timer.Simple( 3, function()
		chat.AddText( Color( 120, 200, 255 ), "[HL2BL] Press ", Color( 255, 255, 255 ), "I",
			Color( 120, 200, 255 ), " for your inventory. Switch guns with 1-4, throw grenades with ",
			Color( 255, 255, 255 ), "G", Color( 120, 200, 255 ), "." )
	end )
end )
