--[[ hl2bl: enemy spawn director (server) ------------------------------------
	Keeps a steady stream of enemies coming at the players (higher spawn rate than
	the map provides). Spawns at traced floor spots near players but out of sight,
	so it works on any map without a navmesh. Variants (incl. Badass) are applied
	automatically by sv_variants via OnEntityCreated.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

local cEnabled  = CreateConVar( "hl2bl_spawn_enabled",  "1",  FCVAR_ARCHIVE, "Enable the enemy spawn director." )
local cInterval = CreateConVar( "hl2bl_spawn_interval", "6",  FCVAR_ARCHIVE, "Seconds between spawn waves." )
local cMax      = CreateConVar( "hl2bl_spawn_max",      "24", FCVAR_ARCHIVE, "Max director-spawned NPCs alive at once." )
local cWave     = CreateConVar( "hl2bl_spawn_wave",     "3",  FCVAR_ARCHIVE, "Base enemies per wave (scales with players/level)." )
local cBossEvery= CreateConVar( "hl2bl_boss_every",     "5",  FCVAR_ARCHIVE, "Spawn a boss every N waves (0 = never)." )

local BOSS_POOL = { "npc_antlionguard" }

local POOL = {
	"npc_combine_s", "npc_metropolice", "npc_zombie",
	"npc_fastzombie", "npc_headcrab", "npc_antlion", "npc_manhack",
}
local DEFAULT_WEP = {
	npc_combine_s   = "weapon_smg1",
	npc_metropolice = "weapon_pistol",
}

local function visibleToAnyPlayer( pos )
	for _, ply in ipairs( player.GetAll() ) do
		if ply:Alive() then
			local tr = util.TraceLine( {
				start = ply:EyePos(), endpos = pos,
				filter = ply, mask = MASK_SOLID_BRUSHONLY,
			} )
			if not tr.Hit then return true end   -- clear line of sight
		end
	end
	return false
end

-- Find a valid floor spot near a player, out of sight. nil if none found.
function HL2BL.FindSpawnNear( ply )
	for _ = 1, 14 do
		local ang  = math.Rand( 0, math.pi * 2 )
		local dist = math.Rand( 520, 1400 )
		local cand = ply:GetPos() + Vector( math.cos( ang ) * dist, math.sin( ang ) * dist, 96 )

		local down = util.TraceLine( { start = cand, endpos = cand - Vector( 0, 0, 600 ), mask = MASK_SOLID_BRUSHONLY } )
		if down.Hit and not down.HitSky then
			local floor = down.HitPos + Vector( 0, 0, 4 )
			local hull = util.TraceHull( {
				start = floor, endpos = floor,
				mins = Vector( -16, -16, 0 ), maxs = Vector( 16, 16, 72 ), mask = MASK_SOLID,
			} )
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
	if not IsValid( npc ) then return end

	npc:SetPos( pos )
	npc:SetAngles( Angle( 0, math.random( 0, 360 ), 0 ) )
	if DEFAULT_WEP[ class ] then npc:SetKeyValue( "additionalequipment", DEFAULT_WEP[ class ] ) end
	npc:Spawn()
	npc:Activate()
	npc.HL2BL_Spawned = true   -- variant is applied by sv_variants (OnEntityCreated)
end

local function avgLevel( players )
	local sum = 0
	for _, p in ipairs( players ) do sum = sum + p:GetNWInt( "hl2bl_level", 1 ) end
	return #players > 0 and ( sum / #players ) or 1
end

local function spawnBoss( players, level )
	if IsValid( HL2BL._Boss ) then return end   -- one boss at a time
	local pos = HL2BL.FindSpawnNear( players[ math.random( #players ) ] )
	if not pos then return end
	local npc = ents.Create( BOSS_POOL[ math.random( #BOSS_POOL ) ] )
	if not IsValid( npc ) then return end
	npc:SetPos( pos )
	npc:SetAngles( Angle( 0, math.random( 0, 360 ), 0 ) )
	npc:Spawn()
	npc:Activate()
	npc.HL2BL_Spawned = true
	HL2BL.MakeBoss( npc, math.floor( level ) )   -- sync, before the variant timer fires
end

HL2BL._WaveCount = HL2BL._WaveCount or 0

timer.Create( "hl2bl_spawn_director", cInterval:GetFloat(), 0, function()
	timer.Adjust( "hl2bl_spawn_director", cInterval:GetFloat() )
	if not cEnabled:GetBool() then return end

	local players = {}
	for _, ply in ipairs( player.GetAll() ) do if ply:Alive() then players[ #players + 1 ] = ply end end
	local n = #players
	if n == 0 then return end

	HL2BL._WaveCount = HL2BL._WaveCount + 1
	local lvl = avgLevel( players )

	-- Boss wave.
	local bossEvery = cBossEvery:GetInt()
	if bossEvery > 0 and HL2BL._WaveCount % bossEvery == 0 then
		spawnBoss( players, lvl )
	end

	-- Wave size + cap scale with player count and average level.
	local waveSize = cWave:GetInt() + ( n - 1 ) * 2 + math.floor( lvl / 10 )
	local maxAlive = cMax:GetInt() + ( n - 1 ) * 8

	local alive = aliveSpawnCount()
	for _ = 1, waveSize do
		if alive >= maxAlive then break end
		local pos = HL2BL.FindSpawnNear( players[ math.random( n ) ] )
		if pos then spawnEnemy( pos ); alive = alive + 1 end
	end
end )
