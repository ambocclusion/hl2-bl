--[[ hl2bl: vendor server logic ----------------------------------------------
	Net handling for opening a vendor, buying stock, and selling backpack guns.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

util.AddNetworkString( "hl2bl_vendor_open" )
util.AddNetworkString( "hl2bl_vendor_buy" )
util.AddNetworkString( "hl2bl_vendor_sell" )

local function sendStock( ply, vendor )
	net.Start( "hl2bl_vendor_open" )
		net.WriteEntity( vendor )
		net.WriteUInt( #vendor.Stock, 6 )
		for _, s in ipairs( vendor.Stock ) do HL2BL.NetWriteStats( s ) end
	net.Send( ply )
end

function HL2BL.OpenVendor( ply, vendor )
	sendStock( ply, vendor )
end

local function near( ply, vendor )
	return IsValid( vendor ) and vendor:GetClass() == "hl2bl_vendor"
		and ply:GetPos():DistToSqr( vendor:GetPos() ) <= 220 * 220
end

net.Receive( "hl2bl_vendor_buy", function( _, ply )
	local vendor = net.ReadEntity()
	local idx    = net.ReadUInt( 6 )
	if not near( ply, vendor ) then return end

	local stock = vendor.Stock or {}
	local s = stock[ idx ]
	if not s then return end

	local price = HL2BL.GunPrice( s )
	if HL2BL.GetCredits( ply ) < price then ply:ChatPrint( "[HL2BL] Not enough credits." ); return end
	if not HL2BL.InventoryAdd( ply, table.Copy( s ) ) then ply:ChatPrint( "[HL2BL] Backpack full." ); return end

	HL2BL.TakeCredits( ply, price )
	table.remove( stock, idx )
	ply:EmitSound( "buttons/button14.wav", 60, 100 )
	sendStock( ply, vendor )   -- refresh the buy list
end )

net.Receive( "hl2bl_vendor_sell", function( _, ply )
	local invIndex = net.ReadUInt( 6 )
	local removed = HL2BL.InventoryRemove( ply, invIndex )
	if removed then
		HL2BL.AddCredits( ply, HL2BL.GunSellPrice( removed ) )
		ply:EmitSound( "buttons/button14.wav", 60, 120 )
	end
end )

-- ---- auto-place one vendor at the map's spawn area on load -----------------
local SPAWN_CLASSES = {
	"info_player_start", "info_player_deathmatch", "info_player_rebel",
	"info_player_combine", "info_player_counterterrorist", "info_player_terrorist",
	"info_player_teamspawn", "info_player_allies", "info_player_axis",
}

local function findSpawnPoint()
	for _, c in ipairs( SPAWN_CLASSES ) do
		local found = ents.FindByClass( c )
		if found[1] then return found[1] end
	end
end

-- A floor spot offset from origin with room for the machine; origin as fallback.
local function floorSpotNear( origin )
	for _, off in ipairs( { Vector( 100, 0, 0 ), Vector( -100, 0, 0 ),
	                        Vector( 0, 100, 0 ), Vector( 0, -100, 0 ), Vector( 90, 90, 0 ) } ) do
		local cand = origin + off + Vector( 0, 0, 24 )
		local tr = util.TraceLine( { start = cand, endpos = cand - Vector( 0, 0, 250 ), mask = MASK_SOLID_BRUSHONLY } )
		if tr.Hit and not tr.HitSky then
			local floor = tr.HitPos + Vector( 0, 0, 2 )
			local hull = util.TraceHull( {
				start = floor, endpos = floor,
				mins = Vector( -20, -20, 0 ), maxs = Vector( 20, 20, 72 ), mask = MASK_SOLID,
			} )
			if not hull.StartSolid then return floor end
		end
	end
	return origin
end

local function placeSpawnVendor()
	if #ents.FindByClass( "hl2bl_vendor" ) > 0 then return end   -- already one here
	local sp = findSpawnPoint()
	if not sp then return end

	local origin = sp:GetPos()
	local pos    = floorSpotNear( origin )

	local v = ents.Create( "hl2bl_vendor" )
	if not IsValid( v ) then return end
	v:SetPos( pos )
	local yaw = ( origin - pos ):Angle().yaw   -- face the spawn
	v:SetAngles( Angle( 0, yaw, 0 ) )
	v:Spawn()
	v.HL2BL_AutoPlaced = true
end

hook.Add( "InitPostEntity", "hl2bl_vendor_autoplace", function()
	timer.Simple( 2, placeSpawnVendor )   -- let map entities settle first
end )

concommand.Add( "hl2bl_spawn_vendor", function( ply )
	if IsValid( ply ) and not ply:IsSuperAdmin() then return end
	local pos = IsValid( ply ) and ply:GetEyeTrace().HitPos or vector_origin
	local v = ents.Create( "hl2bl_vendor" )
	if not IsValid( v ) then return end
	v:SetPos( pos )
	v:Spawn()
end, nil, "Spawn an HL2BL vending machine where you're looking (superadmin)." )
