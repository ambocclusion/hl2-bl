--[[ hl2bl: floating enemy health bars (client) ------------------------------
	A square, red health bar hovering over every hostile NPC, with current/max
	health centered in it. Badass variants get a fancy animated gold frame around
	the bar's edges. The wave boss is skipped (it has its own top-center bar in
	cl_boss_hud). Enemy set comes from the shared HL2BL.EnemyClasses.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

CreateClientConVar( "hl2bl_healthbars", "1", true, false, "Show floating enemy health bars." )

surface.CreateFont( "HL2BL.HealthBar", { font = "Roboto", size = 14, weight = 700, outline = true } )

local BAR_W, BAR_H = 66, 16
local RANGE2       = 1600 * 1600

-- True if world geometry blocks the eye->target line (so bars don't show through walls).
local function occluded( eye, target, ply )
	local tr = util.TraceLine( { start = eye, endpos = target, filter = ply, mask = MASK_SOLID_BRUSHONLY } )
	return tr.Hit
end

local grad      = Material( "gui/gradient" )
local GOLD      = Color( 255, 200,  70 )
local GOLD_HI   = Color( 255, 240, 170 )
local GOLD_DARK = Color( 120,  80,  10 )

-- Fancy gold frame around the bar (Badass only). Drawn procedurally with a
-- gui/gradient sheen + corner ornaments + a soft pulse, so it never depends on a
-- shipped texture (no missing-material checkerboard) yet reads as ornate gold.
local function drawGoldFrame( x, y, w, h )
	local pulse  = 0.5 + 0.5 * math.sin( RealTime() * 4 )
	local pad, t = 2, 3
	local fx, fy = x - pad, y - pad
	local fw, fh = w + pad * 2, h + pad * 2

	-- dark keyline so the gold pops against bright backdrops
	surface.SetDrawColor( GOLD_DARK.r, GOLD_DARK.g, GOLD_DARK.b, 230 )
	surface.DrawOutlinedRect( fx - 1, fy - 1, fw + 2, fh + 2, 1 )

	-- solid gold rails (square corners)
	surface.SetDrawColor( GOLD.r, GOLD.g, GOLD.b, 255 )
	surface.DrawRect( fx, fy, fw, t )              -- top
	surface.DrawRect( fx, fy + fh - t, fw, t )     -- bottom
	surface.DrawRect( fx, fy, t, fh )              -- left
	surface.DrawRect( fx + fw - t, fy, t, fh )     -- right

	-- metallic sheen sweeping the top & bottom rails
	surface.SetMaterial( grad )
	surface.SetDrawColor( GOLD_HI.r, GOLD_HI.g, GOLD_HI.b, 110 + 110 * pulse )
	surface.DrawTexturedRect( fx, fy, fw, t )
	surface.DrawTexturedRect( fx, fy + fh - t, fw, t )

	-- corner ornaments with a bright inner highlight
	local c = t + 2
	local corners = {
		{ fx - 1,          fy - 1          },
		{ fx + fw - c + 1, fy - 1          },
		{ fx - 1,          fy + fh - c + 1 },
		{ fx + fw - c + 1, fy + fh - c + 1 },
	}
	for _, p in ipairs( corners ) do
		surface.SetDrawColor( GOLD.r, GOLD.g, GOLD.b, 255 )
		surface.DrawRect( p[1], p[2], c, c )
		surface.SetDrawColor( GOLD_HI.r, GOLD_HI.g, GOLD_HI.b, 210 )
		surface.DrawRect( p[1] + 1, p[2] + 1, c - 2, c - 2 )
	end
end

hook.Add( "HUDPaint", "hl2bl_health_bars", function()
	if not GetConVar( "hl2bl_healthbars" ):GetBool() then return end
	if not HL2BL.EnemyClasses then return end

	local ply = LocalPlayer()
	if not IsValid( ply ) then return end
	local eye = ply:EyePos()

	for _, npc in ipairs( ents.FindByClass( "npc_*" ) ) do
		if HL2BL.EnemyClasses[ npc:GetClass() ]
			and npc:Health() > 0
			and not npc:GetNWBool( "hl2bl_isboss", false ) then

			local center = npc:WorldSpaceCenter()
			if center:DistToSqr( eye ) < RANGE2 and not occluded( eye, center, ply ) then
				local top = npc:GetPos() + Vector( 0, 0, npc:OBBMaxs().z + 12 )
				local scr = top:ToScreen()
				if scr.visible then
					local maxhp = math.max( 1, npc:GetMaxHealth() )
					local hp    = math.Clamp( npc:Health(), 0, maxhp )
					local frac  = hp / maxhp

					local x = math.Round( scr.x - BAR_W * 0.5 )
					local y = math.Round( scr.y - BAR_H )

					-- Badass: ornate gold frame around the bar's edges.
					if npc:GetNWString( "hl2bl_variant", "" ) == "Badass" then
						drawGoldFrame( x, y, BAR_W, BAR_H )
					end

					-- Square bar: dark backing + red fill + thin outline.
					surface.SetDrawColor( 0, 0, 0, 205 )
					surface.DrawRect( x, y, BAR_W, BAR_H )
					surface.SetDrawColor( 200, 40, 40, 235 )
					surface.DrawRect( x, y, math.Round( BAR_W * frac ), BAR_H )
					surface.SetDrawColor( 0, 0, 0, 230 )
					surface.DrawOutlinedRect( x, y, BAR_W, BAR_H, 1 )

					draw.SimpleText( math.floor( hp ) .. "/" .. math.floor( maxhp ),
						"HL2BL.HealthBar", x + BAR_W * 0.5, y + BAR_H * 0.5,
						color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
				end
			end
		end
	end
end )
