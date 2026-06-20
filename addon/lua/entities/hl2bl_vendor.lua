--[[ hl2bl: vending machine entity -------------------------------------------
	+use to open the buy/sell UI. Holds a rotating low-rarity-skewed stock.
----------------------------------------------------------------------------]]
AddCSLuaFile()

ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"
ENT.PrintName       = "HL2BL Vending Machine"
ENT.Author          = "hl2bl"
ENT.Category        = "HL2: Borderlands"
ENT.Spawnable       = true
ENT.AdminSpawnable  = true

local MODEL = "models/props_c17/console01a.mdl"

if SERVER then

	function ENT:Initialize()
		self:SetModel( MODEL )
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:SetUseType( SIMPLE_USE )

		local phys = self:GetPhysicsObject()
		if IsValid( phys ) then phys:EnableMotion( false ) end

		self.Stock = {}
		self.NextRefresh = 0
		self:RefreshStock( 1 )
	end

	function ENT:RefreshStock( level )
		self.Stock = {}
		for i = 1, 8 do self.Stock[ i ] = HL2BL.RollVendorStats( level or 1 ) end
		self.NextRefresh = CurTime() + 300   -- restock every 5 min
	end

	function ENT:Use( activator )
		if not ( IsValid( activator ) and activator:IsPlayer() ) then return end
		if ( self.NextRefresh or 0 ) < CurTime() then
			self:RefreshStock( activator:GetNWInt( "hl2bl_level", 1 ) )
		end
		HL2BL.OpenVendor( activator, self )
	end

else -- CLIENT

	function ENT:Initialize() self:SetModel( MODEL ) end

	function ENT:Draw()
		self:DrawModel()
		-- subtle green glow so it's findable
		local p = self:LocalToWorld( self:OBBCenter() ) + self:GetUp() * 30
		render.SetMaterial( Material( "sprites/light_glow02_add" ) )
		render.DrawSprite( p, 40, 40, Color( 90, 230, 120, 200 ) )
	end

end
