--[[ hl2bl: variant nameplates (client) --------------------------------------
	Floating label over special enemy variants (Badass / Armored / Runner) so
	they read at a glance.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

surface.CreateFont( "HL2BL.Variant", { font = "Roboto", size = 20, weight = 800, outline = true } )

local COLORS = {
	Badass  = Color( 255, 80, 80 ),
	Armored = Color( 185, 185, 200 ),
	Runner  = Color( 120, 230, 230 ),
}

hook.Add( "HUDPaint", "hl2bl_variant_tag", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) then return end
	local eye = ply:EyePos()

	for _, npc in ipairs( ents.FindByClass( "npc_*" ) ) do
		local id = npc:GetNWString( "hl2bl_variant", "" )
		if id ~= "" and npc:Health() > 0 then
			local pos = npc:WorldSpaceCenter()
			if pos:DistToSqr( eye ) < 1600 * 1600 then
				local top = npc:GetPos() + Vector( 0, 0, npc:OBBMaxs().z + 12 )
				local scr = top:ToScreen()
				if scr.visible then
					draw.SimpleTextOutlined( id, "HL2BL.Variant", scr.x, scr.y,
						COLORS[ id ] or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM,
						1, color_black )
				end
			end
		end
	end
end )
