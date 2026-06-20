--[[ hl2bl: grenades UI (client) ---------------------------------------------
	Grenade-mod bag sync + the shared DrawGrenadeCard, the dropped-mod look-at
	card, the grenade-count HUD, and the throw key (default G). The bag itself is
	the "Grenades" tab in the main inventory (cl_inventory).
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}
HL2BL.Grenades = HL2BL.Grenades or { slot = 0, items = {} }
HL2BL.GrenadeKey = "G"

net.Receive( "hl2bl_gren_sync", function()
	local slot = net.ReadUInt( 6 )
	local n    = net.ReadUInt( 6 )
	local items = {}
	for i = 1, n do items[i] = HL2BL.NetReadGrenade() end
	HL2BL.Grenades = { slot = slot, items = items }
	hook.Run( "HL2BL_GrenadesUpdated" )   -- refresh the inventory's Grenades tab
end )

function HL2BL.DrawGrenadeCard( x, y, g )
	local rc    = HL2BL.RarityColor[ g.rarity ] or color_white
	local lines = HL2BL.GrenadeDescLines( g )
	local pad, titleH, lineH = 10, 28, 20
	local h = titleH + pad + ( #lines + 1 ) * lineH + pad

	draw.RoundedBox( 6, x, y, 280, h, Color( 18, 18, 22, 235 ) )
	draw.RoundedBoxEx( 6, x, y, 280, titleH, Color( rc.r, rc.g, rc.b, 60 ), true, true, false, false )
	surface.SetDrawColor( rc.r, rc.g, rc.b, 220 ); surface.DrawOutlinedRect( x, y, 280, h, 2 )

	draw.SimpleText( g.name or "Grenade", "HL2BL.Title", x + pad, y + titleH / 2, rc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	local cy = y + titleH + pad
	draw.SimpleText( ( HL2BL.RarityName[ g.rarity ] or "Common" ) .. "  -  Lv " .. ( g.itemLevel or 1 ),
		"HL2BL.Body", x + pad, cy, Color( 150, 150, 158 ) ); cy = cy + lineH
	for _, l in ipairs( lines ) do
		draw.SimpleText( l, "HL2BL.Body", x + pad, cy, Color( 200, 220, 255 ) ); cy = cy + lineH
	end
	return h
end

-- ---- throw -----------------------------------------------------------------
concommand.Add( "hl2bl_throw", function()
	net.Start( "hl2bl_gren_throw" ); net.SendToServer()
end, nil, "Throw a grenade (does not use a weapon slot)." )

hook.Add( "PlayerButtonDown", "hl2bl_gren_key", function( ply, button )
	if ply ~= LocalPlayer() or IsValid( vgui.GetKeyboardFocus() ) then return end
	if button == KEY_G then RunConsoleCommand( "hl2bl_throw" ) end
end )

-- ---- count HUD -------------------------------------------------------------
hook.Add( "HUDPaint", "hl2bl_grenade_hud", function()
	local ply = LocalPlayer()
	if not ( IsValid( ply ) and ply:Alive() ) then return end

	local count = ply:GetNWInt( "hl2bl_grenades", 0 )
	local cap   = ply:GetNWInt( "hl2bl_grenade_cap", 3 )
	local items, slot = HL2BL.Grenades.items, HL2BL.Grenades.slot
	local mod  = ( items and slot and slot ~= 0 ) and items[ slot ] or nil
	local name = mod and ( mod.name or "Grenade" ) or "Standard Grenade"
	local col  = mod and ( HL2BL.RarityColor[ mod.rarity ] or color_white ) or color_white

	local x, y = 24, ScrH() - 150
	draw.SimpleText( "[" .. HL2BL.GrenadeKey .. "] " .. name, "HL2BL.Body", x, y - 18,
		count > 0 and Color( 200, 220, 255 ) or Color( 150, 150, 160 ) )
	draw.SimpleText( count .. " / " .. cap, "HL2BL.Ammo", x, y,
		count > 0 and col or Color( 120, 120, 128 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )
end )

-- ---- look-at card for dropped grenade mods ---------------------------------
hook.Add( "HUDPaint", "hl2bl_gren_lookat", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) or not ply:Alive() then return end
	local ent = ply:GetEyeTrace().Entity
	if not IsValid( ent ) or ent:GetClass() ~= "hl2bl_grenademod" then return end
	if ent:GetPos():DistToSqr( ply:EyePos() ) > 200 * 200 then return end

	local j = ent:GetNWString( "hl2bl_grenjson", "" ); if j == "" then return end
	local g = util.JSONToTable( j ); if not g then return end
	local x, y = ScrW() * 0.56, ScrH() * 0.30
	local hh = HL2BL.DrawGrenadeCard( x, y, g )
	draw.SimpleText( "[E] Pick up", "HL2BL.Title", x + 140, y + hh + 8, Color( 120, 230, 120 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
end )
