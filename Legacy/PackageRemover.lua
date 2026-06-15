local module = {}
RunService = game:GetService("RunService")

function module:Initialize()
	game:GetService("Players").PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function(char)
			for _,v in pairs(char:GetDescendants()) do
				if v:IsA("CharacterMesh") then
					v:Destroy()
						
				end
			end
		end)
	end)
end

return module
