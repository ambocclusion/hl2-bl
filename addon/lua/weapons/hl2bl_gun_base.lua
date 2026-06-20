--[[ hl2bl: gun SWEP base ----------------------------------------------------
	Archetype-driven gun. Tuning + models come from HL2BL.Archetypes[archetype];
	rolled stats (rarity/element/multipliers) live in networked vars. Used both
	by droppable world loot (hl2bl_pistol/smg/...) and the equipped slot weapons
	(hl2bl_slot1..4), which can be reconfigured to any archetype.
----------------------------------------------------------------------------]]
SWEP.Base        = "weapon_base"
SWEP.PrintName   = "HL2BL Gun"
SWEP.Author      = "hl2bl"
SWEP.Category    = "HL2: Borderlands"
SWEP.Spawnable   = false
SWEP.UseHands    = true

SWEP.ViewModel   = "models/weapons/c_smg1.mdl"
SWEP.WorldModel  = "models/weapons/w_smg1.mdl"

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = true
SWEP.Primary.Ammo        = "none"
SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

SWEP.HL2BL_Archetype = "smg"   -- concrete classes override; slots set via NW
SWEP.HL2BL_ItemLevel = 1

local function arch( self ) return HL2BL.GetArchetype( self:GetArchetype() ) end

-- ---- accessors -------------------------------------------------------------
function SWEP:GetArchetype()     return self:GetNWString( "hl2bl_arch", self.HL2BL_Archetype or "smg" ) end
function SWEP:GetRarity()        return self:GetNWInt(   "hl2bl_rarity", 0 ) end
function SWEP:GetElement()       return self:GetNWInt(   "hl2bl_element", 0 ) end
function SWEP:GetItemLevel()     return self:GetNWInt(   "hl2bl_ilvl", 1 ) end
function SWEP:GetDamageMult()    return self:GetNWFloat( "hl2bl_dmg", 1 ) end
function SWEP:GetFireRateMult()  return self:GetNWFloat( "hl2bl_rof", 1 ) end
function SWEP:GetSpreadMult()    return self:GetNWFloat( "hl2bl_spread", 1 ) end
function SWEP:GetReloadMult()    return self:GetNWFloat( "hl2bl_reload", 1 ) end
function SWEP:GetMagMult()       return self:GetNWFloat( "hl2bl_mag", 1 ) end
function SWEP:GetRecoilMult()    return self:GetNWFloat( "hl2bl_recoil", 1 ) end
function SWEP:GetElementChance() return self:GetNWFloat( "hl2bl_echance", 0 ) end
function SWEP:GetElementDamage() return self:GetNWFloat( "hl2bl_edmg", 0 ) end
function SWEP:GetReserve()       return self:GetNWInt(   "hl2bl_reserve", 0 ) end

function SWEP:HL2BLMaxClip()
	return math.max( 1, math.Round( arch( self ).clip * self:GetMagMult() ) )
end

function SWEP:AddReserve( amount )
	if CLIENT then return end
	self:SetNWInt( "hl2bl_reserve", self:GetReserve() + amount )
end

-- ---- configuration (server) ------------------------------------------------
function SWEP:ApplyStats( s )
	if CLIENT then return end
	local a = arch( self )
	self:SetNWInt(   "hl2bl_rarity",  s.rarity )
	self:SetNWInt(   "hl2bl_element", s.element )
	self:SetNWInt(   "hl2bl_ilvl",    s.itemLevel )
	self:SetNWFloat( "hl2bl_dmg",     s.damageMult )
	self:SetNWFloat( "hl2bl_rof",     s.fireRateMult )
	self:SetNWFloat( "hl2bl_spread",  s.spreadMult )
	self:SetNWFloat( "hl2bl_reload",  s.reloadMult )
	self:SetNWFloat( "hl2bl_mag",     s.magMult )
	self:SetNWFloat( "hl2bl_recoil",  s.recoilMult or 1 )
	self:SetNWFloat( "hl2bl_echance", s.elementChance )
	self:SetNWFloat( "hl2bl_edmg",    s.elementDamage )
	self:SetNWBool(  "hl2bl_rolled",  true )
	self:SetClip1( self:HL2BLMaxClip() )
	self:SetNWInt(   "hl2bl_reserve", math.Round( a.clip * a.reserve ) )
	self:SetNWString( "hl2bl_manu", s.manufacturer or "vanguard" )

	-- Name: "<Manufacturer> <Element?> <Archetype>" (rarity is shown by color).
	local parts = { HL2BL.ManufacturerName( s.manufacturer ) }
	if s.element ~= HL2BL.Element.NONE then table.insert( parts, HL2BL.ElementName[ s.element ] ) end
	table.insert( parts, a.name )
	local fullName = table.concat( parts, " " )
	self:SetNWString( "hl2bl_name", fullName )

	-- Atomic copy of the whole roll as ONE networked string (mirrors the armor /
	-- artifact / grenade world pickups). World-loot stat cards + loot beams read
	-- this so a remote client never sees partial state -- e.g. the card missing,
	-- or rarity defaulting to Common -- while the ~13 separate NW vars above are
	-- still trickling in across snapshots. The individual vars are kept for
	-- held-weapon firing/prediction; this is just for display reliability.
	local function r4( x ) return math.Round( ( tonumber( x ) or 0 ) * 1e4 ) / 1e4 end
	self:SetNWString( "hl2bl_statjson", util.TableToJSON( {
		kind          = "weapon",
		archetype     = self:GetArchetype(),
		manufacturer  = s.manufacturer or "vanguard",
		name          = fullName,
		rarity        = s.rarity,
		element       = s.element,
		itemLevel     = s.itemLevel,
		damageMult    = r4( s.damageMult ),
		fireRateMult  = r4( s.fireRateMult ),
		spreadMult    = r4( s.spreadMult ),
		reloadMult    = r4( s.reloadMult ),
		magMult       = r4( s.magMult ),
		recoilMult    = r4( s.recoilMult or 1 ),
		elementChance = r4( s.elementChance ),
		elementDamage = r4( s.elementDamage ),
	} ) )
end

-- Reconfigure an (equipped slot) weapon to a specific archetype + roll.
function SWEP:Configure( archId, stats )
	if CLIENT then return end
	self:SetNWString( "hl2bl_arch", archId )
	self:ApplyStats( stats )
	if IsValid( self:GetOwner() ) and self:GetOwner():GetActiveWeapon() == self then
		self:Deploy()   -- refresh viewmodel if currently held
	end
end

function SWEP:Initialize()
	if SERVER and self.HL2BL_Archetype and self:GetNWString( "hl2bl_arch", "" ) == "" then
		self:SetNWString( "hl2bl_arch", self.HL2BL_Archetype )
	end
	self:SetHoldType( arch( self ).hold )
	if SERVER and not self:GetNWBool( "hl2bl_rolled", false ) then
		self:ApplyStats( HL2BL.RollStats( self.HL2BL_ItemLevel ) )
	end
end

function SWEP:Deploy()
	local a = arch( self )
	self.Primary.Automatic = a.auto
	self.ViewModel  = a.vm
	self.WorldModel = a.wm
	self:SetHoldType( a.hold )

	local owner = self:GetOwner()
	if IsValid( owner ) then
		local vm = owner:GetViewModel()
		if IsValid( vm ) then vm:SetModel( a.vm ); vm:SetPlaybackRate( 1 ) end
	end
	return true
end

-- Stop zoom + restore FOV when put away.
function SWEP:Holster()
	self:SetZoom( false )
	return true
end

function SWEP:OnRemove() self:SetZoom( false ) end

-- ---- alt-fire: aim-down-sights zoom ---------------------------------------
function SWEP:SetZoom( on )
	self.HL2BL_Zoomed = on
	local owner = self:GetOwner()
	if IsValid( owner ) and owner:IsPlayer() then
		owner:SetFOV( on and ( arch( self ).zoomFOV or 55 ) or 0, 0.2 )
	end
end

function SWEP:SecondaryAttack()
	if arch( self ).melee then return end
	self:SetNextSecondaryFire( CurTime() + 0.3 )
	if not IsFirstTimePredicted() then return end
	self:SetZoom( not self.HL2BL_Zoomed )
	self:EmitSound( "Default.Zoom" )
end

-- ---- firing ----------------------------------------------------------------
function SWEP:CanPrimaryAttack()
	if self:Clip1() <= 0 then
		self:EmitSound( "Weapon_Pistol.Empty" )
		self:SetNextPrimaryFire( CurTime() + 0.25 )
		return false
	end
	return true
end

function SWEP:TryElementProc( victim, attacker )
	if CLIENT or not IsValid( victim ) then return end
	local elem = self:GetElement()
	if elem == HL2BL.Element.NONE then return end
	if math.random() > self:GetElementChance() then return end

	local d = DamageInfo()
	d:SetAttacker( IsValid( attacker ) and attacker or self )
	d:SetInflictor( self )
	d:SetDamage( self:GetElementDamage() )

	local pos = victim:WorldSpaceCenter()
	if elem == HL2BL.Element.INCENDIARY then
		d:SetDamageType( DMG_BURN )
		if victim.Ignite then victim:Ignite( 4 ) end
		victim:EmitSound( "ambient/fire/ignite.wav", 60, 100, 0.6 )
	elseif elem == HL2BL.Element.SHOCK then
		d:SetDamageType( DMG_SHOCK )
		local ed = EffectData(); ed:SetOrigin( pos ); ed:SetMagnitude( 2 ); ed:SetScale( 1 ); ed:SetRadius( 16 )
		util.Effect( "Sparks", ed )
		victim:EmitSound( "ambient/energy/spark6.wav", 65, 120, 0.7 )
	elseif elem == HL2BL.Element.CORROSIVE then
		d:SetDamageType( DMG_ACID )
		victim:EmitSound( "ambient/levels/canals/toxic_slime_sizzle1.wav", 60, 100, 0.6 )
	elseif elem == HL2BL.Element.EXPLOSIVE then
		d:SetDamageType( DMG_BLAST )
		local ed = EffectData(); ed:SetOrigin( pos ); ed:SetScale( 1 )
		util.Effect( "cball_explode", ed )
		victim:EmitSound( "BaseExplosionEffect.Sound", 70, 110, 0.6 )
	else -- CRYO
		d:SetDamageType( DMG_GENERIC )
		if victim:IsNPC() or victim:IsPlayer() then
			victim:SetLaggedMovementValue( 0.5 )
			timer.Simple( 2, function() if IsValid( victim ) then victim:SetLaggedMovementValue( 1 ) end end )
		end
		victim:EmitSound( "physics/glass/glass_impact_bullet1.wav", 60, 80, 0.6 )
	end
	victim:TakeDamageInfo( d )
end

function SWEP:PrimaryAttack()
	local a = arch( self )
	if a.melee then return self:MeleeAttack( a ) end
	if not self:CanPrimaryAttack() then return end
	local owner = self:GetOwner()
	if not IsValid( owner ) then return end

	self:EmitSound( a.sound )
	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
	owner:MuzzleFlash()
	owner:SetAnimation( PLAYER_ATTACK1 )
	local rc = a.recoil * self:GetRecoilMult()
	owner:ViewPunch( Angle( -math.Rand( rc * 0.5, rc ), math.Rand( -rc * 0.25, rc * 0.25 ), 0 ) )

	local spread = a.spread * self:GetSpreadMult() * ( self.HL2BL_Zoomed and 0.4 or 1 )
	local wep = self
	owner:LagCompensation( true )
	owner:FireBullets( {
		Num        = a.shots,
		Src        = owner:GetShootPos(),
		Dir        = owner:GetAimVector(),
		Spread     = Vector( spread, spread, 0 ),
		Tracer     = 1,
		TracerName = "Tracer",
		Force      = 5,
		Damage     = a.dmg * self:GetDamageMult() * HL2BL.LevelScale( self:GetItemLevel() ),
		AmmoType   = "SMG1",
		Callback   = function( att, tr, dmginfo ) wep:TryElementProc( tr.Entity, att ) end,
	} )
	owner:LagCompensation( false )

	self:SetClip1( self:Clip1() - 1 )
	self:SetNextPrimaryFire( CurTime() + 60 / math.max( 1, a.rpm * self:GetFireRateMult() ) )
end

-- Melee swing: hull trace in front, damage + element proc on hit.
function SWEP:MeleeAttack( a )
	local owner = self:GetOwner()
	if not IsValid( owner ) then return end
	self:SetNextPrimaryFire( CurTime() + 60 / math.max( 1, a.rpm * self:GetFireRateMult() ) )

	local src, dir = owner:GetShootPos(), owner:GetAimVector()
	local tr = util.TraceHull( {
		start = src, endpos = src + dir * a.range,
		mins = Vector( -12, -12, -12 ), maxs = Vector( 12, 12, 12 ),
		filter = owner, mask = MASK_SHOT_HULL,
	} )

	self:EmitSound( a.sound )
	self:SendWeaponAnim( tr.Hit and ACT_VM_HITCENTER or ACT_VM_MISSCENTER )
	owner:SetAnimation( PLAYER_ATTACK1 )
	owner:ViewPunch( Angle( -a.recoil * self:GetRecoilMult(), 0, 0 ) )

	if not tr.Hit or CLIENT then return end

	local ent = tr.Entity
	if IsValid( ent ) then
		local d = DamageInfo()
		d:SetAttacker( owner ); d:SetInflictor( self )
		d:SetDamage( a.dmg * self:GetDamageMult() * HL2BL.LevelScale( self:GetItemLevel() ) )
		d:SetDamageType( DMG_CLUB )
		d:SetDamagePosition( tr.HitPos )
		ent:TakeDamageInfo( d )
		self:TryElementProc( ent, owner )
		if a.hitSound then self:EmitSound( a.hitSound ) end
	end
	local eff = EffectData(); eff:SetOrigin( tr.HitPos ); eff:SetNormal( tr.HitNormal )
	util.Effect( "Impact", eff )
end

function SWEP:Reload()
	if arch( self ).melee then return end
	if self:Clip1() >= self:HL2BLMaxClip() then return end
	if self:GetNWBool( "hl2bl_reloading", false ) then return end
	if self:GetReserve() <= 0 then return end

	local owner = self:GetOwner()
	local t = arch( self ).reload * self:GetReloadMult()

	-- Viewmodel reload animation, scaled to the reload time.
	self:SendWeaponAnim( ACT_VM_RELOAD )
	if IsValid( owner ) then
		owner:SetAnimation( PLAYER_RELOAD )
		local vm = owner:GetViewModel()
		if IsValid( vm ) then
			local dur = vm:SequenceDuration()
			if dur and dur > 0 then vm:SetPlaybackRate( dur / math.max( 0.1, t ) ) end
		end
	end

	self:SetNWBool( "hl2bl_reloading", true )
	self:SetNextPrimaryFire( CurTime() + t )

	if SERVER then
		local wep = self
		timer.Simple( t, function()
			if not IsValid( wep ) then return end
			local need = wep:HL2BLMaxClip() - wep:Clip1()
			local take = math.min( need, wep:GetReserve() )
			wep:SetClip1( wep:Clip1() + take )
			wep:SetNWInt( "hl2bl_reserve", wep:GetReserve() - take )
			wep:SetNWBool( "hl2bl_reloading", false )
			local o = wep:GetOwner()
			if IsValid( o ) then local v = o:GetViewModel(); if IsValid( v ) then v:SetPlaybackRate( 1 ) end end
		end )
	end
end

-- Drive reload from the +reload key ourselves. Our guns use a custom reserve
-- pool (Primary.Ammo "none"), so the engine's ammo-based reload never fires;
-- this guarantees reload (and its animation) works. Server-side so the anim
-- networks cleanly to clients.
function SWEP:Think()
	if CLIENT then return end
	local owner = self:GetOwner()
	if IsValid( owner ) and owner:KeyDown( IN_RELOAD ) then self:Reload() end
end
