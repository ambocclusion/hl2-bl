--[[ hl2bl: grenade-mod world pickup -----------------------------------------
	A floating rarity-colored grenade. +use to add the mod to your grenade bag.
	Mirrors hl2bl_artifact.
----------------------------------------------------------------------------]]
AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_gmodentity"
ENT.PrintName = "HL2BL Grenade Mod"
ENT.Spawnable = false

local MODEL = "models/weapons/w_grenade.mdl"

if SERVER then

	function ENT:Initialize()
		self:SetModel( MODEL )
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:SetUseType( SIMPLE_USE )
		self:SetCollisionGroup( COLLISION_GROUP_WEAPON )   -- walk through, still usable
		if self.HL2BL_Gren then
			self:SetNWString( "hl2bl_grenjson", util.TableToJSON( self.HL2BL_Gren ) )
			self:SetNWInt( "hl2bl_grenrarity", self.HL2BL_Gren.rarity or 0 )
		end
	end

	function ENT:Use( activator )
		if not ( IsValid( activator ) and activator:IsPlayer() and self.HL2BL_Gren ) then return end
		if HL2BL.GiveGrenadeMod( activator, self.HL2BL_Gren ) then SafeRemoveEntity( self ) end
	end

else -- CLIENT

	function ENT:Initialize() self:SetModel( MODEL ) end

	function ENT:Draw()
		self:SetAngles( Angle( 0, CurTime() * 60 % 360, 0 ) )
		self:DrawModel()
		local rc = ( HL2BL.RarityColor and HL2BL.RarityColor[ self:GetNWInt( "hl2bl_grenrarity", 0 ) ] ) or color_white
		render.SetMaterial( Material( "sprites/light_glow02_add" ) )
		render.DrawSprite( self:GetPos() + Vector( 0, 0, 6 ), 36, 36, rc )
	end

end
