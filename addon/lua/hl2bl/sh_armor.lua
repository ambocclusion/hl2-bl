--[[ hl2bl: armor model (shared) ---------------------------------------------
	HEV-suit armor pieces: procedurally rolled, rarity-tiered loot like guns, but
	defensive. Four slots (Helmet / Vest / Greaves / Power Core) mirror the four
	weapon slots. Pieces roll a VARIETY of HL2-flavored bonuses:
	  * maxArmor  -> the blue HEV suit bar (absorbs damage natively),
	  * maxHealth -> bonus max HP,
	  * regen     -> flat HP/s, scaled off item level.
	Slot + HL2-faction source bias which stats a piece favors. Shared so the
	client renders cards/the paper-doll without extra networking. Effects live in
	sv_armor.lua; both fold into HL2BL.RecomputePassive (the single stat authority).
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

HL2BL.ARMOR_SLOTS = { "helmet", "vest", "greaves", "core" }
HL2BL.ArmorSlotName = {
	helmet = "Helmet", vest = "Vest", greaves = "Greaves", core = "Power Core",
}

-- HL2-faction sources: bias the stat mix and flavor the name.
HL2BL.ArmorSources = {
	blackmesa  = { name = "Black Mesa",        armor = 0.9, health = 1.0, regen = 1.4 },
	combine    = { name = "Combine Overwatch", armor = 1.5, health = 1.0, regen = 0.6 },
	civil      = { name = "Civil Protection",  armor = 1.2, health = 1.0, regen = 0.8 },
	resistance = { name = "City 17 Resistance",armor = 0.8, health = 1.3, regen = 1.1 },
	synth      = { name = "Synth",             armor = 1.2, health = 1.2, regen = 1.2 },
}
HL2BL.ArmorSourceList = { "blackmesa", "combine", "civil", "resistance", "synth" }

-- Per-slot allocation across the three stats (each slot specializes).
local SLOT_BIAS = {
	helmet  = { armor = 0.25, health = 0.65, regen = 0.10 },
	vest    = { armor = 0.70, health = 0.25, regen = 0.05 },
	greaves = { armor = 0.50, health = 0.40, regen = 0.10 },
	core    = { armor = 0.30, health = 0.10, regen = 0.60 },
}

local function frand( lo, hi ) return lo + math.random() * ( hi - lo ) end

-- Weighted rarity pick (same shape as guns/artifacts).
local function rollRarity( itemLevel, luck )
	local r = math.random() - ( itemLevel or 1 ) * 0.004 - ( luck or 0 )
	if r < 0.50 then return 0 elseif r < 0.78 then return 1
	elseif r < 0.93 then return 2 elseif r < 0.99 then return 3 else return 4 end
end

-- Magnitude scalar from rarity + level (mirrors ArtifactPower).
function HL2BL.ArmorPower( rarity, level )
	return ( 1 + ( rarity or 0 ) * 0.35 ) * ( 1 + ( math.max( 1, level or 1 ) - 1 ) * 0.05 )
end

--- Roll a fresh armor piece. forceSlot/forceRarity override the rolls.
function HL2BL.RollArmorStats( itemLevel, luck, forceSlot, forceRarity )
	itemLevel = math.max( 1, itemLevel or 1 )
	local rarity = forceRarity or rollRarity( itemLevel, luck )
	local slot   = forceSlot or HL2BL.ARMOR_SLOTS[ math.random( #HL2BL.ARMOR_SLOTS ) ]
	local srcId  = HL2BL.ArmorSourceList[ math.random( #HL2BL.ArmorSourceList ) ]
	local sb     = SLOT_BIAS[ slot ] or SLOT_BIAS.vest
	local sw     = HL2BL.ArmorSources[ srcId ] or HL2BL.ArmorSources.blackmesa
	local power  = HL2BL.ArmorPower( rarity, itemLevel )

	local a = { kind = "armor", slot = slot, source = srcId, rarity = rarity, itemLevel = itemLevel }
	a.maxArmor  = math.Round(  20 * power * sb.armor  * sw.armor  * frand( 0.85, 1.15 ) )
	a.maxHealth = math.Round(  16 * power * sb.health * sw.health * frand( 0.85, 1.15 ) )
	-- Regen is a flat HP/s that scales off item level (per design).
	a.regen     = math.Round( ( 0.6 + itemLevel * 0.07 ) * power * sb.regen * sw.regen * frand( 0.85, 1.15 ) * 10 ) / 10

	-- Declutter: drop trivially small rolls so a piece reads as 1-2 clear bonuses.
	if a.maxArmor  < 2   then a.maxArmor  = 0 end
	if a.maxHealth < 2   then a.maxHealth = 0 end
	if a.regen     < 0.3 then a.regen     = 0 end
	if a.maxArmor == 0 and a.maxHealth == 0 and a.regen == 0 then
		a.maxHealth = math.Round( 8 * power )   -- never roll a do-nothing piece
	end

	a.name = HL2BL.ArmorName( a )
	return a
end

function HL2BL.ArmorName( a )
	local src = ( HL2BL.ArmorSources[ a.source ] or {} ).name or "Salvaged"
	return src .. " " .. ( HL2BL.ArmorSlotName[ a.slot ] or "Plate" )
end

-- Human-readable bonus lines (only the non-zero stats), for the UI cards.
function HL2BL.ArmorDescLines( a )
	local l = {}
	if ( a.maxArmor  or 0 ) > 0 then l[ #l + 1 ] = "+" .. a.maxArmor  .. " Suit Armor" end
	if ( a.maxHealth or 0 ) > 0 then l[ #l + 1 ] = "+" .. a.maxHealth .. " Max Health" end
	if ( a.regen     or 0 ) > 0 then l[ #l + 1 ] = "+" .. string.format( "%.1f", a.regen ) .. " HP/s Regen" end
	return l
end

-- Vendor pricing (cheaper than artifacts; armor is common defensive gear).
local AR_RARITY_PRICE = { [0] = 2, [1] = 4, [2] = 8, [3] = 18, [4] = 45 }
function HL2BL.ArmorPrice( a )
	return math.Round( ( 50 + ( a.itemLevel or 1 ) * 14 ) * ( AR_RARITY_PRICE[ a.rarity ] or 2 ) )
end
function HL2BL.ArmorSellPrice( a )
	return math.floor( HL2BL.ArmorPrice( a ) * 0.4 )
end

-- ---- net (de)serialize -----------------------------------------------------
function HL2BL.NetWriteArmor( a )
	net.WriteString( a.slot or "vest" )
	net.WriteString( a.source or "blackmesa" )
	net.WriteString( a.name or "" )
	net.WriteUInt( a.rarity or 0, 3 )
	net.WriteUInt( a.itemLevel or 1, 12 )
	net.WriteUInt( math.max( 0, a.maxArmor or 0 ), 12 )
	net.WriteUInt( math.max( 0, a.maxHealth or 0 ), 12 )
	net.WriteFloat( a.regen or 0 )
end

function HL2BL.NetReadArmor()
	local a = { kind = "armor" }
	a.slot      = net.ReadString()
	a.source    = net.ReadString()
	a.name      = net.ReadString()
	a.rarity    = net.ReadUInt( 3 )
	a.itemLevel = net.ReadUInt( 12 )
	a.maxArmor  = net.ReadUInt( 12 )
	a.maxHealth = net.ReadUInt( 12 )
	a.regen     = net.ReadFloat()
	return a
end

-- ---- unified backpack item dispatch (the backpack holds weapons + armor) ----
-- A 1-bit kind tag picks the gun (NetWriteStats) or armor serializer.
function HL2BL.NetWriteItem( s )
	local isArmor = ( s.kind == "armor" )
	net.WriteBool( isArmor )
	if isArmor then HL2BL.NetWriteArmor( s ) else HL2BL.NetWriteStats( s ) end
end

function HL2BL.NetReadItem()
	if net.ReadBool() then
		return HL2BL.NetReadArmor()
	end
	local s = HL2BL.NetReadStats(); s.kind = "weapon"; return s
end
