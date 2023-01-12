--[[
Author: Not_Lowest#0317
Description: A better version of my previous bank system that was for Simple Studios LTD
]]

ServerStorage = game:GetService("ServerStorage")
ServerScriptService = game:GetService("ServerScriptService")
ReplicatedStorage = game:GetService("ReplicatedStorage")
TweenService = game:GetService("TweenService")
RunService = game:GetService("RunService")

--== Door System ==--

BankSystem = workspace.Banksystem

VaultDoorSystem = BankSystem.VaultDoor
Movements = VaultDoorSystem.DoorMovements
VaultDoor = VaultDoorSystem.Door
SoundPart = BankSystem.SoundPart

HackingSystem = BankSystem.HackingSystem
HackingDevice = HackingSystem.HackingDevice
HackingReader = HackingSystem.Reader

ScreenPart = HackingDevice.ScreenPart
MovePart = ScreenPart.SurfaceGui.Frame.HackBack.Green

--== BOOLS ==--

IsHacking = false
IsOpen = false
Detected = false
Run = false

--== Second Bools ==--

HackingTime = 15
HackingTimeLeft = 0
random = 0
RandomNumber = 0

--== Code ==--

DoorOpenTweenTime = TweenInfo.new(5)

--== Functions ==--

function OpenDoors()
	for _,Door in pairs(VaultDoor:GetChildren()) do
		local e = TweenService:Create(
			Door,
			DoorOpenTweenTime,
			{Position = Vector3.new(Movements.Open[Door.Name].CFrame.X, Movements.Open[Door.Name].CFrame.Y, Movements.Open[Door.Name].CFrame.Z)}
		)

		e:Play()
		SoundPart.OpenDoor:Play()
	end
end

function CloseDoors()
	for _,Door in pairs(VaultDoor:GetChildren()) do
		local e = TweenService:Create(
			Door,
			DoorOpenTweenTime,
			{Position = Vector3.new(Movements.Open[Door.Name].CFrame.X, Movements.Open[Door.Name].CFrame.Y, Movements.Open[Door.Name].CFrame.Z)}
		)

		e:Play()
		SoundPart.CloseDoor:Play()
	end
end

function Detect()
	if Detected == false then
		Detected = true
		HackingDevice.ScreenPart.SurfaceGui.Frame.Detected.Visible = true		
	end
end


function Reset()
	CloseDoors()
	IsHacking = false
	IsOpen = false
	Detected = false

	HackingDevice.ScreenPart.SurfaceGui.Frame.Detected.Visible = false
	HackingDevice.ScreenPart.SurfaceGui.Frame.Complete.Visible = false
	HackingDevice.ScreenPart.SurfaceGui.Frame.HackBack.Green.Size = UDim2.new(0,0,1,0)

	for _,v in pairs(HackingDevice:GetChildren()) do
		v.Transparency = 1
		if v:FindFirstChild("SurfaceGui") then
			v.SurfaceGui.Enabled = false
		end
	end
end

function StartBankRobbery()
	
	SoundPart.Alarm:Play()
	OpenDoors()
	task.wait(10)
	Detect()
	task.wait(50)
	SoundPart.Alarm:Stop()
	task.wait(140)
	Reset()
end


function StartHacking()
	for _,v in pairs(HackingDevice:GetChildren()) do
		v.Transparency = 0
		if v:FindFirstChild("SurfaceGui") then
			v.SurfaceGui.Enabled = true
		end
		if v:FindFirstChildWhichIsA("Texture") then
			v.Texture.Transparency = 0
		end
	end
	IsHacking = true
end

function Kick(plr)
	plr:Kick("Hacking")
end

--== Hacking System ==--

function CheckDistance(HackingReader,plr)
	return (HackingReader.CFrame.p - plr.Character.HumanoidRootPart.CFrame.p).Magnitude > 15
end

HackingReader.ATT.ProximityPrompt.Triggered:Connect(function(plr)

	if CheckDistance(HackingReader,plr)  then
		Kick(plr)
	else
		if HackingReader.ATT.ProximityPrompt.Enabled == true then
			if IsHacking == false then
				HackingReader.ATT.ProximityPrompt.Enabled = false
				StartHacking()
			end

		else
			Kick(plr)
		end
	end
end)

RunService.Heartbeat:Connect(function()
	if IsHacking and not IsOpen and not Run then
		Run = true
		random = math.random(1,3)
		task.wait(random)
		
		HackingTimeLeft += 1

		RandomNumber = math.random(1,50)
		if RandomNumber == 14 and not Detected then
			Detect()
		end

		MovePart:TweenSize(UDim2.new(HackingTimeLeft/HackingTime,0,1,0), Enum.EasingDirection.In, Enum.EasingStyle.Linear, 0.1)
		if HackingTimeLeft >= HackingTime then
			IsHacking = false
			MovePart:TweenSize(UDim2.new(1,0,1,0), Enum.EasingDirection.In, Enum.EasingStyle.Linear, 0.1)

			ScreenPart.SurfaceGui.Frame.Complete.Visible = true
			StartBankRobbery()
		end
		Run = false
	end
end)
print(gcinfo())