--[[ hl2bl: debug menu (client) ----------------------------------------------
	Open with `hl2bl_debug`. "Reset my save" wipes your own progress; other
	buttons are cheats (need sv_cheats / admin, enforced server-side).
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

local function send( action, arg )
	net.Start( "hl2bl_debug" )
		net.WriteString( action )
		net.WriteFloat( arg or 0 )
	net.SendToServer()
end

function HL2BL.OpenDebug()
	if IsValid( HL2BL._DebugFrame ) then HL2BL._DebugFrame:Remove(); return end

	local f = vgui.Create( "DFrame" )
	f:SetSize( 340, math.min( 580, ScrH() * 0.85 ) ); f:Center(); f:MakePopup()
	f:SetTitle( "HL2: Borderlands - Debug" )
	HL2BL._DebugFrame = f

	local scroll = vgui.Create( "DScrollPanel", f ); scroll:Dock( FILL )

	local function btn( text, fn, col )
		local b = scroll:Add( "DButton" )
		b:Dock( TOP ); b:DockMargin( 8, 4, 8, 0 ); b:SetTall( 30 ); b:SetText( text )
		if col then b:SetTextColor( col ) end
		b.DoClick = fn
		return b
	end
	local function label( t )
		local l = scroll:Add( "DLabel" ); l:Dock( TOP ); l:DockMargin( 8, 8, 8, 0 ); l:SetText( t )
	end

	btn( "RESET MY SAVE", function()
		Derma_Query( "Reset your save?\nThis wipes your backpack, level, and credits.",
			"Reset Save", "Reset", function() send( "reset" ) end, "Cancel" )
	end, Color( 235, 120, 120 ) )

	label( "Cheats (need sv_cheats / admin):" )
	btn( "+1000 Credits", function() send( "credits" ) end )

	local sl = scroll:Add( "DNumSlider" )
	sl:Dock( TOP ); sl:DockMargin( 8, 4, 8, 0 ); sl:SetTall( 36 )
	sl:SetText( "Level" ); sl:SetMin( 1 ); sl:SetMax( HL2BL.MaxLevel ); sl:SetDecimals( 0 )
	sl:SetValue( LocalPlayer():GetNWInt( "hl2bl_level", 1 ) )
	btn( "Set Level", function() send( "setlevel", sl:GetValue() ) end )

	label( "Spawn gun:" )
	for r = 0, HL2BL.RARITY_COUNT - 1 do
		btn( "Spawn " .. HL2BL.RarityName[ r ] .. " Gun", function() send( "spawngun", r ) end, HL2BL.RarityColor[ r ] )
	end

	label( "Spawn artifact:" )
	for r = 0, HL2BL.RARITY_COUNT - 1 do
		btn( "Spawn " .. HL2BL.RarityName[ r ] .. " Artifact", function() send( "spawnartifact", r ) end, HL2BL.RarityColor[ r ] )
	end

	btn( "Spawn Vendor (where you look)", function() send( "vendor" ) end )
	btn( "Toggle Enemy Spawning", function() send( "togglespawn" ) end )
end

concommand.Add( "hl2bl_debug", HL2BL.OpenDebug, nil, "Open the HL2:Borderlands debug menu." )
