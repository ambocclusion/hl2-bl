AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

-- No default sandbox arsenal. Players fight with looted/bought HL2BL guns; their
-- saved 4-slot loadout is re-given by the addon's PlayerSpawn hook.
function GM:PlayerLoadout( ply )
	ply:RemoveAllAmmo()
	ply:StripWeapons()
	return true   -- skip sandbox's loadout (physgun/toolgun/all weapons)
end
