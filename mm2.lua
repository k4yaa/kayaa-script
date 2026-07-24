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

local API_BASE = "http://localhost:3000"
local API_URL = API_BASE .. "/api/update"
local CONFIG_URL = API_BASE .. "/api/config"

local KAYAA_LOG = type(getgenv().trackstat) == "table" and getgenv().trackstat or type(getgenv().kayaatrackstat) == "table" and getgenv().kayaatrackstat or type(getgenv().kayaalog) == "table" and getgenv().kayaalog or {}
local DISPLAY_CONFIG = type(KAYAA_LOG.DISPLAYS) == "table" and KAYAA_LOG.DISPLAYS or {}
local API_KEY = KAYAA_LOG.KEY or getgenv().KEY or "changeme-secret"
local PC_NAME = DISPLAY_CONFIG.PC or getgenv().PC or "PC-1"

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
	Item = {"IcecreamChroma", "Icecream", "Bubbles_K_2026"}
}

local function cleanString(str)
	str = tostring(str or "")
	return str:gsub("|", ""):gsub(";", "")
end

local function getBodyFromUrl(url)
	if httprequest then
		local ok, res = pcall(function()
			return httprequest({
				Url = url,
				Method = "GET",
				Headers = {
					["ngrok-skip-browser-warning"] = "1",
					["User-Agent"] = "Roblox"
				}
			})
		end)
		if ok and res and res.Body then
			return res.Body
		end
	end

	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok then return body end
	return nil
end

local function loadTrackedItemsFromBackend()
	local body = getBodyFromUrl(CONFIG_URL)
	if type(body) ~= "string" or body == "" then return end

	local ok, cfg = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if not ok or type(cfg) ~= "table" or type(cfg.games) ~= "table" then return end

	for _, gameConfig in ipairs(cfg.games) do
		if type(gameConfig) == "table" and tostring(gameConfig.id or ""):lower() == "mm2" then
			local fieldKeys = {}
			if type(gameConfig.fields) == "table" then
				for _, field in ipairs(gameConfig.fields) do
					if type(field) == "table" and type(field.key) == "string" then
						fieldKeys[field.key] = true
					end
				end
			end

			local nextItems = {}
			local seen = {}
			if type(gameConfig.monitors) == "table" then
				for _, monitor in ipairs(gameConfig.monitors) do
					if type(monitor) == "table" and type(monitor.key) == "string" and fieldKeys[monitor.key] and not seen[monitor.key] then
						table.insert(nextItems, monitor.key)
						seen[monitor.key] = true
					end
				end
			end

			if #nextItems > 0 then
				Tracker.Item = nextItems
			end
			break
		end
	end
end

loadTrackedItemsFromBackend()

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

local function CheckInventory()
	local itemAmounts = {}
	local allItems = {}

	for _, itemName in ipairs(Tracker.Item) do
		itemAmounts[itemName] = 0
	end
	local success, result = pcall(function()
		return ReplicatedStorage.Remotes.Extras.GetData:InvokeServer("Weapons")
	end)

	if success and result and result.Owned then
		for name, amount in pairs(result.Owned) do
			if itemAmounts[name] ~= nil then
				local count = tonumber(amount) or 0
				itemAmounts[name] = count
				if count > 0 then
					table.insert(allItems, cleanString(name) .. " x" .. tostring(count))
				end
			end
		end
	end
	return itemAmounts, table.concat(allItems, ", ")
end
local function snapshot()
    local itemAmounts, trackedItems = CheckInventory()

    local prestige, level = Tracker:getLevelData()
    
    local finalLevel = tonumber(level) or level
	local prestigeNumber = tonumber(prestige) or 0
    if prestigeNumber > 0 then
        finalLevel = toRoman(prestigeNumber) .. " " .. tostring(finalLevel)
    end

    local payload = {
        userId = Client.UserId,
        username = Client.Name,
        session = SESSION_ID,
        online = true,
        level = finalLevel, 
        coin = Tracker:GetCurrency("Coins"),
        items = trackedItems,
        pc = PC_NAME,
        game = "MM2",
        ts = os.time(),
    }

	for itemName, amount in pairs(itemAmounts) do
		payload[itemName] = amount
	end

	return payload
end


local maintenanceWarned = false

local function send()
	if not httprequest then
		warn("[TRACKER] httprequest is nil — executor ไม่รองรับ http request")
		return false
	end

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

	if not ok or not res then
		warn("[TRACKER] send FAILED:", tostring(res))
		return false
	end

	-- ── Maintenance mode detection ──────────────────────────
	if res.StatusCode == 503 then
		local bodyOk, bodyData = pcall(function()
			return HttpService:JSONDecode(res.Body or "{}")
		end)
		if bodyOk and type(bodyData) == "table" and bodyData.maintenance then
			if not maintenanceWarned then
				warn("[TRACKER] 🔧 Server is under maintenance — pausing sync for 60s")
				maintenanceWarned = true
			end
			return true -- signal: maintenance, caller should back off
		end
	end

	if maintenanceWarned then
		print("[TRACKER] Maintenance ended — resuming normal sync")
		maintenanceWarned = false
	end

	if res.StatusCode == 200 then
		print("[TRACKER] send OK | status:", res.StatusCode, "| url:", API_URL)
	else
		warn("[TRACKER] send WARN | status:", res.StatusCode, "| body:", tostring(res.Body):sub(1, 80))
	end
	return false
end


task.spawn(function()
	while true do
		local callOk, isMtn = pcall(send)
		if callOk and isMtn == true then
			task.wait(60) -- maintenance back-off: server is under maintenance
		else
			task.wait(15) -- normal interval
		end
	end
end)

local SCRIPT_URL = "https://raw.githubusercontent.com/k4yaa/kayaa-script/refs/heads/main/mm2.lua"

local function queueSelf()
	local code = ([[
        getgenv().trackstat = getgenv().trackstat or {}
        getgenv().trackstat.DISPLAYS = getgenv().trackstat.DISPLAYS or {}
        getgenv().trackstat.KEY = %q
        getgenv().trackstat.DISPLAYS.PC = %q
        getgenv().SESSION = %q
        loadstring(game:HttpGet(%q))()
    ]]):format(
		API_KEY,
		PC_NAME,
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
