--[[
Not_Lowest
Everwood Correctional Facility
]]

--// Globals
ReplicatedStorage = game:GetService("ReplicatedStorage")
ReplicatedFirst = game:GetService("ReplicatedFirst")
Players = game:GetService("Players")
TweenService = game:GetService("TweenService")
Teams = game:GetService("Teams")
StarterGui = game:GetService("StarterGui")
Market = game:GetService("MarketplaceService")

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

ServerRemotes = ReplicatedStorage.ServerRemotes
Player = Players.LocalPlayer
Config = require(ReplicatedStorage.Moderation)

SpawnFunc = ServerRemotes.Spawn

Character = nil
HealthUpdateFunction = nil
StanimaUpdateFunction = nil

SelectedTeam = Teams["Choosing Team"]
LoadedIn = false
CurrentScreen = nil

--// Setup
ReplicatedFirst:RemoveDefaultLoadingScreen()

--// Locals
MainUI 			= script.Parent
PlayerGui		= MainUI.Parent

PlayerList 		= PlayerGui:WaitForChild("PlayerList",100)

PlayerMenu 		= MainUI.PlayerUI
MainMenu 		= MainUI.MainMenu
--// Main Menu UI
CreditsMenuUI 	= MainMenu.CreditsMenu
MainMenuUI		= MainMenu.MainMenu
TeamsMenuUI 	= MainMenu.TeamsMenu
--// PlayerMenu UI
HealthSys 		= PlayerMenu.HealthSystem
StanimaSys 		= PlayerMenu.StaminaSystem
LevelSys 		= PlayerMenu.LevelSystem

--// Health Sys UI
HealthBar 		= HealthSys.Health
HealthBarNumber = HealthSys.Number

--// Stanima Sys UI
StanimaBar 		= StanimaSys.Stamina
StanimaBarNumber= StanimaSys.Number

--// CreditMenu UI
CreditMenuList 	= CreditsMenuUI.List

--// MainMenu UI
PlayButton 		= MainMenuUI.Play
CreditsButton 	= MainMenuUI.Credits
TeamChangeButton= MainMenuUI.TeamChange
UpdatesButton 	= MainMenuUI.Updates

function changegui(gui)
	local closeoldgui = function()

	end

	if gui == "play" then
		if SelectedTeam ~= Teams["Choosing Team"] then
			local response = SpawnFunc:InvokeServer(SelectedTeam)

			if response == 'load' then

				TweenService:Create(MainMenuUI,TweenInfo.new(1,Enum.EasingStyle.Quad,Enum.EasingDirection.In), {Position = UDim2.new(-1.046, 0,-0.045, 0)}):Play()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,true)
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat,true)
				PlayerMenu.Visible = true
				MainMenu.Visible = false

				PlayerList.Enabled = true

			else
				return response
			end
		else

		end

	elseif gui == "teams" then
		if CurrentScreen == TeamsMenuUI then
			local opentween = TweenService:Create(TeamsMenuUI, TweenInfo.new(1,Enum.EasingStyle.Quad,Enum.EasingDirection.In), {Position = UDim2.new(1.292, 0,0.144, 0)})
			opentween:Play()

			CurrentScreen = MainMenuUI
		else
			local opentween = TweenService:Create(TeamsMenuUI, TweenInfo.new(1,Enum.EasingStyle.Quad,Enum.EasingDirection.In), {Position = UDim2.new(0.292, 0,0.144, 0)})
			TeamsMenuUI.Visible = true
			opentween:Play()

			CurrentScreen = TeamsMenuUI
		end

	elseif gui == "credits" then
		if CurrentScreen == CreditsMenuUI then
			local opentween = TweenService:Create(CreditsMenuUI, TweenInfo.new(1,Enum.EasingStyle.Quad,Enum.EasingDirection.In), {Position = UDim2.new(1.046, 0,-0.080, 0)})
			opentween:Play()

			CurrentScreen = MainMenuUI
		else
			local opentween = TweenService:Create(CreditsMenuUI, TweenInfo.new(1,Enum.EasingStyle.Quad,Enum.EasingDirection.In), {Position = UDim2.new(-0.046, 0,-0.080, 0)})
			CreditsMenuUI.Visible = true
			opentween:Play()

			CurrentScreen = CreditsMenuUI
		end
	end
end

updatePlayerUI = function(char)
	Character = char
	if StanimaUpdateFunction then
		StanimaUpdateFunction:Disconnect()

	end
	if HealthUpdateFunction  then
		HealthUpdateFunction:Disconnect()
	end
	char:WaitForChild("Humanoid",10)
	local stan = char.GunClient.Vars.Stamina
	StanimaBarNumber.Text = math.floor(stan.Value)
	TweenService:Create(StanimaBar,TweenInfo.new(0.01,Enum.EasingStyle.Linear,Enum.EasingDirection.In),{Size = UDim2.new((stan.Value / 1000),0,1,0)}):Play()

	StanimaUpdateFunction = stan.Changed:Connect(function(h)

		StanimaBarNumber.Text = math.floor(stan.Value)
		TweenService:Create(StanimaBar,TweenInfo.new(0.01,Enum.EasingStyle.Linear,Enum.EasingDirection.In),{Size = UDim2.new((stan.Value / 1000),0,1,0)}):Play()
	end)

	TweenService:Create(HealthBar,TweenInfo.new(0.01,Enum.EasingStyle.Linear,Enum.EasingDirection.In),{Size = UDim2.new(char.Humanoid.Health / 100,0,1,0)}):Play()

	HealthBarNumber.Text = math.floor(char.Humanoid.Health)
	HealthUpdateFunction = char.Humanoid:GetPropertyChangedSignal("Health"):Connect(function(h)
		TweenService:Create(HealthBar,TweenInfo.new(0.01,Enum.EasingStyle.Linear,Enum.EasingDirection.In),{Size = UDim2.new(char.Humanoid.Health / 100,0,1,0)}):Play()
		HealthBarNumber.Text = math.floor(char.Humanoid.Health)
	end)

end

--// TeamsMenu UI
TeamsMenuList 	= TeamsMenuUI.List

TeamChangeButton.MouseButton1Click:Connect(function(plr)
	changegui("teams")
end)

for name,req in pairs(Config.Teams) do
	local color = Teams[name].TeamColor.Color
	local Allowed = false

	if TeamsMenuList:FindFirstChild(name) then
		local template = TeamsMenuList:FindFirstChild(name)
		template.Join.BackgroundColor3 = Color3.fromRGB(176, 18, 18)
		template.Join.ButtonText.Text = "LOCKED"
		template.TeamName.Text = name

		template.TeamName.TextColor3 = color

		for i,v in ipairs(req.bypass) do
			if v == Player.Name then
				Allowed = true
			end
		end
		if req["gamepass"] then
			if Market:UserOwnsGamePassAsync(Player.UserId,req["gamepassid"]) then
				Allowed = true
			end
		end
		if Player:GetRankInGroup(Config.GroupId) >= req.MinRank then
			Allowed = true
		end


		if Allowed then
			template.Join.ButtonText.Text = "JOIN"
			template.Join.BackgroundColor3 = Color3.fromRGB(104, 177, 78)
			template.Join.MouseButton1Click:Connect(function()
				if SelectedTeam ~= Teams["Choosing Team"] then
					TeamsMenuList[SelectedTeam.Name].Join.ButtonText.Text = "JOIN"
					TeamsMenuList[SelectedTeam.Name].Join.BackgroundColor3 = Color3.fromRGB(104, 177, 78)
				end
				template.Join.ButtonText.Text = "SELECTED"
				template.Join.BackgroundColor3 = Color3.fromRGB(34, 177, 2)
				SelectedTeam = Teams[name]
			end)

		end
	end

	local template = script:FindFirstChild("TeamTemplate"):Clone()

end

--// PlayMenu UI
PlayButton.MouseButton1Click:Connect(function(plr)
	changegui("play")
end)

--// Credits

for i,v in pairs(Config.Credits) do

	local clone = script:FindFirstChild("CreditsTemplate-"..v.Rank):Clone()
	clone.PlayerName.Text = v.Name
	clone.Parent = CreditMenuList
end

CreditsButton.MouseButton1Click:Connect(function(plr)
	changegui("credits")
end)

print("Everwood Correctional Facilities Main UI Loaded.")
print("Clearing Client Log.\n--------------------------------------------------------------\nEverwood Correctional Facility\nTrying to copy or use a leaked version of this game will result in\na report to Roblox moderation.\n\nMany thanks,\nNot_Lowest - Founder\nAidenGamingUk - Management.\n--------------------------------------------------------------")

CurrentScreen = MainMenuUI
Player.CharacterAdded:Connect(updatePlayerUI)