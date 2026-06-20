--[[ hl2bl: player name tags (client) ----------------------------------------
	Floating name (+ level) above other players, hidden through walls.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

surface.CreateFont( "HL2BL.PlayerName", { font = "Roboto", size = 18, weight = 600, outline = true } )

local RANGE2 = 2500 * 2500

hook.Add( "HUDPaint", "hl2bl_player_names", function()
	local me = LocalPlayer()
	if not IsValid( me ) then return end
	local eye = me:EyePos()

	for _, ply in ipairs( player.GetAll() ) do
		if ply ~= me and ply:Alive() and not ply:GetNoDraw() then
			local pos = ply:WorldSpaceCenter()
			if pos:DistToSqr( eye ) < RANGE2 then
				local tr = util.TraceLine( { start = eye, endpos = pos, filter = { me, ply }, mask = MASK_SOLID_BRUSHONLY } )
				if not tr.Hit then
					local top = ply:GetPos() + Vector( 0, 0, ply:OBBMaxs().z + 10 )
					local scr = top:ToScreen()
					if scr.visible then
						local lvl  = ply:GetNWInt( "hl2bl_level", 1 )
						local text = ply:Nick() .. "  (Lv " .. lvl .. ")"
						draw.SimpleTextOutlined( text, "HL2BL.PlayerName", scr.x, scr.y,
							Color( 150, 220, 255 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, color_black )
					end
				end
			end
		end
	end
end )
