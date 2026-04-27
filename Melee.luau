--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SSM = require(ReplicatedStorage.Shared.ServerStateMachine)

local Melee = {}

function Melee.GetStates(self)
	return {
		Idle = {
			onEnter = function()
				if self.IsDead then
					return
				end

				if self.Tracks.Idle and not self:IsPlaying("Idle") then
					self:Play("Idle", 1, 0.1, 55)
				end
			end,

			onUpdate = function()
				if self.IsDead then
					return
				end

				if self:IsActionLocked() then
					self:TransitionState("ActionLocked")
					return
				end

				self:AcquireTarget()

				if self.Target then 
					self:TransitionState("Chase")
				end
			end,
		},

		Chase = {

			onUpdate = function()
				if self.IsDead then
					return
				end

				if self:IsActionLocked() then
					return
				end

				self:AcquireTarget()

				if not self.Target then
					self:TransitionState("Idle")
					return
				end

				local distance = (self.Target.Position - self.Root.Position).Magnitude
				if distance <= self.Data.AttackRange then
					local started = self:TryAttack(self.Target)
					if started then
						self:TransitionState("ActionLocked")
					end

					return
				end

				if self.Humanoid.WalkSpeed <= 0 then
					return
				end
			end,
		},

		ActionLocked = {

			onUpdate = function()
				if self.IsDead and not self.FSM:Is("Dead") then
					self:TransitionState("Dead", true)
					return
				end

				

				self:AcquireTarget()

				if self:IsActionLocked() then
					return
				end

				
				if not self.Target then
					self:TransitionState("Idle")
					return
				end

				

				self:TransitionState("Chase")
			end,
		},
	}
end

function Melee.TryAttack(self): boolean
	if not self.Target then
		return false
	end

	if SSM:GetState(self.Model) == "Dead" then
		return false
	end

	if self:IsActionLocked() then
		return false
	end

	if self.exceededLightLimit then
		self:TransitionState("Chase")
		return false
	end

	

	local actionAnimations = self.Data.Animations.Action
	local lightSwings = self.Data.Animations.LightSwings or (actionAnimations and actionAnimations.LightSwings)

	if not lightSwings or #lightSwings <= 0 then
		return false
	end

	self:Cancel()
	self.IsBusy = true
	self.State = "Attacking"

	local token = self.ActionToken
	local count = #lightSwings

	local function FinishAttack()
		if self.Destroyed then
			return
		end

		
		task.wait(self.Data.LightSwingInterval)

		
		self.IsBusy = false

		if not self.IsDead then
			self.State = "None"
		end
	end

	local function CancelAttack()
		FinishAttack()
		return false
	end

	if self.Destroyed then
		return CancelAttack()
	end

	if self.LightSwingIndex > count then
		self.LightSwingIndex = 1

		if not self.Data.NoLightSwingEndlag then
			self.exceededLightLimit = true

			task.delay(self.Data.LightSwingInterval * 2, function()
				if self.Destroyed then
					return
				end

				self.exceededLightLimit = false
			end)

			return CancelAttack()
		end
	end

	local function DoLightSwing(): boolean
		local swingData = lightSwings[self.LightSwingIndex]
		local trackName = "LightSwing" .. self.LightSwingIndex
		local track = self.Tracks[trackName]

		if not swingData or not track then
			return CancelAttack()
		end

		self:Play(trackName, self.Data.LightSwingSpeed / 100)
		self:WaitForHit(track, swingData.HitTime)

		if not self:CanContinue(token) then
			return CancelAttack()
		end

		self:PlaySound("LightSwing")
		self:ResolveHit(self.Data.LightDamage, false)

		if not self:CanContinue(token) then
			return CancelAttack()
		end

		task.wait(self.Data.LightSwingInterval)
		if not self:CanContinue(token) then
			return CancelAttack()
		end

		if not self.Data.NoLightSwingEndlag then
			
			self.LightSwingIndex += 1
		end

		return true
	end

	local function DoHeavySwing(): boolean
		local heavyData = self.Data.Animations.HeavySwing
		local track = self.Tracks.HeavySwing

		if not heavyData or not track then
			return CancelAttack()
		end

		self:Play("HeavySwing", self.Data.HeavySwingSpeed / 100)
		self:WaitForHit(track, heavyData.HitTime)

		if not self:CanContinue(token) then
			return CancelAttack()
		end

		self:PlaySound("HeavySwing")
		self:ResolveHit(self.Data.HeavyDamage, true)

		if not self:CanContinue(token) then
			return CancelAttack()
		end

		task.wait(0.5)

		if not self:CanContinue(token) then
			return CancelAttack()
		end

		return true
	end

	local success = false
	local randomType = math.random(1, 2)

	if self.Data.NoHeavySwing then
		success = DoLightSwing()
	else
		if randomType <= 1 or self.LightSwingIndex > 1 then
			success = DoLightSwing()
		else
			success = DoHeavySwing()
		end
	end

	if success then
		FinishAttack()
	end

	if self.Destroyed or self.IsDead or token ~= self.ActionToken then
		return false
	end

	

	return success == true
end

return Melee