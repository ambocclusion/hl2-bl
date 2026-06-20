--[[ hl2bl: boss health bar (client) -----------------------------------------
	Top-center health bar + name for the active wave boss.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

local function findBoss()
	for _, e in ipairs( ents.FindByClass( "npc_*" ) ) do
		if e:GetNWBool( "hl2bl_isboss", false ) and e:GetNWInt( "hl2bl_boss_hp", 0 ) > 0 then
			return e
		end
	end
end

hook.Add( "HUDPaint", "hl2bl_boss_hud", function()
	local boss = findBoss()
	if not boss then return end

	local maxhp = boss:GetNWInt( "hl2bl_boss_maxhp", 1 )
	local hp    = boss:GetNWInt( "hl2bl_boss_hp", 0 )
	local frac  = math.Clamp( hp / math.max( 1, maxhp ), 0, 1 )
	local name  = boss:GetNWString( "hl2bl_boss_name", "Boss" )
	local lvl   = boss:GetNWInt( "hl2bl_npclevel", 0 )
	if lvl > 0 then name = name .. "  (Lv " .. lvl .. ")" end

	local w, h = ScrW() * 0.5, 26
	local x, y = ( ScrW() - w ) * 0.5, 70

	draw.SimpleText( name, "HL2BL.Title", ScrW() * 0.5, y - 6,
		Color( 255, 210, 90 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
	draw.RoundedBox( 4, x, y, w, h, Color( 0, 0, 0, 200 ) )
	draw.RoundedBox( 4, x, y, w * frac, h, Color( 220, 60, 60 ) )
	surface.SetDrawColor( 255, 210, 90, 220 )
	surface.DrawOutlinedRect( x, y, w, h, 1 )
	draw.SimpleText( hp .. " / " .. maxhp, "HL2BL.Body", ScrW() * 0.5, y + h * 0.5,
		color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
end )
