--[[ hl2bl: vendor UI (client) -----------------------------------------------
	Buy (vendor stock) / Sell (your backpack) window, opened by +use on a vendor.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

net.Receive( "hl2bl_vendor_open", function()
	local vendor = net.ReadEntity()
	local n = net.ReadUInt( 6 )
	local stock = {}
	for i = 1, n do
		local isArt = net.ReadBool()
		stock[ i ] = { kind = isArt and "artifact" or "gun",
		               data = isArt and HL2BL.NetReadArtifact() or HL2BL.NetReadStats() }
	end
	HL2BL._VendorEnt   = vendor
	HL2BL._VendorStock = stock
	HL2BL.OpenVendorUI()
end )

local function addRow( parent, paintFn, btnText, enabled, onClick )
	local row = parent:Add( "DPanel" )
	row:Dock( TOP ); row:DockMargin( 4, 4, 4, 4 ); row:SetTall( 224 )
	row.Paint = paintFn

	local btn = vgui.Create( "DButton", row )
	btn:SetPos( 292, 92 ); btn:SetSize( 158, 40 )
	btn:SetText( btnText ); btn:SetEnabled( enabled )
	btn.DoClick = onClick
end

local function emptyLabel( parent, text )
	local l = parent:Add( "DLabel" )
	l:Dock( TOP ); l:DockMargin( 10, 10, 0, 0 ); l:SetText( text )
end

function HL2BL.RebuildVendor()
	if not IsValid( HL2BL._VendorFrame ) then return end
	local credits = LocalPlayer():GetNWInt( "hl2bl_credits", 0 )

	local buy = HL2BL._VendorBuy
	buy:Clear()
	local stock = HL2BL._VendorStock or {}
	if #stock == 0 then emptyLabel( buy, "Sold out - check back after a restock." ) end
	for i, e in ipairs( stock ) do
		local isArt = ( e.kind == "artifact" )
		local price = isArt and HL2BL.ArtifactPrice( e.data ) or HL2BL.GunPrice( e.data )
		local paint = isArt and function() HL2BL.DrawArtifactCard( 0, 0, e.data ) end
			or function() HL2BL.DrawStatCard( 0, 0, e.data ) end
		addRow( buy, paint, "Buy  -  " .. price .. " cr", credits >= price, function()
			net.Start( "hl2bl_vendor_buy" )
				net.WriteEntity( HL2BL._VendorEnt )
				net.WriteUInt( i, 6 )
			net.SendToServer()
		end )
	end

	local sell = HL2BL._VendorSell
	sell:Clear()
	local items = HL2BL.Inv and HL2BL.Inv.items or {}
	if #items == 0 then emptyLabel( sell, "Backpack empty - nothing to sell." ) end
	for i, s in ipairs( items ) do
		addRow( sell, function() HL2BL.DrawStatCard( 0, 0, s ) end,
			"Sell  -  " .. HL2BL.GunSellPrice( s ) .. " cr", true, function()
			net.Start( "hl2bl_vendor_sell" )
				net.WriteUInt( i, 6 )
			net.SendToServer()
		end )
	end
end

function HL2BL.OpenVendorUI()
	if not IsValid( HL2BL._VendorFrame ) then
		local f = vgui.Create( "DFrame" )
		f:SetSize( 500, math.min( 740, ScrH() * 0.85 ) )
		f:Center(); f:MakePopup()
		HL2BL._VendorFrame = f

		local sheet = vgui.Create( "DPropertySheet", f ); sheet:Dock( FILL )
		HL2BL._VendorBuy  = vgui.Create( "DScrollPanel", sheet )
		HL2BL._VendorSell = vgui.Create( "DScrollPanel", sheet )
		sheet:AddSheet( "Buy",  HL2BL._VendorBuy,  "icon16/cart.png" )
		sheet:AddSheet( "Sell", HL2BL._VendorSell, "icon16/money.png" )

		f.Think = function( s )
			s:SetTitle( "Vending Machine        Credits: " .. LocalPlayer():GetNWInt( "hl2bl_credits", 0 ) )
		end
	end
	HL2BL.RebuildVendor()
end

-- Refresh the Sell tab (and buy affordability) when the backpack changes.
hook.Add( "HL2BL_InvUpdated", "hl2bl_vendor_refresh", function()
	if IsValid( HL2BL._VendorFrame ) then HL2BL.RebuildVendor() end
end )

-- "[E] Vendor" prompt when looking at a vendor.
hook.Add( "HUDPaint", "hl2bl_vendor_prompt", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) or not ply:Alive() then return end
	local ent = ply:GetEyeTrace().Entity
	if not IsValid( ent ) or ent:GetClass() ~= "hl2bl_vendor" then return end
	if ent:GetPos():DistToSqr( ply:EyePos() ) > 150 * 150 then return end

	draw.SimpleText( "[E] Vendor  -  Buy / Sell", "HL2BL.Title", ScrW() * 0.5, ScrH() * 0.62,
		Color( 90, 230, 120 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
end )
