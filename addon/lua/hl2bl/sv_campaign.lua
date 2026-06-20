--[[ hl2bl: co-op campaign progression (server) ------------------------------
	Ordered HL2 campaign map list with start/next commands, plus best-effort
	auto-advance when a player reaches a trigger_changelevel. Player level/xp and
	backpack are PData-persisted (see sv_leveling / sv_inventory), so progression
	carries across map changes.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

HL2BL.CampaignAuto = CreateConVar( "hl2bl_campaign_auto", "1", FCVAR_ARCHIVE,
	"Auto-advance to the next map when a player reaches a level transition." )

-- Canonical Half-Life 2 campaign order.
HL2BL.Campaign = {
	"d1_trainstation_01", "d1_trainstation_02", "d1_trainstation_03",
	"d1_trainstation_04", "d1_trainstation_05", "d1_trainstation_06",
	"d1_canals_01", "d1_canals_01a", "d1_canals_02", "d1_canals_03",
	"d1_canals_05", "d1_canals_06", "d1_canals_07", "d1_canals_08",
	"d1_canals_09", "d1_canals_10", "d1_canals_11", "d1_canals_12", "d1_canals_13",
	"d1_eli_01", "d1_eli_02",
	"d1_town_01", "d1_town_01a", "d1_town_02", "d1_town_02a",
	"d1_town_03", "d1_town_04", "d1_town_05",
	"d2_coast_01", "d2_coast_03", "d2_coast_04", "d2_coast_05",
	"d2_coast_07", "d2_coast_08", "d2_coast_09", "d2_coast_10",
	"d2_coast_11", "d2_coast_12",
	"d2_prison_01", "d2_prison_02", "d2_prison_03", "d2_prison_04",
	"d2_prison_05", "d2_prison_06", "d2_prison_07", "d2_prison_08",
	"d3_c17_01", "d3_c17_02", "d3_c17_03", "d3_c17_04", "d3_c17_05",
	"d3_c17_06a", "d3_c17_06b", "d3_c17_07", "d3_c17_08", "d3_c17_09",
	"d3_c17_10a", "d3_c17_10b", "d3_c17_11", "d3_c17_12", "d3_c17_12b", "d3_c17_13",
	"d3_citadel_01", "d3_citadel_02", "d3_citadel_03", "d3_citadel_04", "d3_citadel_05",
	"d3_breen_01",
}

local changing = false

local function changeTo( map )
	if changing or not map or map == "" then return end
	changing = true
	for _, ply in ipairs( player.GetAll() ) do
		ply:ChatPrint( "[HL2BL] Advancing to " .. map .. "..." )
	end
	-- level/xp/backpack are already persisted via PData on every change.
	timer.Simple( 1.5, function() game.ConsoleCommand( "changelevel " .. map .. "\n" ) end )
end

local function nextMap()
	local cur = game.GetMap()
	for i, m in ipairs( HL2BL.Campaign ) do
		if m == cur then return HL2BL.Campaign[ i + 1 ] end
	end
	return nil
end
HL2BL.CampaignNext = nextMap

local function canAdmin( ply ) return not IsValid( ply ) or ply:IsSuperAdmin() end

concommand.Add( "hl2bl_campaign_start", function( ply )
	if not canAdmin( ply ) then return end
	changeTo( HL2BL.Campaign[ 1 ] )
end, nil, "Start the HL2 campaign from the beginning." )

concommand.Add( "hl2bl_campaign_next", function( ply )
	if not canAdmin( ply ) then return end
	local m = nextMap()
	if m then changeTo( m )
	else for _, p in ipairs( player.GetAll() ) do p:ChatPrint( "[HL2BL] No next campaign map (end, or off-list map)." ) end end
end, nil, "Advance to the next HL2 campaign map." )

-- Target map for a trigger: its own destination if readable, else next in order.
local function triggerTarget( t )
	local m = t.GetInternalVariable and t:GetInternalVariable( "m_szMapName" )
	if m and m ~= "" then return m end
	return nextMap()
end

-- A player is "at" a transition if touching it, or inside its brush bounds
-- (GMod doesn't reliably report touch for these, so we test the AABB too).
local function playerAtTrigger( ply, t )
	for _, e in ipairs( t:GetTouchingEntities() ) do if e == ply then return true end end
	local lp = t:WorldToLocal( ply:WorldSpaceCenter() )
	return lp:WithinAABox( t:OBBMins(), t:OBBMaxs() )
end

-- Don't auto-advance right after spawning (players may overlap the back-transition).
hook.Add( "InitPostEntity", "hl2bl_campaign_loadtime", function() HL2BL._MapStart = CurTime() end )

-- GMod doesn't fire trigger_changelevel itself in multiplayer, so we drive it:
-- when any player reaches a level transition, change the whole group's level.
timer.Create( "hl2bl_campaign_watch", 1, 0, function()
	if changing or not HL2BL.CampaignAuto:GetBool() then return end
	if CurTime() - ( HL2BL._MapStart or 0 ) < 6 then return end   -- spawn grace

	local triggers = ents.FindByClass( "trigger_changelevel" )
	if #triggers == 0 then return end

	for _, ply in ipairs( player.GetAll() ) do
		if ply:Alive() then
			for _, t in ipairs( triggers ) do
				if IsValid( t ) and playerAtTrigger( ply, t ) then
					changeTo( triggerTarget( t ) )
					return
				end
			end
		end
	end
end )
