--[[
Not_Lowest

Very unorganized hting

]]

ReplicatedStorage = game:GetService("ReplicatedStorage")
ServerScriptService = game:GetService("ServerScriptService")
Players = game:GetService('Players')

NPCTypesFolder = ReplicatedStorage.Types
NPCModels = ReplicatedStorage.TypeModels
NPCWeapons = ReplicatedStorage.TypeWeapons
Modules = ReplicatedStorage.Modules

--// Events //
SendUpateEvent = ReplicatedStorage.SendUpdate
SpawnUnitEvent = ReplicatedStorage.SpawnUnit
DeleteUnitEvent = ReplicatedStorage.DeleteUnit

--// Modules

NameGeneration = require(Modules.NameGen)

--// NPC Stuff

NPCScript = script.MainScript

NPCTypes = {}
NPCData = {}

for name,data in pairs(NPCTypesFolder:GetChildren()) do
	local newdata = require(data)
	table.insert(NPCTypes,data.Name)
	NPCData[data.Name] = newdata

end
--// Main Functions
function spawnunit(unitdata,plr,todestroy)
	local plrfolder = workspace:FindFirstChild(plr.."e")
	local Unit = NPCModels:FindFirstChild(unitdata.UnitType)

	local plr = Players:FindFirstChild(plr)
	local Weapon = NPCWeapons:FindFirstChild(unitdata.UnitWeapon)

	if Unit then Unit = Unit:Clone() else return end
	Unit.Name = unitdata.UnitName
	Unit.PrimaryPart = Unit.HumanoidRootPart

	local Humanoid = Unit.Humanoid
	Humanoid.MaxHealth = unitdata.UnitHealth
	Humanoid.Health = unitdata.UnitHealth
	Humanoid.dmg.Value = unitdata.UnitDamage
	Humanoid.owner.Value = plr

	if Weapon then Weapon = Weapon:Clone() Weapon.Name = "Weapon" else Unit:Destroy() warn("ERROR NO WEAPON FOUND") return end

	Unit:SetPrimaryPartCFrame( CFrame.new(plr.Character.PrimaryPart.CFrame.X,plr.Character.PrimaryPart.CFrame.Y,plr.Character.PrimaryPart.CFrame.Z-10))
	Unit.Parent = plrfolder
	local ScriptClone =NPCScript:Clone()
	ScriptClone.Parent = Unit
	ScriptClone.Disabled = false

	Weapon.Parent = Unit

	Unit.Humanoid:EquipTool(Weapon)
	if todestroy then
		task.wait(0.0001)
		todestroy:Destroy()
	end
end

function despawnunit(unit,plr,todestroy: Instance)
	local plrfolder = workspace:FindFirstChild(plr.."e")
	plrfolder[unit.UnitName]:Destroy()
	if todestroy then
		task.wait(0.0001)
		todestroy:Destroy()
	end
end

function gen(Type)
	local Data = NPCData[Type]
	local NewData = {
		Owner = "";
		OwnerName = "";
		UnitName = "";
		UnitType = "";
		UnitHealth = 0;
		UnitDamage = 0;
		UnitWeapon = "";
		Spawned = false
	}
	NewData.UnitName = NameGeneration.PickName()
	NewData.UnitType = Data.UnitType
	NewData.UnitHealth = math.random(Data.UnitHealthMin,Data.UnitHealthMax)
	NewData.UnitDamage = math.random(Data.UnitDamageMin,Data.UnitDamageMax)
	NewData.UnitWeapon = Data.UnitWeapons[math.random(1,#Data.UnitWeapons)]

	return NewData
end

--// Unit Metatable
local units = {}
units.__index = units

function units.new(items,plrname)
	local newSet = {[1]=plrname}

	for key, value in pairs(items or {}) do
		newSet[value] = value
	end
	return setmetatable(newSet, units)
end

--// UnitFunctions \\--
function units:destroy()
	self = nil
end

function units:add(unitname,data)
	self[unitname] = data
end

function units:remove(unit)
	self[unit] = nil
end

function units:exists(unit)

	return self[unit] ~= nil
end

function units:list()
	return self
end

--// Unit Spawn and Despawn Functions \\--
function units:spawn(unit,pname)
	self[unit].Spawned = true
	spawnunit(self[unit],pname)
end
function units:despawn(unit,pname)
	self[unit].Spawned = false
	despawnunit(self[unit],pname)
end

function units:__newindex(key,val) --// detects when something gets added or removed (units:add, units:remove)
	rawset(self,key,val)
	SendUpateEvent:FireClient(Players[val.OwnerName],val)
end

--// Player Events \\--

Players.PlayerAdded:Connect(function(plr)
	local SpawnerFolder = Instance.new("Folder")
	SpawnerFolder.Name = "SpawnerQueue"
	SpawnerFolder.Parent = plr
	
	local sendInfo = Instance.new("BoolValue")
	sendInfo.Name = "NPCInfoSend"
	sendInfo.Parent = plr
	
	local Directive = Instance.new("StringValue")
	Directive.Name = "Directive"
	Directive.Parent = plr
	
	plr.CharacterAdded:Connect(function(char)
		char.Health:Destroy()
	end)
	
	local SpawnedUnits = Instance.new("Folder",workspace)
	SpawnedUnits.Name = plr.Name.."e"
	local UTable = units.new()
	
	local defaultNPC = gen("SwordMan")
	defaultNPC.Owner = plr.UserId
	defaultNPC.OwnerName = plr.Name
	UTable:add(defaultNPC.UnitName,defaultNPC)	
	print(defaultNPC)
	SpawnerFolder.ChildAdded:Connect(function(item)
		if UTable:exists(item.Name) then
			print("Item Exists")
			if item.Value then
				UTable:spawn(item.Name,plr.Name,item)
			else
				UTable:despawn(item.Name,plr.Name,item)
			end
		end
	end)
	sendInfo.Changed:Connect(function()
		local Children = sendInfo:GetChildren()
		
	end)
end)

SpawnUnitEvent.OnServerEvent:Connect(function(plr,unit)
	if type(unit) == "string" then
		local SpawnerQueue = plr:FindFirstChild("SpawnerQueue")
		
		local QueueItem = Instance.new("BoolValue")
		QueueItem.Value = true
		QueueItem.Name = unit
		QueueItem.Parent = SpawnerQueue
	else
		plr:Kick("Faggot")
	end
end)
DeleteUnitEvent.OnServerEvent:Connect(function(plr,unit)
	if type(unit) == "string" then
		local SpawnerQueue = plr:FindFirstChild("SpawnerQueue")

		local QueueItem = Instance.new("BoolValue")
		QueueItem.Value = false
		QueueItem.Name = unit
		QueueItem.Parent = SpawnerQueue
	else
		plr:Kick("Faggot")
	end
end)