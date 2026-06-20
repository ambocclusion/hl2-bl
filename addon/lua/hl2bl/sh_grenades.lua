--[[ hl2bl: grenades + grenade mods (shared) ---------------------------------
	Every player can throw grenades (a recharging count, NOT a weapon slot). The
	thrown grenade's behaviour comes from a "grenade spec":
	  * with NO mod equipped you throw the BaseGrenadeSpec (a plain frag),
	  * an equipped grenade MOD swaps in its rolled spec -> it "modifies your
	    grenade": delivery TYPE (MIRV / Singularity / Transfusion / Sticky /
	    Bouncing), an optional ELEMENT, damage/radius, carry capacity + recharge.
	Grenade mods are rarity-tiered loot like artifacts/armor: their own equip slot
	and bag. This file holds data/roll/naming/net; behaviour lives in
	sv_grenades.lua and entities/hl2bl_grenade.lua.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

HL2BL.GRENADE_SLOTS = 1   -- one grenade mod equipped at a time

-- Delivery types. dmgMult/radMult scale the base 55 dmg / 180 radius; the flags
-- (children/pull/heal/sticky/bounces) are read by the grenade entity.
HL2BL.GrenadeTypes = {
	standard    = { name = "Standard",       dmgMult = 1.00, radMult = 1.00, fuse = 2.0,
	                desc = "A clean frag blast." },
	mirv        = { name = "MIRV",           dmgMult = 0.70, radMult = 0.90, fuse = 2.0,
	                children = 4, childDmg = 0.45, desc = "Splits into 4 submunitions." },
	singularity = { name = "Singularity",    dmgMult = 0.80, radMult = 1.30, fuse = 2.2,
	                pull = true, desc = "Pulls enemies toward the blast." },
	transfusion = { name = "Transfusion",    dmgMult = 0.85, radMult = 1.00, fuse = 2.0,
	                heal = 0.35, desc = "Heals you for 35% of damage dealt." },
	sticky      = { name = "Sticky",         dmgMult = 1.20, radMult = 1.10, fuse = 2.5,
	                sticky = true, desc = "Sticks to the first surface or target." },
	bouncing    = { name = "Bouncing Betty", dmgMult = 0.60, radMult = 0.80, fuse = 3.0,
	                bounces = 3, desc = "Bounces, blasting on each hop." },
}
HL2BL.GrenadeTypeList = { "standard", "mirv", "singularity", "transfusion", "sticky", "bouncing" }

-- Plain grenade used when no mod is equipped. itemLevel tracks the player so it
-- stays relevant; everything else is fixed.
function HL2BL.BaseGrenadeSpec( level )
	return {
		kind = "grenademod", type = "standard", element = HL2BL.Element.NONE,
		rarity = HL2BL.Rarity.COMMON, itemLevel = math.max( 1, level or 1 ),
		name = "Standard Grenade", damage = 55, radius = 180, fuse = 2.0,
		capacity = 3, recharge = 8,
	}
end

-- Magnitude scalar from rarity + level (mirrors ArtifactPower).
function HL2BL.GrenadePower( rarity, level )
	return ( 1 + ( rarity or 0 ) * 0.4 ) * ( 1 + ( math.max( 1, level or 1 ) - 1 ) * 0.04 )
end

local function frand( lo, hi ) return lo + math.random() * ( hi - lo ) end

local function rollRarity( itemLevel, luck )
	local r = math.random() - ( itemLevel or 1 ) * 0.004 - ( luck or 0 )
	if r < 0.50 then return 0 elseif r < 0.78 then return 1
	elseif r < 0.93 then return 2 elseif r < 0.99 then return 3 else return 4 end
end

--- Roll a fresh grenade mod. forceRarity overrides the rarity roll.
function HL2BL.RollGrenade( itemLevel, luck, forceRarity )
	itemLevel = math.max( 1, itemLevel or 1 )
	local rarity = forceRarity or rollRarity( itemLevel, luck )
	local typeId = HL2BL.GrenadeTypeList[ math.random( #HL2BL.GrenadeTypeList ) ]
	local t      = HL2BL.GrenadeTypes[ typeId ]
	local power  = HL2BL.GrenadePower( rarity, itemLevel )

	local g = { kind = "grenademod", type = typeId, rarity = rarity, itemLevel = itemLevel }

	-- Element chance + identity scale with rarity (same shape as guns).
	local hasElement = 0.12 + rarity * 0.18
	g.element = ( math.random() < hasElement )
		and math.random( HL2BL.Element.INCENDIARY, HL2BL.ELEMENT_COUNT - 1 )
		or  HL2BL.Element.NONE

	g.damage   = math.Round( 55 * power * t.dmgMult * frand( 0.9, 1.1 ) )
	g.radius   = math.Round( 180 * t.radMult * frand( 0.95, 1.05 ) )
	g.fuse     = t.fuse
	g.capacity = 2 + rarity                       -- common 2 .. legendary 6
	g.recharge = math.max( 3, 9 - rarity )        -- common 9s .. legendary 5s
	g.name     = HL2BL.GrenadeName( g )
	return g
end

function HL2BL.GrenadeName( g )
	local t = HL2BL.GrenadeTypes[ g.type ] or HL2BL.GrenadeTypes.standard
	local parts = {}
	if ( g.element or 0 ) ~= HL2BL.Element.NONE then parts[ #parts + 1 ] = HL2BL.ElementName[ g.element ] end
	parts[ #parts + 1 ] = t.name
	return table.concat( parts, " " ) .. " Grenade"
end

-- Human-readable lines for the UI card.
function HL2BL.GrenadeDescLines( g )
	local t = HL2BL.GrenadeTypes[ g.type ] or HL2BL.GrenadeTypes.standard
	local lines = { "Thrown - does not use a weapon slot" }
	if ( g.element or 0 ) ~= HL2BL.Element.NONE then
		lines[ #lines + 1 ] = HL2BL.ElementName[ g.element ] .. " element"
	end
	lines[ #lines + 1 ] = math.Round( ( g.damage or 0 ) * HL2BL.LevelScale( g.itemLevel or 1 ) ) .. " blast damage"
	lines[ #lines + 1 ] = ( g.radius or 0 ) .. " blast radius"
	if t.desc then lines[ #lines + 1 ] = t.desc end
	lines[ #lines + 1 ] = string.format( "Holds %d  -  recharge %.0fs", g.capacity or 3, g.recharge or 8 )
	return lines
end

-- ---- net (de)serialize -----------------------------------------------------
function HL2BL.NetWriteGrenade( g )
	net.WriteString( g.type or "standard" )
	net.WriteUInt( g.element or 0, 3 )
	net.WriteUInt( g.rarity or 0, 3 )
	net.WriteUInt( g.itemLevel or 1, 12 )
	net.WriteString( g.name or "" )
	net.WriteUInt( math.max( 0, math.Round( g.damage or 0 ) ), 16 )
	net.WriteUInt( math.max( 0, math.Round( g.radius or 0 ) ), 12 )
	net.WriteUInt( math.Clamp( g.capacity or 3, 0, 31 ), 5 )
	net.WriteFloat( g.fuse or 2 )
	net.WriteFloat( g.recharge or 8 )
end

function HL2BL.NetReadGrenade()
	local g = { kind = "grenademod" }
	g.type      = net.ReadString()
	g.element   = net.ReadUInt( 3 )
	g.rarity    = net.ReadUInt( 3 )
	g.itemLevel = net.ReadUInt( 12 )
	g.name      = net.ReadString()
	g.damage    = net.ReadUInt( 16 )
	g.radius    = net.ReadUInt( 12 )
	g.capacity  = net.ReadUInt( 5 )
	g.fuse      = net.ReadFloat()
	g.recharge  = net.ReadFloat()
	return g
end
