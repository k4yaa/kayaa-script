if not game:IsLoaded() then game.Loaded:Wait() end

repeat task.wait() until game:GetService("Players")
repeat task.wait() until game:GetService("Players").LocalPlayer
repeat task.wait() until game:GetService("Players").LocalPlayer.PlayerGui

local function missing(t, f, fallback)
	if type(f) == t then return f end
	return fallback
end
local cloneref = missing("function", cloneref, function(...) return ... end)
local httprequest = missing("function", request or http_request or (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request))

local Services = setmetatable({}, {
	__index = function(self, key)
		local ok, svc = pcall(function()
			return cloneref(game:GetService(key))
		end)
		if ok and svc then
			rawset(self, key, svc)
			return svc
		end
	end
})

local Players = Services.Players
local Client = Players.LocalPlayer
local HttpService = Services.HttpService
local TeleportService = Services.TeleportService
local ReplicatedStorage = Services.ReplicatedStorage
local PlaceId, JobId = game.PlaceId, game.JobId

local API_URL = "https://reggae-jolliness-sworn.ngrok-free.dev/api/update"

local API_KEY = getgenv().kayaatrackstat.KEY or "changeme-secret"

if API_KEY == "changeme-secret" then
	warn("Wrong Key")
end

getgenv().SESSION = getgenv().SESSION or HttpService:GenerateGUID(false)
local SESSION_ID = getgenv().SESSION

if game.PlaceId ~= 142823291 and game.PlaceId ~= 335132309 and game.PlaceId ~= 636649648 then
	warn("[RSKD] wrong game:", game.PlaceId)
	return
end
local Tracker = {
	Item = {"HeartWand", "HeartWandChroma"}
}

local function toRoman(num)
	if not num or num <= 0 then return "" end
	if type(num) == "string" then
		local n = tonumber(num)
		if not n then return num end
		num = n
	end
	local val = {100, 90, 50, 40, 10, 9, 5, 4, 1}
	local syb = {"C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"}
	local roman = ""
	for i = 1, #val do
		while num >= val[i] do
			roman = roman .. syb[i]
			num = num - val[i]
		end
	end
	return roman
end

local function getProfileTable()
	local modules = ReplicatedStorage:WaitForChild("Modules", 3)
	if not modules then return nil end

	local moduleNames = {"ProfileData", "PlayerData", "Profile", "PlayerProfile"}
	for _, name in ipairs(moduleNames) do
		local mod = modules:FindFirstChild(name)
		if mod then
			local ok, res = pcall(require, mod)
			if ok and res then
				if type(res) == "table" then
					local playerEntry = res[Client] or res[Client.Name] or res[tostring(Client.UserId)]
					if type(playerEntry) == "table" then
						return playerEntry
					end
					return res
				end
			end
		end
	end
	return nil
end

function Tracker:GetProfileValue(key)
	local prof = getProfileTable()
	if prof then
		local lowerKey = string.lower(key)
		for k, v in pairs(prof) do
			if string.lower(k) == lowerKey then
				return v
			end
		end
		if prof.Materials and prof.Materials.Owned then
			for k, v in pairs(prof.Materials.Owned) do
				if string.lower(k) == lowerKey then
					return v
				end
			end
		end
	end
	return nil
end

function Tracker:GetCurrency(Type)
	local val = self:GetProfileValue(Type)
	if val then return val end

	local leaderstats = Client:FindFirstChild("leaderstats")
	local leaderVal = leaderstats and leaderstats:FindFirstChild(Type)
	if leaderVal then return leaderVal.Value end

	return 0
end

function Tracker:getLevelData()
	local prestige = 0
	local level = 0

	local profPres = self:GetProfileValue("Prestige") or self:GetProfileValue("Pres")
	local profLvl = self:GetProfileValue("Level") or self:GetProfileValue("Lvl")
	if profPres then prestige = profPres end
	if profLvl then level = profLvl end

	local ok, ProfileData = pcall(function()
		local modulesFolder = ReplicatedStorage:WaitForChild("Modules", 3)
		if modulesFolder then
			return require(modulesFolder:WaitForChild("ProfileData", 3))
		end
	end)
	if ok and ProfileData then
		for k, v in pairs(ProfileData) do
			if type(v) == "table" then
				for k2, v2 in pairs(v) do
				end
			end
		end
	end

	local leaderstats = Client:FindFirstChild("leaderstats")
	if leaderstats then
		for _, child in ipairs(leaderstats:GetChildren()) do
			local lName = string.lower(child.Name)
			if lName == "prestige" or lName == "pres" then
				prestige = child.Value
			elseif lName == "level" or lName == "lvl" then
				level = child.Value
			end
		end
	end

	local attrOk, attrs = pcall(function() return Client:GetAttributes() end)
	if attrOk and attrs then
		for k, v in pairs(attrs) do
			local lk = string.lower(k)
			if lk == "prestige" or lk == "pres" or lk == "prestigelevel" then
				prestige = v
			elseif lk == "level" or lk == "lvl" then
				level = v
			end
		end
	end

	pcall(function()
		local pg = Client:FindFirstChild("PlayerGui")
		local mainGui = pg and pg:FindFirstChild("MainGui")
		local gameFolder = mainGui and mainGui:FindFirstChild("Game")
		local lobby = gameFolder and gameFolder:FindFirstChild("Lobby")
		local xp = lobby and lobby:FindFirstChild("XP")
		if xp then
			local lvlLabel = xp:FindFirstChild("Level") or xp:FindFirstChild("LevelLabel")
			if lvlLabel and lvlLabel:IsA("TextLabel") then
				local lvlNum = tonumber(lvlLabel.Text:match("%d+"))
				if lvlNum and level == 0 then
					level = lvlNum
				end
			end
			local presLabel = xp:FindFirstChild("Prestige") or xp:FindFirstChild("PrestigeLabel")
			if presLabel and presLabel:IsA("TextLabel") then
				local presNum = tonumber(presLabel.Text:match("%d+"))
				if presNum and prestige == 0 then
					prestige = presNum
				end
			end
		end
	end)


	return prestige, level
end

local function snapshot()
    local trackedItems = {}

    local prestige, level = Tracker:getLevelData()
    
    local finalLevel = tonumber(level)
    if prestige > 0 then
        finalLevel = toRoman(prestige) .." ".. finalLevel
    end

    return {
        userId = Client.UserId,
        username = Client.Name,
        session = SESSION_ID,
        online = true,
        level = finalLevel, 
        coin = Tracker:GetCurrency("Coins"),
        items = trackedItems,
        pc = getgenv().kayaatrackstat.DISPLAYS.PC or "PC-1",
        game = "MM2",
        ts = os.time(),
    }
end


local function send()
	local payload = snapshot()

	local ok, res = pcall(function()
		return httprequest({
			Url = API_URL,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["X-API-Key"] = API_KEY,
				["ngrok-skip-browser-warning"] = "1",
			},
			Body = HttpService:JSONEncode(payload),
		})
	end)

	if ok and res then
		print("[Roblox][TRACKER] send 15.0s")
	end
end


task.spawn(function()
	while true do
		pcall(send)
		task.wait(15)
	end
end)

local SCRIPT_URL = "https://pastefy.app/9YPWW2wZ/raw"

local function queueSelf()
	local code = ([[
        getgenv().kayaatrackstat.KEY = %q
        getgenv().kayaatrackstat.DISPLAYS.PC = %q
        getgenv().SESSION = %q
        loadstring(game:HttpGet(%q))()
    ]]):format(
		getgenv().kayaatrackstat.KEY or "",
		getgenv().kayaatrackstat.DISPLAYS.PC or "PC-1",
		SESSION_ID,
		SCRIPT_URL
	)

	if queue_on_teleport then
		queue_on_teleport(code)
	elseif syn and syn.queue_on_teleport then
		syn.queue_on_teleport(code)
	end
end

local okOnTp, err = pcall(function()
	Client.OnTeleport:Connect(function(state)
		if state == Enum.TeleportState.Started then
			queueSelf()
		end
	end)
end)

if not okOnTp then
	queueSelf()
end
