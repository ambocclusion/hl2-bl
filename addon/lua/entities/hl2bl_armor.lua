--[[ hl2bl: armor world pickup -----------------------------------------------
	A dropped HEV-suit armor piece (rendered as the suit battery). +use to add it
	to your backpack. Carries its rolled stats as JSON in a networked var so the
	look-at card can show them. Mirrors hl2bl_artifact.
----------------------------------------------------------------------------]]
AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_gmodentity"
ENT.PrintName = "HL2BL Armor"
ENT.Spawnable = false

local MODEL = "models/items/battery.mdl"   -- the HEV suit battery -- lore-perfect

if SERVER then

	function ENT:Initialize()
		self:SetModel( MODEL )
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:SetUseType( SIMPLE_USE )
		self:SetCollisionGroup( COLLISION_GROUP_WEAPON )   -- walk through, still usable
		-- NB: intentionally NOT HL2BL_IsLoot -- that flag routes +use through the
		-- weapon pickup hook (sv_inventory), which would block this ent's Use.
		if self.HL2BL_Armor then
			self:SetNWString( "hl2bl_armorjson", util.TableToJSON( self.HL2BL_Armor ) )
			self:SetNWInt( "hl2bl_armorrarity", self.HL2BL_Armor.rarity or 0 )
		end
	end

	function ENT:Use( activator )
		if not ( IsValid( activator ) and activator:IsPlayer() and self.HL2BL_Armor ) then return end
		if HL2BL.GiveArmor( activator, self.HL2BL_Armor ) then SafeRemoveEntity( self ) end
	end

else -- CLIENT

	function ENT:Initialize() self:SetModel( MODEL ) end

	function ENT:Draw()
		self:SetAngles( Angle( 0, CurTime() * 60 % 360, 0 ) )
		self:DrawModel()
		local rc = ( HL2BL.RarityColor and HL2BL.RarityColor[ self:GetNWInt( "hl2bl_armorrarity", 0 ) ] ) or color_white
		render.SetMaterial( Material( "sprites/light_glow02_add" ) )
		render.DrawSprite( self:GetPos() + Vector( 0, 0, 10 ), 42, 42, rc )
	end

end
