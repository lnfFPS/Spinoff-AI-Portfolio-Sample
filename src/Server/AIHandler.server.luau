local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Manager = require(ServerStorage.Modules.Manager)

local Actor = ServerScriptService.Actor

local function lilFuncition()
	local character, aiUnit = Manager.spawn(Actor, "FistArtist", Vector3.new(0, 5, 0))
	character["Left Arm"].CanCollide = false
	character["Right Arm"].CanCollide = false
	character["Left Leg"].CanCollide = false
	character["Right Leg"].CanCollide = false


	task.wait(5)

	character, aiUnit = Manager.spawn(Actor, "Whoopsie", Vector3.new(15, 5, 15))

	character["Left Arm"].CanCollide = false
	character["Right Arm"].CanCollide = false
	character["Left Leg"].CanCollide = false
	character["Right Leg"].CanCollide = false


	task.wait(5)


	task.wait(30)

	character, aiUnit = Manager.spawn(Actor, "RatTrick", Vector3.new(15, 5, 15))

	character["Left Arm"].CanCollide = false
	character["Right Arm"].CanCollide = false
	character["Left Leg"].CanCollide = false
	character["Right Leg"].CanCollide = false
end

lilFuncition() 

while task.wait(30) do
	lilFuncition()
end
