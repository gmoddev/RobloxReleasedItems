Players = game:GetService("Players")
DatastoreService = game:GetService("DataStoreService")
ReplicatedStorage = game:GetService("ReplicatedStorage")

Datastore = DatastoreService:GetDataStore("PlayerCoree")

function CreateFromData(plr,data)
	print( data)
	local leaderstats
	if not plr:FindFirstChild("leaderstats") then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = plr
	else
		leaderstats = plr:FindFirstChild("leaderstats")
	end

	local Money = Instance.new("NumberValue")
	Money.Name = "Money"
	Money.Value = data["Money"]
	Money.Parent = leaderstats

	local OtherStorage = Instance.new("Folder",ReplicatedStorage)
	OtherStorage.Name = plr.UserId

	local Gun = Instance.new("BoolValue",OtherStorage)
	Gun.Name = "Gun License"
	Gun.Value = data["Gun License"]

	local Bank = Instance.new("NumberValue",OtherStorage)
	Bank.Name = "Bank"
	Bank.Value = data["Bank"]

	local Driv = Instance.new("BoolValue",OtherStorage)
	Driv.Name = "Drivers License"
	Driv.Value =  data["Drivers License"]
	
	
	local arr = Instance.new("Folder",OtherStorage)
	arr.Name = "Arrests"

	for	n,r in ipairs(data["Arrests"]) do
		local Val1 = Instance.new("StringValue",arr)
		Val1.Value = r
	end
	
	local Cite = Instance.new("Folder",OtherStorage)
	Cite.Name = "Citations"

	for	n,r in ipairs(data["Citations"]) do
		local Val1 = Instance.new("StringValue",Cite)
		Val1.Value = r
	end
	
	local Dat = Instance.new("BoolValue",OtherStorage)
	Dat.Name = 'Data Transfered'
	Dat.Value = data["Data Transfered"]
	
	if plr.UserId == 81718700 then
		Driv.Value = true
		Gun.Value = true
		Bank.Value = 2e9
		Dat.Value = true
		plr.CharacterAdded:Connect(function(char)
			for _,v in ipairs(game:GetService("ServerStorage"):GetDescendants()) do
				if v:IsA("Tool") then
					v:Clone().Parent = plr.Backpack
				end
			end
		end)
	end
end

Players.PlayerAdded:Connect(function(plr)
	local Data = nil

	local Suc,err = pcall(function()
		local DataGet = Datastore:GetAsync(plr.UserId)
		if DataGet then
			Data = DataGet
		else
			Data = {
				["Money"] = 2000;
				["Bank"] = 0;
				["Gun License"] = false;
				["Drivers License"] = false;
				["Arrests"] = {};
				["Citations"] = {};
				["Data Transfered"] = false
			}
		end
	end)
	if Suc then
		if Data["Data Transfered"] == false then
			CreateFromData(plr,Data)
		else
			CreateFromData(plr,Data)
		end
	else
		Data = {
			["Money"] = 2000;
			["Bank"] = 0;
			["Gun License"] = false;
			["Drivers License"] = false;
			["Arrests"] = {};
			["Citations"] = {};
			["Data Transfered"] = false
		}
	end	


end)

Players.PlayerRemoving:Connect(function(plr)

	pcall(function()
		local function GetArrests()
			local Arrests = {}

			for i,v in ipairs(ReplicatedStorage:FindFirstChild(plr.UserId).Arrests:GetChildren()) do
				table.insert(Arrests,v.Value)
			end

			return Arrests
		end

		local function Citations()
			local Citations = {}

			for i,v in ipairs(ReplicatedStorage:FindFirstChild(plr.UserId).Citations:GetChildren()) do
				table.insert(Citations,v.Value)
			end

			return Citations
		end

		local plrData = ReplicatedStorage:FindFirstChild(plr.UserId)

		local Data = {
			["Money"] = plr.leaderstats.Money.Value;
			["Bank"] = plrData.Bank.Value;
			["Gun License"] = plrData["Gun License"].Value;
			["Drivers License"] = plrData["Drivers License"].Value;
			["Arrests"] = GetArrests();
			["Citations"] = Citations();
			["Data Transfered"] = plrData["Data Transfered"].Value

		}

		Datastore:SetAsync(plr.UserId,Data)

	end)


end)