function GM:PlayerAddSkills(ply, skillIDs)
	local appliedSkills = hook.Run("GetAppliedSkills")
	local appliedSkillsToAdd = {}
	for k,v in pairs(skillIDs) do
		if not appliedSkills[k] then
			appliedSkillsToAdd[k] = v
		end
	end
	hook.Run("AddAppliedSkills", appliedSkillsToAdd)
	
	net.Start("rotgb_gamemode")
	net.WriteUInt(RTG_OPERATION_SKILLS, 4)
	net.WriteBool(true)
	if next(skillIDs, next(skillIDs)) then
		net.WriteUInt(RTG_SKILL_MULTIPLE, 2)
		net.WriteUInt(table.Count(skillIDs)-1, 12)
		for k,v in pairs(skillIDs) do
			net.WriteUInt(k-1, 12)
		end
	else
		net.WriteUInt(RTG_SKILL_ONE, 2)
		net.WriteUInt(next(skillIDs)-1, 12)
	end
	net.Send(ply)
	
	local nextKey = next(appliedSkillsToAdd)
	if nextKey then
		net.Start("rotgb_gamemode")
		net.WriteUInt(RTG_OPERATION_SKILLS, 4)
		net.WriteBool(false)
		if next(appliedSkillsToAdd, nextKey) then
			net.WriteUInt(RTG_SKILL_MULTIPLE, 2)
			net.WriteUInt(table.Count(appliedSkillsToAdd)-1, 12)
			for k,v in pairs(appliedSkillsToAdd) do
				net.WriteUInt(k-1, 12)
			end
		else
			net.WriteUInt(RTG_SKILL_ONE, 2)
			net.WriteUInt(nextKey-1, 12)
		end
		net.Broadcast()
	end
end

function GM:PlayerClearSkills(ply)
	local skillsToApply = {}
	local plys = player.GetAll()
	for k,v in pairs(hook.Run("GetSkills")) do
		for k2,v2 in pairs(plys) do
			if v2:RTG_HasSkill(k) then
				skillsToApply[k2] = v2 break
			end
		end
	end
	hook.Run("SetAppliedSkills", skillsToApply)
	
	net.Start("rotgb_gamemode")
	net.WriteUInt(RTG_OPERATION_SKILLS, 4)
	net.WriteBool(true)
	net.WriteUInt(RTG_SKILL_CLEAR, 2)
	net.Send(ply)
	
	net.Start("rotgb_gamemode")
	net.WriteUInt(RTG_OPERATION_SKILLS, 4)
	net.WriteBool(false)
	if next(appliedSkills) then
		net.WriteUInt(RTG_SKILL_MULTIPLE, 2)
		net.WriteUInt(table.Count(appliedSkills)-1, 12)
		for k,v in pairs(appliedSkills) do
			net.WriteUInt(k-1, 12)
		end
	else
		net.WriteUInt(RTG_SKILL_CLEAR, 2)
	end
	net.Broadcast()
end