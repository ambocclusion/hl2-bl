--[[ hl2bl: world stat card (client) -----------------------------------------
	Draws a Borderlands-style stat card for the rolled gun the player is looking
	at. The draw function is reused by the inventory/equip UI.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

surface.CreateFont( "HL2BL.Title", { font = "Roboto", size = 21, weight = 700 } )
surface.CreateFont( "HL2BL.Body",  { font = "Roboto", size = 17, weight = 500 } )

local COL_BG    = Color( 18, 18, 22, 235 )
local COL_TEXT  = Color( 225, 225, 230 )
local COL_DIM   = Color( 150, 150, 158 )
local COL_GOOD  = Color( 120, 230, 120 )
local COL_BAD   = Color( 230, 120, 120 )
local CARD_W    = 280

-- Build the +/-% benefit lines (positive is always "better").
local function statLines( s )
	local function line( label, pct )
		local good = pct >= -0.5
		return {
			text  = string.format( "%s%.0f%%  %s", pct >= 0 and "+" or "", pct, label ),
			color = ( math.abs( pct ) < 0.5 ) and COL_DIM or ( good and COL_GOOD or COL_BAD ),
		}
	end
	return {
		line( "Damage",       ( s.damageMult   - 1 ) * 100 ),
		line( "Fire Rate",    ( s.fireRateMult - 1 ) * 100 ),
		line( "Accuracy",     ( 1 - s.spreadMult   ) * 100 ),
		line( "Reload Speed", ( 1 - s.reloadMult   ) * 100 ),
		line( "Magazine",     ( s.magMult      - 1 ) * 100 ),
	}
end

--- Draw a stat card with top-left at (x, y). Returns its height.
function HL2BL.DrawStatCard( x, y, s )
	local rc    = HL2BL.RarityColor[ s.rarity ] or color_white
	local title = ( s.name ~= "" and s.name ) or ( HL2BL.RarityName[ s.rarity ] .. " Gun" )
	local lines = statLines( s )

	local pad, titleH, lineH = 12, 32, 22
	local rows  = #lines + 1                                   -- + item level row
	local hasEl = s.element ~= HL2BL.Element.NONE
	if hasEl then rows = rows + 1 end
	local h = titleH + pad + rows * lineH + pad

	-- background + rarity title bar + rarity outline
	draw.RoundedBox( 6, x, y, CARD_W, h, COL_BG )
	draw.RoundedBoxEx( 6, x, y, CARD_W, titleH, Color( rc.r, rc.g, rc.b, 60 ), true, true, false, false )
	surface.SetDrawColor( rc.r, rc.g, rc.b, 220 )
	surface.DrawOutlinedRect( x, y, CARD_W, h, 2 )

	draw.SimpleText( title, "HL2BL.Title", x + pad, y + titleH / 2, rc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )

	local cy = y + titleH + pad
	draw.SimpleText( "Item Level " .. s.itemLevel, "HL2BL.Body", x + pad, cy, COL_DIM ); cy = cy + lineH

	if hasEl then
		local ec = string.format( "%s  -  %d%% on hit, %d dmg",
			HL2BL.ElementName[ s.element ], math.Round( s.elementChance * 100 ), math.Round( s.elementDamage ) )
		draw.SimpleText( ec, "HL2BL.Body", x + pad, cy, Color( 255, 200, 120 ) ); cy = cy + lineH
	end

	for _, l in ipairs( lines ) do
		draw.SimpleText( l.text, "HL2BL.Body", x + pad, cy, l.color ); cy = cy + lineH
	end

	return h
end

--- Draw an armor card (same look as the gun card) with top-left at (x, y).
-- Returns its height. Reused by the inventory paper-doll + category list.
function HL2BL.DrawArmorCard( x, y, a )
	local rc    = HL2BL.RarityColor[ a.rarity or 0 ] or color_white
	local title = ( a.name and a.name ~= "" ) and a.name or ( HL2BL.RarityName[ a.rarity or 0 ] .. " Armor" )
	local lines = HL2BL.ArmorDescLines( a )

	local pad, titleH, lineH = 12, 32, 22
	local rows = #lines + 1                                     -- + slot/level row
	local h = titleH + pad + rows * lineH + pad

	draw.RoundedBox( 6, x, y, CARD_W, h, COL_BG )
	draw.RoundedBoxEx( 6, x, y, CARD_W, titleH, Color( rc.r, rc.g, rc.b, 60 ), true, true, false, false )
	surface.SetDrawColor( rc.r, rc.g, rc.b, 220 )
	surface.DrawOutlinedRect( x, y, CARD_W, h, 2 )

	draw.SimpleText( title, "HL2BL.Title", x + pad, y + titleH / 2, rc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )

	local cy = y + titleH + pad
	local slotName = ( HL2BL.ArmorSlotName and HL2BL.ArmorSlotName[ a.slot ] ) or "Armor"
	draw.SimpleText( slotName .. "  -  Item Level " .. ( a.itemLevel or 1 ), "HL2BL.Body", x + pad, cy, COL_DIM ); cy = cy + lineH

	for _, l in ipairs( lines ) do
		draw.SimpleText( l, "HL2BL.Body", x + pad, cy, COL_GOOD ); cy = cy + lineH
	end

	return h
end

-- Draw the card for a gun or armor entity. Returns true if it drew one.
local function drawItemCard( ent, x, y )
	if not IsValid( ent ) then return false end

	if ent:GetClass() == "hl2bl_armor" then
		local a = util.JSONToTable( ent:GetNWString( "hl2bl_armorjson", "" ) or "" )
		if not a then return false end
		local h = HL2BL.DrawArmorCard( x, y, a )
		draw.SimpleText( "[E] Pick up", "HL2BL.Title", x + CARD_W * 0.5, y + h + 8,
			Color( 120, 230, 120 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
		return true
	end

	if ent:IsWeapon() then
		local s = HL2BL.GetEntStats( ent )
		if not s then return false end
		local h = HL2BL.DrawStatCard( x, y, s )
		if not IsValid( ent:GetOwner() ) then   -- world loot, not a held gun
			draw.SimpleText( "[E] Pick up", "HL2BL.Title", x + CARD_W * 0.5, y + h + 8,
				Color( 120, 230, 120 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
		end
		return true
	end

	return false
end

-- Look-at card on the HUD: either the item you're aimed straight at (up to ~5 m),
-- or the loot whose colored beacon you're looking at within ~2 m (forgiving aim).
hook.Add( "HUDPaint", "hl2bl_statcard", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) or not ply:Alive() then return end

	local x, y = ScrW() * 0.56, ScrH() * 0.30

	local ent = ply:GetEyeTrace().Entity
	if IsValid( ent ) and ent:GetPos():DistToSqr( ply:EyePos() ) <= 200 * 200 then
		if drawItemCard( ent, x, y ) then return end
	end

	if HL2BL.LootBeaconTarget then
		drawItemCard( HL2BL.LootBeaconTarget( ply ), x, y )
	end
end )
