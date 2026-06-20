--[[ hl2bl: update notifier (server) -----------------------------------------
	GMod's sandbox can't run git, so we can't self-update from Lua. Instead we
	check the repo's version.txt and tell admins to run scripts/update.sh when a
	newer version is available. Disable with hl2bl_update_check 0.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

local cCheck = CreateConVar( "hl2bl_update_check", "1", FCVAR_ARCHIVE,
	"Check GitHub for a newer HL2:Borderlands version on load." )

local VERSION_URL = "https://raw.githubusercontent.com/ambocclusion/hl2-bl/main/version.txt"

local function notify( ply )
	if HL2BL._UpdateLatest and ply:IsSuperAdmin() then
		ply:ChatPrint( string.format(
			"[HL2BL] Update available: %s -> %s. Run scripts/update.sh on the server.",
			HL2BL.Version or "?", HL2BL._UpdateLatest ) )
	end
end

hook.Add( "InitPostEntity", "hl2bl_updatecheck", function()
	if not cCheck:GetBool() then return end
	timer.Simple( 6, function()
		http.Fetch( VERSION_URL, function( body )
			local latest    = string.Trim( body or "" )
			local installed = HL2BL.Version or "?"
			if latest ~= "" and latest ~= installed then
				HL2BL._UpdateLatest = latest
				print( string.format(
					"[HL2BL] Update available: installed %s, latest %s. Run scripts/update.sh",
					installed, latest ) )
				for _, ply in ipairs( player.GetAll() ) do notify( ply ) end
			else
				print( "[HL2BL] Up to date (" .. installed .. ")." )
			end
		end, function() end )
	end )
end )

-- Tell superadmins who join after the check.
hook.Add( "PlayerInitialSpawn", "hl2bl_updatecheck_join", function( ply )
	timer.Simple( 8, function() if IsValid( ply ) then notify( ply ) end end )
end )
