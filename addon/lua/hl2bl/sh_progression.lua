--[[ hl2bl: progression curve (shared) ---------------------------------------
	XP/level math shared so the client HUD can render the XP bar without extra
	networking.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

HL2BL.MaxLevel = 60

-- XP required to advance FROM `level` to level+1.
function HL2BL.XPForLevel( level )
	return math.floor( 50 * ( level ^ 1.5 ) )
end

-- Damage power multiplier for an item/character level. Keeps guns scaling so a
-- level-60 weapon is meaningfully stronger than a level-1 one (1x at L1 -> ~6.3x
-- at L60). Applied on top of the rolled quality multiplier.
function HL2BL.LevelScale( level )
	return 1 + ( math.max( 1, level ) - 1 ) * 0.09
end
