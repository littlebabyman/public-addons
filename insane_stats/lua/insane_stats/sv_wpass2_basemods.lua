local damageTiers = {0}
-- 0: normal, 1: explosive recalculate, 2: explosive, 3: arcing, 4: status effect, 5: doom
--[[
shock, electroblast and cosmicurse status effects have complicated interactions
only for tier 1 damage PostEntityTakeDamage should apply those status effects immediately
this doesn't happen for any other tier damage
]]

local entities = {}
for i,v in ipairs(ents.GetAll()) do
	entities[v] = true
end
local rapidThinkEntities = {}
for k,v in pairs(entities) do
	if k:InsaneStats_IsMob() then
		rapidThinkEntities[k] = true
	end
end

local blastDamageTypes = bit.bor(DMG_BLAST, DMG_BLAST_SURFACE)
local fireDamageTypse = bit.bor(DMG_BURN, DMG_SLOWBURN)
local poisonDamageTypes = bit.bor(DMG_PARALYZE, DMG_NERVEGAS, DMG_POISON, DMG_RADIATION, DMG_ACID)
local freezeDamageTypes = bit.bor(DMG_DROWN, DMG_VEHICLE)
local shockDamageTypes = bit.bor(DMG_FALL, DMG_SHOCK)
local vector_down = -vector_up
local explosionCount = 0

hook.Add("InsaneStatsWPASS2Doom", "InsaneStatsWPASS2", function(victim, level, attacker)
	if level ~= 0 and victim:InsaneStats_GetHealth() > 0 then
		table.insert(damageTiers, 5)
		
		if not IsValid(attacker) then
			attacker = victim
		end
		local dmginfo = DamageInfo()
		dmginfo:SetAmmoType(-1)
		dmginfo:SetAttacker(attacker)
		dmginfo:SetBaseDamage(level)
		dmginfo:SetDamage(level)
		dmginfo:SetDamageForce(vector_origin)
		dmginfo:SetDamagePosition(victim:WorldSpaceCenter())
		dmginfo:SetDamageType(DMG_ENERGYBEAM)
		dmginfo:SetInflictor(attacker)
		dmginfo:SetMaxDamage(level)
		dmginfo:SetReportedPosition(attacker:WorldSpaceCenter())
		victim:TakeDamageInfo(dmginfo)
		
		table.remove(damageTiers)
	end
end)

local armoredClasses = { -- these entities are counted as armored for armored_victim_damage
	["npc_antlionguard"]=true,
	["npc_combinedropship"]=true,
	["npc_combinegunship"]=true,
	["npc_helicopter"]=true,
	["npc_rollermine"]=true,
	["npc_sniper"]=true,
	["npc_strider"]=true,
	["npc_turret_floor"]=true,
	["prop_vehicle_apc"]=true
}

local function CalculateDamage(vic, attacker, dmginfo)
	local wep = attacker.GetActiveWeapon and attacker:GetActiveWeapon()
	--if math.random() < attacker:InsaneStats_GetAttributeValue("misschance") - 1 then return true end
	if not dmginfo:IsDamageType(DMG_DISSOLVE) then
		if math.random() < vic:InsaneStats_GetAttributeValue("dodge") - 1 then return true end
		if attacker:InsaneStats_GetStatusEffectLevel("stunned") > 0 then return true end
	end
	
	local totalMul = attacker:InsaneStats_GetAttributeValue("damage")
	local knockbackMul = attacker:InsaneStats_GetAttributeValue("knockback")
	
	totalMul = totalMul * vic:InsaneStats_GetAttributeValue("damagetaken")
	knockbackMul = knockbackMul * vic:InsaneStats_GetAttributeValue("knockbacktaken")
	
	if vic.insaneStats_LastHitGroup == HITGROUP_HEAD then
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("crit_damage")
		totalMul = totalMul * vic:InsaneStats_GetAttributeValue("crit_damagetaken")
	end
	
	if vic == attacker then
		knockbackMul = knockbackMul * vic:InsaneStats_GetAttributeValue("self_knockbacktaken")
	end
	
	local isNotBulletDamage = not dmginfo:IsBulletDamage()
	local attackerHealthFraction = attacker:InsaneStats_GetMaxHealth() > 0
		and 1-math.Clamp(attacker:InsaneStats_GetHealth() / attacker:InsaneStats_GetMaxHealth(), 0, 1) or 0
	local attackerArmorInverseFraction = attacker:InsaneStats_GetArmor() > 0
		and attacker:InsaneStats_GetArmor() / attacker:InsaneStats_GetMaxArmor() or 0
	local victimHealthFraction = vic:InsaneStats_GetMaxHealth() > 0
		and 1-math.Clamp(vic:InsaneStats_GetHealth() / vic:InsaneStats_GetMaxHealth(), 0, 1) or 0
	local attackerSpeedFraction = attacker:GetVelocity():Length() / 400
	local victimSpeedFraction = vic:GetVelocity():Length() / 400
	local attackerCombatFraction = math.Clamp(attacker:InsaneStats_GetCombatTime()/5, 0, 1)
	--local victimCombatFraction = math.Clamp(vic:InsaneStats_GetCombatTime()/5, 0, 1)
	
	--[[local combatDodgeChance = (vic:InsaneStats_GetAttributeValue("combat5s_dodge") - 1) * victimCombatFraction
	if math.random() < combatDodgeChance then return true end]]
	
	if isNotBulletDamage then
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("nonbullet_damage")
		--if math.random() < attacker:InsaneStats_GetAttributeValue("nonbullet_misschance") - 1 then return true end
	else
		totalMul = totalMul * vic:InsaneStats_GetAttributeValue("bullet_damagetaken")
	end
	if dmginfo:IsDamageType(blastDamageTypes) then
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("explode_damage")
		totalMul = totalMul * vic:InsaneStats_GetAttributeValue("explode_damagetaken")
	end
	if dmginfo:IsDamageType(fireDamageTypse) then
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("fire_damage")
		totalMul = totalMul * vic:InsaneStats_GetAttributeValue("fire_damagetaken")
	end
	if dmginfo:IsDamageType(poisonDamageTypes) then
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("poison_damage")
		totalMul = totalMul * vic:InsaneStats_GetAttributeValue("poison_damagetaken")
	end
	if dmginfo:IsDamageType(freezeDamageTypes) then
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("freeze_damage")
		totalMul = totalMul * vic:InsaneStats_GetAttributeValue("freeze_damagetaken")
	end
	if dmginfo:IsDamageType(shockDamageTypes) then
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("shock_damage")
		totalMul = totalMul * vic:InsaneStats_GetAttributeValue("shock_damagetaken")
	end
	if dmginfo:IsDamageType(DMG_SLASH) then
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("bleed_damage")
		totalMul = totalMul * vic:InsaneStats_GetAttributeValue("bleed_damagetaken")
	end
	if dmginfo:IsDamageType(DMG_CLUB) then
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("melee_damage")
		totalMul = totalMul * (1 + (attacker:InsaneStats_GetAttributeValue("lowhealth_victim_melee_damage") - 1) * victimHealthFraction)
	end
	
	if (IsValid(wep) and wep.Clip1 and wep:Clip1() < 2) then
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("lastammo_damage")
	end
	if attacker:WorldSpaceCenter():DistToSqr(vic:WorldSpaceCenter()) > 262144 then
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("longrange_damage")
		totalMul = totalMul * vic:InsaneStats_GetAttributeValue("longrange_damagetaken")
		if isNotBulletDamage then
			totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("longrange_nonbullet_damage")
		end
	else
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("shortrange_damage")
		totalMul = totalMul * vic:InsaneStats_GetAttributeValue("shortrange_damagetaken")
		if isNotBulletDamage then
			totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("shortrange_nonbullet_damage")
		end
	end
	
	totalMul = totalMul * (1 + (attacker:InsaneStats_GetAttributeValue("lowhealth_damage") - 1) * attackerHealthFraction)
	totalMul = totalMul * (1 + (attacker:InsaneStats_GetAttributeValue("lowhealth_victim_damage") - 1) * victimHealthFraction)
	totalMul = totalMul * (1 + (vic:InsaneStats_GetAttributeValue("lowhealth_damagetaken") - 1) * victimHealthFraction)
	if victimHealthFraction > 0.9 then
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("high90health_victim_damage")
	end
	if victimHealthFraction < attacker:InsaneStats_GetAttributeValue("lowxhealth_victim_doubledamage") - 1 then
		totalMul = totalMul * 2
	end
	totalMul = totalMul * (1 + (attacker:InsaneStats_GetAttributeValue("speed_damage") - 1) * attackerSpeedFraction)
	totalMul = totalMul * (1 + (attacker:InsaneStats_GetAttributeValue("armor_damage") - 1) * attackerArmorInverseFraction)
	totalMul = totalMul * (1 + (vic:InsaneStats_GetAttributeValue("speed_damagetaken") - 1) * victimSpeedFraction)
	--totalMul = totalMul * (1 + (attacker:InsaneStats_GetAttributeValue("combat5s_damage") - 1) * attackerCombatFraction)
	--totalMul = totalMul * (1 + (vic:InsaneStats_GetAttributeValue("combat5s_damagetaken") - 1) * victimCombatFraction)
	
	if attackerCombatFraction <= 0 then
		totalMul = totalMul * vic:InsaneStats_GetAttributeValue("noncombat_damagetaken")
	end
	
	totalMul = totalMul * (1-attacker:InsaneStats_GetStatusEffectLevel("damage_down")/100)
	totalMul = totalMul * (1+attacker:InsaneStats_GetStatusEffectLevel("damage_up")/100)
	totalMul = totalMul * (1+attacker:InsaneStats_GetStatusEffectLevel("arcane_damage_up")/100)
	totalMul = totalMul * (1+attacker:InsaneStats_GetStatusEffectLevel("alt_damage_up")/100)
	totalMul = totalMul * (1+attacker:InsaneStats_GetStatusEffectLevel("hittaken_damage_up")/100)
	totalMul = totalMul * (1+attacker:InsaneStats_GetStatusEffectLevel("killstackmarked_damage_up")/100)
	totalMul = totalMul * (1+attacker:InsaneStats_GetStatusEffectLevel("ctrl_damage_up")/100)
	totalMul = totalMul * (1+vic:InsaneStats_GetStatusEffectLevel("defence_down")/100)
	totalMul = totalMul / (1+vic:InsaneStats_GetStatusEffectLevel("defence_up")/100)
	totalMul = totalMul / (1+vic:InsaneStats_GetStatusEffectLevel("arcane_defence_up")/100)
	totalMul = totalMul / (1+vic:InsaneStats_GetStatusEffectLevel("killstackmarked_defence_up")/100)
	totalMul = totalMul / (1+vic:InsaneStats_GetStatusEffectLevel("alt_defence_up")/100)
	
	--totalMul = totalMul * (1+(attacker:InsaneStats_GetAttributeValue("perdebuff_damage")-1)*vic:InsaneStats_GetStatusEffectCountByType(-1))
	--totalMul = totalMul / (1+(vic:InsaneStats_GetAttributeValue("perdebuff_defence")-1)*vic:InsaneStats_GetStatusEffectCountByType(-1))
	--print(attacker:InsaneStats_GetAttributeValue("perdebuff_damage"), vic:InsaneStats_GetStatusEffectCountByType(-1))
	
	totalMul = totalMul * (1 + attacker:InsaneStats_GetStatusEffectLevel("stack_damage_up") / 100)
	totalMul = totalMul / (1 + vic:InsaneStats_GetStatusEffectLevel("stack_defence_up") / 100)
	
	totalMul = totalMul * (1 + vic:InsaneStats_GetStatusEffectLevel("perhit_defence_down")/100)
	totalMul = totalMul * (1 - attacker:InsaneStats_GetStatusEffectLevel("menacing_damage_down")/100)

	if vic:InsaneStats_GetAttributeValue("starlight_defence") ~= 1 then
		totalMul = totalMul / (1 + vic:InsaneStats_GetStatusEffectDuration("starlight") / 100)
	end
	
	--totalMul = totalMul * (1 + attacker:InsaneStats_GetStatusEffectLevel("hit10s_damage_up") / 100)
	
	--[[if not attacker:IsPlayer() then
		-- non-players are not affected by firerate, so we adjust damage accordingly
		-- using a faked InsaneStatsModifyNextFire call
		local data = {next = CurTime() + 1, wep = wep, attacker = attacker}
		hook.Run("InsaneStatsModifyNextFire", data)
		
		totalMul = totalMul / (data.next - CurTime())
	end
		
	if not (vic:IsPlayer() or vic:IsNextBot()) then
		-- similarly, non-Nextbot, non-players ignore any movement speed adjustments, so adjust damage received
		-- using a faked InsaneStatsMoveSpeed call
		local data = {ent = vic, speed = 1, sprintSpeed = 1}
		hook.Run("InsaneStatsMoveSpeed", data)
		
		totalMul = totalMul / data.speed
		totalMul = totalMul / math.sqrt(data.sprintSpeed)
	end]]

	if vic:InsaneStats_GetStatusEffectLevel("hittaken1s_damagetaken_cooldown") <= 0 then
		totalMul = totalMul * vic:InsaneStats_GetAttributeValue("hittaken1s_damagetaken")
	end
	
	if vic:InsaneStats_IsMob() then
		--[[local overloadableArmorFraction = attacker:InsaneStats_GetArmor() / attacker:InsaneStats_GetMaxArmor()
		if overloadableArmorFraction >= 1 then
			local conversionRate = attacker:InsaneStats_GetAttributeValue("amp_armorloss") - 1
			attacker:SetArmor(attacker:InsaneStats_GetArmor() * (1-conversionRate))
			local convertedArmor = overloadableArmorFraction * conversionRate * 100
			dmginfo:AddDamage(convertedArmor * attacker:InsaneStats_GetAttributeValue("amp_damage"))
		end]]
		
		--[[if attacker:InsaneStats_GetArmor() >= attacker:InsaneStats_GetMaxArmor() and attacker:InsaneStats_GetArmor() > 0 then
			-- how much armor is lost?
			local conversionRate = attacker:InsaneStats_GetAttributeValue("amp_armorloss") - 1
			local armorLost = attacker:InsaneStats_GetArmor() * conversionRate
			
			if attacker:InsaneStats_GetArmor() < math.huge then
				attacker:SetArmor(attacker:InsaneStats_GetArmor() - armorLost)
			end
			
			dmginfo:AddDamage(armorLost / (attacker.insaneStats_CurrentArmorAdd or 1) * attacker:InsaneStats_GetAttributeValue("amp_damage"))
		end]]
		
		if attacker:InsaneStats_GetStatusEffectLevel("hit1s_damage_cooldown") <= 0 then
			totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("hit1s_damage")
		end
		
		--[[if attacker:InsaneStats_GetAttributeValue("hit10s_damage") ~= 1
		and attacker:InsaneStats_GetStatusEffectLevel("hit10s_damage_up") <= 0
		and attacker:InsaneStats_GetStatusEffectLevel("hit10s_damage_cooldown") <= 0
		then
			local stacks = (attacker:InsaneStats_GetAttributeValue("hit10s_damage")-1)*100
			attacker:InsaneStats_ApplyStatusEffect("hit10s_damage_up", stacks, 10)
		end]]
	
		--[[if attacker:InsaneStats_GetAttributeValue("hit10s_firerate") ~= 1
		and attacker:InsaneStats_GetStatusEffectLevel("hit10s_firerate_up") <= 0
		and attacker:InsaneStats_GetStatusEffectLevel("hit10s_firerate_cooldown") <= 0
		then
			local stacks = (attacker:InsaneStats_GetAttributeValue("hit10s_firerate")-1)*100
			attacker:InsaneStats_ApplyStatusEffect("hit10s_firerate_up", stacks, 10)
		end]]
		
		if attacker:InsaneStats_GetAttributeValue("hit3_damage") ~= 1 then
			if attacker:InsaneStats_GetStatusEffectLevel("hit3_damage_stacks") < 2 then
				attacker:InsaneStats_ApplyStatusEffect("hit3_damage_stacks", 1, math.huge, {amplify = true})
			else
				attacker:InsaneStats_ClearStatusEffect("hit3_damage_stacks")
				totalMul = totalMul * (1 + attacker:InsaneStats_GetAttributeValue("hit3_damage"))
			end
		end
		
		if attacker:InsaneStats_IsValidAlly(vic) and not (attacker:IsPlayer() and attacker:KeyDown(IN_WALK)) then
			totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("ally_damage")
		end
	--[[else
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("nonliving_damage")]]
	end
	
	local levelDifference = vic:InsaneStats_GetLevel() - attacker:InsaneStats_GetLevel()
	if levelDifference > 0 then
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("highlevel_damage")
		totalMul = totalMul * vic:InsaneStats_GetAttributeValue("lowlevel_damagetaken")
	end
	
	if attacker:InsaneStats_GetAttributeValue("random_damage") ~= 1 then
		local randomness = 1 - attacker:InsaneStats_GetAttributeValue("random_damage")
		totalMul = totalMul * Lerp(math.random(), 1 - randomness, 1 + randomness)
	end
	
	if attacker.insaneStats_MarkedEntity == vic then
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("mark_damage")
	end
	if vic.insaneStats_MarkedEntity == attacker then
		totalMul = totalMul * vic:InsaneStats_GetAttributeValue("mark_damagetaken")
	end
	
	if attacker:InsaneStats_GetLevel() % 2 == 0 then
		totalMul = totalMul * vic:InsaneStats_GetAttributeValue("evenlevel_damagetaken")
	else
		totalMul = totalMul * vic:InsaneStats_GetAttributeValue("oddlevel_damagetaken")
	end
	
	if vic:InsaneStats_GetLevel() % 2 == 0 then
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("evenlevel_damage")
	else
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("oddlevel_damage")
	end
	
	if armoredClasses[vic:GetClass()] or vic:InsaneStats_GetArmor() > 0 then
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("armored_victim_damage")
	else
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("unarmored_victim_damage")
	end
	
	local attackerPositionVector = attacker:WorldSpaceCenter() - vic:WorldSpaceCenter()
	attackerPositionVector:Normalize()
	local vicLookVector = vic:GetForward()
	if vicLookVector:Dot(attackerPositionVector) > 0 then
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("front_damage")
		totalMul = totalMul * vic:InsaneStats_GetAttributeValue("front_damagetaken")
	else
		totalMul = totalMul * attacker:InsaneStats_GetAttributeValue("back_damage")
		totalMul = totalMul * vic:InsaneStats_GetAttributeValue("back_damagetaken")
	end
	
	--print(totalMul)
	dmginfo:ScaleDamage(totalMul)
	
	vic.insaneStats_ArmorBlocksAll = vic:InsaneStats_GetAttributeValue("armor_trueblock") > 1
	--print(vic, vic.insaneStats_ArmorBlocksAll)
	
	dmginfo:SetDamageForce(dmginfo:GetDamageForce() * knockbackMul)
end

local function CauseDelayedDamage(data)
	--{damagePos,attacker,victim,damage,shouldExplode,shouldShock}
	local damagePos = data.pos
	local attacker = data.attacker
	local victim = data.victim
	local damage = data.damage
	local damageTier = data.damageTier
	local shouldExplode = data.shouldExplode
	local shouldShock = data.shouldShock
	local shouldElectroblast = data.shouldElectroblast
	local shouldCosmicurse = data.shouldCosmicurse
	local localPos
	
	if IsValid(victim) then
		localPos = victim:WorldToLocal(damagePos)
	end
					
	if shouldExplode or shouldElectroblast or shouldCosmicurse then
		local effdata = EffectData()
		effdata:SetOrigin(damagePos)
		effdata:SetScale(1)
		effdata:SetMagnitude(1)
		util.Effect("StunstickImpact", effdata)
	end
	
	timer.Simple(0.5, function()
		if IsValid(attacker) then
			local forceDir = vector_origin
			--local halfDamage = damage/2
			--local explosionDamage = halfDamage * attacker:InsaneStats_GetAttributeValue("explode_damage") --this isn't status effect damage
			--print(halfDamage)
			
			-- translate local pos if possible, else use world pos
			if IsValid(victim) then
				damagePos = victim:LocalToWorld(localPos)
				--forceDir = victim:GetPos() - damagePos
				--forceDir:Mul(128/forceDir:Length())
				
				if shouldShock and attacker ~= victim then
					local effectDamage = damage
					effectDamage = effectDamage * attacker:InsaneStats_GetAttributeValue("shock_damage")
					effectDamage = effectDamage * victim:InsaneStats_GetAttributeValue("shock_damagetaken")
					
					victim:InsaneStats_ApplyStatusEffect("shock", effectDamage, 5, {amplify = true, attacker = attacker})
				end
			end
			
			if (shouldExplode or shouldElectroblast or shouldCosmicurse) and explosionCount < 10 then
				table.insert(damageTiers, damageTier)
				explosionCount = explosionCount + 1
				
				local dmginfo = DamageInfo()
				dmginfo:SetAmmoType(8)
				dmginfo:SetAttacker(attacker)
				--dmginfo:SetBaseDamage(damage/2)
				dmginfo:SetDamage(damage/2)
				dmginfo:SetDamageForce(forceDir)
				dmginfo:SetDamagePosition(damagePos)
				if shouldCosmicurse then
					dmginfo:SetDamageType(bit.bor(DMG_BLAST, DMG_SHOCK, DMG_NERVEGAS, DMG_SLASH, DMG_SLOWBURN, DMG_VEHICLE, DMG_ENERGYBEAM))
				elseif shouldElectroblast then
					dmginfo:SetDamageType(bit.bor(DMG_BLAST, DMG_SHOCK))
				else
					dmginfo:SetDamageType(DMG_BLAST)
				end
				dmginfo:SetInflictor(attacker)
				--dmginfo:SetMaxDamage(damage)
				dmginfo:SetReportedPosition(attacker:WorldSpaceCenter())
				util.BlastDamageInfo(dmginfo, damagePos, 128)
				
				local effdata = EffectData()
				effdata:SetOrigin(damagePos)
				effdata:SetMagnitude(1)
				effdata:SetScale(1)
				effdata:SetFlags(0)
				util.Effect("Explosion", effdata)
				
				table.remove(damageTiers)
			end
		end
	end)
end

local totalDamageTicks = 0
local storedScaleCVars
hook.Add("EntityTakeDamage", "InsaneStatsWPASS2", function(vic, dmginfo)
	if InsaneStats:GetConVarValue("wpass2_enabled") and IsValid(vic) then
		totalDamageTicks = (totalDamageTicks or 0) + 1
		if totalDamageTicks > 1000 then
			print("Something caused an infinite loop!")
			debug.Trace()
			return true
		end
		
		if vic.insaneStats_LastHitGroupUpdate ~= engine.TickCount() then
			vic.insaneStats_LastHitGroup = 0
		end

		-- crits
		local attacker = dmginfo:GetAttacker()
		if (IsValid(attacker) and math.random() < attacker:InsaneStats_GetAttributeValue("crit_chance") - 1)
		and vic.insaneStats_LastHitGroup ~= HITGROUP_HEAD then
			if not storedScaleCVars then
				storedScaleCVars = {
					npc = {
						arm = GetConVar("sk_npc_arm"),
						chest = GetConVar("sk_npc_chest"),
						head = GetConVar("sk_npc_head"),
						leg = GetConVar("sk_npc_leg"),
						stomach = GetConVar("sk_npc_stomach")
					},
					player = {
						arm = GetConVar("sk_player_arm"),
						chest = GetConVar("sk_player_chest"),
						head = GetConVar("sk_player_head"),
						leg = GetConVar("sk_player_leg"),
						stomach = GetConVar("sk_player_stomach")
					}
				}
			end
			local damageMultiplier = 1
			local scaleCVars = vic:IsPlayer() and storedScaleCVars.player or storedScaleCVars.npc
			local lastHitGroup = vic.insaneStats_LastHitGroup
			if lastHitGroup == HITGROUP_CHEST then
				damageMultiplier = scaleCVars.chest:GetFloat()
			elseif lastHitGroup == HITGROUP_STOMACH then
				damageMultiplier = scaleCVars.stomach:GetFloat()
			elseif lastHitGroup == HITGROUP_LEFTARM	or lastHitGroup == HITGROUP_RIGHTARM then
				damageMultiplier = scaleCVars.arm:GetFloat()
			elseif lastHitGroup == HITGROUP_LEFTLEG	or lastHitGroup == HITGROUP_RIGHTLEG then
				damageMultiplier = scaleCVars.leg:GetFloat()
			--[[elseif lastHitGroup == HITGROUP_GEAR then
				damageMultiplier = 0.01]]
			end
			if damageMultiplier > 0 then
				damageMultiplier = scaleCVars.head:GetFloat() / damageMultiplier
			end
			dmginfo:ScaleDamage(damageMultiplier)
			vic.insaneStats_LastHitGroup = HITGROUP_HEAD
			vic.insaneStats_LastHitGroupUpdate = engine.TickCount()
		end

		if (vic:InsaneStats_GetStatusEffectLevel("hittaken_invincible") > 0 or vic:InsaneStats_GetStatusEffectLevel("invincible") > 0)
		and not dmginfo:IsDamageType(DMG_DISSOLVE) then
			vic:InsaneStats_DamageNumber(attacker, "immune")
			
			-- on melee hits, reduce duration of invincibility
			if dmginfo:IsDamageType(DMG_CLUB) then
				local deduct = vic:InsaneStats_GetAttributeValue("hittaken_invincible_meleebreak") - 1
				vic:InsaneStats_ApplyStatusEffect("hittaken_invincible", 1, deduct, {extend = true})
			end
			
			return true
		end
		
		if IsValid(attacker) or attacker == game.GetWorld() and not vic:IsVehicle() then
			if attacker:GetClass() == "entityflame"
			and (vic:InsaneStats_GetStatusEffectLevel("fire") > 0
			or vic:InsaneStats_GetStatusEffectLevel("frostfire") > 0
			or vic:InsaneStats_GetStatusEffectLevel("cosmicurse") > 0) then
				return true
			end
			
			if vic:InsaneStats_IsMob() and damageTiers[#damageTiers] > 0
			and (not attacker:InsaneStats_IsValidEnemy(vic) or vic:GetClass() == "prop_dropship_container") then
				if dmginfo:IsExplosionDamage() then
					vic:InsaneStats_ApplyKnockback(dmginfo:GetDamageForce())
				end
				return true
			end
			if vic:InsaneStats_GetHealth() > 0 and damageTiers[#damageTiers] < 2 then
				--print(vic, attacker, dmginfo:GetDamage())
				local shouldBreak = CalculateDamage(vic, attacker, dmginfo)
				--print(vic, attacker, dmginfo:GetDamage())
				if shouldBreak then
					vic:InsaneStats_DamageNumber(attacker, "miss")
					if attacker == vic then
						vic:InsaneStats_ApplyKnockback(dmginfo:GetDamageForce())
					end
					--print(vic, "BLOCKED")
					return true
				end
			end
		end
	end
end)

hook.Add("PostEntityTakeDamage", "InsaneStatsWPASS2", function(vic, dmginfo, notImmune)
	if InsaneStats:GetConVarValue("wpass2_enabled") then
		local attacker = dmginfo:GetAttacker()
		if IsValid(attacker) and IsValid(vic) and attacker ~= vic then
			local vicIsMob = vic:InsaneStats_IsMob()
			if vicIsMob and attacker:InsaneStats_IsMob() then
				vic:InsaneStats_UpdateCombatTime()
				attacker:InsaneStats_UpdateCombatTime()
			end
			
			local wep = attacker.GetActiveWeapon and attacker:GetActiveWeapon()
			
			if damageTiers[#damageTiers] < 4 and not dmginfo:IsDamageType(DMG_BURN) and not IsValid(vic:GetParent()) then
				-- non-damage based effects
				local speedDownLevel = (1 - attacker:InsaneStats_GetAttributeValue("victim_speed")) * 100
				vic:InsaneStats_ApplyStatusEffect("speed_down", speedDownLevel, 5)
				local defenceDownLevel = (attacker:InsaneStats_GetAttributeValue("victim_damagetaken") - 1) * 100
				vic:InsaneStats_ApplyStatusEffect("defence_down", defenceDownLevel, 5)
				local damageDownLevel = (1 - attacker:InsaneStats_GetAttributeValue("victim_damage")) * 100
				vic:InsaneStats_ApplyStatusEffect("damage_down", damageDownLevel, 5)
				local fireRateDownLevel = (1 - attacker:InsaneStats_GetAttributeValue("victim_firerate")) * 100
				vic:InsaneStats_ApplyStatusEffect("firerate_down", fireRateDownLevel, 5)
				
				-- non-over time / delayed effects
				local damage = dmginfo:GetDamage()
				--print(damage)
				--print(not dmginfo:IsBulletDamage(), damageTiers[#damageTiers] < 1, vic:GetCollisionGroup() ~= COLLISION_GROUP_DEBRIS)
				
				if math.random() < attacker:InsaneStats_GetAttributeValue("arc_chance") - 1 then
					-- get a random nearby entity
					local traceResult = {}
					local trace = {
						start = vic:WorldSpaceCenter(),
						filter = {vic, vic.GetVehicle and vic:GetVehicle()},
						mask = MASK_SHOT,
						output = traceResult
					}
					
					local randomEntity = NULL
					for k,v in RandomPairs(ents.FindInSphere(trace.start, 512)) do
						if attacker:InsaneStats_IsValidEnemy(v) then
							local damagePos = v:HeadTarget(attacker:WorldSpaceCenter()) or v:WorldSpaceCenter()
							damagePos = damagePos:IsZero() and v:WorldSpaceCenter() or damagePos
							trace.endpos = damagePos
							util.TraceLine(trace)
							if not traceResult.Hit or traceResult.Entity == v then
								randomEntity = v break
							end
						end
					end
					
					if IsValid(randomEntity) then
						table.insert(damageTiers, 3)
						randomEntity:TakeDamageInfo(dmginfo)
						table.remove(damageTiers)
					end
				end
				
				local worldPos = dmginfo:GetDamagePosition()
				worldPos = worldPos:IsZero() and vic:WorldSpaceCenter() or worldPos
				
				local explodeCondition = not dmginfo:IsBulletDamage() and damageTiers[#damageTiers] < 1 and vic:GetCollisionGroup() ~= COLLISION_GROUP_DEBRIS
				local shouldExplode = math.random() < attacker:InsaneStats_GetAttributeValue("explode") - 1
				local shouldShock = math.random() < attacker:InsaneStats_GetAttributeValue("shock") - 1
				local shouldElectroblast = math.random() < attacker:InsaneStats_GetAttributeValue("electroblast") - 1
				local shouldCosmicurse = attacker:InsaneStats_GetAttributeValue("cosmicurse") > 1
				
				if shouldExplode or shouldShock or shouldElectroblast or shouldCosmicurse then
					CauseDelayedDamage({
						pos = worldPos,
						attacker = attacker,
						victim = vic,
						damage = damage,
						damageTier = 2,
						shouldExplode = explodeCondition and shouldExplode,
						shouldShock = shouldShock,
						shouldElectroblast = explodeCondition and shouldElectroblast,
						shouldCosmicurse = explodeCondition and shouldCosmicurse
					})
				end
				
				if attacker:InsaneStats_GetAttributeValue("perhit_victim_damagetaken") ~= 1 then
					local stacks = (attacker:InsaneStats_GetAttributeValue("perhit_victim_damagetaken")-1)*100
					vic:InsaneStats_ApplyStatusEffect("perhit_defence_down", stacks, 5, {amplify = true})
				end
				
				if vic:InsaneStats_GetAttributeValue("hittakenstack_defence") ~= 1 then
					local stacks = (vic:InsaneStats_GetAttributeValue("hittakenstack_defence")-1)*100
					vic:InsaneStats_ApplyStatusEffect("stack_defence_up", stacks, math.huge, {amplify = true})
				end
				
				if vic:InsaneStats_GetAttributeValue("hittaken_invincible") > 1
				and vic:InsaneStats_GetStatusEffectLevel("hittaken_invincible") == 0
				and vic:InsaneStats_GetStatusEffectLevel("hittaken_invincible_cooldown") == 0
				and vic:InsaneStats_GetHealth() > 0 then
					vic:InsaneStats_ApplyStatusEffect("hittaken_invincible", 1, vic:InsaneStats_GetAttributeValue("hittaken_invincible") - 1)
				end
				
				if vic:InsaneStats_GetAttributeValue("hittaken_damage") ~= 1
				and vic:InsaneStats_GetStatusEffectLevel("hittaken_damage_up") <= 0
				and vic:InsaneStats_GetStatusEffectLevel("hittaken_damage_cooldown") <= 0
				and vic:InsaneStats_GetHealth() > 0 then
					local stacks = (vic:InsaneStats_GetAttributeValue("hittaken_damage")-1)*100
					vic:InsaneStats_ApplyStatusEffect("hittaken_damage_up", stacks, 10)
				end
				
				if vic:InsaneStats_GetAttributeValue("hittaken_regen") ~= 1
				and vic:InsaneStats_GetStatusEffectLevel("hittaken_regen") <= 0
				and vic:InsaneStats_GetStatusEffectLevel("hittaken_regen_cooldown") <= 0
				and vic:InsaneStats_GetHealth() > 0 then
					local stacks = (vic:InsaneStats_GetAttributeValue("hittaken_regen")-1)*100
					vic:InsaneStats_ApplyStatusEffect("hittaken_regen", stacks, 10)
				end
				
				if vic:InsaneStats_GetAttributeValue("hittaken_armorregen") ~= 1
				and vic:InsaneStats_GetStatusEffectLevel("hittaken_armorregen") <= 0
				and vic:InsaneStats_GetStatusEffectLevel("hittaken_armorregen_cooldown") <= 0
				and vic:InsaneStats_GetHealth() > 0 then
					local stacks = (vic:InsaneStats_GetAttributeValue("hittaken_armorregen")-1)*100
					vic:InsaneStats_ApplyStatusEffect("hittaken_armorregen", stacks, 10)
				end
				
				-- over time effects
				local shouldPoison = math.random() < attacker:InsaneStats_GetAttributeValue("poison") - 1
				local shouldBleed = math.random() < attacker:InsaneStats_GetAttributeValue("bleed") - 1
				local shouldHemotoxin = math.random() < attacker:InsaneStats_GetAttributeValue("hemotoxic") - 1
				
				local shouldFire = math.random() < attacker:InsaneStats_GetAttributeValue("fire") - 1
				local shouldFreeze = math.random() < attacker:InsaneStats_GetAttributeValue("freeze") - 1
				local shouldFrostfire = math.random() < attacker:InsaneStats_GetAttributeValue("frostfire") - 1
				
				if shouldPoison or shouldBleed or shouldHemotoxin then
					local effectDamage = 0
					
					if shouldPoison or shouldHemotoxin then
						effectDamage = effectDamage + damage*2
					end
					if shouldBleed or shouldHemotoxin then
						effectDamage = effectDamage + damage
					end
					
					if shouldPoison or shouldHemotoxin then
						effectDamage = effectDamage * attacker:InsaneStats_GetAttributeValue("poison_damage")
						effectDamage = effectDamage * vic:InsaneStats_GetAttributeValue("poison_damagetaken")
					end
					if shouldBleed or shouldHemotoxin then
						effectDamage = effectDamage * attacker:InsaneStats_GetAttributeValue("bleed_damage")
						effectDamage = effectDamage * vic:InsaneStats_GetAttributeValue("bleed_damagetaken")
					end
					
					if shouldPoison then
						vic:InsaneStats_ApplyStatusEffect("poison", effectDamage, 5, {amplify = true, attacker = attacker})
					elseif shouldBleed then
						vic:InsaneStats_ApplyStatusEffect("bleed", effectDamage, 5, {amplify = true, attacker = attacker})
					else
						vic:InsaneStats_ApplyStatusEffect("hemotoxin", effectDamage, 5, {amplify = true, attacker = attacker})
					end
				end
				
				if shouldFire or shouldFreeze or shouldFrostfire then
					local effectDamage = 0
					
					if shouldFire or shouldFrostfire then
						effectDamage = effectDamage + damage*2
					end
					if shouldFreeze or shouldFrostfire then
						effectDamage = effectDamage + damage
					end
					
					if shouldFire or shouldFrostfire then
						effectDamage = effectDamage * attacker:InsaneStats_GetAttributeValue("fire_damage")
						effectDamage = effectDamage * vic:InsaneStats_GetAttributeValue("fire_damagetaken")
					end
					if shouldFreeze or shouldFrostfire then
						effectDamage = effectDamage * attacker:InsaneStats_GetAttributeValue("freeze_damage")
						effectDamage = effectDamage * vic:InsaneStats_GetAttributeValue("freeze_damagetaken")
					end
					
					if shouldFire then
						vic:InsaneStats_ApplyStatusEffect("fire", effectDamage, 5, {amplify = true, attacker = attacker})
					elseif shouldFreeze then
						vic:InsaneStats_ApplyStatusEffect("freeze", effectDamage, 5, {amplify = true, attacker = attacker})
					else
						vic:InsaneStats_ApplyStatusEffect("frostfire", effectDamage, 5, {amplify = true, attacker = attacker})
					end
				end
				
				local damageTier = damageTiers[#damageTiers]
				local hasElectroblast = attacker:InsaneStats_GetAttributeValue("electroblast") > 1
				if damageTier > 0 and damageTier < 3
				and (hasElectroblast or shouldCosmicurse) then
					local effectDamage = 0
				
					if hasElectroblast then
						effectDamage = damage * 2
					else
						effectDamage = damage * (attacker:InsaneStats_GetAttributeValue("cosmicurse")-1)
					end

					effectDamage = effectDamage * attacker:InsaneStats_GetAttributeValue("shock_damage")
					effectDamage = effectDamage * vic:InsaneStats_GetAttributeValue("shock_damagetaken")
					effectDamage = effectDamage * attacker:InsaneStats_GetAttributeValue("explode_damage")
					effectDamage = effectDamage * vic:InsaneStats_GetAttributeValue("explode_damagetaken")

					if shouldCosmicurse then
						effectDamage = effectDamage * attacker:InsaneStats_GetAttributeValue("poison_damage")
						effectDamage = effectDamage * attacker:InsaneStats_GetAttributeValue("bleed_damage")
						effectDamage = effectDamage * attacker:InsaneStats_GetAttributeValue("fire_damage")
						effectDamage = effectDamage * attacker:InsaneStats_GetAttributeValue("freeze_damage")
						effectDamage = effectDamage * vic:InsaneStats_GetAttributeValue("poison_damagetaken")
						effectDamage = effectDamage * vic:InsaneStats_GetAttributeValue("bleed_damagetaken")
						effectDamage = effectDamage * vic:InsaneStats_GetAttributeValue("fire_damagetaken")
						effectDamage = effectDamage * vic:InsaneStats_GetAttributeValue("freeze_damagetaken")
					end
					
					if hasElectroblast then
						vic:InsaneStats_ApplyStatusEffect("electroblast", effectDamage, 5, {amplify = true, attacker = attacker})
					else
						vic:InsaneStats_ApplyStatusEffect("cosmicurse", effectDamage, 5, {amplify = true, attacker = attacker})
					end
				end
				
				if damageTier < 5 then
					local effectDamage = damage*(attacker:InsaneStats_GetAttributeValue("repeat1s_damage")-1)
					vic:InsaneStats_ApplyStatusEffect("doom", effectDamage, 1, {amplify = true, attacker = attacker})
				end
				
				-- redamage effects
				if vic:InsaneStats_GetAttributeValue("retaliation10_damage") ~= 1 then
					if vic:InsaneStats_GetStatusEffectLevel("retaliation10_buildup") < 9 then
						vic:InsaneStats_ApplyStatusEffect("retaliation10_buildup", 1, 5, {amplify = true})
					else
						vic:InsaneStats_ClearStatusEffect("retaliation10_buildup")
						
						local scaleFactor = vic:InsaneStats_GetAttributeValue("retaliation10_damage") - 1
						local oldAttacker = attacker
						
						dmginfo:SetAttacker(vic)
						dmginfo:ScaleDamage(scaleFactor)
						oldAttacker:TakeDamageInfo(dmginfo)
						dmginfo:ScaleDamage(1/scaleFactor)
						dmginfo:SetAttacker(oldAttacker)
					end
				end
				
				if vicIsMob and notImmune and vic:GetClass() ~= "npc_turret_floor" then
					if vic.insaneStats_LastHitGroup == HITGROUP_HEAD then
						local lifeSteal = (attacker:InsaneStats_GetAttributeValue("crit_lifesteal") - 1) * attacker:InsaneStats_GetMaxHealth()
						
						if attacker:InsaneStats_GetStatusEffectLevel("bleed") > 0
						or attacker:InsaneStats_GetStatusEffectLevel("hemotoxin") > 0
						or attacker:InsaneStats_GetStatusEffectLevel("cosmicurse") > 0 then
							lifeSteal = lifeSteal / 2
						end
						
						attacker:InsaneStats_AddHealthCapped(lifeSteal)
						
						local armorSteal = (attacker:InsaneStats_GetAttributeValue("crit_armorsteal") - 1) * attacker:InsaneStats_GetMaxArmor()
						
						if attacker:InsaneStats_GetStatusEffectLevel("shock") > 0
						or attacker:InsaneStats_GetStatusEffectLevel("electroblast") > 0
						or attacker:InsaneStats_GetStatusEffectLevel("cosmicurse") > 0 then
							armorSteal = armorSteal / 2
						end
						
						attacker:InsaneStats_AddArmorNerfed(armorSteal)
						
						local stacks = (attacker:InsaneStats_GetAttributeValue("critstack_damage") - 1) * 100
						attacker:InsaneStats_ApplyStatusEffect("stack_damage_up", stacks, math.huge, {amplify = true})
						stacks = (attacker:InsaneStats_GetAttributeValue("critstack_firerate") - 1) * 100
						attacker:InsaneStats_ApplyStatusEffect("stack_firerate_up", stacks, math.huge, {amplify = true})
					end
					
					if attacker:InsaneStats_GetAttributeValue("hit100_damagepulse") ~= 1 then
						if attacker:InsaneStats_GetStatusEffectLevel("hit100_damagepulse_stacks") < 99 then
							attacker:InsaneStats_ApplyStatusEffect("hit100_damagepulse_stacks", 1, math.huge, {amplify = true})
						else
							attacker:InsaneStats_ClearStatusEffect("hit100_damagepulse_stacks")
							
							local damage = attacker:InsaneStats_GetAttributeValue("hit100_damagepulse") - 1
							local dmginfo = DamageInfo()
							dmginfo:SetAttacker(attacker)
							dmginfo:SetInflictor(attacker)
							dmginfo:SetBaseDamage(damage)
							dmginfo:SetDamage(damage)
							dmginfo:SetMaxDamage(damage)
							dmginfo:SetDamageForce(vector_origin)
							dmginfo:SetDamageType(bit.bor(DMG_SONIC, DMG_ENERGYBEAM))
							dmginfo:SetReportedPosition(attacker:WorldSpaceCenter())
							
							local traceResult = {}
							local trace = {
								start = attacker:WorldSpaceCenter(),
								filter = {attacker, attacker.GetVehicle and attacker:GetVehicle()},
								mask = MASK_SHOT,
								output = traceResult
							}
							
							for k,v in pairs(ents.FindInPVS(attacker)) do
								if attacker:InsaneStats_IsValidEnemy(v) then
									local damagePos = v:HeadTarget(attacker:WorldSpaceCenter()) or v:WorldSpaceCenter()
									damagePos = damagePos:IsZero() and v:WorldSpaceCenter() or damagePos
									trace.endpos = damagePos
									util.TraceLine(trace)
									if not traceResult.Hit or traceResult.Entity == v then
										dmginfo:SetDamagePosition(damagePos)
										v:TakeDamageInfo(dmginfo)
									end
								end
							end
							attacker:EmitSound("ambient/energy/whiteflash.wav", 100, 100, 1, CHAN_WEAPON)
						end
					end
				
					if attacker:InsaneStats_GetAttributeValue("hit100_self_damage") ~= 1 then
						if attacker:InsaneStats_GetStatusEffectLevel("hit100_selfdamage_stacks") < 99 then
							attacker:InsaneStats_ApplyStatusEffect("hit100_selfdamage_stacks", 1, 5, {amplify = true})
						else
							attacker:InsaneStats_ClearStatusEffect("hit100_selfdamage_stacks")
							
							local scaleFactor = attacker:InsaneStats_GetAttributeValue("hit100_self_damage") - 1
							dmginfo:ScaleDamage(scaleFactor)
							attacker:TakeDamageInfo(dmginfo)
							dmginfo:ScaleDamage(1/scaleFactor)
						end
					end
				
					if attacker:InsaneStats_GetAttributeValue("hit1s_damage") ~= 1 and attacker:InsaneStats_GetStatusEffectLevel("hit1s_damage_cooldown") <= 0 then
						attacker:InsaneStats_ApplyStatusEffect("hit1s_damage_cooldown", 1, 1)
					end
					if vic:InsaneStats_GetAttributeValue("hittaken1s_damagetaken") ~= 1 and vic:InsaneStats_GetStatusEffectLevel("hittaken1s_damagetaken_cooldown") <= 0 then
						vic:InsaneStats_ApplyStatusEffect("hittaken1s_damagetaken_cooldown", 1, 1)
					end
				end
			end
		end
	end
end)

hook.Add("ScaleNPCDamage", "InsaneStatsWPASS2", function(vic, hitgroup, dmginfo)
	vic.insaneStats_LastHitGroup = hitgroup
	vic.insaneStats_LastHitGroupUpdate = engine.TickCount()
end)

hook.Add("ScalePlayerDamage", "InsaneStatsWPASS2", function(vic, hitgroup, dmginfo)
	vic.insaneStats_LastHitGroup = hitgroup
	vic.insaneStats_LastHitGroupUpdate = engine.TickCount()
end)

hook.Add("EntityFireBullets", "InsaneStatsWPASS2", function(attacker, data)
	if InsaneStats:GetConVarValue("wpass2_enabled") then
		local isModified = false
		
		if math.random() + 1 < attacker:InsaneStats_GetAttributeValue("aimbot") then
			local bestNPC = NULL
			local bestCos = -1
			local traceResult = {}
			local trace = {
				start = data.Src,
				filter = {attacker, attacker.GetVehicle and attacker:GetVehicle()},
				mask = MASK_SHOT,
				output = traceResult
			}
			
			-- get every NPC who hates us / entities we hate on the map
			for k,v in pairs(entities) do
				if attacker:InsaneStats_IsValidEnemy(k) then
					local bulletDir = data.Dir
					if bulletDir:LengthSqr() ~= 1 and not bulletDir:IsZero() then
						-- normalize the direction or it will mess up our calculations
						bulletDir:Normalize()
					end
					
					local allegedHeadTarget = k:HeadTarget(data.Src) or k:WorldSpaceCenter()
					local endPos = allegedHeadTarget:IsZero() and k:WorldSpaceCenter() or allegedHeadTarget 
					local desiredDir = endPos - data.Src
					desiredDir:Normalize()
					
					local desiredCos = desiredDir:Dot(bulletDir)
					if desiredCos > bestCos then
						-- hold that thought, we need to make sure the bullet can actually travel through that direction and hit the enemy
						trace.endpos = endPos
						trace.endpos:Mul(2)
						trace.endpos:Sub(trace.start)
						util.TraceLine(trace)
						if traceResult.Entity == k then
							bestNPC = k
							bestCos = desiredCos
						end
					end
				end
			end
			
			if IsValid(bestNPC) then
				local allegedHeadTarget = bestNPC:HeadTarget(data.Src) or bestNPC:WorldSpaceCenter()
				local endPos = allegedHeadTarget:IsZero() and bestNPC:WorldSpaceCenter() or allegedHeadTarget
				data.Dir = endPos - data.Src
				data.Dir:Normalize()
				
				isModified = true
			end
		end
				
		local explodeCondition = damageTiers[#damageTiers] < 1
		local shouldExplode = math.random() < attacker:InsaneStats_GetAttributeValue("explode") - 1
		local shouldElectroblast = math.random() < attacker:InsaneStats_GetAttributeValue("electroblast") - 1
		local shouldCosmicurse = attacker:InsaneStats_GetAttributeValue("cosmicurse") > 1
		
		if explodeCondition and (shouldExplode or shouldElectroblast or shouldCosmicurse) then
			local oldCallback = data.Callback
			data.Callback = function(attacker, trace, dmginfo, ...)
				if oldCallback then
					oldCallback(attacker, trace, dmginfo, ...)
				end
				
				if trace.Hit then
					CauseDelayedDamage({
						pos = trace.HitPos,
						attacker = attacker,
						victim = trace.Entity,
						damage = dmginfo:GetDamage(),
						damageTier = 1,
						shouldExplode = shouldExplode,
						shouldElectroblast = shouldElectroblast,
						shouldCosmicurse = shouldCosmicurse
					})
				end
			end
		
			isModified = true
		end
		
		if isModified then return true end
	end
end)

hook.Add("InsaneStatsScaleXP", "InsaneStatsWPASS2", function(data)
	if InsaneStats:GetConVarValue("wpass2_enabled") then
		local attacker = data.attacker
		local victim = data.victim
		data.xp = data.xp * attacker:InsaneStats_GetAttributeValue("xp")
		
		if not victim:IsPlayer() then
			if victim:InsaneStats_IsMob() then
				if attacker:InsaneStats_IsValidAlly(victim) then
					data.xp = data.xp * attacker:InsaneStats_GetAttributeValue("ally_xp")
				end
			else -- prop
				data.xp = data.xp * (attacker:InsaneStats_GetAttributeValue("prop_xp") - 1)
			end
		end
		
		data.xp = data.xp * (1 + attacker:InsaneStats_GetStatusEffectLevel("xp_up") / 100)
		data.xp = data.xp * (1 + attacker:InsaneStats_GetStatusEffectLevel("stack_xp_up") / 100)
		
		if victim.insaneStats_LastHitGroup == HITGROUP_HEAD then
			data.xp = data.xp * attacker:InsaneStats_GetAttributeValue("crit_xp")
		end
		
		--[[data.xp = data.xp * ((attacker:InsaneStats_GetAttributeValue("simul_xp") - 1) * (attacker.insaneStats_MasterfulStacks or 0) + 1)
		attacker.insaneStats_MasterfulStacks = (attacker.insaneStats_MasterfulStacks or 0) + 1]]
		
		local masterfulXPFactor = attacker:InsaneStats_GetStatusEffectLevel("masterful_xp") * attacker:InsaneStats_GetStatusEffectDuration("masterful_xp")
		masterfulXPFactor = math.max(masterfulXPFactor - (attacker:InsaneStats_GetAttributeValue("kill1s_xp") - 1) * 100, 0)
		data.xp = data.xp * (1 + masterfulXPFactor / 100)
		
		for k,v in pairs(entities) do
			if (IsValid(k) and k:InsaneStats_GetAttributeValue("else_xp") ~= 1 and not data.receivers[k]) then
				data.receivers[k] = k:InsaneStats_GetAttributeValue("else_xp") - 1
			end
		end
	end
end)

hook.Add("InsaneStatsScaleCoins", "InsaneStatsWPASS2", function(data)
	if InsaneStats:GetConVarValue("wpass2_enabled") then
		local attacker = data.attacker
		if IsValid(attacker) then
			local victim = data.victim
			data.coins = data.coins * attacker:InsaneStats_GetAttributeValue("xp")
			
			if not victim:IsPlayer() then
				if victim:InsaneStats_IsMob() then
					if attacker:InsaneStats_IsValidAlly(victim) then
						data.coins = data.coins * attacker:InsaneStats_GetAttributeValue("ally_xp")
					end
				else -- prop
					data.coins = data.coins * attacker:InsaneStats_GetAttributeValue("prop_xp")
				end
			end
			
			data.coins = data.coins * (1 + attacker:InsaneStats_GetStatusEffectLevel("xp_up") / 100)
			data.coins = data.coins * (1 + attacker:InsaneStats_GetStatusEffectLevel("stack_xp_up") / 100)
			
			if victim.insaneStats_LastHitGroup == HITGROUP_HEAD then
				data.coins = data.coins * attacker:InsaneStats_GetAttributeValue("crit_xp")
			end
			
			local masterfulXPFactor = attacker:InsaneStats_GetStatusEffectLevel("masterful_xp") * attacker:InsaneStats_GetStatusEffectDuration("masterful_xp")
			masterfulXPFactor = math.max(masterfulXPFactor - (attacker:InsaneStats_GetAttributeValue("kill1s_xp") - 1) * 100, 0)
			data.coins = data.coins * (1 + masterfulXPFactor / 100)
		end
	end
end)

local function SpawnRandomItems(items, pos)
	if math.random() < items then
	--[[if math.random() < items%1 then
		items = math.ceil(items)
	else
		items = math.floor(items)
	end
	for i=1, items do]]
		local item = ents.Create("item_dynamic_resupply")
		item:SetKeyValue("DesiredHealth", string.format("%f", math.random()))
		item:SetKeyValue("DesiredArmor", string.format("%f", math.random()))
		item:SetKeyValue("DesiredAmmoPistol", string.format("%f", math.random()))
		item:SetKeyValue("DesiredAmmoSMG1", string.format("%f", math.random()))
		item:SetKeyValue("DesiredAmmoSMG1_Grenade", string.format("%f", math.random()))
		item:SetKeyValue("DesiredAmmoAR2", string.format("%f", math.random()))
		item:SetKeyValue("DesiredAmmoBuckshot", string.format("%f", math.random()))
		item:SetKeyValue("DesiredAmmoRPG_Round", string.format("%f", math.random()))
		-- the following is a weapon rather than an item
		-- allowing this would allow for sequence-breaking in certain campaign maps
		item:SetKeyValue("DesiredAmmoGrenade", "0.0")--string.format("%f", math.random()))
		item:SetKeyValue("DesiredAmmo357", string.format("%f", math.random()))
		item:SetKeyValue("DesiredAmmoCrossbow", string.format("%f", math.random()))
		item:SetKeyValue("DesiredAmmoAR2_AltFire", string.format("%f", math.random()))
		item:SetKeyValue("spawnflags", 8)
		item:SetPos(pos)
		item:Spawn()
		item:Fire("CalculateType")
	end
end

hook.Add("InsaneStatsEntityKilledOnce", "InsaneStatsWPASS2", function(victim, attacker, inflictor)
	if InsaneStats:GetConVarValue("wpass2_enabled") and IsValid(attacker) then
		if (attacker:IsVehicle() and attacker:IsValidVehicle() and IsValid(attacker:GetDriver())) then
			attacker = attacker:GetDriver()
		end
		
		if victim ~= attacker then
			if attacker:InsaneStats_GetHealth() < attacker:InsaneStats_GetMaxHealth() then
				local healthRestored = (attacker:InsaneStats_GetAttributeValue("kill_lifesteal") - 1) * attacker:InsaneStats_GetMaxHealth()
				if attacker:InsaneStats_GetStatusEffectLevel("bleed") > 0
				or attacker:InsaneStats_GetStatusEffectLevel("hemotoxin") > 0
				or attacker:InsaneStats_GetStatusEffectLevel("cosmicurse") > 0 then
					healthRestored = healthRestored / 2
				end
				attacker:SetHealth(math.min(attacker:InsaneStats_GetHealth() + healthRestored, attacker:InsaneStats_GetMaxHealth()))
			end
			--print(attacker:InsaneStats_GetHealth(), healthRestored, attacker:InsaneStats_GetMaxHealth())
			
			if attacker.GetMaxArmor then
				local armorRestored = (attacker:InsaneStats_GetAttributeValue("kill_armorsteal") - 1) * attacker:InsaneStats_GetMaxArmor()
				attacker:InsaneStats_AddArmorNerfed(armorRestored)
			end
			
			local wep = attacker.GetActiveWeapon and attacker:GetActiveWeapon() or NULL
			local clipSteal = attacker:InsaneStats_GetAttributeValue("kill_clipsteal") - 1
			if IsValid(wep) and clipSteal ~= 0 then
				local ammoToGive1 = wep:GetMaxClip1() * clipSteal
				local ammoToGive2 = wep:GetMaxClip2() * clipSteal
				local clip1Used = wep:GetMaxClip1() > 0
				local clip2Used = wep:GetMaxClip2() > 0
				
				local isPlayer = attacker:IsPlayer()
				if not clip1Used and isPlayer and wep:GetPrimaryAmmoType() > 0 then
					ammoToGive1 = game.GetAmmoMax(wep:GetPrimaryAmmoType()) / 5 * clipSteal
				end
				if not clip2Used and isPlayer and wep:GetSecondaryAmmoType() > 0 then
					ammoToGive2 = game.GetAmmoMax(wep:GetSecondaryAmmoType()) / 5 * clipSteal
				end
				
				ammoToGive1 = ((math.random() < ammoToGive1 % 1) and math.ceil or math.floor)(ammoToGive1)
				ammoToGive2 = ((math.random() < ammoToGive2 % 1) and math.ceil or math.floor)(ammoToGive2)
				
				if clip1Used then
					wep:SetClip1(wep:Clip1()+ammoToGive1)
				elseif isPlayer then
					attacker:GiveAmmo(ammoToGive1, wep:GetPrimaryAmmoType())
				end
				
				if clip2Used then
					wep:SetClip2(wep:Clip2()+ammoToGive2)
				elseif isPlayer then
					attacker:GiveAmmo(ammoToGive2, wep:GetSecondaryAmmoType())
				end
			end
			
			local stacks = (attacker:InsaneStats_GetAttributeValue("killstack_damage") - 1) * 100
			attacker:InsaneStats_ApplyStatusEffect("stack_damage_up", stacks, math.huge, {amplify = true})
			stacks = (attacker:InsaneStats_GetAttributeValue("killstack_defence") - 1) * 100
			attacker:InsaneStats_ApplyStatusEffect("stack_defence_up", stacks, math.huge, {amplify = true})
			--[[stacks = (attacker:InsaneStats_GetAttributeValue("killstack_speed") - 1) * 100
			attacker:InsaneStats_ApplyStatusEffect("stack_speed_up", stacks, math.huge, {amplify = true})]]
			stacks = (attacker:InsaneStats_GetAttributeValue("killstack_xp") - 1) * 100
			attacker:InsaneStats_ApplyStatusEffect("stack_xp_up", stacks, math.huge, {amplify = true})
			stacks = (attacker:InsaneStats_GetAttributeValue("killstack_firerate") - 1) * 100
			attacker:InsaneStats_ApplyStatusEffect("stack_firerate_up", stacks, math.huge, {amplify = true})
			
			
			stacks = (attacker:InsaneStats_GetAttributeValue("kill5s_damage") - 1) * 100
			--[[if stacks < 0 then
				attacker:InsaneStats_ApplyStatusEffect("damage_down", -stacks, 5, {extend = true})
			else]]
				attacker:InsaneStats_ApplyStatusEffect("damage_up", stacks, 5, {extend = true})
			--end
			
			stacks = (1 / attacker:InsaneStats_GetAttributeValue("kill5s_damagetaken") - 1) * 100
			attacker:InsaneStats_ApplyStatusEffect("defence_up", stacks, 5, {extend = true})
			
			stacks = (attacker:InsaneStats_GetAttributeValue("kill5s_firerate") - 1) * 100
			attacker:InsaneStats_ApplyStatusEffect("firerate_up", stacks, 5, {extend = true})
			
			stacks = (attacker:InsaneStats_GetAttributeValue("kill5s_xp") - 1) * 100
			attacker:InsaneStats_ApplyStatusEffect("xp_up", stacks, 5, {extend = true})
			
			stacks = (attacker:InsaneStats_GetAttributeValue("kill5s_speed") - 1) * 100
			attacker:InsaneStats_ApplyStatusEffect("speed_up", stacks, 5, {extend = true})
			
			stacks = (attacker:InsaneStats_GetAttributeValue("kill5s_regen") - 1) * 100
			attacker:InsaneStats_ApplyStatusEffect("regen", stacks, 5, {extend = true})
			
			stacks = (attacker:InsaneStats_GetAttributeValue("kill5s_armorregen") - 1) * 100
			attacker:InsaneStats_ApplyStatusEffect("armor_regen", stacks, 5, {extend = true})
			
			stacks = attacker:InsaneStats_GetAttributeValue("kill5s_damageaura") - 1
			attacker:InsaneStats_ApplyStatusEffect("damage_aura", stacks, 5, {extend = true})
			
			local duration = attacker:InsaneStats_GetAttributeValue("starlight") - 1
			attacker:InsaneStats_ApplyStatusEffect("starlight", 1, duration, {extend = true})
			
			if attacker:InsaneStats_IsValidAlly(victim) then
				stacks = (1 - attacker:InsaneStats_GetAttributeValue("kill5s_ally_damage")) * 100
				attacker:InsaneStats_ApplyStatusEffect("damage_down", stacks, 5, {extend = true})
			end
			
			if attacker.insaneStats_MarkedEntity == victim then
				stacks = (attacker:InsaneStats_GetAttributeValue("killstackmarked_damage") - 1) * 100
				attacker:InsaneStats_ApplyStatusEffect("stack_damage_up", stacks, math.huge, {amplify = true})
				stacks = (attacker:InsaneStats_GetAttributeValue("killstackmarked_defence") - 1) * 100
				attacker:InsaneStats_ApplyStatusEffect("stack_defence_up", stacks, math.huge, {amplify = true})
			end
			
			SpawnRandomItems(attacker:InsaneStats_GetAttributeValue("kill_supplychance") - 1, victim:WorldSpaceCenter())
			
			stacks = (attacker:InsaneStats_GetAttributeValue("kill1s_xp") - 1) * 100
			attacker:InsaneStats_ApplyStatusEffect("masterful_xp", stacks, 1, {extend = true})
		end
	end
end)

local function AttemptDupeEntity(ply, item)
	if InsaneStats:GetConVarValue("wpass2_enabled") then
		local itemHasNoModifiers = not item:InsaneStats_IsWPASS2Pickup() or item.insaneStats_Tier == 0
		local ignoreWPASS2Pickup = (item.insaneStats_DisableWPASS2Pickup or 0) > RealTime()
		local itemPickupCooldownElapsed = (item.insaneStats_NextPickup or 0) < CurTime()
		
		if itemPickupCooldownElapsed then
			if not item.insaneStats_Duplicated and itemHasNoModifiers and ply:InsaneStats_GetAttributeValue("copying") ~= 1 then
				item.insaneStats_Duplicated = true
				
				local duplicates = ply:InsaneStats_GetAttributeValue("copying") - 1
				if math.random() < duplicates % 1 then
					duplicates = math.ceil(duplicates)
				else
					duplicates = math.floor(duplicates)
				end
				
				for i=1,duplicates do
					local itemDuplicate = ents.Create(item:GetClass())
					itemDuplicate.insaneStats_Duplicated = true
					itemDuplicate:SetPos(item:GetPos())
					itemDuplicate:SetAngles(item:GetAngles())
					if item:GetClass() == "item_grubnugget" then
						itemDuplicate:SetSaveValue("m_nDenomination", item:GetInternalVariable("m_nDenomination"))
					end
					itemDuplicate.insaneStats_StartTier = 0
					itemDuplicate:Spawn()
				end
			end
			
			if item:GetClass() == "item_battery" and ply:InsaneStats_GetAttributeValue("armor_fullpickup") ~= 1 then
				local shouldAutoPickup = true
				local autoPickup = ply:GetInfoNum("insanestats_wpass2_autopickup_battery_override", -1) or -1
				if autoPickup < 0 then
					autoPickup = InsaneStats:GetConVarValueDefaulted("wpass2_autopickup_battery", "wpass2_autopickup")
				end
				if autoPickup == 0 then shouldAutoPickup = false end

				local newTier = item.insaneStats_Tier or 0
				if newTier ~= 0 then
					if autoPickup == 1 then shouldAutoPickup = false end 
					local currentTier = ply.insaneStats_Tier or 0
					if newTier > currentTier and autoPickup < 6 then shouldAutoPickup = false
					elseif newTier == currentTier and autoPickup < 4 then shouldAutoPickup = false
					end
				end
				if shouldAutoPickup or ignoreWPASS2Pickup then
					local expectedArmor = GetConVar("sk_battery"):GetFloat() * (ply.insaneStats_CurrentArmorAdd or 1)

					if ply:InsaneStats_GetArmor() + expectedArmor > ply:InsaneStats_GetMaxArmor() then
						if ply:InsaneStats_GetArmor() < ply:InsaneStats_GetMaxArmor() then
							expectedArmor = expectedArmor + ply:InsaneStats_GetArmor() - ply:InsaneStats_GetMaxArmor()
							ply:SetArmor(ply:InsaneStats_GetMaxArmor())
						end
						
						expectedArmor = expectedArmor * ply:InsaneStats_GetAttributeValue("armor_fullpickup")
						
						if ply:InsaneStats_GetStatusEffectLevel("shock") > 0
						or ply:InsaneStats_GetStatusEffectLevel("electroblast") > 0
						or ply:InsaneStats_GetStatusEffectLevel("cosmicurse") > 0 then
							expectedArmor = expectedArmor / 2
						end
						
						ply:InsaneStats_AddArmorNerfed(expectedArmor)
						
						ply:EmitSound("ItemBattery.Touch")
						net.Start("insane_stats")
						net.WriteUInt(2, 8)
						net.WriteString("item_battery")
						net.Send(ply)
						item:Remove()
						
						return false
					end
				end
			end
		end
	end
end

hook.Add("InsaneStatsPlayerCanPickupItem", "InsaneStatsWPASS2", AttemptDupeEntity)
hook.Add("InsaneStatsPlayerCanPickupWeapon", "InsaneStatsWPASS2", AttemptDupeEntity)

hook.Add("InsaneStatsArmorBatteryChanged", "InsaneStatsWPASS2", function(ent, item)
	item.insaneStats_Duplicated = true
end)

local notAppliedForNonNPCs = bit.bor(DMG_SLOWBURN, DMG_NERVEGAS)
local function CauseStatusEffectDamage(data)
	local stat = data.stat
	for i, victim in ipairs(InsaneStats:GetEntitiesByStatusEffect(stat)) do
		local statLevel = victim:InsaneStats_GetStatusEffectLevel(stat)
		if victim:InsaneStats_GetHealth() > 0 then
			local damageType = bit.bor(data.damageType, DMG_PREVENT_PHYSICS_FORCE)
			if not victim:IsNPC() then
				damageType = bit.band(damageType, bit.bnot(notAppliedForNonNPCs))
			end
			--print(stat, statLevel)
			table.insert(damageTiers, 4)
			--PrintTable(data)
			local attacker = victim:InsaneStats_GetStatusEffectAttacker(stat)
			if not IsValid(attacker) then
				attacker = victim
			end
			local damage = statLevel / 5
			
			local dmginfo = DamageInfo()
			dmginfo:SetAmmoType(data.ammoType or -1)
			dmginfo:SetAttacker(attacker)
			dmginfo:SetBaseDamage(damage)
			dmginfo:SetDamage(damage)
			dmginfo:SetDamageForce(vector_origin)
			dmginfo:SetDamagePosition(victim:WorldSpaceCenter())
			dmginfo:SetDamageType(damageType)
			dmginfo:SetInflictor(attacker)
			dmginfo:SetMaxDamage(damage)
			dmginfo:SetReportedPosition(attacker:WorldSpaceCenter())
			victim:TakeDamageInfo(dmginfo)
			
			table.remove(damageTiers)
		end
	end
end

local tickIndex = 0
local timerResolution = 0.2
local decayRate = 0.99^timerResolution
timer.Create("InsaneStatsWPASS2", timerResolution, 0, function()
	if InsaneStats:GetConVarValue("wpass2_enabled") then
		local startTime = SysTime()
		local timeIndex = {0, 0, 0, 0}
		local tempTimeStart
		
		tickIndex = (tickIndex + 1) % 5
		tempTimeStart = SysTime()
		
		-- for marking modifier
		local entitiesNeedMarkingEntities = {}
		for k,v in pairs(rapidThinkEntities) do
			if (IsValid(k) and k:InsaneStats_GetAttributeValue("mark") > 1) then
				k.insaneStats_MarkedEntity = nil
				entitiesNeedMarkingEntities[k] = true
			end
		end
		
		timeIndex[2] = SysTime() - tempTimeStart
		tempTimeStart = SysTime()
		
		-- get all entities with regen
		local regenAmounts = {}
		for i,v in ipairs(InsaneStats:GetEntitiesByStatusEffect("regen")) do
			regenAmounts[v] = v:InsaneStats_GetStatusEffectLevel("regen")
		end
		for i,v in ipairs(InsaneStats:GetEntitiesByStatusEffect("hittaken_regen")) do
			regenAmounts[v] = (regenAmounts[v] or 0) + v:InsaneStats_GetStatusEffectLevel("hittaken_regen")
		end
		for k,v in pairs(regenAmounts) do
			local healthRestored = v / 100 * k:InsaneStats_GetMaxHealth() * timerResolution
			
			if k:InsaneStats_GetStatusEffectLevel("bleed") > 0
			or k:InsaneStats_GetStatusEffectLevel("hemotoxin") > 0
			or k:InsaneStats_GetStatusEffectLevel("cosmicurse") > 0 then
				healthRestored = healthRestored / 2
			end
			
			k:InsaneStats_AddHealthCapped(healthRestored)
		end
		
		-- get all entities with armor regen
		regenAmounts = {}
		for i,v in ipairs(InsaneStats:GetEntitiesByStatusEffect("armor_regen")) do
			regenAmounts[v] = v:InsaneStats_GetStatusEffectLevel("armor_regen")
		end
		for i,v in ipairs(InsaneStats:GetEntitiesByStatusEffect("hittaken_armorregen")) do
			regenAmounts[v] = (regenAmounts[v] or 0) + v:InsaneStats_GetStatusEffectLevel("hittaken_armorregen")
		end
		for k,v in pairs(regenAmounts) do
			local armorRestored = v / 100 * k:InsaneStats_GetMaxArmor() * timerResolution
			
			if k:InsaneStats_GetStatusEffectLevel("shock") > 0
			or k:InsaneStats_GetStatusEffectLevel("electroblast") > 0
			or k:InsaneStats_GetStatusEffectLevel("cosmicurse") > 0 then
				armorRestored = armorRestored / 2
			end
			
			k:InsaneStats_AddArmorNerfed(armorRestored)
		end
		
		for i,v in ipairs(InsaneStats:GetEntitiesByStatusEffect("stack_damage_up")) do
			v:InsaneStats_SetStatusEffectLevel("stack_damage_up", v:InsaneStats_GetStatusEffectLevel("stack_damage_up") * decayRate)
		end
		for i,v in ipairs(InsaneStats:GetEntitiesByStatusEffect("stack_defence_up")) do
			v:InsaneStats_SetStatusEffectLevel("stack_defence_up", v:InsaneStats_GetStatusEffectLevel("stack_defence_up") * decayRate)
		end
		for i,v in ipairs(InsaneStats:GetEntitiesByStatusEffect("stack_xp_up")) do
			v:InsaneStats_SetStatusEffectLevel("stack_xp_up", v:InsaneStats_GetStatusEffectLevel("stack_xp_up") * decayRate)
		end
		for i,v in ipairs(InsaneStats:GetEntitiesByStatusEffect("stack_firerate_up")) do
			v:InsaneStats_SetStatusEffectLevel("stack_firerate_up", v:InsaneStats_GetStatusEffectLevel("stack_firerate_up") * decayRate)
		end
		for i,v in ipairs(InsaneStats:GetEntitiesByStatusEffect("starlight")) do
			local radius = math.sqrt(v:InsaneStats_GetStatusEffectDuration("starlight")) * 32
			if v:InsaneStats_GetStatusEffectLevel("invisibility") > 0 then
				radius = 0
			end
			--[[local brightness = math.max(radius / 2048 - 1, 0)
			radius = math.min(radius, 2048)]]
			if not IsValid(v.insaneStats_Starlight) then
				-- we probably have just lost the pointer to it
				for i,v2 in ipairs(v:GetChildren()) do
					if v2.insaneStats_IsStarlight then
						v.insaneStats_Starlight = v2
					end
				end
			end
			if not IsValid(v.insaneStats_Starlight) then
				local light = ents.Create("light_dynamic")
				light:SetPos(v:WorldSpaceCenter())
				light:SetParent(v)
				light:SetKeyValue("_light", "255 255 255")
				light:SetKeyValue("style", "12")
				light:Spawn()
				light.insaneStats_IsStarlight = true
				v.insaneStats_Starlight = light
			end
			--v.insaneStats_Starlight:Fire("brightness", brightness)
			v.insaneStats_Starlight:Fire("distance", radius)
		end
		
		if tickIndex == 0 then
			CauseStatusEffectDamage({
				stat = "poison",
				damageType = DMG_NERVEGAS
			})
			CauseStatusEffectDamage({
				stat = "hemotoxin",
				damageType = bit.bor(DMG_NERVEGAS, DMG_SLASH)
			})
			CauseStatusEffectDamage({
				stat = "cosmicurse",
				ammoType = 8,
				damageType = bit.bor(DMG_SLASH, DMG_SLOWBURN, DMG_BLAST, DMG_NERVEGAS, DMG_SONIC, DMG_VEHICLE, DMG_SHOCK, DMG_ENERGYBEAM)
			})
		
			tempTimeStart = SysTime()
			
			for k,v in pairs(entities) do
				if not (IsValid(k) and (k:GetModel() or "") ~= "") then
					entities[k] = nil
				end
			end
			
			for k,v in pairs(rapidThinkEntities) do
				if not IsValid(k) then
					rapidThinkEntities[k] = nil
				end
			end
			
			timeIndex[4] = SysTime() - tempTimeStart
		elseif tickIndex == 1 then
			CauseStatusEffectDamage({
				stat = "bleed",
				damageType = DMG_SLASH
			})
			
			for i,v in ipairs(InsaneStats:GetEntitiesByStatusEffect("damage_aura")) do
				local damage = v:InsaneStats_GetStatusEffectLevel("damage_aura")
				local dmginfo = DamageInfo()
				dmginfo:SetAttacker(v)
				dmginfo:SetInflictor(v)
				dmginfo:SetBaseDamage(damage)
				dmginfo:SetDamage(damage)
				dmginfo:SetMaxDamage(damage)
				dmginfo:SetDamageForce(vector_origin)
				dmginfo:SetDamageType(bit.bor(DMG_ENERGYBEAM, DMG_PREVENT_PHYSICS_FORCE))
				dmginfo:SetReportedPosition(v:WorldSpaceCenter())
				
				local traceResult = {}
				local trace = {
					start = v:WorldSpaceCenter(),
					filter = {v, v.GetVehicle and v:GetVehicle()},
					mask = MASK_SHOT,
					output = traceResult
				}
				
				for k2,v2 in pairs(ents.FindInSphere(v:WorldSpaceCenter(), 512)) do
					if v:InsaneStats_IsValidEnemy(v2) then
						local damagePos = v2:HeadTarget(v:WorldSpaceCenter()) or v2:WorldSpaceCenter()
						damagePos = damagePos:IsZero() and v2:WorldSpaceCenter() or damagePos
						trace.endpos = damagePos
						util.TraceLine(trace)
						if not traceResult.Hit or traceResult.Entity == v2 then
							dmginfo:SetDamagePosition(damagePos)
							v2:TakeDamageInfo(dmginfo)
						end
					end
				end
			end
		elseif tickIndex == 2 then
			CauseStatusEffectDamage({
				stat = "fire",
				ammoType = 8,
				damageType = DMG_SLOWBURN
			})
			CauseStatusEffectDamage({
				stat = "frostfire",
				damageType = bit.bor(DMG_SLOWBURN, DMG_VEHICLE)
			})
		elseif tickIndex == 3 then
			CauseStatusEffectDamage({
				stat = "freeze",
				damageType = DMG_VEHICLE
			})
		elseif tickIndex == 4 then
			CauseStatusEffectDamage({
				stat = "shock",
				ammoType = 17,
				damageType = DMG_SHOCK
			})
			CauseStatusEffectDamage({
				stat = "electroblast",
				ammoType = 8,
				damageType = bit.bor(DMG_SHOCK, DMG_BLAST)
			})
		end
		
		timeIndex[1] = SysTime() - tempTimeStart
		
		for k,v in pairs(rapidThinkEntities) do
			if IsValid(k) then
				tempTimeStart = SysTime()
				
				for k2,v2 in pairs(entitiesNeedMarkingEntities) do
					if k2:InsaneStats_IsValidEnemy(k) then
						local thisEnemyDistance = k:WorldSpaceCenter():DistToSqr(k2:WorldSpaceCenter())
						local thatEnemyDistance = IsValid(k2.insaneStats_MarkedEntity) and k2.insaneStats_MarkedEntity:WorldSpaceCenter():DistToSqr(k2:WorldSpaceCenter()) or math.huge
						
						if thisEnemyDistance < thatEnemyDistance then
							k2.insaneStats_MarkedEntity = k
						end
					end
				end
				
				timeIndex[2] = timeIndex[2] + SysTime() - tempTimeStart
				tempTimeStart = SysTime()
			
				if k:InsaneStats_GetAttributeValue("toggle_damage") ~= 1
				and k:InsaneStats_GetStatusEffectLevel("arcane_defence_up") > 0
				and k:InsaneStats_GetStatusEffectLevel("arcane_damage_up") > 0 then
					local stacks = (k:InsaneStats_GetAttributeValue("toggle_damage")-1)*100
					k:InsaneStats_ApplyStatusEffect(math.random() < 0.5 and "arcane_defence_up" or "arcane_damage_up", stacks, 5)
				end
				if k.insaneStats_HoldingCtrl then
					local stacks = (k:InsaneStats_GetAttributeValue("ctrl_gamespeed") - 1) * 100 * timerResolution
					if stacks ~= 0 then
						k:InsaneStats_ApplyStatusEffect("ctrl_gamespeed_up", stacks, math.huge, {amplify = true})
					end
					stacks = (k:InsaneStats_GetAttributeValue("ctrl_damage") - 1) * 100 * timerResolution
					if stacks ~= 0 then
						k:InsaneStats_ApplyStatusEffect("ctrl_damage_up", stacks, math.huge, {amplify = true})
					end
				else
					k:InsaneStats_ClearStatusEffect("ctrl_gamespeed_up")
					k:InsaneStats_ClearStatusEffect("ctrl_damage_up")
				end
				
				timeIndex[3] = timeIndex[3] + SysTime() - tempTimeStart
			end
		end
		
		tempTimeStart = SysTime()
		
		for k,v in pairs(entitiesNeedMarkingEntities) do
			if IsValid(k.insaneStats_MarkedEntity) then 
				local ent = k.insaneStats_MarkedEntity
				if k:IsPlayer() then
					local pos = ent:HeadTarget(k:WorldSpaceCenter()) or ent:WorldSpaceCenter()
					pos = pos:IsZero() and ent:WorldSpaceCenter() or pos
					-- send a net message about the current entity
					net.Start("insane_stats", true)
					net.WriteUInt(4, 8)
					net.WriteUInt(ent:EntIndex(), 16)
					net.WriteVector(pos)
					net.WriteString(ent:GetClass())
					net.WriteDouble(ent:InsaneStats_GetHealth())
					net.WriteDouble(ent:InsaneStats_GetMaxHealth())
					net.WriteDouble(ent:InsaneStats_GetArmor())
					net.WriteDouble(ent:InsaneStats_GetMaxArmor())
					net.Send(k)
				elseif (k:IsNPC() and k:Disposition(ent) == D_HT and k:HasEnemyEluded(ent)) then
					-- update the NPC's memory about the current entity's location
					--print("NPC:UpdateEnemyMemory", ent, ent:WorldSpaceCenter())
					k:UpdateEnemyMemory(ent, ent:WorldSpaceCenter())
				end
			end
		end
		
		timeIndex[2] = timeIndex[2] + SysTime() - tempTimeStart
		
		local delay = SysTime() - startTime
		if delay > 0.01 then
			InsaneStats:Log("WARNING: WPASS2 attribute timer at tick index "..tickIndex.." is taking "..(delay*1000-10).."ms more than expected!")
			InsaneStats:Log("Time breakdown:")
			InsaneStats:Log("1: "..(timeIndex[1]*1000).."ms")
			InsaneStats:Log("2: "..(timeIndex[2]*1000).."ms")
			InsaneStats:Log("3: "..(timeIndex[3]*1000).."ms")
			InsaneStats:Log("4: "..(timeIndex[4]*1000).."ms")
		end
	end
end)

hook.Add("InsaneStatsWPASS2AttributesChanged", "InsaneStatsWPASS2", function(ent)
	local oldHealthMul = ent.insaneStats_WPASS2HealthMul or 1
	local oldArmorMul = ent.insaneStats_WPASS2ArmorMul or 1
	
	local newHealthMul = ent:InsaneStats_GetAttributeValue("health")
	local newArmorMul = ent:InsaneStats_GetAttributeValue("armor")
	
	local entNewMaxHealth = ent:InsaneStats_GetMaxHealth() * newHealthMul / oldHealthMul
	local entNewHealth = ent:InsaneStats_GetHealth() * newHealthMul / oldHealthMul
	local entNewMaxArmor = ent:InsaneStats_GetMaxArmor() * newArmorMul / oldArmorMul
	local entNewArmor = ent:InsaneStats_GetArmor() * newArmorMul / oldArmorMul
	
	ent:SetMaxHealth(entNewMaxHealth)
	ent:SetHealth(entNewHealth)
	if ent.SetArmor then
		ent:SetMaxArmor(entNewMaxArmor)
		ent:SetArmor(entNewArmor)
	end
	
	ent.insaneStats_WPASS2HealthMul = newHealthMul
	ent.insaneStats_WPASS2ArmorMul = newArmorMul
end)

hook.Add("InsaneStatsEntityCreated", "InsaneStatsWPASS2", function(ent)
	if InsaneStats:GetConVarValue("wpass2_enabled") then
		-- if a gib gets set on fire by an explosion, extinguish it
		local parent = ent:GetParent()
		if (ent:GetClass() == "entityflame" or ent:GetClass() == "env_entity_igniter") then
			--print("Something is on fire...", parent, IsValid(parent) and parent:GetCollisionGroup())
			if (IsValid(parent) and parent:GetCollisionGroup() == COLLISION_GROUP_DEBRIS and IsValid(parent.insaneStats_LastAttacker)) then
				parent:Extinguish()
			end
		end
	end

	entities[ent] = true
	if ent:InsaneStats_IsMob() then
		rapidThinkEntities[ent] = true
	end
	if IsValid(ent.insaneStats_Starlight) then
		ent.insaneStats_Starlight:Remove()
	end
	if ent:GetClass() == "momentary_rot_button" then
		ent:Fire("AddOutput", "Position !self:InsaneStatsInteraction::0:-1")
	end
	ent:InsaneStats_ClearAllStatusEffects()
end)

hook.Add("AcceptInput", "InsaneStatsWPASS2", function(ent, input, activator, caller, value)
	if input == "InsaneStatsInteraction" then
		ent:SetNW2Float("insanestats_progress", tonumber(value) or 0)
	end
end)

hook.Add("PlayerSpawn", "InsaneStatsWPASS2", function(ply, fromTransition)
	entities[ply] = true
	rapidThinkEntities[ply] = true
	if IsValid(ply.insaneStats_Starlight) then
		ply.insaneStats_Starlight:Remove()
	end
	if InsaneStats:GetConVarValue("wpass2_enabled") then
		if fromTransition then
			ply:InsaneStats_ClearAllStatusEffects()
		else
			ply:InsaneStats_ClearStatusEffectsByType(-1)
			ply:InsaneStats_ClearStatusEffectsByType(1)
			ply:SetLadderClimbSpeed(200)
		
			ply.insaneStats_WPASS2HealthMul = 1
			ply.insaneStats_WPASS2ArmorMul = 1
		end
		
		ply.insaneStats_OldMoveMul = 1
		ply.insaneStats_OldSprintMoveMul = 1
		ply.insaneStats_OldCrouchedMoveMul = 1
		
		if ply:InsaneStats_GetStatusEffectLevel("invisibility") > 0 then
			ply:AddFlags(FL_NOTARGET)
			ply:RemoveFlags(FL_AIMTARGET)
			ply:AddEffects(bit.bor(EF_NOSHADOW, EF_NODRAW, EF_NORECEIVESHADOW))
		end

		timer.Simple(1, function()
			if (IsValid(ply) and ply:InsaneStats_GetStatusEffectLevel("starlight") <= 0) then
				for i,v in ipairs(ply:GetChildren()) do
					if v.insaneStats_IsStarlight then
						SafeRemoveEntity(v)
					end
				end
			end
		end)
	end
end)

hook.Add("PlayerUse", "InsaneStatsWPASS2", function(ply, ent)
	if InsaneStats:GetConVarValue("wpass2_enabled") then
		if (ent:GetClass() == "item_suitcharger" or ent:GetClass() == "func_recharge")
		and ply:InsaneStats_GetAttributeValue("charger_fullpickup") ~= 1
		and ply:InsaneStats_GetArmor() >= ply:InsaneStats_GetMaxArmor() then
			local armorToAdd = ent:GetInternalVariable("m_iJuice")
			* ply:InsaneStats_GetAttributeValue("charger_fullpickup")
			* (ply.insaneStats_CurrentArmorAdd or 1)
			
			if ent:HasSpawnFlags(8192) then
				ply:SetHealth(ply:InsaneStats_GetHealth() + armorToAdd/2)
			end
				
			if ply:InsaneStats_GetStatusEffectLevel("shock") > 0
			or ply:InsaneStats_GetStatusEffectLevel("electroblast") > 0
			or ply:InsaneStats_GetStatusEffectLevel("cosmicurse") > 0 then
				armorToAdd = armorToAdd / 2
			end
			
			ply:InsaneStats_AddArmorNerfed(armorToAdd)
			
			ent:SetSaveValue("m_iJuice",0)
		end
	end
end)

hook.Add("Think", "InsaneStatsWPASS2", function()
	if InsaneStats:GetConVarValue("wpass2_enabled") then
		totalDamageTicks = 0
		explosionCount = 0
		
		game.SetTimeScale(game.GetTimeScale() * (InsaneStats.totalTimeDilation or 1))
		InsaneStats.totalTimeDilation = 1
		
		for k,v in pairs(rapidThinkEntities) do
			if IsValid(k) then
				local wep = k.GetActiveWeapon and k:GetActiveWeapon()
				
				if k:IsPlayer() or k:IsNextBot() then
					-- NPCs can't have their speeds changed, I've tried
					k.insaneStats_OldMoveMul = k.insaneStats_OldMoveMul or 1
					k.insaneStats_OldSprintMoveMul = k.insaneStats_OldSprintMoveMul or 1
					k.insaneStats_OldCrouchedMoveMul = k.insaneStats_OldCrouchedMoveMul or 1
					local data = {ent = k, speed = 1, sprintSpeed = 1, crouchedSpeed = 1}
					hook.Run("InsaneStatsMoveSpeed", data)
					local newMoveSpeed = data.speed
					local newSprintSpeed = data.sprintSpeed
					local newCrouchedSpeed = data.crouchedSpeed
					if k.insaneStats_OldMoveMul ~= newMoveSpeed
					or k.insaneStats_OldSprintMoveMul ~= newSprintSpeed
					or k.insaneStats_OldCrouchedMoveMul ~= newCrouchedSpeed then
						local applyMul = newMoveSpeed / k.insaneStats_OldMoveMul
						local sprintApplyMul = applyMul * newSprintSpeed / k.insaneStats_OldSprintMoveMul
						local crouchedApplyMul = newCrouchedSpeed / k.insaneStats_OldCrouchedMoveMul
						if k:IsPlayer() then
							if InsaneStats:GetConVarValue("wpass2_attributes_player_constant_speed") then
								local runSpeed = 400*newMoveSpeed*newSprintSpeed
								local walkSpeed = 200*newMoveSpeed
								local slowWalkSpeed = 100*math.sqrt(newMoveSpeed)
								local crouchSpeed = 0.3*newCrouchedSpeed

								k:SetLadderClimbSpeed(walkSpeed)
								k:SetMaxSpeed(walkSpeed)
								k:SetRunSpeed(runSpeed)
								k:SetWalkSpeed(walkSpeed)
								k:SetSlowWalkSpeed(slowWalkSpeed)
								k:SetCrouchedWalkSpeed(crouchSpeed)
								k:SetDuckSpeed(crouchSpeed)
								k:SetUnDuckSpeed(crouchSpeed)
							else
								k:SetLadderClimbSpeed(k:GetLadderClimbSpeed()*applyMul)
								k:SetMaxSpeed(k:GetMaxSpeed()*applyMul)
								k:SetRunSpeed(k:GetRunSpeed()*sprintApplyMul)
								k:SetWalkSpeed(k:GetWalkSpeed()*applyMul)
								k:SetSlowWalkSpeed(k:GetSlowWalkSpeed()*math.sqrt(applyMul))
								k:SetCrouchedWalkSpeed(k:GetCrouchedWalkSpeed()*crouchedApplyMul)
								k:SetDuckSpeed(k:GetDuckSpeed()*crouchedApplyMul)
								k:SetUnDuckSpeed(k:GetUnDuckSpeed()*crouchedApplyMul)
							end
						elseif SERVER and k:IsNextBot() then
							k.loco:SetDesiredSpeed(k.loco:GetDesiredSpeed()*applyMul)
						end
						
						k.insaneStats_OldMoveMul = newMoveSpeed
						k.insaneStats_OldSprintMoveMul = newSprintSpeed
						k.insaneStats_OldCrouchedMoveMul = newCrouchedSpeed
					end
					
					if k:IsPlayer() then
						-- there are two particular non-Lua weapons - weapon_grenade and weapon_rpg - that don't have unlimited ammo + don't use clips.
						k.insaneStats_LastWeapon = k.insaneStats_LastWeapon or wep
						if k.insaneStats_LastWeapon == wep and (IsValid(wep) and not wep:IsScripted()) then
							if wep:Clip1() <= 0 then
								local ammoType = wep:GetPrimaryAmmoType()
								local count = k:GetAmmoCount(ammoType)
								k.insaneStats_LastPrimaryAmmo = k.insaneStats_LastPrimaryAmmo or count
								if k.insaneStats_LastPrimaryAmmo ~= count then
									-- FIXME: wouldn't it be easier to just call the relevant hook???
									k.insaneStats_OldSetAmmoValue = k.insaneStats_LastPrimaryAmmo
									k:SetAmmo(count, ammoType)
									k.insaneStats_LastPrimaryAmmo = k:GetAmmoCount(ammoType)
									k.insaneStats_OldSetAmmoValue = nil
								end
							else
								k.insaneStats_LastPrimaryAmmo = nil
							end
							if wep:Clip2() <= 0 then
								local ammoType = wep:GetSecondaryAmmoType()
								local count = k:GetAmmoCount(ammoType)
								k.insaneStats_LastSecondaryAmmo = k.insaneStats_LastSecondaryAmmo or count
								if k.insaneStats_LastSecondaryAmmo ~= count then
									k.insaneStats_OldSetAmmoValue = k.insaneStats_LastSecondaryAmmo
									k:SetAmmo(count, ammoType)
									k.insaneStats_LastSecondaryAmmo = k:GetAmmoCount(ammoType)
									k.insaneStats_OldSetAmmoValue = nil
								end
							else
								k.insaneStats_LastSecondaryAmmo = nil
							end
						else
							k.insaneStats_LastPrimaryAmmo = nil
							k.insaneStats_LastSecondaryAmmo = nil
						end
						k.insaneStats_LastWeapon = wep

						-- check for aux drain rate
						local drainRate = k:InsaneStats_GetAttributeValue("aux_drain")
						if drainRate ~= 1 then
							local suitPower = k:GetSuitPower()
							k.insaneStats_LastSuitPower = k.insaneStats_LastSuitPower or suitPower
							if suitPower < k.insaneStats_LastSuitPower and math.random() >= drainRate then
								k:SetSuitPower(k.insaneStats_LastSuitPower)
							else
								k.insaneStats_LastSuitPower = suitPower
							end
						end
					end
				end
				
				if k:InsaneStats_GetAttributeValue("bloodletting") ~= 1 and k.SetArmor then
					local minimumHealth = k:InsaneStats_GetMaxHealth() * k:InsaneStats_GetAttributeValue("bloodletting")
					local lostHealth = math.ceil(k:InsaneStats_GetHealth() - minimumHealth)
					local armorMul = 1

					if k:InsaneStats_GetStatusEffectLevel("shock") > 0
					or k:InsaneStats_GetStatusEffectLevel("electroblast") > 0
					or k:InsaneStats_GetStatusEffectLevel("cosmicurse") > 0 then
						armorMul = armorMul / 2
					end
					
					if lostHealth > 0 then
						k:InsaneStats_AddArmorNerfed(lostHealth * armorMul)
						if lostHealth < math.huge then
							k:SetHealth(k:InsaneStats_GetHealth() - lostHealth)
						end
					end
				end
				
				if (IsValid(wep) and not wep:IsScripted()) then
					wep.insaneStats_LastPrimaryFire = wep.insaneStats_LastPrimaryFire or wep:GetNextPrimaryFire()
					if wep.insaneStats_LastPrimaryFire ~= wep:GetNextPrimaryFire() then
						wep:SetNextPrimaryFire(wep:GetNextPrimaryFire())
						wep.insaneStats_LastPrimaryFire = wep:GetNextPrimaryFire()
					end
					
					wep.insaneStats_LastSecondaryFire = wep.insaneStats_LastSecondaryFire or wep:GetNextSecondaryFire()
					if wep.insaneStats_LastSecondaryFire ~= wep:GetNextSecondaryFire() then
						wep:SetNextSecondaryFire(wep:GetNextSecondaryFire())
						wep.insaneStats_LastSecondaryFire = wep:GetNextSecondaryFire()
					end
					
					wep.insaneStats_LastClip1 = wep.insaneStats_LastClip1 or wep:Clip1()
					if wep.insaneStats_LastClip1 ~= wep:Clip1() then
						wep:SetClip1(wep:Clip1())
						wep.insaneStats_LastClip1 = wep:Clip1()
					end
					
					wep.insaneStats_LastClip2 = wep.insaneStats_LastClip2 or wep:Clip2()
					if wep.insaneStats_LastClip2 ~= wep:Clip2() then
						wep:SetClip2(wep:Clip2())
						wep.insaneStats_LastClip2 = wep:Clip2()
					end
				end
				
				if (k:IsPlayer() and not k:InVehicle()) then
					--print(InsaneStats.totalTimeDilation)
					local plyVel = k:GetVelocity()
					local speedFactor = plyVel:Length2DSqr()^0.25 / 20
					if k:InsaneStats_GetAttributeValue("speed_dilation") ~= 1 then
						InsaneStats.totalTimeDilation = InsaneStats.totalTimeDilation
						* (1 + (k:InsaneStats_GetAttributeValue("speed_dilation") - 1) * speedFactor)
						--print(1 + (k:InsaneStats_GetAttributeValue("speed_dilation") - 1) * speedFactor)
					end
					--print(speedFactor, k:InsaneStats_GetAttributeValue("speed_dilation"), InsaneStats.totalTimeDilation)
					
					--[[if k:InsaneStats_GetAttributeValue("dilation") ~= 1 then
						if k:KeyDown(IN_FORWARD) or k:KeyDown(IN_BACK) or k:KeyDown(IN_LEFT) or k:KeyDown(IN_RIGHT) then
							InsaneStats.totalTimeDilation = InsaneStats.totalTimeDilation * k:InsaneStats_GetAttributeValue("dilation")
						end
					end]]
				end
				
				InsaneStats.totalTimeDilation = InsaneStats.totalTimeDilation / (1+k:InsaneStats_GetStatusEffectLevel("ctrl_gamespeed_up")/100)
				InsaneStats.totalTimeDilation = InsaneStats.totalTimeDilation / (1-k:InsaneStats_GetStatusEffectLevel("alt_gamespeed_down")/100)
			end
		end
		
		if InsaneStats:GetConVarValue("wpass2_attributes_player_constant_timescale") then
			game.SetTimeScale(1 / InsaneStats.totalTimeDilation)
		else
			game.SetTimeScale(game.GetTimeScale() / InsaneStats.totalTimeDilation)
		end
		--print(InsaneStats.totalTimeDilation)
	end
end)

local function ProcessBreakEvent(victim, attacker)
	if not IsValid(attacker) and IsValid(victim.insaneStats_LastAttacker) then
		attacker = victim.insaneStats_LastAttacker
	end
	
	--[[local physAttacker = attacker:GetPhysicsAttacker(5)
	if IsValid(physAttacker) then
		attacker = physAttacker
	end
	
	if IsValid(attacker.insaneStats_LastAttacker) then
		attacker = attacker.insaneStats_LastAttacker
	end]]
	
	if IsValid(attacker) and victim:GetCollisionGroup() ~= COLLISION_GROUP_DEBRIS
	and not victim.insaneStats_SuppressCoinDrops then
		local stacks = (attacker:InsaneStats_GetAttributeValue("kill1s_xp2") - 1) * 100
		attacker:InsaneStats_ApplyStatusEffect("masterful_xp", stacks, 1, {extend = true})
		local duration = attacker:InsaneStats_GetAttributeValue("starlight") - 1
		attacker:InsaneStats_ApplyStatusEffect("starlight", 1, duration, {extend = true})
		
		local inflictor = attacker.GetActiveWeapon and attacker:GetActiveWeapon() or attacker
		local xpMul = InsaneStats:GetConVarValue("xp_other_mul")
		local currentHealthAdd = victim.insaneStats_CurrentHealthAdd or 1
		local startingHealth = victim:InsaneStats_GetMaxHealth() / currentHealthAdd
		
		local data = {
			xp = startingHealth * xpMul / 5,
			attacker = attacker, inflictor = inflictor, victim = victim,
			receivers = {[attacker] = 1, [inflictor] = 1}
		}
		hook.Run("InsaneStatsScaleXP", data)
		
		local xpToGive = data.xp
		local xpDropMul = InsaneStats:GetConVarValue("xp_other_kill")
		
		for k,v in pairs(data.receivers) do
			if IsValid(k) then
				local xp = xpToGive * v
				k:InsaneStats_AddXP(xp, xp*xpDropMul)
				k:InsaneStats_AddBatteryXP(xp)
				
				local wep = k.GetActiveWeapon and k:GetActiveWeapon()
				if IsValid(wep) and wep ~= inflictor then
					wep:InsaneStats_AddXP(xp, xp*xpDropMul)
					wep:InsaneStats_AddBatteryXP(xp)
				end
			end
		end
			
		SpawnRandomItems(attacker:InsaneStats_GetAttributeValue("prop_supplychance") - 1, victim:WorldSpaceCenter())
	end
end

hook.Add("break_prop", "InsaneStatsWPASS2", function(data)
	if InsaneStats:GetConVarValue("wpass2_enabled") then
		local victim = Entity(data.entindex or 0)
		local attacker = Player(data.userid or 0)
		
		ProcessBreakEvent(victim, attacker)
	end
end)

hook.Add("break_breakable", "InsaneStatsWPASS2", function(data)
	if InsaneStats:GetConVarValue("wpass2_enabled") then
		local victim = Entity(data.entindex or 0)
		local attacker = Player(data.userid or 0)
		
		ProcessBreakEvent(victim, attacker)
	end
end)

hook.Add("InsaneStatsModifyWeaponClip", "InsaneStatsWPASS2", function(data)
	local attacker = data.wep:GetOwner()
	if IsValid(attacker) and data.old > data.new then
		local shouldSave = math.random() + 1 < attacker:InsaneStats_GetAttributeValue("ammo_savechance")
		if shouldSave then
			data.new = data.old
		end
	end
end)

hook.Add("InsaneStatsPlayerSetAmmo", "InsaneStatsWPASS2", function(data)
	local attacker = data.ply
	if IsValid(attacker) and data.old > data.new then
		local wep = attacker:GetActiveWeapon()
		local shouldSave = math.random() + 1 < attacker:InsaneStats_GetAttributeValue("ammo_savechance")
		
		if IsValid(wep) then
			local primarySavable = wep:Clip1() <= 0 and wep:GetPrimaryAmmoType() == data.type
			local secondarySavable = wep:Clip2() <= 0 and wep:GetSecondaryAmmoType() == data.type
			shouldSave = shouldSave and (primarySavable or secondarySavable)
		end
		
		if shouldSave then
			data.new = data.old
		end
	end
end)

hook.Add("InsaneStatsPlayerRemoveAmmo", "InsaneStatsWPASS2", function(data)
	local attacker = data.ply
	if IsValid(attacker) and data.num > 0 then
		local wep = attacker:GetActiveWeapon()
		local shouldSave = math.random() + 1 < attacker:InsaneStats_GetAttributeValue("ammo_savechance")
		
		if IsValid(wep) then
			local primarySavable = wep:Clip1() <= 0 and wep:GetPrimaryAmmoType() == data.type
			local secondarySavable = wep:Clip2() <= 0 and wep:GetSecondaryAmmoType() == data.type
			shouldSave = shouldSave and (primarySavable or secondarySavable)
		end
		
		if shouldSave then
			data.num = 0
		end
	end
end)

