--[[ hl2bl: equipped slot bar (client) ---------------------------------------
	Bottom-center bar of the 4 equipped weapon slots, rarity-colored, with the
	active slot highlighted. Driven by the synced inventory (HL2BL.Inv).
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

surface.CreateFont( "HL2BL.SlotNum",  { font = "Roboto", size = 16, weight = 800 } )
surface.CreateFont( "HL2BL.SlotName", { font = "Roboto", size = 16, weight = 600 } )

local CELL_W, CELL_H, GAP = 150, 44, 6

local function activeSlot()
	local ply = LocalPlayer()
	if not IsValid( ply ) then return end
	local w = ply:GetActiveWeapon()
	if not IsValid( w ) then return end
	local n = string.match( w:GetClass(), "^hl2bl_slot(%d)$" )
	return n and tonumber( n ) or nil
end

local function fit( text, font, maxw )
	surface.SetFont( font )
	if surface.GetTextSize( text ) <= maxw then return text end
	while #text > 1 and surface.GetTextSize( text .. "..." ) > maxw do
		text = string.sub( text, 1, #text - 1 )
	end
	return text .. "..."
end

hook.Add( "HUDPaint", "hl2bl_slotbar", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) or not ply:Alive() then return end

	local slots, items = HL2BL.Inv.slots, HL2BL.Inv.items
	if not slots then return end

	local max     = HL2BL.MAX_SLOTS
	local total   = max * CELL_W + ( max - 1 ) * GAP
	local x0      = ( ScrW() - total ) * 0.5
	local y       = ScrH() - 64
	local active  = activeSlot()

	for sl = 1, max do
		local x    = x0 + ( sl - 1 ) * ( CELL_W + GAP )
		local idx  = slots[ sl ] or 0
		local item = idx ~= 0 and items[ idx ] or nil
		local rc   = item and ( HL2BL.RarityColor[ item.rarity ] or color_white ) or Color( 90, 90, 100 )
		local isOn = ( sl == active )

		draw.RoundedBox( 4, x, y, CELL_W, CELL_H,
			isOn and Color( rc.r, rc.g, rc.b, 70 ) or Color( 0, 0, 0, 170 ) )
		surface.SetDrawColor( rc.r, rc.g, rc.b, isOn and 255 or 120 )
		surface.DrawOutlinedRect( x, y, CELL_W, CELL_H, isOn and 2 or 1 )

		draw.SimpleText( sl, "HL2BL.SlotNum", x + 7, y + 6, isOn and color_white or Color( 170, 170, 180 ) )

		local name = item and ( item.name ~= "" and item.name
			or HL2BL.GetArchetype( item.archetype ).name ) or "Empty"
		draw.SimpleText( fit( name, "HL2BL.SlotName", CELL_W - 16 ), "HL2BL.SlotName",
			x + CELL_W * 0.5, y + CELL_H - 14, item and rc or Color( 120, 120, 128 ),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end
end )
