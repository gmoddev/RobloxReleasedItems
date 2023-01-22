ReplicatedStorage = game:GetService("ReplicatedStorage")

Players = game:GetService("Players")
RunService = game:GetService('RunService')

Modules = ReplicatedStorage.Modules

--// Weapon FastCast
FastCast = require(Modules.FastCastRedux)
--//


--// Attack Anim

Entity = script.Parent
Humanoid = Entity.Humanoid
HumanoidRootPart = Entity.HumanoidRootPart
Animator = Humanoid.Animator

Tool = Entity:WaitForChild("Weapon",100)

Animations = Tool:FindFirstChild("Animations"):GetChildren()

Swinging = false
CanSwing = false
MovementActive = false
TargetingPlayer = nil
Cooldown = false

Possible = {}
PossiblePlayers = {}
Damaged = {}

RightPossible = false
LeftPossible = false
FrontPossible = false
BackPossible = false

RightDistance = 0 
LeftDistance = 0
FrontDistance = 0
BackDistance = 0

--// Setting up fastcast
Caster = FastCast.new()
Caster.VisualizeCasts = true

CasterParams = RaycastParams.new()
CasterParams.FilterType = Enum.RaycastFilterType.Blacklist
CasterParams.RespectCanCollide = true

cstertable = {}

for i,v in ipairs(Entity:GetDescendants()) do
	if v:IsA("BasePart") then
		table.insert(cstertable,v)
	end
end

CasterBehavior = FastCast.newBehavior(CasterParams,2,2)
--// eee
---- NOTE IMPROVE LOADANIMATION, IT LOADS AN ANIM EVERY TIME ITS FIRED
function Attack()
	local Anim = Animations[math.random(1,#Animations)]
	local AnimLoaded = Animator:LoadAnimation(Anim)
	AnimLoaded:Play()
	Swinging = true
	AnimLoaded.Ended:Connect(function()
		Swinging = false
	end)
end

function CheckResult(Result)
	for i,v in ipairs(Damaged) do
		if Result.Instance.Parent.Name == v.Name then
			return true
		end
	end
	if string.find(tostring(Result.Instance:GetFullName()),Entity.Name) then
		return true
	end
	return false
end

RunService.Heartbeat:Connect(function()
	if Swinging then
		local cast = Caster:Fire(Vector3.new(Tool.Handle.Raycast.CFrame.X,Tool.Handle.Raycast.CFrame.Y,Tool.Handle.Raycast.CFrame.Z),Tool.Handle.Raycast.CFrame.LookVector,100,CasterBehavior)
		task.wait(0.01)
	end
	
	if not TargetingPlayer then
		if not Cooldown then
			for i,v in ipairs(Players:GetChildren()) do
				local Allow = true
				if v.Name == Humanoid.owner.Value.Name then
					Allow = false
				end

				if v.Character and Allow then

					if v:DistanceFromCharacter(HumanoidRootPart.Position) <= 30 then

						local RP = RaycastParams.new()
						local BL = {}
						RP.FilterType = Enum.RaycastFilterType.Blacklist
						RP.FilterDescendantsInstances = BL

						local RC = workspace:Raycast(HumanoidRootPart.Position,(v.Character.HumanoidRootPart.Position - HumanoidRootPart.Position).Unit * 30,RP)

						if RC then
							if RC.Instance.Parent:FindFirstChild("Humanoid") then
								if RC.Instance.Parent.Name == v.Name then
									TargetingPlayer = v
								else
									TargetingPlayer = nil

								end
							else
								TargetingPlayer = nil
							end
						end
					end
				end
			end
			--[[
			if not TargetingPlayer then
				local Ran = math.random(1,3562)
				if Ran == 25 and not MovementActive then
					print("Moving")
					local right = workspace:Raycast(HumanoidRootPart.Position,HumanoidRootPart.CFrame.RightVector* 10,RCPerms)
					local left = workspace:Raycast(HumanoidRootPart.Position,-HumanoidRootPart.CFrame.RightVector* 10,RCPerms)
					local front = workspace:Raycast(HumanoidRootPart.Position,HumanoidRootPart.CFrame.LookVector* 10 ,RCPerms)
					local back = workspace:Raycast(HumanoidRootPart.Position,-HumanoidRootPart.CFrame.LookVector * 10,RCPerms)

					if right then
						if (right.Distance) >= 3 then
							RightPossible = true
							RightDistance = right.Distance
						end
					else
						RightPossible = true
						RightDistance = 15
					end
					if left then
						if (left.Distance) >= 3 then
							LeftPossible = true
							LeftDistance = left.Distance
						end
					else
						LeftPossible = true
						LeftDistance = 15
					end
					if front then
						if (front.Distance) >= 3 then
							FrontPossible = true
							FrontDistance = front.Distance
						end
					else
						FrontPossible = true
						FrontDistance = 15
					end
					if back then
						if (back.Distance) >= 3 then
							BackPossible = true
							BackDistance = back.Distance
						end
						BackPossible = true
						BackDistance = 15
					end

					local Ran2 = math.random(1,4)
					print(FrontDistance,BackDistance,RightDistance,LeftDistance)
					if Ran2 == 1 then
						if RightDistance >= 1 then
							Humanoid:MoveTo(HumanoidRootPart.Position * (HumanoidRootPart.CFrame.RightVector + Vector3.new(math.random(1,RightDistance),0,0)) )
						end
					elseif Ran2 == 2 then
						if LeftDistance >= 1 then
							Humanoid:MoveTo(HumanoidRootPart.Position * (-HumanoidRootPart.CFrame.RightVector + Vector3.new(math.random(1,LeftDistance),0,0)) )
						end
					elseif Ran2 == 3 then
						if FrontDistance >= 1 then
							Humanoid:MoveTo(HumanoidRootPart.Position * (HumanoidRootPart.CFrame.LookVector + Vector3.new(0,0,math.random(1,FrontDistance))) )
						end
					elseif Ran2 == 4 then
						if BackDistance >= 1 then
							Humanoid:MoveTo(HumanoidRootPart.Position * (-HumanoidRootPart.CFrame.LookVector + Vector3.new(0,0,math.random(1,BackDistance))) )

						end

					end
					MovementActive = true

				end
			end
			]]
		end
	else
		if TargetingPlayer.Character then
			local PlrCharacter = TargetingPlayer.Character
			local PlrHumanRootPart = PlrCharacter.HumanoidRootPart

			if TargetingPlayer:DistanceFromCharacter(HumanoidRootPart.Position) <= 30 then
				if TargetingPlayer:DistanceFromCharacter(HumanoidRootPart.Position) > 3 then
					if not Cooldown then
						local RP = RaycastParams.new()
						local BL = {}
						RP.FilterType = Enum.RaycastFilterType.Blacklist
						RP.BruteForceAllSlow = true

						--[[
						local Check = ray()
						if Check then
							if Check.Instance.Parent.Name ~= TargetingPlayer.Name then
								TargetingPlayer = nil
								return
							end
						end]]
						local RC = workspace:Raycast(HumanoidRootPart.Position,(PlrHumanRootPart.Position - HumanoidRootPart.Position).Unit * 100,RP)

						if RC.Instance.Parent:FindFirstChild("Humanoid") then
							if RC.Instance.Parent.Name == TargetingPlayer.Name then
								MovementActive = true
								TargetingPlayer = TargetingPlayer
								Humanoid:MoveTo(PlrHumanRootPart.Position)
							else
								TargetingPlayer = nil
							end

						else
							TargetingPlayer = nil
						end
					end
				else
					if not Cooldown then
						print("Attack player")
						Cooldown = true
						PlrCharacter.Humanoid.Health -= 10

						task.wait(2)
						Cooldown = false
					end
				end

			else
				TargetingPlayer = nil
				MovementActive = false
			end
		end
	end
	
end)

Caster.RayHit:Connect(function(ActiveCast,Result: RaycastResult)
	if CheckResult(Result) then
		return
	end
	Humanoid = Result.Instance.Parent:FindFirstChild("Humanoid")
	if Humanoid then
		if CheckResult(Result) then
			return
		end
		table.insert(Damaged,Result.Instance.Parent)
		Humanoid.Health -= 10
	end
end)


--// Movement System

function Move(pos)
	Humanoid:MoveTo(pos)
end


Humanoid.MoveToFinished:Connect(function()
	MovementActive = false
end)