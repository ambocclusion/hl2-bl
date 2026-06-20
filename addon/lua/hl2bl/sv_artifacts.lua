--[[ hl2bl: artifacts (server) -----------------------------------------------
	Equip artifacts, apply passive aggregates, run composed active abilities, and
	handle artifact loot/pickup/persistence.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

util.AddNetworkString( "hl2bl_art_sync" )
util.AddNetworkString( "hl2bl_art_equip" )
util.AddNetworkString( "hl2bl_art_drop" )
util.AddNetworkString( "hl2bl_art_ability" )

local MAX_BAG = 24

local function bag( ply )  ply.HL2BL_ArtBag = ply.HL2BL_ArtBag or {}; return ply.HL2BL_ArtBag end
local function equipped( ply ) local i = ply.HL2BL_ArtSlot; return i and bag( ply )[ i ] or nil end

-- ---- persistence -----------------------------------------------------------
local function saveArt( ply )
	if not IsValid( ply ) then return end
	ply:SetPData( "hl2bl_art", util.TableToJSON( { bag = bag( ply ), slot = ply.HL2BL_ArtSlot or 0 } ) )
end
local function loadArt( ply )
	local j = ply:GetPData( "hl2bl_art", nil ); if not j then return end
	local t = util.JSONToTable( j ); if not t then return end
	ply.HL2BL_ArtBag  = t.bag or {}
	ply.HL2BL_ArtSlot = ( t.slot and t.slot ~= 0 ) and t.slot or nil
end

local function syncArt( ply )
	local items = bag( ply )
	net.Start( "hl2bl_art_sync" )
		net.WriteUInt( ply.HL2BL_ArtSlot or 0, 6 )
		net.WriteUInt( #items, 6 )
		for _, a in ipairs( items ) do HL2BL.NetWriteArtifact( a ) end
	net.Send( ply )
end

-- ---- passive aggregation ---------------------------------------------------
function HL2BL.RecomputePassive( ply )
	local agg = { maxhp = 0, speedPct = 0, regen = 0, lifestealPct = 0,
	              resistPct = 0, dmgPct = 0, creditPct = 0, xpPct = 0 }
	local art = equipped( ply )
	if art and art.kind == "passive" then
		for _, id in ipairs( art.parts ) do
			local mag = HL2BL.PassiveMag( id, art.rarity, art.itemLevel )
			if     id == "vitality"   then agg.maxhp       = agg.maxhp + mag
			elseif id == "swiftness"  then agg.speedPct    = agg.speedPct + mag
			elseif id == "regen"      then agg.regen       = agg.regen + mag
			elseif id == "lifesteal"  then agg.lifestealPct= agg.lifestealPct + mag
			elseif id == "juggernaut" then agg.resistPct   = agg.resistPct + mag
			elseif id == "power"      then agg.dmgPct      = agg.dmgPct + mag
			elseif id == "greed"      then agg.creditPct   = agg.creditPct + mag
			elseif id == "scholar"    then agg.xpPct       = agg.xpPct + mag end
		end
	end
	ply.HL2BL_Passive = agg

	local base = 100 + ( ply:GetNWInt( "hl2bl_level", 1 ) - 1 ) * 10
	ply:SetMaxHealth( base + agg.maxhp )
	if ply:Alive() and ply:Health() > ply:GetMaxHealth() then ply:SetHealth( ply:GetMaxHealth() ) end

	local mul = 1 + agg.speedPct / 100
	ply:SetWalkSpeed( math.Round( 200 * mul ) )
	ply:SetRunSpeed( math.Round( 400 * mul ) )
end

-- ---- equip / unequip / drop ------------------------------------------------
local function equipArtifact( ply, index )
	if not bag( ply )[ index ] then return end
	ply.HL2BL_ArtSlot = ( ply.HL2BL_ArtSlot == index ) and nil or index   -- toggle
	HL2BL.RecomputePassive( ply )
	saveArt( ply ); syncArt( ply )
end

net.Receive( "hl2bl_art_equip", function( _, ply ) equipArtifact( ply, net.ReadUInt( 6 ) ) end )

net.Receive( "hl2bl_art_drop", function( _, ply )
	local index = net.ReadUInt( 6 )
	local items = bag( ply )
	local a = items[ index ]; if not a then return end
	if ply.HL2BL_ArtSlot == index then ply.HL2BL_ArtSlot = nil
	elseif ply.HL2BL_ArtSlot and ply.HL2BL_ArtSlot > index then ply.HL2BL_ArtSlot = ply.HL2BL_ArtSlot - 1 end
	table.remove( items, index )

	local e = ents.Create( "hl2bl_artifact" )
	if IsValid( e ) then
		e:SetPos( ply:GetShootPos() + ply:GetAimVector() * 40 )
		e.HL2BL_Art = a
		e:Spawn()
	end
	HL2BL.RecomputePassive( ply ); saveArt( ply ); syncArt( ply )
end )

HL2BL.ArtifactChance = CreateConVar( "hl2bl_artifact_chance", "0.06", FCVAR_ARCHIVE,
	"Chance an NPC also drops an artifact." )

-- Spawn an artifact world pickup at pos.
function HL2BL.SpawnArtifact( pos, art )
	local e = ents.Create( "hl2bl_artifact" )
	if not IsValid( e ) then return end
	e:SetPos( pos )
	e.HL2BL_Art = art
	e:Spawn()
	local phys = e:GetPhysicsObject()
	if IsValid( phys ) then phys:SetVelocity( VectorRand() * 50 + Vector( 0, 0, 90 ) ) end
	return e
end

-- Called by the artifact pickup entity.
function HL2BL.GiveArtifact( ply, art )
	local items = bag( ply )
	if #items >= MAX_BAG then ply:ChatPrint( "[HL2BL] Artifact bag full." ); return false end
	items[ #items + 1 ] = art
	if not ply.HL2BL_ArtSlot then ply.HL2BL_ArtSlot = #items; HL2BL.RecomputePassive( ply ) end
	ply:EmitSound( "items/ammo_pickup.wav", 60, 80 )
	ply:ChatPrint( "[HL2BL] Found artifact: " .. ( art.name or "?" ) )
	saveArt( ply ); syncArt( ply )
	return true
end

-- ---- active abilities ------------------------------------------------------
local CD = { nova = 12, heal = 15, overcharge = 20, phase = 18 }

local function modSet( art )
	local m = {}
	for i = 2, #art.parts do m[ art.parts[i] ] = true end
	return m
end

local EFFECT = {}

EFFECT.nova = function( ply, art, m )
	local p      = HL2BL.ArtifactPower( art.rarity, art.itemLevel )
	local radius = 280 * ( m.extended and 1.4 or 1 )
	local dmg    = 40 * p * ( m.empowered and 1.3 or 1 )
	local elem   = ( m.incendiary and HL2BL.Element.INCENDIARY ) or ( m.shock and HL2BL.Element.SHOCK )
		or ( m.corrosive and HL2BL.Element.CORROSIVE ) or HL2BL.Element.NONE
	local healed = 0
	for _, e in ipairs( ents.FindInSphere( ply:GetPos(), radius ) ) do
		if IsValid( e ) and e ~= ply and ( e:IsNPC() or ( e:IsPlayer() and false ) ) and e:Health() > 0 then
			local di = DamageInfo()
			di:SetAttacker( ply ); di:SetInflictor( ply ); di:SetDamage( dmg )
			di:SetDamageType( elem == HL2BL.Element.INCENDIARY and DMG_BURN or elem == HL2BL.Element.SHOCK and DMG_SHOCK
				or elem == HL2BL.Element.CORROSIVE and DMG_ACID or DMG_BLAST )
			di:SetDamagePosition( e:WorldSpaceCenter() )
			e:TakeDamageInfo( di )
			if elem == HL2BL.Element.INCENDIARY and e.Ignite then e:Ignite( 4 ) end
			healed = healed + dmg
		end
	end
	if m.vampiric then ply:SetHealth( math.min( ply:GetMaxHealth(), ply:Health() + healed * 0.1 ) ) end
	local ed = EffectData(); ed:SetOrigin( ply:GetPos() ); ed:SetScale( radius / 64 ); util.Effect( "cball_explode", ed )
	ply:EmitSound( "ambient/levels/labs/electric_explosion4.wav", 80, 110 )
end

EFFECT.heal = function( ply, art, m )
	local p = HL2BL.ArtifactPower( art.rarity, art.itemLevel )
	ply:SetHealth( math.min( ply:GetMaxHealth(), ply:Health() + math.Round( 50 * p * ( m.empowered and 1.3 or 1 ) ) ) )
	ply:EmitSound( "items/smallmedkit1.wav" )
end

EFFECT.overcharge = function( ply, art, m )
	ply.HL2BL_Buff = ply.HL2BL_Buff or {}
	ply.HL2BL_Buff.dmgPct   = 30 * ( m.empowered and 1.3 or 1 )
	ply.HL2BL_Buff.dmgUntil = CurTime() + 8 * ( m.extended and 1.4 or 1 )
	ply:EmitSound( "ambient/energy/newspark04.wav" )
end

EFFECT.phase = function( ply, art, m )
	local dur = 5 * ( m.extended and 1.4 or 1 )
	ply.HL2BL_Buff = ply.HL2BL_Buff or {}
	ply.HL2BL_Buff.resistPct   = 40 * ( m.empowered and 1.3 or 1 )
	ply.HL2BL_Buff.resistUntil = CurTime() + dur
	ply:SetLaggedMovementValue( 1.4 )
	timer.Simple( dur, function() if IsValid( ply ) then ply:SetLaggedMovementValue( 1 ) end end )
	ply:EmitSound( "ambient/energy/whiteflash.wav" )
end

net.Receive( "hl2bl_art_ability", function( _, ply )
	local art = equipped( ply )
	if not ( art and art.kind == "active" ) then return end
	if ( ply.HL2BL_AbilityReady or 0 ) > CurTime() then return end

	local m  = modSet( art )
	local cd = ( CD[ art.parts[1] ] or 15 ) * ( m.swift and 0.7 or 1 )
	local fn = EFFECT[ art.parts[1] ]
	if not fn then return end
	fn( ply, art, m )

	ply.HL2BL_AbilityReady = CurTime() + cd
	ply:SetNWFloat( "hl2bl_ability_until", CurTime() + cd )
	ply:SetNWFloat( "hl2bl_ability_cd", cd )
end )

-- ---- global hooks: passive/buff damage + regen -----------------------------
hook.Add( "EntityTakeDamage", "hl2bl_artifact_dmg", function( target, dmg )
	local att = dmg:GetAttacker()
	if IsValid( att ) and att:IsPlayer() then
		local p, b = att.HL2BL_Passive, att.HL2BL_Buff
		local dpct = ( p and p.dmgPct or 0 ) + ( ( b and b.dmgUntil and b.dmgUntil > CurTime() ) and b.dmgPct or 0 )
		if dpct > 0 then dmg:ScaleDamage( 1 + dpct / 100 ) end
		if p and p.lifestealPct and p.lifestealPct > 0 and IsValid( target ) and target:IsNPC() and att:Alive() then
			att:SetHealth( math.min( att:GetMaxHealth(), att:Health() + dmg:GetDamage() * p.lifestealPct / 100 ) )
		end
	end
	if IsValid( target ) and target:IsPlayer() then
		local p, b = target.HL2BL_Passive, target.HL2BL_Buff
		local rpct = ( p and p.resistPct or 0 ) + ( ( b and b.resistUntil and b.resistUntil > CurTime() ) and b.resistPct or 0 )
		rpct = math.min( rpct, 85 )
		if rpct > 0 then dmg:ScaleDamage( 1 - rpct / 100 ) end
	end
end )

timer.Create( "hl2bl_artifact_regen", 1, 0, function()
	for _, ply in ipairs( player.GetAll() ) do
		local p = ply.HL2BL_Passive
		if ply:Alive() and p and p.regen and p.regen > 0 then
			ply:SetHealth( math.min( ply:GetMaxHealth(), ply:Health() + p.regen ) )
		end
	end
end )

-- ---- spawn / load ----------------------------------------------------------
hook.Add( "PlayerInitialSpawn", "hl2bl_art_load", function( ply )
	loadArt( ply )
	timer.Simple( 1, function() if IsValid( ply ) then syncArt( ply ) end end )
end )

hook.Add( "PlayerSpawn", "hl2bl_art_apply", function( ply )
	timer.Simple( 0.4, function() if IsValid( ply ) and ply:Alive() then HL2BL.RecomputePassive( ply ) end end )
end )

hook.Add( "PlayerDisconnected", "hl2bl_art_save", saveArt )
