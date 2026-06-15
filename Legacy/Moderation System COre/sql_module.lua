m = {}
HttpService = game:GetService("HttpService")

local function Post(packet)
	local posted = HttpService:PostAsync("http://play.unturnedliferp.com:27049/v1", packet, Enum.HttpContentType.ApplicationJson, false)
	local returnData

	local success, err = pcall(function()
		returnData = HttpService:JSONDecode(posted)
	end)

	if not success then
		warn("======================== SQL | ERROR ========================")
		if err == "Can't parse JSON" then
			warn("======================== SQL | DUMPING POSTED ========================")
			warn(tostring(posted))
		else
			warn(err)
		end
		return err, returnData
	end

	warn("======================= SQL | SUCCESS =======================")
	return returnData
end

local sett ={
	SQL_HOST = "135.148.120.242",
	SQL_NAME = "astrotech_data",
	SQL_USER = "astrotech_astroteche",
	SQL_PASS = "9t8^%t89*%(tf8e^3w^9*(%*(£",
	SQL_DATABASE = "astrotech_data",
	SQL_PORT = "3306"
}

function m:Post(QuerySQL,sett,c)
	local Host = sett.SQL_HOST
	local Username = sett.SQL_USER
	local Password = sett.SQL_PASS
	local Database = sett.SQL_DATABASE
	local Port = sett.SQL_PORT

	if (Host or Username or Password or Database or Port) == nil then
		return("Host: ".. Host.. " Username: " .. Username.. " Password: ".. Password.. " Database: ".. Database.. "Port: "..Port)
	end

	local Data = {
		Host = Host,
		Username = Username,
		Password = Password,
		Database = Database,
		Port = Port,
		Query = QuerySQL
	}

	local response = Post(HttpService:JSONEncode(Data))
	if type(response) == "table" then
		if table.getn(response) == 0  then
			return nil
		end
	end
	return response
end

function m:ban(userid: number, length: number, reason: string, banner: string)



	local Query = "INSERT INTO bans (user_id, ban_length, created_at, ban_reason, banned_by) VALUES ("..userid..", "..length..", "..os.time()..", ".."'"..reason.."'"..", ".."'"..banner.."'"..")"

	local response = m.Post(nil,Query,sett)
	return response
end

function m:warn(userid: number, executor, reason)
	local Query = "INSERT INTO warns (user_id, created_at, executor, reason) VALUES ("..userid..", ".. os.time().. ", '".. executor.."', '"..reason.."'".. ")"

	local response = m.Post(nil,Query,sett)
	return response
end

function m:kick(userid,executor,reason)
	local Query = "INSERT INTO kicks (user_id, created_at, executor, reason) VALUES ("..userid..", ".. os.time().. ", '".. executor.."', '"..reason.."'".. ")"
	local response = m.Post(nil,Query,sett)
	return response
end

function m:get(userid)
	local Query = "SELECT * FROM `bans` WHERE user_id='"..userid.."'"
	local response = m.Post(nil,Query,sett)
	return response
end

function m:sendcmd(Query)
	local responses = {}
	for i,v in ipairs(Query) do
		local response = m.Post(nil,v,sett)
		table.insert(responses,i,response)
	end
	return responses
end

return m

