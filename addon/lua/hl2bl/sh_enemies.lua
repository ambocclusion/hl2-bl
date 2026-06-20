--[[ hl2bl: hostile NPC classes (shared) -------------------------------------
	The set of NPC classes the addon treats as enemies (level-scaled, variant-
	rolled, loot-dropping, health-barred). Friendlies (citizens, vortigaunts,
	etc.) are intentionally excluded. Shared so the client HUD can tell which
	NPCs are enemies without any extra networking.
----------------------------------------------------------------------------]]
HL2BL = HL2BL or {}

HL2BL.EnemyClasses = {
	npc_combine_s = true, npc_metropolice = true, npc_manhack = true,
	npc_antlion = true, npc_antlionguard = true, npc_stalker = true, npc_hunter = true,
	npc_zombie = true, npc_fastzombie = true, npc_poisonzombie = true, npc_zombine = true,
	npc_headcrab = true, npc_headcrab_fast = true, npc_headcrab_black = true,
}

-- Player-allied NPCs, protected from friendly fire (players/allies can't hurt them).
HL2BL.FriendlyClasses = {
	npc_citizen = true, npc_alyx = true, npc_barney = true, npc_kleiner = true,
	npc_eli = true, npc_mossman = true, npc_magnusson = true, npc_gman = true,
	npc_vortigaunt = true, npc_dog = true, npc_monk = true, npc_fisherman = true,
}
