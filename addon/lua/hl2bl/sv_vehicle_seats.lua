--[[ hl2bl: vehicle passenger seats (server) ---------------------------------
	HL2's airboat and buggy are single-seat. This bolts up to 3 passenger seats
	(prop_vehicle_prisoner_pod) onto each, parented so they ride along with the
	host vehicle. Pods let the occupant keep and FIRE their handheld weapon, so
	co-op passengers can shoot while seated -- unlike the locked driver seat.

	Seats attach automatically to any airboat/buggy as it's created (spawned via
	the menu or placed by an HL2 campaign map), and to any that already exist
	when this module (re)loads.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

local cEnabled = CreateConVar( "hl2bl_vehicle_seats", "1", FCVAR_ARCHIVE,
	"Bolt passenger seats onto airboats/buggies so co-op players can ride and shoot." )

-- Per-vehicle config. Offsets are LOCAL space (X forward, Y left, Z up) relative
-- to the host vehicle; angles are local facing. Tuned by eye -- adjust here if a
-- seat sits low/clips on a given vehicle.
local SEATS = {
	prop_vehicle_airboat = {
		model = "models/nova/airboat_seat.mdl",
		seats = {
			{ Vector( -16,  20, -6 ), Angle( 0, 0, 0 ) },   -- rear left
			{ Vector( -16, -20, -6 ), Angle( 0, 0, 0 ) },   -- rear right
			{ Vector( -40,   0, -4 ), Angle( 0, 0, 0 ) },   -- tail
		},
	},
	prop_vehicle_jeep = {
		model = "models/nova/jeep_seat.mdl",
		seats = {
			{ Vector(   4, -28, -10 ), Angle( 0, 0, 0 ) },  -- shotgun (passenger)
			{ Vector( -34,  22,  -8 ), Angle( 0, 0, 0 ) },  -- rear left
			{ Vector( -34, -22,  -8 ), Angle( 0, 0, 0 ) },  -- rear right
		},
	},
}

local function addSeat( vehicle, model, offset, ang )
	local pod = ents.Create( "prop_vehicle_prisoner_pod" )
	if not IsValid( pod ) then return end
	pod:SetModel( model )
	pod:SetKeyValue( "vehiclescript", "scripts/vehicles/prisoner_pod.txt" )
	pod:SetKeyValue( "limitview", "0" )           -- let passengers look/aim freely
	pod:Spawn()
	pod:Activate()
	pod:SetParent( vehicle )
	pod:SetLocalPos( offset )
	pod:SetLocalAngles( ang )
	pod.HL2BL_Seat = true

	vehicle.HL2BL_Seats[ #vehicle.HL2BL_Seats + 1 ] = pod
	return pod
end

function HL2BL.AttachVehicleSeats( vehicle )
	if not cEnabled:GetBool() then return end
	if not IsValid( vehicle ) then return end
	if vehicle.HL2BL_Seats then return end        -- already fitted

	local cfg = SEATS[ vehicle:GetClass() ]
	if not cfg then return end

	vehicle.HL2BL_Seats = {}
	for _, s in ipairs( cfg.seats ) do
		addSeat( vehicle, cfg.model, s[1], s[2] )
	end

	-- Parented pods are removed automatically with the host, but be explicit so a
	-- vehicle that's picked up/respawned doesn't leak orphaned seats.
	vehicle:CallOnRemove( "hl2bl_vehicle_seats", function( v )
		for _, pod in ipairs( v.HL2BL_Seats or {} ) do
			if IsValid( pod ) then pod:Remove() end
		end
	end )
end

hook.Add( "OnEntityCreated", "hl2bl_vehicle_seats", function( ent )
	if not IsValid( ent ) or not SEATS[ ent:GetClass() ] then return end
	-- Defer one tick so the vehicle is fully initialized before we parent to it.
	timer.Simple( 0, function()
		if IsValid( ent ) then HL2BL.AttachVehicleSeats( ent ) end
	end )
end )

-- Fit vehicles that already exist (hot reload, or this module loading after the
-- map's vehicles spawned).
for class in pairs( SEATS ) do
	for _, v in ipairs( ents.FindByClass( class ) ) do
		HL2BL.AttachVehicleSeats( v )
	end
end
