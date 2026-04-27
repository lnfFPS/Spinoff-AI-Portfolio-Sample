--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AITypes = ServerStorage.AITypes
local SSM = require(ReplicatedStorage.Shared.ServerStateMachine)
local Gun = require(AITypes.Gun)
local Melee = require(AITypes.Melee)



return {
	Type = "universal",
	Health = 185,
	WalkSpeed = 12.5,
	DetectionRange = 90,
	StunImmune = false,
	RecoveryTime = 1.2,

	LightSwingSpeed = 100,
	LightSwingInterval = 3.5/2,
	LightDamage = 25,
    NoLightSwingEndlag = true, -- doesn't disable lightswinginterval disables exceededlightlimit which makes it so the ai can only do the max amount of light swings before putting it on cd
    NoHeavySwing = true,
    -- HeavySwingSpeed = 45,
	-- HeavyDamage = 16,
	AttackRange = 5,

	BulletSpread = 7,
	PelletAmount = 1,
	BulletDamage = 3, -- self explababtory
	ShootInterval = .07, -- yields the time before an AI can shoot again
	ShootRange = 70,
	ReactionTime = 0.25, -- the time the AI will fully realise that the player is in their sights and will only come into effect again until the AI has lost sight of the player

	AmmoAmount = 32,-- the max ammo an AI can have
	ReloadSpeed = 87, -- will adjust the anim speed to this has

	TargetTags = {}, -- what enemies will specifically target even if they are an AI or a possible Ally

	SwingHitbox = {
		Size = Vector3.new(4, 4, 4),
		Offset = Vector3.new(0, 0, -2),
		MultiHit = false,
	},

    -- will be used later for damage types and stuff like that, currently just for the sake of it
    DamageTypes = {
        Melee = "Sharp",
        Gun = "Bullet", -- duh
    },

    TryAttack = function(self): boolean
        if self.Target == nil then
            return false
        end

        if SSM:GetState(self.Model) == "Dead" then
            return false
        end

        local distance = (self.Root.Position - self.Target.Position).Magnitude

        if distance <= self.Data.AttackRange then
        	-- local lastMeleeTick = self:MakeTick("LightSwingIntervalTick")
			-- print(tick() - lastMeleeTick)
        	-- if tick() - lastMeleeTick >= self.Data.LightSwingInterval then
        	-- 	self:MakeTick("LightSwingIntervalTick", true)

            --     task.spawn(function()
            --         local allow = Melee.TryAttack(self)
			-- 		print(allow)
            --     end)
        		
        	-- end
			

			task.spawn(function()
                local allow = Melee.TryAttack(self)
            end)
        end


        if distance <= self.Data.ShootRange then
            local allow = Gun.TryAttack(self, true)
            return
        end
        
        return true
    end,

    States = {
        Idle = {
            onEnter = function(self)
				if self.IsDead then
					return
				end

				if self.MechanicalStats.AmmoCount == nil then
					self.MechanicalStats.AmmoCount = self.Data.AmmoAmount
				end

				if self.MechanicalStats.Reloading == nil then
					self.MechanicalStats.Reloading = false
				end
				

				self:MakeTick("ShootIntervalTick")
				self:MakeTick("reactionTime", true)


				-- should stay outside of this but i'll keep it here for now
				task.delay(1, function()
					self:SetMovementState("KeepDistance")
				end)
				

				if self.Tracks.Idle and not self:IsPlaying("Idle") then
					self:Play("Idle", 1, 0.1, 55)
				end
			end,

			onUpdate = function(self)
				if self.IsDead then
					return
				end

				if self:IsActionLocked() then
					return
				end

				self:AcquireTarget()

				if self.Target then
					self:TransitionState("Chase")
				end
			end,
        },

        Chase = {

			onUpdate = function(self)
				if self.IsDead then 
					return
				end

				if SSM:GetState(self.Model) == "Dead" then
		            return
	            end

				self:AcquireTarget()

				if not self.Target then
					self.SeenTarget = nil
					self:TransitionState("Idle")
					return
				end

				local distance = (self.Target.Position - self.Root.Position).Magnitude
				if distance >= self.Data.ShootRange then
					self.SeenTarget = nil
					return
				end

				if not self:HasLineOfSight() then
					self.SeenTarget = nil
					self:MakeTick("reactionTime", true)
					return
				end

				if self.MechanicalStats.FaceTowards then
					self.MechanicalStats.FaceTowards:Disconnect()
					self.MechanicalStats.FaceTowards = nil
				end
				self.MechanicalStats.FaceTowards = self:FaceTarget(self.Target)

				local reactionTimeTick = self:MakeTick("reactionTime")
				
				local elapsed = tick() - reactionTimeTick

				if not self.SeenTarget then
					if elapsed >= self.Data.ReactionTime then
						self.SeenTarget = self.Target
					end
					return
				end 

                if self.MechanicalStats.AmmoCount <= 0 then
					self.SeenTarget = nil
					self:MakeTick("reactionTime", true)

                    self:TransitionState("ActionLocked")
                    local hey = Gun.Reload(self, true)
					if not hey then
						self:TransitionState("Chase")
                        return
                    end
                    

                end

				local needToReload = self:TryAttack(self.Target)
                if needToReload == "melee" then return end -- it should be the MELEEs buisness lmao
				self:TransitionState("ActionLocked")
			end,
		},

        ActionLocked = {
			onUpdate = function(self)
				if self.IsDead then
					self:TransitionState("Dead", true)
					return
				end

				self:AcquireTarget()

				if not self.Target then
					self:TransitionState("Idle")
					return
				end

				if self.MechanicalStats.Reloading then
					return
				end
                
				self:TransitionState("Chase")
			end,
        }
    },

	Animations = {
		Idle = "rbxassetid://83970136514946",
		Death = nil,

		Shoot = "rbxassetid://76691644069702", 
	
		LightSwings = {
		    [1] = { ID = "rbxassetid://74296328958110", HitTime = 0.3 },
		 },
        Reload = "rbxassetid://81576488445073",
        

		-- HeavySwing = { ID = "rbxassetid://117459585257309", HitTime = 0.95 * 1.5 },
	},

	Sounds = {
		LightSwing = "rbxassetid://12958250 9517716",
		-- HeavySwing = "rbxassetid://9120728815",
		LightHitSound = "rbxassetid://136518851744814",
		-- HeavyHitSound = "rbxassetid://139890294541073",
		Shoot = "rbxassetid://93756726513919",
		Reload = "rbxassetid://95082227513454", -- following a basic reload sound because i'm not bothered to make a events system to do magin magout etc
		Death = nil,
	},

	Actor = {
		DefaultState = "Default",
		-- RepathInterval = 0.25,

		MovementStates = {
			Hold = {
				Mode = "Hold",
			},

			-- Default = {
			-- 	Mode = "Target",
			-- 	SharePath = true, -- to make it more optimised shares paths with other AIs if they are close enough
			-- 	DistanceTolerance = 8, -- keeps the distance like this i hope
			-- },

			KeepDistance = {
				Mode = "KeepDistance",
				DesiredDistance = 2,
				DistanceTolerance = 1,
				SharePath = true,
			},

			-- StrafeLeft = {
			-- 	Mode = "StrafeLeft",
			-- 	StrafeDistance = 10,
			-- 	SharePath = false,
			-- },

			-- StrafeRight = {
			-- 	Mode = "StrafeRight",
			-- 	StrafeDistance = 10,
			-- 	SharePath = false,
			-- },

			-- CustomGoal = {
			-- 	Mode = "CustomGoal",
			-- 	SharePath = false,
			-- },
		},
	},

	OnDeath = {
		CustomStats = {
			Lives = 1,
		},

		func = function(character: Model, damage, customStats)
			if customStats.Lives <= 0 then
				return false
			end

			ReplicatedStorage.Events.SoundEvent:FireAllClients(
				"rbxassetid://137385031681735",
				1,
				nil,
				character.PrimaryPart
			)

			customStats.Lives -= 1
			

			return customStats
		end,
	},
}