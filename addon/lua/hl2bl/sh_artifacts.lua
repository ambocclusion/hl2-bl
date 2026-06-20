--[[ hl2bl: artifacts (shared) -----------------------------------------------
	Equippable artifacts with rarity. Each grants ONE ability, procedurally
	composed from combinable "elements":
	  * passive artifacts stack 1-3 passive MODS (e.g. Vitality + Lifesteal),
	  * active artifacts combine one EFFECT (Nova/Heal/Overcharge/Phase) with
	    0-2 MODIFIERS (element / empowered / extended / swift / vampiric).
	Higher rarity = more combined elements + bigger magnitudes -> unique abilities.
	This file holds the data/roll/naming; behaviours live in sv_artifacts.lua.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

HL2BL.ARTIFACT_SLOTS = 1   -- equipped artifacts at once

-- Passive mods: base magnitude scales with rarity + level via ArtifactPower.
HL2BL.PassiveMods = {
	vitality   = { name = "Vitality",   base = 25, unit = " max HP",        fmt = "+%d%s" },
	swiftness  = { name = "Swiftness",  base = 10, unit = "%% move speed",  fmt = "+%d%s" },
	regen      = { name = "Regen",      base = 2,  unit = " HP/s",          fmt = "+%d%s" },
	lifesteal  = { name = "Lifesteal",  base = 5,  unit = "%% lifesteal",   fmt = "+%d%s" },
	juggernaut = { name = "Juggernaut", base = 8,  unit = "%% damage resist", fmt = "+%d%s", cap = 60 },
	power      = { name = "Power",      base = 8,  unit = "%% gun damage",   fmt = "+%d%s" },
	greed      = { name = "Greed",      base = 15, unit = "%% credits",      fmt = "+%d%s" },
	scholar    = { name = "Scholar",    base = 15, unit = "%% XP",           fmt = "+%d%s" },
}
HL2BL.PassiveModList = { "vitality", "swiftness", "regen", "lifesteal", "juggernaut", "power", "greed", "scholar" }

-- Active effects.
HL2BL.ActiveEffects = {
	nova       = { name = "Nova",       desc = "AoE damage burst around you" },
	heal       = { name = "Mend",       desc = "Instantly restore health" },
	overcharge = { name = "Overcharge", desc = "Temporary gun-damage boost" },
	phase      = { name = "Phase",      desc = "Brief speed + damage resistance" },
}
HL2BL.ActiveEffectList = { "nova", "heal", "overcharge", "phase" }

-- Modifiers combined onto an active effect to make it unique.
HL2BL.AbilityMods = {
	incendiary = { name = "Incendiary", element = HL2BL.Element.INCENDIARY },
	shock      = { name = "Shock",      element = HL2BL.Element.SHOCK },
	corrosive  = { name = "Corrosive",  element = HL2BL.Element.CORROSIVE },
	empowered  = { name = "Empowered" },  -- +magnitude
	extended   = { name = "Extended" },   -- +duration / radius
	swift      = { name = "Swift" },      -- -cooldown
	vampiric   = { name = "Vampiric" },   -- ability heals you
}
HL2BL.AbilityModList = { "incendiary", "shock", "corrosive", "empowered", "extended", "swift", "vampiric" }

-- Magnitude scalar from rarity + level.
function HL2BL.ArtifactPower( rarity, level )
	return ( 1 + ( rarity or 0 ) * 0.4 ) * ( 1 + ( math.max( 1, level or 1 ) - 1 ) * 0.04 )
end

-- Final magnitude for a passive mod id at a rarity/level.
function HL2BL.PassiveMag( id, rarity, level )
	local m = HL2BL.PassiveMods[ id ]; if not m then return 0 end
	local v = math.Round( m.base * HL2BL.ArtifactPower( rarity, level ) )
	if m.cap then v = math.min( v, m.cap ) end
	return v
end

local function rollRarity( itemLevel, luck )
	local r = math.random() - ( itemLevel or 1 ) * 0.004 - ( luck or 0 )
	if r < 0.50 then return 0 elseif r < 0.78 then return 1
	elseif r < 0.93 then return 2 elseif r < 0.99 then return 3 else return 4 end
end

local function pickDistinct( list, n )
	local pool, out = table.Copy( list ), {}
	for _ = 1, math.min( n, #pool ) do
		out[ #out + 1 ] = table.remove( pool, math.random( #pool ) )
	end
	return out
end

-- Roll a fresh artifact. Returns a table: { rarity, itemLevel, kind, parts, name }.
-- forceRarity overrides the rarity roll (used by the debug spawner).
function HL2BL.RollArtifact( itemLevel, luck, forceRarity )
	itemLevel = math.max( 1, itemLevel or 1 )
	local rarity = forceRarity or rollRarity( itemLevel, luck )
	local nElements = ( { [0] = 1, [1] = 1, [2] = 2, [3] = 2, [4] = 3 } )[ rarity ] or 1

	local art = { rarity = rarity, itemLevel = itemLevel }
	if math.random() < 0.5 then
		art.kind  = "passive"
		art.parts = pickDistinct( HL2BL.PassiveModList, nElements )
	else
		art.kind  = "active"
		art.parts = { HL2BL.ActiveEffectList[ math.random( #HL2BL.ActiveEffectList ) ] }
		for _, id in ipairs( pickDistinct( HL2BL.AbilityModList, nElements - 1 ) ) do
			art.parts[ #art.parts + 1 ] = id
		end
	end
	art.name = HL2BL.ArtifactName( art )
	return art
end

function HL2BL.ArtifactName( art )
	if art.kind == "passive" then
		local names = {}
		for _, id in ipairs( art.parts ) do
			names[ #names + 1 ] = ( HL2BL.PassiveMods[ id ] or {} ).name or id
		end
		return "Charm of " .. table.concat( names, " & " )
	end
	local eff = HL2BL.ActiveEffects[ art.parts[1] ] or {}
	local pre = {}
	for i = 2, #art.parts do pre[ #pre + 1 ] = ( HL2BL.AbilityMods[ art.parts[i] ] or {} ).name end
	return ( #pre > 0 and ( table.concat( pre, " " ) .. " " ) or "" ) .. ( eff.name or art.parts[1] ) .. " Relic"
end

-- Human-readable ability lines for UI.
function HL2BL.ArtifactDescLines( art )
	local lines = {}
	if art.kind == "passive" then
		for _, id in ipairs( art.parts ) do
			local m = HL2BL.PassiveMods[ id ]
			if m then lines[ #lines + 1 ] = string.format( m.fmt, HL2BL.PassiveMag( id, art.rarity, art.itemLevel ), m.unit ) end
		end
	else
		local eff = HL2BL.ActiveEffects[ art.parts[1] ]
		lines[ #lines + 1 ] = "Active: " .. ( eff and eff.desc or "" )
		for i = 2, #art.parts do
			local m = HL2BL.AbilityMods[ art.parts[i] ]
			if m then lines[ #lines + 1 ] = " + " .. m.name end
		end
	end
	return lines
end

-- Vendor pricing (artifacts are pricier than guns - they're powerful + rare).
local ART_RARITY_PRICE = { [0] = 4, [1] = 8, [2] = 16, [3] = 35, [4] = 90 }
function HL2BL.ArtifactPrice( a )
	return math.Round( ( 80 + ( a.itemLevel or 1 ) * 18 ) * ( ART_RARITY_PRICE[ a.rarity ] or 4 ) )
end

-- Net (de)serialize.
function HL2BL.NetWriteArtifact( a )
	net.WriteUInt( a.rarity or 0, 3 )
	net.WriteUInt( a.itemLevel or 1, 12 )
	net.WriteBool( a.kind == "active" )
	net.WriteString( a.name or "" )
	net.WriteUInt( #a.parts, 4 )
	for _, id in ipairs( a.parts ) do net.WriteString( id ) end
end

function HL2BL.NetReadArtifact()
	local a = { rarity = net.ReadUInt( 3 ), itemLevel = net.ReadUInt( 12 ) }
	a.kind = net.ReadBool() and "active" or "passive"
	a.name = net.ReadString()
	a.parts = {}
	for _ = 1, net.ReadUInt( 4 ) do a.parts[ #a.parts + 1 ] = net.ReadString() end
	return a
end
