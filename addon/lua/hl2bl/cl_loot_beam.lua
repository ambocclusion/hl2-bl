--[[ hl2bl: loot beams + glow (client) ---------------------------------------
	Rarity-colored light beam, pulsing glow sprite, and a real dynamic light over
	dropped guns so loot is exciting and easy to spot. Higher rarity = bigger,
	brighter, faster pulse.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

local matGlow = Material( "sprites/light_glow02_add" )
local matBeam = Material( "trails/laser" )

hook.Add( "PostDrawTranslucentRenderables", "hl2bl_loot_beam", function( bDepth, bSky )
	if bDepth or bSky then return end

	for _, class in ipairs( HL2BL.LootClasses ) do
		for _, w in ipairs( ents.FindByClass( class ) ) do
			if IsValid( w ) and not IsValid( w:GetOwner() ) then
				local s   = HL2BL.GetEntStats( w )
				local rar = s and s.rarity or 0
				local rc  = ( s and HL2BL.RarityColor[ rar ] ) or color_white
				local pos = w:GetPos()

				local tall  = 110 + rar * 24            -- taller beam for rarer loot
				local width = 8 + rar * 2
				local pulse = ( 24 + rar * 5 ) + math.sin( CurTime() * ( 3 + rar ) ) * ( 4 + rar )

				render.SetMaterial( matBeam )
				render.DrawBeam( pos, pos + Vector( 0, 0, tall ), width, 0, 1,
					Color( rc.r, rc.g, rc.b, 170 ) )

				render.SetMaterial( matGlow )
				render.DrawSprite( pos + Vector( 0, 0, 22 ), pulse, pulse, rc )

				-- Real dynamic light so the drop actually illuminates the area.
				local dl = DynamicLight( w:EntIndex() )
				if dl then
					dl.pos        = pos + Vector( 0, 0, 24 )
					dl.r, dl.g, dl.b = rc.r, rc.g, rc.b
					dl.brightness = ( rar >= 3 ) and 4 or 2
					dl.size       = 160 + rar * 40
					dl.decay      = 1000
					dl.dietime    = CurTime() + 1
				end
			end
		end
	end
end )
