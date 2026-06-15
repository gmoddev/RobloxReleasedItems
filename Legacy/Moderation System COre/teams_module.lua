ReplicatedStorage = game:GetService("ReplicatedStorage")
Teams = game:GetService("Teams")

Remotes = ReplicatedStorage.ServerRemotes
Config = require(ReplicatedStorage.Moderation)

local Spawn = Remotes.Spawn

function functeam(teamname)
	local succ, err = pcall(function(team)
		local thing = Teams[teamname]
		thing = thing
	end)
	return succ
end

return {
	
	Init = function()
		Spawn.OnServerInvoke = function(plr,team: Team)
			print(team)
			if not Teams:FindFirstChild(team.Name) then
				return "banned"
			end

			if functeam(team.Name) then
				local TeamConfig = Config.Teams[team.Name]
				
				if plr:GetRankInGroup(Config.GroupId) >= TeamConfig.MinRank or table.find(TeamConfig.bypass,plr.Name) then
					coroutine.resume(coroutine.create(function()
						plr.Team = Teams[team.Name]
						task.wait(0.04)
						plr:LoadCharacter()
					end))
					
					return "load"
				else
					return "Not Allowed"
				end
				
			end
		end
	end,
}