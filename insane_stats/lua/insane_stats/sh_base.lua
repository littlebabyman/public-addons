InsaneStats.BOOL = 1
InsaneStats.INT = 2
InsaneStats.FLOAT = 3
InsaneStats.STRING = 4
InsaneStats.NOP = function()end

InsaneStats.numConVars = 0
InsaneStats.conVars = {}
InsaneStats._defaultConVarCategory = ""
--defaultConVarCategoryDisplay = ""

-- this is on the shared side, because the client needs to know
-- the server's ConVars for the GUI menu, but at the same time
-- the server doesn't need to know about the client's ConVars
AccessorFunc(InsaneStats, "_defaultConVarCategory", "DefaultConVarCategory", FORCE_STRING)

--[[function InsaneStats:SetDefaultConVarCategory(name, display)
	self.defaultConVarCategory = name
	self.defaultConVarCategoryDisplay = display
end]]

function InsaneStats:RegisterConVar(name, internal, default, data)
	local conVar
	
	-- if it is of boolean type, only 0 and 1 values are allowed
	if data.type == self.BOOL then
		data.min = 0
		data.max = 1
	end
	
	if data.type == self.INT or data.type == self.BOOL then
		conVar = CreateConVar(
			internal,
			default,
			bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED),
			data.desc,
			data.min,
			data.max
		)
	else
		conVar = CreateConVar(
			internal,
			default,
			bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED),
			data.desc
		)
	end
	
	self.numConVars = self.numConVars + 1
	
	local conVarData = {
		conVar = conVar,
		internal = internal,
		default = default,
		id = self.numConVars
	}
	table.Merge(conVarData, data)
	
	if not conVarData.category then
		conVarData.category = self:GetDefaultConVarCategory()
		--conVarData.category, conVarData.categoryDisplay = self:GetDefaultConVarCategory()
	end
	
	self.conVars[name] = conVarData
	
	return conVar
end

function InsaneStats:GetConVarValue(name)
	local valueType = self.conVars[name].type
	local conVar = self.conVars[name].conVar
	
	if valueType == self.BOOL then
		return conVar:GetBool()
	elseif valueType == self.INT then
		return conVar:GetInt()
	elseif valueType == self.FLOAT then
		return conVar:GetFloat()
	elseif conVar then
		return conVar:GetString()
	end
end

function InsaneStats:GetConVarValueDefaulted(...)
	local vars = {...}
	
	if istable(vars[1]) then
		vars = vars[1]
	end
	
	for i,v in ipairs(vars) do
		if v then
			local value = self:GetConVarValue(v)
			if value >= 0 then
				return value
			end
		end
	end
	
	return self:GetConVarValue(vars[#vars])
end

function InsaneStats:GetConVarData(name)
	return self.conVars[name]
end

-- MISC

InsaneStats:SetDefaultConVarCategory("Miscellaneous")
InsaneStats:RegisterConVar("save_file", "insanestats_save_file", "default", {
	display = "Save File Name", desc = "Data from other modules such as XP and WPASS2 will be saved in \z
	data/insane_stats/<name>.json.\n\z
	Note that ConVar values are not saved this way, and changes to this ConVar only take effect after a map change.",
	type = InsaneStats.STRING
})
InsaneStats:RegisterConVar("gametext_tochat", "insanestats_gametext_tochat", "0", {
	display = "game_text To Chat", desc = "Activated game_texts will also send their texts to chat.",
	type = InsaneStats.BOOL
})
InsaneStats:RegisterConVar("gametext_tochat_once", "insanestats_gametext_tochat_once", "0", {
	display = "Chat Only Once", desc = "Activated game_texts will only send their texts to chat once.",
	type = InsaneStats.BOOL
})
InsaneStats:RegisterConVar("ammocrate_maxammo", "insanestats_ammocrate_maxammo", "0", {
	display = "Ammo Crates Give 9999", desc = "Ammo crates always give 9999 ammo, limited only by the gmod_maxammo ConVar.",
	type = InsaneStats.BOOL
})
InsaneStats:RegisterConVar("transition_delay", "insanestats_transition_delay", "1", {
	display = "Level Transitions Have Cooldowns", desc = "trigger_changelevels cannot be activated within the first 15 seconds of a map.\n\z
	Useful for maps where both trigger_changelevels are at the same place.",
	type = InsaneStats.BOOL
})
InsaneStats:RegisterConVar("spawn_master", "insanestats_spawn_master", "0", {
	display = "Spawn At First Spawn Position", desc = "Players will always spawn at the first spawn position within the map, \z
	instead of a random spawn position. \z
	Additionally, master info_player_starts will always take priority over other info_player_starts.\n\z
	Useful for maps that have made the above assumptions, such as campaign maps.",
	type = InsaneStats.BOOL
})
InsaneStats:RegisterConVar("flashlight_disable_fix", "insanestats_flashlight_disable_fix", "0", {
	display = "Fix DisableFlashlight", desc = "The DisableFlashlight map input will now actually disable the player's flashlight.",
	type = InsaneStats.BOOL
})
InsaneStats:RegisterConVar("flashlight_disable_fix_modifyspeed", "insanestats_flashlight_disable_fix_modifyspeed", "0", {
	display = "ModifySpeed on player_speedmod Disables Flashlight", desc = "In HL2, the ModifySpeed input on a player_speedmod entity would disable the player's flashlight. \z
	You can reenable this behaviour via this ConVar.",
	type = InsaneStats.BOOL
})
