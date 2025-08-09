local SETTINGS = {
	NPC_STORAGE = game:GetService("ReplicatedStorage"), -- The place where your NPC models are stored
	NPC_TAG = "NPC", -- The tag needed to detect a model as an NPC
	NPC_AGGRESSIVE_TAG = "Aggressive",
	NPC_RESPAWN_TAG = "Respawn",
	NPC_RESPAWN_AT_ORIGIN_TAG = "OriginRespawn",
	NPC_WANDER_TAG = "Wander",
	CULLING_DISTANCE = 100, -- The distance where if there are no nearby players within the proximity, the NPC despawns temporarily
	CULLING_FREQUENCY = 5, -- Amount of culling checks fired per second
	PATH_VISUALIZE = false, -- Decides whether you can see the path created by SimplePath
}

return SETTINGS