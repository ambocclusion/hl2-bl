--[[ hl2bl: weapon archetypes (shared) ---------------------------------------
	Base tuning + models per gun type. The generic gun base reads these by
	archetype id, so equipped "slot" weapons can become any archetype (and you
	can equip duplicates of the same type across your 4 slots).
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

HL2BL.Archetypes = {
	pistol = {
		name = "Pistol", hold = "pistol", auto = false,
		vm = "models/weapons/c_pistol.mdl",  wm = "models/weapons/w_pistol.mdl",
		dmg = 16, rpm = 360, spread = 0.015, shots = 1, reload = 1.2, clip = 18,
		recoil = 0.5, reserve = 6, sound = "Weapon_Pistol.Single",
	},
	smg = {
		name = "SMG", hold = "smg", auto = true,
		vm = "models/weapons/c_smg1.mdl",    wm = "models/weapons/w_smg1.mdl",
		dmg = 11, rpm = 720, spread = 0.05, shots = 1, reload = 1.5, clip = 30,
		recoil = 0.4, reserve = 6, sound = "Weapon_SMG1.Single",
	},
	shotgun = {
		name = "Shotgun", hold = "shotgun", auto = false,
		vm = "models/weapons/c_shotgun.mdl", wm = "models/weapons/w_shotgun.mdl",
		dmg = 8, rpm = 80, spread = 0.09, shots = 8, reload = 2.2, clip = 6,
		recoil = 1.4, reserve = 8, sound = "Weapon_Shotgun.Single",
	},
	rifle = {
		name = "Rifle", hold = "ar2", auto = true,
		vm = "models/weapons/c_irifle.mdl",  wm = "models/weapons/w_irifle.mdl",
		dmg = 18, rpm = 450, spread = 0.03, shots = 1, reload = 2.0, clip = 30,
		recoil = 0.6, reserve = 6, sound = "Weapon_AR2.Single",
	},
	sniper = {
		name = "Sniper", hold = "crossbow", auto = false,
		vm = "models/weapons/c_crossbow.mdl", wm = "models/weapons/w_crossbow.mdl",
		dmg = 90, rpm = 50, spread = 0.002, shots = 1, reload = 2.5, clip = 5,
		recoil = 1.2, reserve = 10, sound = "Weapon_Crossbow.Single",
	},
}

HL2BL.MAX_SLOTS = 4

function HL2BL.GetArchetype( id )
	return HL2BL.Archetypes[ id ] or HL2BL.Archetypes.smg
end
