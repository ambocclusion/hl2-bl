--[[ hl2bl: artifacts UI (client) --------------------------------------------
	Artifact bag window (O), an active-ability HUD with cooldown ([X] to use),
	and a look-at card for dropped artifacts.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}
HL2BL.Arts = HL2BL.Arts or { slot = 0, items = {} }
HL2BL.AbilityKey = "X"

net.Receive( "hl2bl_art_sync", function()
	local slot = net.ReadUInt( 6 )
	local n    = net.ReadUInt( 6 )
	local items = {}
	for i = 1, n do items[i] = HL2BL.NetReadArtifact() end
	HL2BL.Arts = { slot = slot, items = items }
	if IsValid( HL2BL._ArtScroll ) then HL2BL.RebuildArtifacts() end
end )

function HL2BL.DrawArtifactCard( x, y, art )
	local rc    = HL2BL.RarityColor[ art.rarity ] or color_white
	local lines = HL2BL.ArtifactDescLines( art )
	local pad, titleH, lineH = 10, 28, 20
	local h = titleH + pad + ( #lines + 1 ) * lineH + pad

	draw.RoundedBox( 6, x, y, 280, h, Color( 18, 18, 22, 235 ) )
	draw.RoundedBoxEx( 6, x, y, 280, titleH, Color( rc.r, rc.g, rc.b, 60 ), true, true, false, false )
	surface.SetDrawColor( rc.r, rc.g, rc.b, 220 ); surface.DrawOutlinedRect( x, y, 280, h, 2 )

	draw.SimpleText( art.name or "Artifact", "HL2BL.Title", x + pad, y + titleH / 2, rc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	local cy = y + titleH + pad
	draw.SimpleText( ( art.kind == "active" and "Active" or "Passive" ) .. "  -  Lv " .. ( art.itemLevel or 1 ),
		"HL2BL.Body", x + pad, cy, Color( 150, 150, 158 ) ); cy = cy + lineH
	for _, l in ipairs( lines ) do
		draw.SimpleText( l, "HL2BL.Body", x + pad, cy, Color( 200, 220, 255 ) ); cy = cy + lineH
	end
	return h
end

function HL2BL.RebuildArtifacts()
	local scroll = HL2BL._ArtScroll
	if not IsValid( scroll ) then return end
	scroll:Clear()

	local items = HL2BL.Arts.items
	if #items == 0 then
		local l = scroll:Add( "DLabel" ); l:Dock( TOP ); l:DockMargin( 8, 8, 0, 0 )
		l:SetText( "No artifacts - kill enemies to find them." ); return
	end
	for i, art in ipairs( items ) do
		local row = scroll:Add( "DPanel" )
		row:Dock( TOP ); row:DockMargin( 4, 4, 4, 4 ); row:SetTall( 170 )
		row.Paint = function() HL2BL.DrawArtifactCard( 0, 0, art ) end

		local eq = ( i == HL2BL.Arts.slot )
		local b = vgui.Create( "DButton", row )
		b:SetPos( 292, 30 ); b:SetSize( 150, 34 )
		b:SetText( eq and "Equipped (unequip)" or "Equip" )
		b.DoClick = function() net.Start( "hl2bl_art_equip" ); net.WriteUInt( i, 6 ); net.SendToServer() end

		local d = vgui.Create( "DButton", row )
		d:SetPos( 292, 70 ); d:SetSize( 150, 28 ); d:SetText( "Drop" ); d:SetTextColor( Color( 235, 120, 120 ) )
		d.DoClick = function()
			Derma_Query( "Drop " .. ( art.name or "this artifact" ) .. "?", "Drop", "Drop",
				function() net.Start( "hl2bl_art_drop" ); net.WriteUInt( i, 6 ); net.SendToServer() end, "Cancel" )
		end
	end
end

function HL2BL.OpenArtifacts()
	if IsValid( HL2BL._ArtFrame ) then HL2BL._ArtFrame:Remove(); return end
	local f = vgui.Create( "DFrame" )
	f:SetSize( 470, math.min( 720, ScrH() * 0.8 ) ); f:Center(); f:MakePopup()
	f:SetTitle( "HL2: Borderlands  -  Artifacts" )
	HL2BL._ArtFrame = f
	local scroll = vgui.Create( "DScrollPanel", f ); scroll:Dock( FILL )
	HL2BL._ArtScroll = scroll
	HL2BL.RebuildArtifacts()
end

concommand.Add( "hl2bl_artifacts", HL2BL.OpenArtifacts, nil, "Open the artifact bag." )
concommand.Add( "hl2bl_ability", function()
	net.Start( "hl2bl_art_ability" ); net.SendToServer()
end, nil, "Use your equipped active artifact ability." )

-- Default keys: O = artifacts, X = use ability (rebind via bind <key> <cmd>).
hook.Add( "PlayerButtonDown", "hl2bl_art_keys", function( ply, button )
	if ply ~= LocalPlayer() or IsValid( vgui.GetKeyboardFocus() ) then return end
	if button == KEY_O then HL2BL.OpenArtifacts()
	elseif button == KEY_X then RunConsoleCommand( "hl2bl_ability" ) end
end )

-- Active-ability HUD (name + cooldown).
hook.Add( "HUDPaint", "hl2bl_ability_hud", function()
	local items, slot = HL2BL.Arts.items, HL2BL.Arts.slot
	if not ( items and slot and slot ~= 0 ) then return end
	local art = items[ slot ]
	if not ( art and art.kind == "active" ) then return end

	local ply    = LocalPlayer()
	local untilT = ply:GetNWFloat( "hl2bl_ability_until", 0 )
	local cd     = ply:GetNWFloat( "hl2bl_ability_cd", 1 )
	local remain = math.max( 0, untilT - CurTime() )
	local frac   = ( cd > 0 ) and ( 1 - remain / cd ) or 1
	local ready  = remain <= 0

	local w, h = 210, 14
	local x, y = 24, ScrH() - 112
	draw.SimpleText( "[" .. HL2BL.AbilityKey .. "] " .. ( art.name or "Ability" ) .. ( ready and "" or ( "  " .. math.ceil( remain ) .. "s" ) ),
		"HL2BL.Body", x, y - 16, ready and Color( 120, 230, 120 ) or Color( 180, 180, 190 ) )
	draw.RoundedBox( 3, x, y, w, h, Color( 0, 0, 0, 180 ) )
	draw.RoundedBox( 3, x, y, w * frac, h, ready and Color( 120, 220, 140 ) or Color( 120, 160, 220 ) )
end )

-- Look-at card for dropped artifacts.
hook.Add( "HUDPaint", "hl2bl_art_lookat", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) or not ply:Alive() then return end
	local ent = ply:GetEyeTrace().Entity
	if not IsValid( ent ) or ent:GetClass() ~= "hl2bl_artifact" then return end
	if ent:GetPos():DistToSqr( ply:EyePos() ) > 200 * 200 then return end

	local j = ent:GetNWString( "hl2bl_artjson", "" ); if j == "" then return end
	local art = util.JSONToTable( j ); if not art then return end
	local x, y = ScrW() * 0.56, ScrH() * 0.30
	local hh = HL2BL.DrawArtifactCard( x, y, art )
	draw.SimpleText( "[E] Pick up", "HL2BL.Title", x + 140, y + hh + 8, Color( 120, 230, 120 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
end )
