--[[ hl2bl: grenades + grenade mods (server) ---------------------------------
	Owns the grenade-mod bag/equip slot (parallel to artifacts), the recharging
	grenade COUNT every player carries, the throw command, and the shared blast
	that the grenade entity (+ its MIRV children) calls. Grenades never occupy a
	weapon slot -- they're thrown with a key (default G).
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

util.AddNetworkString( "hl2bl_gren_sync" )
util.AddNetworkString( "hl2bl_gren_equip" )
util.AddNetworkString( "hl2bl_gren_drop" )
util.AddNetworkString( "hl2bl_gren_throw" )

local MAX_BAG = 24

local function bag( ply )      ply.HL2BL_GrenBag = ply.HL2BL_GrenBag or {}; return ply.HL2BL_GrenBag end
local function equippedMod( ply ) local i = ply.HL2BL_GrenSlot; return i and bag( ply )[ i ] or nil end

-- The spec the player currently throws: their mod, or a level-tracked base frag.
function HL2BL.PlayerGrenadeSpec( ply )
	return equippedMod( ply ) or HL2BL.BaseGrenadeSpec( ply:GetNWInt( "hl2bl_level", 1 ) )
end

-- ---- persistence -----------------------------------------------------------
local function saveGren( ply )
	if not IsValid( ply ) then return end
	ply:SetPData( "hl2bl_gren", util.TableToJSON( { bag = bag( ply ), slot = ply.HL2BL_GrenSlot or 0 } ) )
end
local function loadGren( ply )
	local j = ply:GetPData( "hl2bl_gren", nil ); if not j then return end
	local t = util.JSONToTable( j ); if not t then return end
	ply.HL2BL_GrenBag  = t.bag or {}
	ply.HL2BL_GrenSlot = ( t.slot and t.slot ~= 0 ) and t.slot or nil
end

local function syncGren( ply )
	local items = bag( ply )
	net.Start( "hl2bl_gren_sync" )
		net.WriteUInt( ply.HL2BL_GrenSlot or 0, 6 )
		net.WriteUInt( #items, 6 )
		for _, g in ipairs( items ) do HL2BL.NetWriteGrenade( g ) end
	net.Send( ply )
end

-- ---- count + recharge ------------------------------------------------------
local function setCount( ply, n )
	ply.HL2BL_Grenades = math.max( 0, n )
	ply:SetNWInt( "hl2bl_grenades", ply.HL2BL_Grenades )
end

-- Recompute capacity from the equipped spec; optionally refill to full (on spawn).
function HL2BL.RefreshGrenades( ply, refill )
	if not IsValid( ply ) then return end
	local spec = HL2BL.PlayerGrenadeSpec( ply )
	local cap  = math.max( 1, spec.capacity or 3 )
	ply.HL2BL_GrenCap = cap
	ply:SetNWInt( "hl2bl_grenade_cap", cap )
	if refill then
		setCount( ply, cap )
	else
		setCount( ply, math.min( ply.HL2BL_Grenades or cap, cap ) )
	end
	ply.HL2BL_GrenNext = CurTime() + ( spec.recharge or 8 )
end

-- ---- equip / drop / give ---------------------------------------------------
local function equipGrenade( ply, index )
	if not bag( ply )[ index ] then return end
	ply.HL2BL_GrenSlot = ( ply.HL2BL_GrenSlot == index ) and nil or index   -- toggle
	HL2BL.RefreshGrenades( ply )
	saveGren( ply ); syncGren( ply )
end

net.Receive( "hl2bl_gren_equip", function( _, ply ) equipGrenade( ply, net.ReadUInt( 6 ) ) end )

net.Receive( "hl2bl_gren_drop", function( _, ply )
	local index = net.ReadUInt( 6 )
	local items = bag( ply )
	local g = items[ index ]; if not g then return end
	if ply.HL2BL_GrenSlot == index then ply.HL2BL_GrenSlot = nil
	elseif ply.HL2BL_GrenSlot and ply.HL2BL_GrenSlot > index then ply.HL2BL_GrenSlot = ply.HL2BL_GrenSlot - 1 end
	table.remove( items, index )

	HL2BL.SpawnGrenadeMod( ply:GetShootPos() + ply:GetAimVector() * 40, g )
	HL2BL.RefreshGrenades( ply ); saveGren( ply ); syncGren( ply )
end )

HL2BL.GrenadeChance = CreateConVar( "hl2bl_grenade_chance", "0.05", FCVAR_ARCHIVE,
	"Chance an NPC also drops a grenade mod (boss/elite boosted)." )

-- World pickup spawner (used by loot drops, vendor-less drops, and the dropper).
function HL2BL.SpawnGrenadeMod( pos, g )
	local e = ents.Create( "hl2bl_grenademod" )
	if not IsValid( e ) then return end
	e:SetPos( pos )
	e.HL2BL_Gren = g
	e:Spawn()
	local phys = e:GetPhysicsObject()
	if IsValid( phys ) then phys:SetVelocity( VectorRand() * 50 + Vector( 0, 0, 90 ) ) end
	return e
end

-- Called by the grenade-mod pickup entity.
function HL2BL.GiveGrenadeMod( ply, g )
	local items = bag( ply )
	if #items >= MAX_BAG then ply:ChatPrint( "[HL2BL] Grenade bag full." ); return false end
	items[ #items + 1 ] = g
	if not ply.HL2BL_GrenSlot then ply.HL2BL_GrenSlot = #items end
	HL2BL.RefreshGrenades( ply )
	ply:EmitSound( "items/ammo_pickup.wav", 60, 90 )
	ply:ChatPrint( "[HL2BL] Found grenade mod: " .. ( g.name or "?" ) )
	saveGren( ply ); syncGren( ply )
	return true
end

-- ---- throw -----------------------------------------------------------------
function HL2BL.ThrowGrenade( ply )
	if not ( IsValid( ply ) and ply:Alive() ) then return end
	if ( ply.HL2BL_GrenLast or 0 ) > CurTime() then return end       -- throw cooldown
	if ( ply.HL2BL_Grenades or 0 ) <= 0 then
		ply:EmitSound( "common/wpn_denyselect.wav", 60, 100 )
		return
	end
	ply.HL2BL_GrenLast = CurTime() + 0.6

	local spec = table.Copy( HL2BL.PlayerGrenadeSpec( ply ) )
	-- The base (no-mod) frag tracks the thrower's level each throw.
	if not equippedMod( ply ) then spec.itemLevel = ply:GetNWInt( "hl2bl_level", 1 ) end

	local aim = ply:GetAimVector()
	local e = ents.Create( "hl2bl_grenade" )
	if not IsValid( e ) then return end
	e:SetPos( ply:GetShootPos() + aim * 16 )
	e:SetAngles( aim:Angle() )
	e.Spec         = spec
	e.HL2BL_Thrower = ply
	e:Spawn()

	local phys = e:GetPhysicsObject()
	if IsValid( phys ) then
		phys:SetVelocity( ply:GetVelocity() + aim * 1000 + Vector( 0, 0, 160 ) )
		phys:AddAngleVelocity( VectorRand() * 200 )
	end
	ply:EmitSound( "WeaponFrag.Throw" )

	setCount( ply, ( ply.HL2BL_Grenades or 1 ) - 1 )
	ply.HL2BL_GrenNext = CurTime() + ( spec.recharge or 8 )   -- (re)start recharge timer
end

net.Receive( "hl2bl_gren_throw", function( _, ply ) HL2BL.ThrowGrenade( ply ) end )

-- Tick recharge for everyone.
timer.Create( "hl2bl_grenade_recharge", 0.5, 0, function()
	local now = CurTime()
	for _, ply in ipairs( player.GetAll() ) do
		if ply:Alive() then
			local cap = ply.HL2BL_GrenCap or 3
			if ( ply.HL2BL_Grenades or 0 ) < cap then
				if now >= ( ply.HL2BL_GrenNext or 0 ) then
					setCount( ply, ( ply.HL2BL_Grenades or 0 ) + 1 )
					ply.HL2BL_GrenNext = now + ( HL2BL.PlayerGrenadeSpec( ply ).recharge or 8 )
				end
			else
				ply.HL2BL_GrenNext = now + ( HL2BL.PlayerGrenadeSpec( ply ).recharge or 8 )
			end
		end
	end
end )

-- ---- shared blast (called by the grenade entity + its children) -------------
local DMGTYPE = {
	[HL2BL.Element.NONE]       = DMG_BLAST,
	[HL2BL.Element.INCENDIARY] = DMG_BURN,
	[HL2BL.Element.SHOCK]      = DMG_SHOCK,
	[HL2BL.Element.CORROSIVE]  = DMG_ACID,
	[HL2BL.Element.EXPLOSIVE]  = DMG_BLAST,
	[HL2BL.Element.CRYO]       = DMG_GENERIC,
}

local function elementStatus( victim, elem, pos )
	if elem == HL2BL.Element.INCENDIARY then
		if victim.Ignite then victim:Ignite( 4 ) end
	elseif elem == HL2BL.Element.SHOCK then
		local ed = EffectData(); ed:SetOrigin( victim:WorldSpaceCenter() ); ed:SetMagnitude( 2 ); ed:SetScale( 1 ); ed:SetRadius( 16 )
		util.Effect( "Sparks", ed )
	elseif elem == HL2BL.Element.CRYO then
		if victim:IsNPC() or victim:IsPlayer() then
			victim:SetLaggedMovementValue( 0.5 )
			timer.Simple( 2, function() if IsValid( victim ) then victim:SetLaggedMovementValue( 1 ) end end )
		end
	end
end

-- Detonate `spec` at `pos`. Damages NPCs (with element status) + breakable props
-- (so boxes can pop loot), shoves physics, and heals a Transfusion thrower.
-- Player targets are spared (co-op); friendly NPCs are filtered by the existing
-- friendly-fire EntityTakeDamage hook since the attacker is the thrower.
function HL2BL.GrenadeBlast( inflictor, thrower, pos, spec )
	spec = spec or {}
	local t       = HL2BL.GrenadeTypes[ spec.type ] or {}
	local radius  = spec.radius or 180
	local dmg     = ( spec.damage or 55 ) * HL2BL.LevelScale( spec.itemLevel or 1 )
	local elem    = spec.element or HL2BL.Element.NONE
	local dt      = DMGTYPE[ elem ] or DMG_BLAST
	local att     = IsValid( thrower ) and thrower or inflictor
	local healed  = 0

	for _, e in ipairs( ents.FindInSphere( pos, radius ) ) do
		if IsValid( e ) and e ~= inflictor and e ~= thrower then
			local isNPC     = e:IsNPC() or ( e.IsNextBot and e:IsNextBot() )
			local breakable = ( not isNPC ) and ( not e:IsPlayer() ) and e:Health() and e:Health() > 0
			if isNPC or breakable then
				local frac = 1 - math.Clamp( ( e:WorldSpaceCenter() - pos ):Length() / radius, 0, 1 ) * 0.6
				local di = DamageInfo()
				di:SetAttacker( att ); di:SetInflictor( inflictor )
				di:SetDamage( dmg * frac )
				di:SetDamageType( dt )
				di:SetDamagePosition( pos )
				e:TakeDamageInfo( di )
				if isNPC then
					healed = healed + dmg * frac
					elementStatus( e, elem, pos )
				end
			end
			-- Shove nearby physics for some kaboom.
			local phys = e:GetPhysicsObject()
			if IsValid( phys ) and e:GetMoveType() == MOVETYPE_VPHYSICS then
				phys:ApplyForceOffset( ( e:WorldSpaceCenter() - pos ):GetNormalized() * dmg * 6, e:WorldSpaceCenter() )
			end
		end
	end

	if ( t.heal or 0 ) > 0 and IsValid( thrower ) and thrower:IsPlayer() and thrower:Alive() then
		thrower:SetHealth( math.min( thrower:GetMaxHealth(), thrower:Health() + healed * t.heal ) )
	end

	-- Visual + audio.
	local scale = math.Clamp( radius / 96, 0.6, 4 )
	local ed = EffectData(); ed:SetOrigin( pos ); ed:SetScale( scale ); ed:SetMagnitude( scale ); ed:SetRadius( radius )
	util.Effect( "cball_explode", ed )
	if elem == HL2BL.Element.INCENDIARY then
		local fd = EffectData(); fd:SetOrigin( pos ); fd:SetScale( scale )
		util.Effect( "Explosion", fd )
	end
	sound.Play( "BaseExplosionEffect.Sound", pos, 95, math.random( 90, 110 ) )
	util.ScreenShake( pos, 8, 5, 0.6, radius * 1.5 )
end

-- ---- spawn / load ----------------------------------------------------------
hook.Add( "PlayerInitialSpawn", "hl2bl_gren_load", function( ply )
	loadGren( ply )
	timer.Simple( 1, function() if IsValid( ply ) then syncGren( ply ) end end )
end )

hook.Add( "PlayerSpawn", "hl2bl_gren_refill", function( ply )
	timer.Simple( 0.5, function()
		if IsValid( ply ) and ply:Alive() then HL2BL.RefreshGrenades( ply, true ) end
	end )
end )

hook.Add( "PlayerDisconnected", "hl2bl_gren_save", saveGren )
