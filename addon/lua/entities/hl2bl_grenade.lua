--[[ hl2bl: thrown grenade projectile ----------------------------------------
	Carries a resolved grenade spec (self.Spec) + thrower (self.HL2BL_Thrower).
	Detonates on its fuse; Sticky freezes on first contact, Bouncing blasts on
	each hop, MIRV spawns child grenades, Singularity pulls then blasts. The actual
	damage is HL2BL.GrenadeBlast (sv_grenades), shared with the child grenades.
----------------------------------------------------------------------------]]
AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_gmodentity"
ENT.PrintName = "HL2BL Grenade"
ENT.Spawnable = false

local MODEL = "models/weapons/w_grenade.mdl"   -- HL2 frag grenade world model

if SERVER then

	function ENT:Initialize()
		self:SetModel( MODEL )
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )

		local spec = self.Spec or HL2BL.BaseGrenadeSpec( 1 )
		self.Spec  = spec
		local t    = HL2BL.GrenadeTypes[ spec.type ] or {}
		self.Fuse     = CurTime() + ( spec.fuse or 2 )
		self.Bounces  = t.bounces or 0
		self.NextBeep = 0

		self:SetNWInt( "hl2bl_gren_elem",   spec.element or 0 )
		self:SetNWInt( "hl2bl_gren_rarity", spec.rarity or 0 )

		if IsValid( self.HL2BL_Thrower ) then self:SetOwner( self.HL2BL_Thrower ) end

		local phys = self:GetPhysicsObject()
		if IsValid( phys ) then phys:Wake() end
	end

	function ENT:PhysicsCollide( data, phys )
		if self.Detonated then return end
		local spec = self.Spec or {}
		local t    = HL2BL.GrenadeTypes[ spec.type ] or {}

		if t.sticky and not self.Stuck then
			self.Stuck = true
			local hit = data.HitEntity
			timer.Simple( 0, function()
				if not IsValid( self ) then return end
				local p = self:GetPhysicsObject()
				if IsValid( p ) then p:EnableMotion( false ) end
				if IsValid( hit ) and ( hit:IsNPC() or hit:GetClass() == "prop_physics" ) then self:SetParent( hit ) end
			end )
			return
		end

		if self.Bounces and self.Bounces > 0 and data.Speed > 80 and CurTime() >= ( self.NextBounce or 0 ) then
			self.NextBounce = CurTime() + 0.2
			self.Bounces = self.Bounces - 1
			local mini = table.Copy( spec )
			mini.damage = ( spec.damage or 55 ) * 0.4
			mini.radius = ( spec.radius or 180 ) * 0.7
			HL2BL.GrenadeBlast( self, self.HL2BL_Thrower, self:GetPos(), mini )
			if self.Bounces <= 0 then self:Detonate() end
		end
	end

	function ENT:Think()
		if not self.Detonated and CurTime() >= ( self.Fuse or 0 ) then
			self:Detonate()
			return
		end
		if CurTime() >= ( self.NextBeep or 0 ) then
			self.NextBeep = CurTime() + 0.4
			self:EmitSound( "npc/roller/blade_in.wav", 55, 130, 0.4 )
		end
		self:NextThink( CurTime() )
		return true
	end

	function ENT:Detonate()
		if self.Detonated then return end
		self.Detonated = true

		local spec = self.Spec or HL2BL.BaseGrenadeSpec( 1 )
		local t    = HL2BL.GrenadeTypes[ spec.type ] or {}
		local pos  = self:GetPos()
		local thr  = self.HL2BL_Thrower

		if t.pull then
			-- Singularity: yank NPCs inward, then blast a beat later.
			for _, e in ipairs( ents.FindInSphere( pos, ( spec.radius or 180 ) * 1.6 ) ) do
				if IsValid( e ) and e ~= thr and ( e:IsNPC() or ( e.IsNextBot and e:IsNextBot() ) ) then
					local dir = ( pos - e:WorldSpaceCenter() ):GetNormalized()
					local ph  = e:GetPhysicsObject()
					if IsValid( ph ) then ph:SetVelocity( dir * 650 ) end
					if e.SetVelocity then e:SetVelocity( dir * 420 ) end
				end
			end
			local ed = EffectData(); ed:SetOrigin( pos ); ed:SetScale( 2 ); util.Effect( "cball_explode", ed )
			local cp = table.Copy( spec )
			timer.Simple( 0.45, function() HL2BL.GrenadeBlast( NULL, thr, pos, cp ) end )
		else
			HL2BL.GrenadeBlast( self, thr, pos, spec )
		end

		-- MIRV: scatter child grenades that each do a fraction of the damage.
		if t.children and t.children > 0 then
			for _ = 1, t.children do
				local child = ents.Create( "hl2bl_grenade" )
				if IsValid( child ) then
					local cs = table.Copy( spec )
					cs.type   = "standard"
					cs.damage = ( spec.damage or 55 ) * ( t.childDmg or 0.45 )
					cs.radius = ( spec.radius or 180 ) * 0.6
					cs.fuse   = 0.6 + math.Rand( 0, 0.4 )
					child:SetPos( pos + Vector( 0, 0, 10 ) )
					child.Spec = cs
					child.HL2BL_Thrower = thr
					child:Spawn()
					local p = child:GetPhysicsObject()
					if IsValid( p ) then p:SetVelocity( VectorRand() * 260 + Vector( 0, 0, 260 ) ) end
				end
			end
		end

		SafeRemoveEntity( self )
	end

else -- CLIENT

	local ELEM_COLOR = {
		[0] = Color( 235, 235, 235 ), [1] = Color( 255, 120,  40 ),
		[2] = Color(  90, 200, 255 ), [3] = Color( 130, 230,  90 ),
		[4] = Color( 255, 210,  70 ), [5] = Color( 150, 220, 255 ),
	}

	function ENT:Initialize() self:SetModel( MODEL ) end

	function ENT:Draw()
		self:DrawModel()
		local col   = ELEM_COLOR[ self:GetNWInt( "hl2bl_gren_elem", 0 ) ] or color_white
		-- Pulse a colored glow so a live grenade reads clearly.
		local pulse = 18 + math.abs( math.sin( CurTime() * 12 ) ) * 14
		render.SetMaterial( Material( "sprites/light_glow02_add" ) )
		render.DrawSprite( self:WorldSpaceCenter(), pulse, pulse, col )
	end

end
