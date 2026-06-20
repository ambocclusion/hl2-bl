--[[ hl2bl: encounter director (server) --------------------------------------
	Instead of spawning forever, the director runs discrete ENCOUNTERS: when the
	group moves into a new area it spawns a finite budget of enemies (with
	variance) over a few ticks, throttled by a concurrent cap, then STOPS once the
	budget is used and the area is cleared. Moving to a new area starts the next
	encounter after a cooldown.

	Dynamic difficulty: clearing cleanly (no deaths, high health, fast) raises a
	difficulty multiplier that sizes future encounters; struggling lowers it.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}
HL2BL.Difficulty = HL2BL.Difficulty or 1.0

local cEnabled  = CreateConVar( "hl2bl_spawn_enabled",      "1",    FCVAR_ARCHIVE, "Enable the encounter director." )
local cTick     = CreateConVar( "hl2bl_director_tick",      "3",    FCVAR_ARCHIVE, "Director think interval (seconds)." )
local cBase     = CreateConVar( "hl2bl_encounter_base",     "9",    FCVAR_ARCHIVE, "Base enemies per encounter (before scaling)." )
local cMaxBudget= CreateConVar( "hl2bl_encounter_max",      "36",   FCVAR_ARCHIVE, "Hard cap on enemies per encounter." )
local cCooldown = CreateConVar( "hl2bl_encounter_cooldown", "15",   FCVAR_ARCHIVE, "Seconds after a clear before the next encounter." )
local cTravel   = CreateConVar( "hl2bl_encounter_travel",   "1000", FCVAR_ARCHIVE, "Distance the group must move to start a new encounter." )
local cWave     = CreateConVar( "hl2bl_spawn_wave",         "4",    FCVAR_ARCHIVE, "Enemies spawned per director tick." )
local cConc     = CreateConVar( "hl2bl_spawn_max",          "14",   FCVAR_ARCHIVE, "Base concurrent alive cap during an encounter." )
local cBossEvery= CreateConVar( "hl2bl_boss_every",         "4",    FCVAR_ARCHIVE, "Boss encounter every N encounters (0 = never)." )

local POOL = {
	"npc_combine_s", "npc_metropolice", "npc_zombie",
	"npc_fastzombie", "npc_headcrab", "npc_antlion", "npc_manhack",
}
local DEFAULT_WEP = { npc_combine_s = "weapon_smg1", npc_metropolice = "weapon_pistol" }
local BOSS_POOL   = { "npc_antlionguard" }

-- ---- helpers ---------------------------------------------------------------
local function alivePlayers()
	local t = {}
	for _, p in ipairs( player.GetAll() ) do if p:Alive() then t[ #t + 1 ] = p end end
	return t
end

local function centroid( players )
	local v = Vector()
	for _, p in ipairs( players ) do v = v + p:GetPos() end
	return v / #players
end

local function avgLevel( players )
	local s = 0
	for _, p in ipairs( players ) do s = s + p:GetNWInt( "hl2bl_level", 1 ) end
	return #players > 0 and ( s / #players ) or 1
end

local function avgHealthFrac( players )
	local sum, n = 0, 0
	for _, p in ipairs( players ) do
		local mh = p:GetMaxHealth()
		if mh > 0 then sum = sum + p:Health() / mh; n = n + 1 end
	end
	return n > 0 and ( sum / n ) or 1
end

local function visibleToAnyPlayer( pos )
	for _, ply in ipairs( player.GetAll() ) do
		if ply:Alive() then
			local tr = util.TraceLine( { start = ply:EyePos(), endpos = pos, filter = ply, mask = MASK_SOLID_BRUSHONLY } )
			if not tr.Hit then return true end
		end
	end
	return false
end

function HL2BL.FindSpawnNear( ply )
	for _ = 1, 14 do
		local ang  = math.Rand( 0, math.pi * 2 )
		local dist = math.Rand( 520, 1400 )
		local cand = ply:GetPos() + Vector( math.cos( ang ) * dist, math.sin( ang ) * dist, 96 )
		local down = util.TraceLine( { start = cand, endpos = cand - Vector( 0, 0, 600 ), mask = MASK_SOLID_BRUSHONLY } )
		if down.Hit and not down.HitSky then
			local floor = down.HitPos + Vector( 0, 0, 4 )
			local hull = util.TraceHull( { start = floor, endpos = floor,
				mins = Vector( -16, -16, 0 ), maxs = Vector( 16, 16, 72 ), mask = MASK_SOLID } )
			if not hull.StartSolid and not visibleToAnyPlayer( floor + Vector( 0, 0, 40 ) ) then
				return floor
			end
		end
	end
end

local function aliveSpawnCount()
	local n = 0
	for _, class in ipairs( POOL ) do
		for _, e in ipairs( ents.FindByClass( class ) ) do
			if IsValid( e ) and e.HL2BL_Spawned and e:Health() > 0 then n = n + 1 end
		end
	end
	return n
end

local function spawnEnemy( pos )
	local class = POOL[ math.random( #POOL ) ]
	local npc = ents.Create( class )
	if not IsValid( npc ) then return false end
	npc:SetPos( pos )
	npc:SetAngles( Angle( 0, math.random( 0, 360 ), 0 ) )
	if DEFAULT_WEP[ class ] then npc:SetKeyValue( "additionalequipment", DEFAULT_WEP[ class ] ) end
	npc:Spawn()
	npc:Activate()
	npc.HL2BL_Spawned = true   -- variant applied by sv_variants
	return true
end

local function spawnBoss( players, level )
	if IsValid( HL2BL._Boss ) then return end
	local pos = HL2BL.FindSpawnNear( players[ math.random( #players ) ] )
	if not pos then return end
	local npc = ents.Create( BOSS_POOL[ math.random( #BOSS_POOL ) ] )
	if not IsValid( npc ) then return end
	npc:SetPos( pos ); npc:SetAngles( Angle( 0, math.random( 0, 360 ), 0 ) )
	npc:Spawn(); npc:Activate()
	npc.HL2BL_Spawned = true
	HL2BL.MakeBoss( npc, math.floor( level ) )
end

-- ---- encounter state machine ----------------------------------------------
local enc = { active = false, budget = 0, origin = nil, startTime = 0, deaths = 0, lastProgress = 0 }
HL2BL._EncCount = HL2BL._EncCount or 0

local function startEncounter( players, c )
	local n   = #players
	local lvl = avgLevel( players )

	local budget = ( cBase:GetInt() + ( n - 1 ) * 4 + math.floor( lvl / 8 ) )
		* HL2BL.Difficulty * math.Rand( 0.8, 1.2 )   -- variance
	enc.budget       = math.Clamp( math.Round( budget ), 3, cMaxBudget:GetInt() )
	enc.active       = true
	enc.origin       = c
	enc.startTime    = CurTime()
	enc.lastProgress = CurTime()
	enc.deaths       = 0

	HL2BL._EncCount = HL2BL._EncCount + 1
	if cBossEvery:GetInt() > 0 and HL2BL._EncCount % cBossEvery:GetInt() == 0 then
		spawnBoss( players, lvl )
		enc.budget = math.max( 3, math.Round( enc.budget * 0.6 ) )   -- fewer trash with a boss
	end
end

local function endEncounter( players )
	enc.active = false
	enc.cooldownUntil = CurTime() + cCooldown:GetInt()

	-- Dynamic difficulty from how the fight went.
	local hp   = avgHealthFrac( players )
	local fast = ( CurTime() - enc.startTime ) < 35
	local old  = HL2BL.Difficulty
	if enc.deaths == 0 and hp > 0.6 then
		HL2BL.Difficulty = math.min( HL2BL.Difficulty + ( fast and 0.18 or 0.10 ), 2.5 )
	elseif enc.deaths > 0 or hp < 0.30 then
		HL2BL.Difficulty = math.max( HL2BL.Difficulty - 0.20, 0.6 )
	end
	if math.abs( HL2BL.Difficulty - old ) > 0.001 then
		DevMsg( string.format( "[HL2BL] Difficulty %.2f -> %.2f (deaths %d, hp %.0f%%)\n",
			old, HL2BL.Difficulty, enc.deaths, hp * 100 ) )
	end
end

hook.Add( "PlayerDeath", "hl2bl_enc_deaths", function( victim )
	if enc.active and IsValid( victim ) and victim:IsPlayer() then enc.deaths = enc.deaths + 1 end
end )

enc.cooldownUntil = 0

timer.Create( "hl2bl_encounter_director", cTick:GetFloat(), 0, function()
	timer.Adjust( "hl2bl_encounter_director", cTick:GetFloat() )
	if not cEnabled:GetBool() then return end

	local players = alivePlayers()
	if #players == 0 then return end
	local c     = centroid( players )
	local alive = aliveSpawnCount()

	if enc.active then
		if enc.budget > 0 then
			-- Spawn a sub-wave up to the concurrent cap.
			local cap = cConc:GetInt() + ( #players - 1 ) * 3
			local room = math.max( 0, cap - alive )
			local n = math.min( cWave:GetInt(), enc.budget, room )
			for _ = 1, n do
				local pos = HL2BL.FindSpawnNear( players[ math.random( #players ) ] )
				if pos and spawnEnemy( pos ) then
					enc.budget = enc.budget - 1
					enc.lastProgress = CurTime()
				end
			end
		elseif alive == 0 and not IsValid( HL2BL._Boss ) then
			endEncounter( players )                       -- area cleared -> stop
		end

		-- Stall guard: if we can't make progress for a while, end it.
		if enc.active and alive == 0 and ( CurTime() - enc.lastProgress ) > 25 then
			endEncounter( players )
		end
	else
		-- Idle: start a new encounter only after moving into a new area + cooldown.
		local moved = ( not enc.origin ) or ( c:Distance( enc.origin ) >= cTravel:GetFloat() )
		if moved and CurTime() >= ( enc.cooldownUntil or 0 ) then
			startEncounter( players, c )
		end
	end
end )
