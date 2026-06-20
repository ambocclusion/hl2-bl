--[[ hl2bl: ammo HUD (client) ------------------------------------------------
	Shows clip / reserve and the rarity-colored gun name for the active rolled
	gun (our guns use a custom reserve pool, not GMod's ammo types).
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

surface.CreateFont( "HL2BL.Ammo", { font = "Roboto", size = 34, weight = 800 } )

local function activeHL2BLGun()
	local ply = LocalPlayer()
	if not IsValid( ply ) or not ply:Alive() then return end
	local wep = ply:GetActiveWeapon()
	if IsValid( wep ) and wep:GetNWBool( "hl2bl_rolled", false ) then return wep end
end

hook.Add( "HUDPaint", "hl2bl_ammo_hud", function()
	local wep = activeHL2BLGun()
	if not wep then return end

	local x, y = ScrW() - 40, ScrH() - 56
	draw.SimpleText( wep:Clip1() .. " / " .. wep:GetNWInt( "hl2bl_reserve", 0 ),
		"HL2BL.Ammo", x, y, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )

	local s = HL2BL.GetEntStats( wep )
	if s and s.name ~= "" then
		draw.SimpleText( s.name, "HL2BL.Body", x, y - 34,
			HL2BL.RarityColor[ s.rarity ] or color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
	end
end )

-- Hide the stock ammo HUD while holding one of our guns.
hook.Add( "HUDShouldDraw", "hl2bl_hide_ammo", function( name )
	if ( name == "CHudAmmo" or name == "CHudSecondaryAmmo" ) and activeHL2BLGun() then
		return false
	end
end )
