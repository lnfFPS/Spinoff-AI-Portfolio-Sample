--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")

return {
	Type = "melee",
	Health = 100,
	WalkSpeed = 14,
	DetectionRange = 60,
	StunImmune = false,
	RecoveryTime = 1.65,
	
	LightSwingSpeed = 100,
	LightSwingInterval = 0.5,
	LightDamage = 10,
	HeavySwingSpeed = 50,
	HeavyDamage = 54,
	AttackRange = 5,

	TargetTags = {}, -- what enemies will specifically target even if they are an AI or a possible Ally

	SwingHitbox = {
		Size = Vector3.new(4, 4, 4),
		Offset = Vector3.new(0, 0, -2),
		MultiHit = false,
	},

	Animations = {
		Idle = "rbxassetid://131621811462974",
		Death = nil,

		LightSwings = {
			[1] = { ID = "rbxassetid://111925428472766", HitTime = 0.3 },
			[2] = { ID = "rbxassetid://91841670842373", HitTime = 0.3},
			[3] = { ID = "rbxassetid://103105861962187", HitTime = 0.25 },
		},

		HeavySwing = { ID = "rbxassetid://117459585257309", HitTime = 0.95 * 1.5},
	},

	Sounds = {
		LightSwing = "rbxassetid://9120728815",
		HeavySwing = "rbxassetid://9120728815",
		LightHitSound = "rbxassetid://139890294541073",
		HeavyHitSound = "rbxassetid://139890294541073",
		Death = nil,
	},

	Actor = {
		DefaultState = "Default",
		-- RepathInterval = 0.05,

		MovementStates = {
			Hold = {
				Mode = "Hold",
			},

			Default = {
				Mode = "Target",
				SharePath = true, -- to make it more optimised shares paths with other AIs if they are close enough
				DistanceTolerance = 2, -- keeps the distance like this i hope
			},

			-- KeepDistance = {
			-- 	Mode = "KeepDistance",
			-- 	DesiredDistance = 18,
			-- 	DistanceTolerance = 4,
			-- 	SharePath = true,
			-- },

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
				nil,
				nil,
				character.PrimaryPart
			)

			customStats.Lives -= 1
			character.Humanoid.Health += damage

			return customStats
		end,
	},
}