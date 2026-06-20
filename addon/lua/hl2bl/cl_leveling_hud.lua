--[[ hl2bl: level / XP HUD (client) ------------------------------------------]]
HL2BL = HL2BL or {}

surface.CreateFont( "HL2BL.Level", { font = "Roboto", size = 24, weight = 800 } )

hook.Add( "HUDPaint", "hl2bl_level_hud", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) or not ply:Alive() then return end

	local lvl  = ply:GetNWInt( "hl2bl_level", 1 )
	local xp   = ply:GetNWInt( "hl2bl_xp", 0 )
	local need = HL2BL.XPForLevel( lvl )
	local frac = ( lvl >= HL2BL.MaxLevel ) and 1 or math.Clamp( xp / math.max( 1, need ), 0, 1 )

	local w, h = 240, 16
	local x, y = 24, ScrH() - 64

	draw.SimpleText( "Level " .. lvl, "HL2BL.Level", x, y - 26, color_white )
	draw.RoundedBox( 3, x, y, w, h, Color( 0, 0, 0, 180 ) )
	draw.RoundedBox( 3, x, y, w * frac, h, Color( 120, 200, 255 ) )

	local label = ( lvl >= HL2BL.MaxLevel ) and "MAX" or ( xp .. " / " .. need .. " XP" )
	draw.SimpleText( label, "HL2BL.Body", x + w / 2, y + h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

	draw.SimpleText( ply:GetNWInt( "hl2bl_credits", 0 ) .. " credits", "HL2BL.Body",
		x, y + h + 4, Color( 255, 220, 120 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )
end )
