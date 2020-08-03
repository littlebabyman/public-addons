AddCSLuaFile()

ENT.Base = "gballoon_tower_base"
ENT.Type = "anim"
ENT.PrintName = "Gatling Gun Knight"
ENT.Category = "RotgB: Towers"
ENT.Author = "RandomTNT"
ENT.Contact = "http://steamcommunity.com/id/RandomTNT12/"
ENT.Purpose = "Gun those gBalloons!"
ENT.Instructions = ""
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.Model = Model("models/props_phx/games/chess/black_knight.mdl")
ENT.FireRate = 10
ENT.Cost = 550
ENT.DetectionRadius = 512
ENT.UseLOS = true
ENT.LOSOffset = Vector(0,0,40)
ENT.UserTargeting = true
ENT.AttackDamage = 10
ENT.rotgb_Spread = 40
ENT.rotgb_Shots = 1
ENT.UpgradeReference = {
	{
		Names = {"Stabilized Barrel","Heated Bullets","Consistent Barrel Spinner","Computerized Targeting","Laser Shooter","Ray of Doom"},
		Descs = {
			"Considerably reduces bullet spread.",
			"Increases damage dealt by each bullet and can pop Gray gBalloons.",
			"Disables bullet spread altogether.",
			"Deals tremendously increased damage versus gBlimps. Also enables the tower to see hidden gBalloons.",
			"Fires a continuous focused laser that shreds gBalloons.",
			"Fires an even bigger beam that obliterates ALL gBalloons in its path."
		},
		Prices = {400,1200,4000,40000,100000,400000},
		Funcs = {
			function(self)
				self.rotgb_Spread = self.rotgb_Spread * 0.65
			end,
			function(self)
				self.rotgb_CanPopGray = true
				self.AttackDamage = self.AttackDamage + 10
			end,
			function(self)
				self.rotgb_Spread = 0
			end,
			function(self)
				self.rotgb_ExtraVsCeramic = true
				self.SeeCamo = true
			end,
			function(self)
				self.AttackDamage = self.AttackDamage + 90
				self.rotgb_UseLaser = 1
			end,
			function(self)
				self.AttackDamage = self.AttackDamage - 90
				self.rotgb_UseLaser = 2
			end
		}
	},
	{
		Names = {"Higher Torque","Aerodynamic Bullets","TripShot","Super High Torque","DodecaShot","A Million Rounds Per Minute"},
		Descs = {
			"Increases fire rate.",
			"Increases range and damage dealt by each bullet.",
			"Fires three bullets per shot.",
			"Significantly increases fire rate.",
			"Significantly increases bullet spread, but twelve bullets are fired per shot!",
			"Tremendously increases bullet spread, but sixty bullets are fired per shot!"
		},
		Prices = {250,2500,6000,9000,17500,50000},
		Funcs = {
			function(self)
				self.FireRate = self.FireRate * 1.5
			end,
			function(self)
				self.DetectionRadius = self.DetectionRadius * 1.5
				self.AttackDamage = self.AttackDamage + 10
			end,
			function(self)
				self.rotgb_Shots = self.rotgb_Shots * 3
			end,
			function(self)
				self.FireRate = self.FireRate * 2
			end,
			function(self)
				self.rotgb_Spread = self.rotgb_Spread * 2
				self.rotgb_Shots = self.rotgb_Shots * 4
			end,
			function(self)
				self.rotgb_Spread = self.rotgb_Spread * 2
				self.rotgb_Shots = self.rotgb_Shots * 5
			end
		}
	}
}
ENT.UpgradeLimits = {6,2}

local function SnipeEntity()
	while true do
		local self,ent = coroutine.yield()
		local startPos = self:GetShootPos()
		--uDir:Normalize()
		if self.rotgb_UseLaser then
			for i=1,self.rotgb_Shots do
				local laser = ents.Create(self.rotgb_UseLaser==1 and "env_laser" or "env_beam")
				local startEnt = self.rotgb_UseLaser==2 and ents.Create("info_target") or NULL
				laser:SetPos(startPos)
				local oldEntName = ent:GetName()
				local entityName = ent:GetName() ~= "" and ent:GetName() or "laser_target"..self:GetCreationID()
				ent:SetName(entityName)
				if IsValid(startEnt) then
					startEnt:SetName("laser_pointer"..self:GetCreationID())
					startEnt:SetPos(startPos)
				end
				laser:SetKeyValue("LaserTarget",entityName)
				laser:SetKeyValue("renderamt","255")
				laser:SetKeyValue("rendercolor",self.rotgb_UseLaser==1 and "0 255 127" or "255 0 0")
				laser:SetKeyValue("width","3")
				laser:SetKeyValue("BoltWidth","12")
				laser:SetKeyValue("NoiseAmplitude","0")
				laser:SetKeyValue("texture","sprites/laserbeam.spr")
				laser:SetKeyValue("TextureScroll","35")
				laser:SetKeyValue("damage",self.AttackDamage*self.FireRate)
				laser:SetKeyValue("LightningStart","laser_pointer"..self:GetCreationID())
				laser:SetKeyValue("LightningEnd",entityName)
				laser:SetKeyValue("HDRColorScale","1")
				laser:SetKeyValue("spawnflags","33")
				laser:SetKeyValue("life",2/self.FireRate)
				laser:Spawn()
				laser:Activate()
				laser.rotgb_UseLaser = self.rotgb_UseLaser
				laser:Fire("TurnOn")
				timer.Simple(0.2,function()
					if IsValid(laser) then
						laser:Remove()
					end
					if (IsValid(ent) and entityName == ent:GetName()) then
						ent:SetName(oldEntName)
					end
					if IsValid(startEnt) then
						startEnt:Remove()
					end
				end)
			end
		else
			local uDir = ent:LocalToWorld(ent:OBBCenter())-startPos
			local bullet = {
				Attacker = self:GetTowerOwner(),
				Callback = function(attacker,tracer,dmginfo)
					dmginfo:SetDamageType(self.rotgb_CanPopGray and DMG_SNIPER or DMG_BULLET)
					--[[if self.rotgb_Explosive then -- no longer used
						local dmginfo = DamageInfo()
						dmginfo:SetAmmoType(game.GetAmmoID("Grenade"))
						dmginfo:SetAttacker(self:GetTowerOwner())
						dmginfo:SetInflictor(self)
						dmginfo:SetDamageType(DMG_BLAST)
						dmginfo:SetReportedPosition(tracer.HitPos)
						local effdata = EffectData()
						effdata:SetOrigin(tracer.HitPos)
						effdata:SetMagnitude(6)
						effdata:SetScale(6)
						effdata:SetStart(tracer.HitPos)
						effdata:SetEntity(self)
						util.Effect("Explosion",effdata,true,true)
						for k,v in pairs(ents.FindInSphere(tracer.HitPos,128)) do
							if v:GetClass()=="gballoon_base" then
								dmginfo:SetDamagePosition(tracer.HitPos)
								dmginfo:SetDamage(self.rotgb_ExtraVsCeramic and v:GetMaxHealth()>1 and self.AttackDamage*2 or self.AttackDamage)
								dmginfo:SetMaxDamage(dmginfo:GetDamage())
								v:TakeDamageInfo(dmginfo)
							end
						end
						dmginfo:SetDamagePosition(tracer.HitPos)
						dmginfo:SetDamage(self.rotgb_ExtraVsCeramic and ent:GetMaxHealth()>(ent:GetBalloonProperty("BalloonShielded") and 2 or 1) and self.AttackDamage*5 or self.AttackDamage)
						dmginfo:SetMaxDamage(dmginfo:GetDamage())
						util.BlastDamageInfo(dmginfo,tracer.HitPos,128)
					end]]
				end,
				Damage = self.rotgb_ExtraVsCeramic and ent:GetBalloonProperty("BalloonBlimp") and self.AttackDamage*5 or self.AttackDamage,
				Distance = self.DetectionRadius*1.5,
				HullSize = 1,
				Num = self.rotgb_Shots,
				Tracer = 2,
				AmmoType = "SniperRound",
				TracerName = "Tracer",
				Dir = uDir,
				Spread = Vector(self.rotgb_Spread,self.rotgb_Spread,0),
				Src = startPos
			}
			self:FireBullets(bullet)
		end
	end
end

hook.Add("EntityTakeDamage","RotgB_Towers",function(vic,dmginfo)
	if (IsValid(dmginfo:GetAttacker()) and dmginfo:GetAttacker().rotgb_UseLaser==2) then
		dmginfo:SetDamageType(DMG_GENERIC)
		if dmginfo:GetDamage()>=vic:Health() and vic:GetClass()=="gballoon_base" and dmginfo:GetAttacker().rotgb_NoChildren then
			vic:Pop(-1)
		end
	end
end)

ENT.thread = coroutine.create(SnipeEntity)
coroutine.resume(ENT.thread)

function ENT:FireFunction(gBalloons)
	local perf,str = coroutine.resume(self.thread,self,gBalloons[1])
	if not perf then error(str) end
end

list.Set("NPC","gballoon_tower_04",{
	Name = ENT.PrintName,
	Class = "gballoon_tower_04",
	Category = ENT.Category
})