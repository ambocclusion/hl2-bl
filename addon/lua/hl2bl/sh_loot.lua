--[[ hl2bl: shared loot model -------------------------------------------------
	Rarity + element definitions and the weighted gun-stat roll. Loaded on both
	client and server so they agree on stat meaning. Ported from the C++
	prototype (hl2bl_loot.cpp).
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

-- Gun classes eligible to drop / be rendered as loot. Extend as guns are added.
HL2BL.LootClasses = {
	"hl2bl_pistol", "hl2bl_smg", "hl2bl_shotgun", "hl2bl_rifle", "hl2bl_sniper",
	"hl2bl_crowbar", "hl2bl_stunbaton",
}

-- Rarity tiers (higher = stronger rolls).
HL2BL.Rarity = {
	COMMON    = 0,
	UNCOMMON  = 1,
	RARE      = 2,
	EPIC      = 3,
	LEGENDARY = 4,
}
HL2BL.RARITY_COUNT = 5

HL2BL.RarityName = {
	[0] = "Common", [1] = "Uncommon", [2] = "Rare", [3] = "Epic", [4] = "Legendary",
}

-- Borderlands-style rarity tints.
HL2BL.RarityColor = {
	[0] = Color( 255, 255, 255 ),	-- common    white
	[1] = Color(  61, 209,  61 ),	-- uncommon  green
	[2] = Color(  74, 144, 217 ),	-- rare      blue
	[3] = Color( 166,  77, 209 ),	-- epic      purple
	[4] = Color( 255, 128,   0 ),	-- legendary orange
}

-- Elemental modifiers.
HL2BL.Element = {
	NONE       = 0,
	INCENDIARY = 1,
	SHOCK      = 2,
	CORROSIVE  = 3,
	EXPLOSIVE  = 4,
	CRYO       = 5,
}
HL2BL.ELEMENT_COUNT = 6

HL2BL.ElementName = {
	[0] = "Kinetic", [1] = "Incendiary", [2] = "Shock",
	[3] = "Corrosive", [4] = "Explosive", [5] = "Cryo",
}

-- Manufacturers bias the rolled stats and flavor the name (spread/reload < 1 is
-- better, so a <1 bias improves them).
HL2BL.Manufacturers = {
	vanguard   = { name = "Vanguard",   dmg = 1.00, rof = 1.00, spread = 1.00, mag = 1.00, reload = 1.00, elem = 1.00 },
	ironclad   = { name = "Ironclad",   dmg = 1.25, rof = 0.80, spread = 0.90, mag = 0.90, reload = 1.00, elem = 1.00 },
	volt       = { name = "Volt",       dmg = 0.90, rof = 1.30, spread = 1.15, mag = 1.10, reload = 1.00, elem = 1.00 },
	precision  = { name = "Precision",  dmg = 1.05, rof = 0.95, spread = 0.70, mag = 0.90, reload = 1.00, elem = 1.00 },
	surplus    = { name = "Surplus",    dmg = 0.95, rof = 1.05, spread = 1.15, mag = 1.60, reload = 1.10, elem = 1.00 },
	elementech = { name = "Elementech", dmg = 0.95, rof = 1.00, spread = 0.95, mag = 1.00, reload = 1.00, elem = 1.50 },
	rapidax    = { name = "Rapidax",    dmg = 1.00, rof = 1.05, spread = 1.00, mag = 0.95, reload = 0.65, elem = 1.00 },
}
HL2BL.ManufacturerList = { "vanguard", "ironclad", "volt", "precision", "surplus", "elementech", "rapidax" }

function HL2BL.ManufacturerName( id )
	local m = HL2BL.Manufacturers[ id ]
	return m and m.name or "Vanguard"
end

-- Weighted rarity pick; higher item level + luck nudge odds upward.
local function RollRarity( itemLevel, luck )
	local roll = math.random() - itemLevel * 0.004 - ( luck or 0 )
	if roll < 0.50 then return HL2BL.Rarity.COMMON end
	if roll < 0.78 then return HL2BL.Rarity.UNCOMMON end
	if roll < 0.93 then return HL2BL.Rarity.RARE end
	if roll < 0.99 then return HL2BL.Rarity.EPIC end
	return HL2BL.Rarity.LEGENDARY
end

local function frand( lo, hi ) return lo + math.random() * ( hi - lo ) end

--- Roll a fresh stat table for a weapon at the given item level.
-- Multipliers are 1.0 == base weapon value.
-- Vendor stock skews low: good guns are genuinely rare to find for sale.
local function RollVendorRarity()
	local r = math.random()
	if r < 0.62  then return HL2BL.Rarity.COMMON end
	if r < 0.88  then return HL2BL.Rarity.UNCOMMON end
	if r < 0.975 then return HL2BL.Rarity.RARE end
	if r < 0.998 then return HL2BL.Rarity.EPIC end
	return HL2BL.Rarity.LEGENDARY	-- ~0.2%
end

-- Build a full stat table for a known rarity + item level.
local function buildStats( rarity, itemLevel )
	itemLevel = math.max( 1, itemLevel or 1 )
	local rarityBonus = rarity * 0.15	-- 0.0 .. 0.6

	-- Quality multipliers (level power is applied separately via LevelScale).
	local s = {
		kind          = "weapon",
		rarity        = rarity,
		itemLevel     = itemLevel,
		damageMult    = 1.0 + rarityBonus + frand( -0.08, 0.12 ),
		fireRateMult  = 1.0 + frand( -0.10, 0.10 + rarityBonus * 0.3 ),
		spreadMult    = 1.0 - frand( 0.0, 0.10 + rarityBonus * 0.4 ),
		reloadMult    = 1.0 - frand( 0.0, 0.10 + rarityBonus * 0.3 ),
		magMult       = 1.0 + frand( 0.0, rarityBonus ),
		element       = HL2BL.Element.NONE,
		elementChance = 0.0,
		elementDamage = 0.0,
	}

	-- Element chance + magnitude scale with rarity and item level.
	local hasElement = 0.10 + rarity * 0.18
	if math.random() < hasElement then
		s.element       = math.random( HL2BL.Element.INCENDIARY, HL2BL.ELEMENT_COUNT - 1 )
		s.elementChance = frand( 0.10, 0.20 + rarityBonus * 0.3 )
		s.elementDamage = ( 4.0 + itemLevel * 0.75 ) * ( 1.0 + rarityBonus )
	end

	-- Manufacturer biases (adds variety; flavors the name).
	local manuId = HL2BL.ManufacturerList[ math.random( #HL2BL.ManufacturerList ) ]
	local m = HL2BL.Manufacturers[ manuId ]
	s.manufacturer  = manuId
	s.damageMult    = s.damageMult   * m.dmg
	s.fireRateMult  = s.fireRateMult * m.rof
	s.spreadMult    = math.Clamp( s.spreadMult * m.spread, 0.30, 1.60 )
	s.reloadMult    = math.Clamp( s.reloadMult * m.reload, 0.40, 1.40 )
	s.magMult       = s.magMult      * m.mag
	if s.element ~= HL2BL.Element.NONE then
		s.elementDamage = s.elementDamage * m.elem
		s.elementChance = math.Clamp( s.elementChance * m.elem, 0, 0.95 )
	end

	return s
end

-- luck (0..~0.3) biases toward higher rarity; forceRarity overrides the roll.
function HL2BL.RollStats( itemLevel, luck, forceRarity )
	itemLevel = math.max( 1, itemLevel or 1 )
	return buildStats( forceRarity or RollRarity( itemLevel, luck ), itemLevel )
end

-- Vendor stock roll (low-rarity skew).
function HL2BL.RollVendorStats( itemLevel )
	return buildStats( RollVendorRarity(), math.max( 1, itemLevel or 1 ) )
end

-- Buy / sell pricing from a stat table.
local RARITY_PRICE = { [0] = 1, [1] = 2, [2] = 4, [3] = 9, [4] = 25 }
function HL2BL.GunPrice( s )
	return math.Round( ( 40 + ( s.itemLevel or 1 ) * 12 ) * ( RARITY_PRICE[ s.rarity ] or 1 ) )
end
function HL2BL.GunSellPrice( s )
	return math.floor( HL2BL.GunPrice( s ) * 0.4 )
end

-- Serialize a stat table over the net library (used by the inventory sync).
function HL2BL.NetWriteStats( s )
	net.WriteString( s.archetype or "smg" )
	net.WriteString( s.manufacturer or "vanguard" )
	net.WriteString( s.name or "" )
	net.WriteUInt( s.rarity or 0, 3 )
	net.WriteUInt( s.element or 0, 3 )
	net.WriteUInt( s.itemLevel or 1, 12 )
	net.WriteFloat( s.damageMult or 1 )
	net.WriteFloat( s.fireRateMult or 1 )
	net.WriteFloat( s.spreadMult or 1 )
	net.WriteFloat( s.reloadMult or 1 )
	net.WriteFloat( s.magMult or 1 )
	net.WriteFloat( s.elementChance or 0 )
	net.WriteFloat( s.elementDamage or 0 )
end

function HL2BL.NetReadStats()
	local s = {}
	s.archetype     = net.ReadString()
	s.manufacturer  = net.ReadString()
	s.name          = net.ReadString()
	s.rarity        = net.ReadUInt( 3 )
	s.element       = net.ReadUInt( 3 )
	s.itemLevel     = net.ReadUInt( 12 )
	s.damageMult    = net.ReadFloat()
	s.fireRateMult  = net.ReadFloat()
	s.spreadMult    = net.ReadFloat()
	s.reloadMult    = net.ReadFloat()
	s.magMult       = net.ReadFloat()
	s.elementChance = net.ReadFloat()
	s.elementDamage = net.ReadFloat()
	return s
end

--- Read a weapon/loot entity's rolled stats from its networked vars.
-- Works in both realms; returns nil if the entity hasn't been rolled.
function HL2BL.GetEntStats( ent )
	if not IsValid( ent ) or not ent:GetNWBool( "hl2bl_rolled", false ) then return nil end
	return {
		archetype     = ent:GetNWString( "hl2bl_arch", "smg" ),
		manufacturer  = ent:GetNWString( "hl2bl_manu", "vanguard" ),
		rarity        = ent:GetNWInt(   "hl2bl_rarity", 0 ),
		element       = ent:GetNWInt(   "hl2bl_element", 0 ),
		itemLevel     = ent:GetNWInt(   "hl2bl_ilvl", 1 ),
		damageMult    = ent:GetNWFloat( "hl2bl_dmg", 1 ),
		fireRateMult  = ent:GetNWFloat( "hl2bl_rof", 1 ),
		spreadMult    = ent:GetNWFloat( "hl2bl_spread", 1 ),
		reloadMult    = ent:GetNWFloat( "hl2bl_reload", 1 ),
		magMult       = ent:GetNWFloat( "hl2bl_mag", 1 ),
		elementChance = ent:GetNWFloat( "hl2bl_echance", 0 ),
		elementDamage = ent:GetNWFloat( "hl2bl_edmg", 0 ),
		name          = ent:GetNWString( "hl2bl_name", "" ),
	}
end

-- ---- loot beacon targeting -------------------------------------------------
-- "Look at the colored beacon to grab/inspect" range. ~2 m in source units.
HL2BL.LOOT_REACH = 110
local BEACON_DOT = math.cos( math.rad( 22 ) )   -- aim-cone half-angle

-- The world loot the player is looking at (dropped guns w/o owner + armor
-- pickups) within LOOT_REACH, picking whichever beacon best lines up with their
-- aim and is actually visible (not behind world geometry). Shared so the stat
-- card (client) and the extended pickup (server) agree on the target. nil if none.
function HL2BL.LootBeaconTarget( ply )
	if not IsValid( ply ) then return nil end
	local eye, aim = ply:EyePos(), ply:GetAimVector()
	local reach    = HL2BL.LOOT_REACH
	local best, bestDot = nil, BEACON_DOT

	local function consider( ent )
		if not IsValid( ent ) then return end
		local target = ent:WorldSpaceCenter() + Vector( 0, 0, 18 )   -- toward the beacon base
		local to     = target - eye
		local d      = to:Length()
		if d < 4 or d > reach then return end
		if aim:Dot( to / d ) < bestDot then return end
		-- Require line of sight: the beacon renders depth-tested, so if a wall
		-- hides it you aren't "looking at" it.
		local tr = util.TraceLine( { start = eye, endpos = target, filter = ply, mask = MASK_SOLID_BRUSHONLY } )
		if tr.Hit and tr.Fraction < 0.97 then return end
		bestDot = aim:Dot( to / d ); best = ent
	end

	for _, class in ipairs( HL2BL.LootClasses ) do
		for _, e in ipairs( ents.FindByClass( class ) ) do
			if not IsValid( e:GetOwner() ) then consider( e ) end
		end
	end
	for _, e in ipairs( ents.FindByClass( "hl2bl_armor" ) ) do consider( e ) end

	return best
end
