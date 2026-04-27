--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")

return {
	Type = "gun",
	Health = 75,
	WalkSpeed = 11.5,
	DetectionRange = 60,
	StunImmune = false,
	RecoveryTime = 2,

	-- LightSwingSpeed = 100,
	-- LightSwingInterval = 0.5,
	-- LightDamage = 4,
	-- HeavySwingSpeed = 45,
	-- HeavyDamage = 16,
	-- AttackRange = 5,

	BulletSpread = 15,
	PelletAmount = 4,
	BulletDamage = 5, -- self explababtory
	ShootInterval = 1, -- yields the time before an AI can shoot again
	ShootRange = 30,
	ReactionTime = 0.25, -- the time the AI will fully realise that the player is in their sights and will only come into effect again until the AI has lost sight of the player

	AmmoAmount = 8,
	ReloadSpeed = 80, -- will adjust the anim speed to this has

	TargetTags = {}, -- what enemies will specifically target even if they are an AI or a possible Ally

	-- SwingHitbox = {
	-- 	Size = Vector3.new(4, 4, 4),
	-- 	Offset = Vector3.new(0, 0, -2),
	-- 	MultiHit = false,
	-- },

	Animations = {
		Idle = "rbxassetid://135886714806110",
		Death = nil,

		Shoot = "rbxassetid://79155414423545", -- could use some math to simulate the arms backing down but
		-- yet again i'm too lazy and i'm planning it like this

		Reload = "rbxassetid://123908471616984"

		-- LightSwings = {
		-- 	[1] = { ID = "rbxassetid://111925428472766", HitTime = 0.3 },
		-- 	[2] = { ID = "rbxassetid://91841670842373", HitTime = 0.3 },
		-- 	[3] = { ID = "rbxassetid://103105861962187", HitTime = 0.25 },
		-- },

		-- HeavySwing = { ID = "rbxassetid://117459585257309", HitTime = 0.95 * 1.5 },
	},

	Sounds = {
		-- LightSwing = "rbxassetid://9120728815",
		-- HeavySwing = "rbxassetid://9120728815",
		-- LightHitSound = "rbxassetid://139890294541073",
		-- HeavyHitSound = "rbxassetid://139890294541073",
		Shoot = "rbxassetid://356911785",
		Reload = "rbxassetid://140069224599018", -- following a basic reload sound because i'm not bothered to make a events system to do magin magout etc
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
				DesiredDistance = 14,
				DistanceTolerance = 4,
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
				.5,
				nil,
				character.PrimaryPart
			)

			customStats.Lives -= 1
			

			return customStats
		end,
	},
}