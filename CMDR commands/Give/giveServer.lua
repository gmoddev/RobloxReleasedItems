local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Resources = ServerScriptService.Resources

local Logger = require(Resources.Logger)

return function(context,to,tool)
	print(tool)
	for _,v in pairs(ServerStorage.Tools:GetChildren()) do
		for i,g in pairs(tool) do
			if string.lower(v.Name) == string.lower(g.Name) then
				v:Clone().Parent = to.Backpack
				Logger.Log("Command",context.Executor,string.gsub(script.Name,"Server",""))
				return "Successfully gave ".. to.Name.. " ".. v.Name 
			end	
		end
		
	end

end