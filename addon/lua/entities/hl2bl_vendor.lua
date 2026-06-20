--[[ hl2bl: vendor NPC -------------------------------------------------------
	A stationary citizen "shopkeeper" you +use to open the buy/sell UI. Holds a
	rotating, low-rarity-skewed stock.
----------------------------------------------------------------------------]]
AddCSLuaFile()

ENT.Type           = "anim"
ENT.Base           = "base_gmodentity"
ENT.PrintName      = "HL2BL Vendor"
ENT.Author         = "hl2bl"
ENT.Category       = "HL2: Borderlands"
ENT.Spawnable      = true
ENT.AdminSpawnable = true

local MODEL = "models/humans/group01/male_07.mdl"

function ENT:SetupIdle()
	local seq = self:LookupSequence( "idle_subtle" )
	if seq <= 0 then seq = self:LookupSequence( "idle_all_01" ) end
	if seq <= 0 then seq = self:SelectWeightedSequence( ACT_IDLE ) end
	if seq and seq > 0 then self:ResetSequence( seq ) end
	self:SetCycle( math.Rand( 0, 1 ) )
	self:SetAutomaticFrameAdvance( true )   -- keep the idle animating
end

if SERVER then

	function ENT:Initialize()
		self:SetModel( MODEL )
		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_BBOX )
		self:SetCollisionBounds( Vector( -16, -16, 0 ), Vector( 16, 16, 72 ) )
		-- Keep bounds (so +use can target it) but don't block players walking through.
		self:SetCollisionGroup( COLLISION_GROUP_WEAPON )
		self:SetUseType( SIMPLE_USE )
		self:DropToFloor()
		self:SetupIdle()

		self.Stock = {}
		self.NextRefresh = 0
		self:RefreshStock( 1 )
	end

	function ENT:RefreshStock( level )
		level = level or 1
		self.Stock = {}
		for i = 1, 8 do
			-- Super super rare: a slot is occasionally an artifact instead of a gun.
			if HL2BL.RollArtifact and math.random() < 0.02 then
				self.Stock[ i ] = { kind = "artifact", data = HL2BL.RollArtifact( level, -0.1 ) }
			else
				self.Stock[ i ] = { kind = "gun", data = HL2BL.RollVendorStats( level ) }
			end
		end
		self.NextRefresh = CurTime() + 300
	end

	function ENT:Use( activator )
		if not ( IsValid( activator ) and activator:IsPlayer() ) then return end
		if ( self.NextRefresh or 0 ) < CurTime() then
			self:RefreshStock( activator:GetNWInt( "hl2bl_level", 1 ) )
		end
		HL2BL.OpenVendor( activator, self )
	end

else -- CLIENT

	local matGlow = Material( "sprites/light_glow02_add" )

	function ENT:Initialize()
		self:SetModel( MODEL )
		self:SetupIdle()
	end

	function ENT:Draw()
		self:DrawModel()
		-- floating green glow so the vendor is easy to spot
		render.SetMaterial( matGlow )
		render.DrawSprite( self:GetPos() + Vector( 0, 0, 84 ), 36, 36, Color( 90, 230, 120, 200 ) )
	end

end
