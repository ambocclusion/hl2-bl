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
-- at L60). Applied on top of the rolled quality multiplier. Also reused as the
-- enemy outgoing-damage curve (enemies scale damage by LevelScale of their level).
function HL2BL.LevelScale( level )
	return 1 + ( math.max( 1, level ) - 1 ) * 0.09
end

-- ---- enemy level (derived) -------------------------------------------------
-- Enemies don't have their own progression; their level is DERIVED from nearby
-- players: +1 for a regular enemy, +3 for a boss. This single value is the parent
-- that both an enemy's health (EnemyHealthScale) and its outgoing damage
-- (LevelScale) scale from -- neither reads the player's level directly.
HL2BL.EnemyLevelOffset = 1
HL2BL.BossLevelOffset  = 3

function HL2BL.EnemyLevel( playerLevel, isBoss )
	return math.max( 1, playerLevel ) + ( isBoss and HL2BL.BossLevelOffset or HL2BL.EnemyLevelOffset )
end

-- Enemy max-health growth per level (tunable). Default +9%/level.
if SERVER then
	HL2BL.NPCHealthScale = HL2BL.NPCHealthScale
		or CreateConVar( "hl2bl_npc_health_scale", "0.09", FCVAR_ARCHIVE, "Enemy max-health growth per level." )
end

-- Enemy max-health multiplier for an enemy of the given level.
function HL2BL.EnemyHealthScale( level )
	local per = ( HL2BL.NPCHealthScale and HL2BL.NPCHealthScale:GetFloat() ) or 0.09
	return 1 + ( math.max( 1, level ) - 1 ) * per
end
