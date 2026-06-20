--[[ hl2bl: backpack + slots UI (client) -------------------------------------
	Shows the player's backpack as stat cards; each can be equipped into one of
	the 4 weapon slots (or unequipped). Open with `hl2bl_inv`.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}
HL2BL.Inv = HL2BL.Inv or { slots = {}, items = {} }

net.Receive( "hl2bl_inv_sync", function()
	local sl = {}
	for i = 1, HL2BL.MAX_SLOTS do sl[i] = net.ReadUInt( 6 ) end
	local n = net.ReadUInt( 6 )
	local items = {}
	for i = 1, n do items[i] = HL2BL.NetReadStats() end
	HL2BL.Inv = { slots = sl, items = items }
	if IsValid( HL2BL._InvScroll ) then HL2BL.RebuildInventory() end
	hook.Run( "HL2BL_InvUpdated" )
end )

local function slotOfItem( i )
	for sl = 1, HL2BL.MAX_SLOTS do
		if HL2BL.Inv.slots[ sl ] == i then return sl end
	end
end

local function equippedCount()
	local n = 0
	for sl = 1, HL2BL.MAX_SLOTS do if ( HL2BL.Inv.slots[ sl ] or 0 ) ~= 0 then n = n + 1 end end
	return n
end

function HL2BL.RebuildInventory()
	local scroll = HL2BL._InvScroll
	if not IsValid( scroll ) then return end
	scroll:Clear()

	local hdr = scroll:Add( "DLabel" )
	hdr:Dock( TOP ); hdr:DockMargin( 8, 6, 8, 2 ); hdr:SetFont( "HL2BL.Body" )
	hdr:SetText( "Equipped slots: " .. equippedCount() .. " / " .. HL2BL.MAX_SLOTS
		.. "   (switch equipped guns with keys 1-" .. HL2BL.MAX_SLOTS .. ")" )

	local items = HL2BL.Inv.items
	if #items == 0 then
		local lbl = scroll:Add( "DLabel" )
		lbl:Dock( TOP ); lbl:DockMargin( 8, 8, 0, 0 )
		lbl:SetText( "Backpack empty - kill NPCs to find guns." )
		return
	end

	for i, s in ipairs( items ) do
		local row = scroll:Add( "DPanel" )
		row:Dock( TOP ); row:DockMargin( 4, 4, 4, 4 ); row:SetTall( 220 )
		row.Paint = function() HL2BL.DrawStatCard( 0, 0, s ) end

		local sl  = slotOfItem( i )
		local btn = vgui.Create( "DButton", row )
		btn:SetPos( 292, 72 ); btn:SetSize( 150, 40 )
		btn:SetText( sl and ( "Equipped (Slot " .. sl .. ")\nclick to unequip" ) or "Equip" )
		btn.DoClick = function()
			net.Start( "hl2bl_inv_equip" )
				net.WriteUInt( i, 6 )
			net.SendToServer()
		end

		local drop = vgui.Create( "DButton", row )
		drop:SetPos( 292, 120 ); drop:SetSize( 150, 30 )
		drop:SetText( "Drop" )
		drop:SetTextColor( Color( 235, 120, 120 ) )
		drop.DoClick = function()
			local name = ( s.name ~= "" and s.name ) or "this gun"
			Derma_Query( "Drop " .. name .. "?", "Drop weapon", "Drop", function()
				net.Start( "hl2bl_inv_drop" )
					net.WriteUInt( i, 6 )
				net.SendToServer()
			end, "Cancel" )
		end
	end
end

function HL2BL.OpenInventory()
	if IsValid( HL2BL._InvFrame ) then HL2BL._InvFrame:Remove(); return end

	local fr = vgui.Create( "DFrame" )
	fr:SetSize( 470, math.min( 720, ScrH() * 0.8 ) )
	fr:Center()
	fr:SetTitle( "HL2: Borderlands  -  Backpack" )
	fr:MakePopup()
	HL2BL._InvFrame = fr

	local scroll = vgui.Create( "DScrollPanel", fr )
	scroll:Dock( FILL )
	HL2BL._InvScroll = scroll

	HL2BL.RebuildInventory()
end

concommand.Add( "hl2bl_inv", HL2BL.OpenInventory, nil, "Open the HL2BL backpack." )

-- Default key: I toggles the backpack (rebind with: bind <key> hl2bl_inv).
hook.Add( "PlayerButtonDown", "hl2bl_inv_key", function( ply, button )
	if ply ~= LocalPlayer() then return end
	if button ~= KEY_I then return end
	if IsValid( vgui.GetKeyboardFocus() ) then return end   -- don't fire while typing
	HL2BL.OpenInventory()
end )

hook.Add( "InitPostEntity", "hl2bl_inv_hint", function()
	timer.Simple( 3, function()
		chat.AddText( Color( 120, 200, 255 ), "[HL2BL] Press ", Color( 255, 255, 255 ), "I",
			Color( 120, 200, 255 ), " to open your backpack. Switch equipped guns with 1-4." )
	end )
end )
