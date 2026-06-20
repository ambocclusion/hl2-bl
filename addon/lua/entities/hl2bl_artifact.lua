--[[ hl2bl: artifact world pickup --------------------------------------------
	A floating rarity-colored relic. +use to add it to your artifact bag.
----------------------------------------------------------------------------]]
AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_gmodentity"
ENT.PrintName = "HL2BL Artifact"
ENT.Spawnable = false

local MODEL = "models/dav0r/hoverball.mdl"   -- ships with GMod; reads as a relic orb

if SERVER then

	function ENT:Initialize()
		self:SetModel( MODEL )
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:SetUseType( SIMPLE_USE )
		self:SetCollisionGroup( COLLISION_GROUP_WEAPON )   -- walk through, still usable
		if self.HL2BL_Art then
			self:SetNWString( "hl2bl_artjson", util.TableToJSON( self.HL2BL_Art ) )
			self:SetNWInt( "hl2bl_artrarity", self.HL2BL_Art.rarity or 0 )
		end
	end

	function ENT:Use( activator )
		if not ( IsValid( activator ) and activator:IsPlayer() and self.HL2BL_Art ) then return end
		if HL2BL.GiveArtifact( activator, self.HL2BL_Art ) then SafeRemoveEntity( self ) end
	end

else -- CLIENT

	function ENT:Initialize() self:SetModel( MODEL ) end

	function ENT:Draw()
		self:SetAngles( Angle( 0, CurTime() * 60 % 360, 0 ) )
		self:DrawModel()
		local rc = ( HL2BL.RarityColor and HL2BL.RarityColor[ self:GetNWInt( "hl2bl_artrarity", 0 ) ] ) or color_white
		render.SetMaterial( Material( "sprites/light_glow02_add" ) )
		render.DrawSprite( self:GetPos() + Vector( 0, 0, 6 ), 40, 40, rc )
	end

end
