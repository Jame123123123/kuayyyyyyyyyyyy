local CONFIG = {
	Key      = "BaseAccel",   -- ชื่อ Value / Attribute ที่จะยัด
	Amount   = 100,          -- ค่าที่จะยัด
	Container = nil,          -- nil = หาเอง | ใส่ชื่อถ้าอยากล็อกเอง เช่น "SpawnedVehicles"
	Defend   = true,          -- true = ดันค่ากลับถ้าโดนเขียนทับ
	Poll     = 1.0,           -- สแกนซ้ำทุกกี่วินาที (nil = ปิด)
	OnlyOther = false,        -- true = ไม่แตะรถของตัวเอง
	Verbose  = true,

	-- ชื่อ player ที่จะเล็dง: {} = ทุกคน | {"bnzvu3m"} | {"a","b","c"}
	Players  = { "bnzvu3m", "pv_ntwpp","lizukamulu3802", },

	OnNotListed = "ignore",   -- "ignore" | "log" | "kick"
	KickMessage = "ควย 50 บาทเองทักมา IG:graphic.ggt",

	-- เช็คไลเซนส์ตอนรัน: ชื่อใครไม่อยู่ใน Players = เตะออกทันที
	Whitelist = true,
	DebugWhitelist = false,   -- true = พิมพ์ชื่อจริง/norm ออกมาให้ดูว่าทำไมไม่ผ่าน

	-- ทางเตะคนอื่น: ต้องยิง remote ของเกม (client เตะเองไม่ได้)
	-- หา remote ด้วย remote_spy.lua แล้วใส่ path ที่นี่
	KickRemote = nil,   -- เช่น "ReplicatedStorage.Remotes.KickPlayer"
	KickArgs   = nil,   -- function(owner) return {owner, "kuy"} end

	-- Discord webhook log
	Webhook     = "https://ptb.discord.com/api/webhooks/1570447603395465376/PI-LjCsL1SQ6WVTcdV9EaWDJI0KX-msicpQMk3sGvchcRfC1REgzjEGXHWA-YYGzJBtj",              -- ใส่ URL ของ webhook ที่นี่
	WebhookName = "Mahanakhon Log",
	LogInfect   = true,            -- ส่งสรุปการติดเชื้อเป็นช่วงๆ
	LogInterval = 15,              -- ทุกกี่วินาที
}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------
-- Discord webhook
------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local pending = {}

local function webhookReady()
	return type(CONFIG.Webhook) == "string" and CONFIG.Webhook:find("discord", 1, true) ~= nil
end

local function httpRequest()
	return (syn and syn.request) or (http and http.request) or http_request or request
end

local function postNow(payload)
	if not webhookReady() then return false end
	local req = httpRequest()
	if not req then return false end
	local ok, body = pcall(function() return HttpService:JSONEncode(payload) end)
	if not ok then return false end
	return (pcall(function()
		req({
			Url = CONFIG.Webhook,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = body,
		})
	end))
end

local function nowISO()
	local ok, s = pcall(function() return DateTime.now():ToIsoDate() end)
	return ok and s or nil
end

local function embed(title, desc, color, fields)
	local e = {
		title = title,
		description = desc,
		color = color or 3447003,
		timestamp = nowISO(),
		footer = { text = CONFIG.WebhookName },
	}
	if fields then e.fields = fields end
	return e
end

-- เข้าคิวไว้ ยิงรวมทีละหลาย embed กัน rate limit
local function queue(e)
	if not webhookReady() then return end
	pending[#pending + 1] = e
end

task.spawn(function()
	while true do
		task.wait(3)
		if #pending > 0 then
			local batch = {}
			while #pending > 0 and #batch < 8 do
				batch[#batch + 1] = table.remove(pending, 1)
			end
			postNow({ username = CONFIG.WebhookName, embeds = batch })
		end
	end
end)

local function executorName()
	local ok, name = pcall(function()
		if identifyexecutor then return (select(1, identifyexecutor())) end
		return "unknown"
	end)
	return (ok and name) or "unknown"
end

local stats = { infected = 0, owners = {}, started = os.clock() }

------------------------------------------------------------
-- ไลเซนส์: ไม่มีชื่อใน CONFIG.Players = เตะทิ้งทันที ไม่ต้องรออะไร
------------------------------------------------------------
-- normalize: ตัดทุกอย่างที่ไม่ใช่ a-z 0-9 _ ออก (ช่องว่าง, zero-width, ตัวอักษรแปลก)
-- กันเคสพิมพ์ชื่อแล้วมีอักขระซ่อนติดมา
local function norm(s)
	return (tostring(s or ""):lower():gsub("[^%w_]", ""))
end

local function whitelistMatch(entry)
	local e = tostring(entry)
	local n = norm(e)
	if n ~= "" then
		if n == norm(LocalPlayer.Name) then return "Name" end
		if n == norm(LocalPlayer.DisplayName) then return "DisplayName" end
	end
	local id = tonumber(e)
	if id and id == LocalPlayer.UserId then return "UserId" end
	return nil
end

if CONFIG.DebugWhitelist then
	print("[VIRUS] Name        =", ("%q"):format(LocalPlayer.Name))
	print("[VIRUS] DisplayName =", ("%q"):format(LocalPlayer.DisplayName))
	print("[VIRUS] UserId      =", LocalPlayer.UserId)
	for i, n in ipairs(CONFIG.Players) do
		print(("[VIRUS] CONFIG.Players[%d] = %q  -> norm %q"):format(i, tostring(n), norm(n)))
	end
	print("[VIRUS] Name -> norm", ("%q"):format(norm(LocalPlayer.Name)))
end

if CONFIG.Whitelist and CONFIG.Players and #CONFIG.Players > 0 then
	local allowed, how = false, nil
	for _, entry in ipairs(CONFIG.Players) do
		local m = whitelistMatch(entry)
		if m then allowed, how = true, m break end
	end

	if not allowed then
		if CONFIG.DebugWhitelist then
			-- โหมด debug: ไม่เตะ แค่บอกว่าติดตรงไหน เพื่อให้เอา log มาดูได้
			warn("[VIRUS] ไลเซนส์ไม่ผ่าน (debug mode: ไม่เตะ) — เทียบ log ด้านบน")
			warn("[VIRUS] ต้องได้ norm(Name) ตรงกับ norm ของชื่อใน CONFIG.Players")
		else
			postNow({
			username = CONFIG.WebhookName,
			embeds = {
				embed("ไม่ผ่านไลเซนส์ — เตะออก", "ชื่อไม่ได้อยู่ใน CONFIG.Players", 15158332, {
					{ name = "Player.Name", value = ("`%s`"):format(LocalPlayer.Name), inline = true },
					{ name = "DisplayName", value = ("`%s`"):format(LocalPlayer.DisplayName), inline = true },
					{ name = "UserId", value = tostring(LocalPlayer.UserId), inline = true },
					{ name = "norm(Name)", value = ("`%s`"):format(norm(LocalPlayer.Name)), inline = false },
					{ name = "CONFIG.Players", value = ("`%s`"):format(table.concat(
						(function()
							local t = {}
							for _, v in ipairs(CONFIG.Players) do t[#t + 1] = tostring(v) end
							return t
						end)(), "`, `")), inline = false },
					{ name = "Place / JobId", value = tostring(game.PlaceId) .. " / " .. tostring(game.JobId), inline = false },
					{ name = "Executor", value = executorName(), inline = true },
					{ name = "Kick message", value = CONFIG.KickMessage, inline = true },
				}),
			},
		})
			task.wait(0.8) -- ให้ webhook ส่งออกก่อนโดนตัดการเชื่อมต่อ
			pcall(function() LocalPlayer:Kick(CONFIG.KickMessage) end)
			return -- ไม่ให้ส่วนที่เหลือของสคริปต์รันต่อ
		end
	end

	if CONFIG.DebugWhitelist then
		print("[VIRUS] whitelist passed by", how)
	end
end

queue(embed("Script เริ่มทำงาน", nil, 3066993, {
	{ name = "Player", value = LocalPlayer.Name, inline = true },
	{ name = "UserId", value = tostring(LocalPlayer.UserId), inline = true },
	{ name = "Place", value = tostring(game.PlaceId), inline = true },
	{ name = "JobId", value = tostring(game.JobId), inline = false },
	{ name = "Executor", value = executorName(), inline = true },
	{ name = "Targets", value = #CONFIG.Players > 0 and table.concat(CONFIG.Players, ", ") or "(ทุกคน)", inline = false },
}))

local registry = setmetatable({}, { __mode = "k" })
local conns = {}
local running = true
local container -- จะถูกตั้งตอนสแกน

local function log(...)
	if CONFIG.Verbose then print("[VIRUS]", ...) end
end

------------------------------------------------------------
-- ลิสต์เป้าหมาย
------------------------------------------------------------
local targets = nil

local function rebuildTargets()
	targets = nil
	if CONFIG.Players and #CONFIG.Players > 0 then
		targets = {}
		for _, n in ipairs(CONFIG.Players) do
			local key = norm(n)
			if key ~= "" then targets[key] = true end
		end
	end
end
rebuildTargets()

local function isTargeted(owner)
	if not targets then return true end
	return targets[norm(owner)] == true
end

------------------------------------------------------------
-- เตะ (client เตะได้แค่ตัวเอง)
------------------------------------------------------------
local function kickLocal(msg)
	local ok, err = pcall(function() LocalPlayer:Kick(msg or CONFIG.KickMessage) end)
	if not ok then
		log("kickLocal failed:", err, "-> executor อาจบล็อก Kick, ลอง kickOut/remote แทน")
	end
	return ok
end

local function enforceSelf()
	if not isTargeted(LocalPlayer.Name) then
		kickLocal(CONFIG.KickMessage)
		return true
	end
	return false
end

local function findKickRemotes()
	local out = {}
	for _, d in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
		if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
			local n = d.Name:lower()
			if n:find("kick", 1, true) or n:find("ban", 1, true) or n:find("remove", 1, true) then
				table.insert(out, d:GetFullName())
			end
		end
	end
	if #out == 0 then log("ไม่เจอ remote ที่ชื่อมี kick/ban/remove") end
	for _, v in ipairs(out) do log("remote:", v) end
	return out
end

------------------------------------------------------------
-- เตะคนอื่น = ยิง remote ของเกม (client เตะเองไม่ได้)
------------------------------------------------------------
local function resolvePath(path)
	local node = game
	for part in tostring(path):gmatch("[^%.]+") do
		node = node and node:FindFirstChild(part)
		if not node then return nil end
	end
	return node
end

local function kickOut(owner)
	if owner and owner:lower() == LocalPlayer.Name:lower() then
		return kickLocal(CONFIG.KickMessage)
	end

	if not CONFIG.KickRemote then
		log("kickOut: ยังไม่ได้ตั้ง CONFIG.KickRemote — หา remote ด้วย remote_spy.lua ก่อน")
		return false
	end

	local remote = resolvePath(CONFIG.KickRemote)
	if not remote then
		log("kickOut: ไม่เจอ remote ->", CONFIG.KickRemote)
		return false
	end

	local args = CONFIG.KickArgs and CONFIG.KickArgs(owner) or { owner, CONFIG.KickMessage }
	local ok, err = pcall(function()
		if remote:IsA("RemoteFunction") then
			remote:InvokeServer(table.unpack(args))
		else
			remote:FireServer(table.unpack(args))
		end
	end)
	log("kickOut", tostring(owner), ok and "sent" or ("failed: " .. tostring(err)))
	return ok
end

------------------------------------------------------------
-- หาเจ้าของรถ โดยไม่ต้องรู้ชื่อรุ่น
------------------------------------------------------------
local OWNER_ATTRS = {
	"Owner", "OwnerName", "Player", "PlayerName", "PlrName",
	"OwnerId", "UserId", "Creator", "Driver", "UserName",
}

-- "VESPA_S_bnzvu3m_3792" -> "VESPA_S_bnzvu3m"  (ตัด _<ตัวเลข> ที่ Roblox เติมให้)
local function stripCounter(name)
	return (name:gsub("_%d+$", ""))
end

-- 1) attribute  2) คนขับ  3) ชื่อ model ลงท้ายด้วยชื่อ player จริง  4) ชื่อดิบ
local function ownerOf(obj)
	for _, attr in ipairs(OWNER_ATTRS) do
		local v = obj:GetAttribute(attr)
		if type(v) == "string" and v ~= "" then return v end
		if type(v) == "number" and v > 0 then
			local p = Players:GetPlayerByUserId(v)
			if p then return p.Name end
		end
	end

	local seat = obj:FindFirstChildWhichIsA("VehicleSeat", true)
	if seat and seat.Occupant then
		local char = seat.Occupant.Parent
		local p = char and Players:GetPlayerFromCharacter(char)
		if p then return p.Name end
	end

	local base = stripCounter(obj.Name):lower()
	local best
	for _, p in ipairs(Players:GetPlayers()) do
		local n = p.Name:lower()
		if #base > #n and base:sub(-#n - 1) == "_" .. n then
			if not best or #p.Name > #best then best = p.Name end
		end
	end
	if best then return best end

	if base ~= "" then return base end
	return nil
end

------------------------------------------------------------
-- หา BaseAccel + เขียนค่า
------------------------------------------------------------
local function findAccel(veh)
	for _, d in ipairs(veh:GetDescendants()) do
		if d.Name == CONFIG.Key and d:IsA("ValueBase") then return d end
	end
	if veh:GetAttribute(CONFIG.Key) ~= nil then return "attribute" end
	return nil
end

local function write(veh, accel)
	if accel == "attribute" then
		if veh:GetAttribute(CONFIG.Key) ~= CONFIG.Amount then
			veh:SetAttribute(CONFIG.Key, CONFIG.Amount)
		end
	elseif typeof(accel) == "Instance" and accel:IsA("ValueBase") then
		if accel.Value ~= CONFIG.Amount then accel.Value = CONFIG.Amount end
	end
end

local function release(veh)
	local rec = registry[veh]
	if not rec then return end
	for _, c in ipairs(rec.conns) do
		pcall(function() c:Disconnect() end)
	end
	registry[veh] = nil
end

local function attach(veh, accel)
	local rec = registry[veh]
	if not rec or rec.accel == accel then return end
	rec.accel = accel

	write(veh, accel)

	if CONFIG.Defend then
		if accel == "attribute" then
			table.insert(rec.conns, veh:GetAttributeChangedSignal(CONFIG.Key):Connect(function()
				write(veh, accel)
			end))
		else
			table.insert(rec.conns, accel:GetPropertyChangedSignal("Value"):Connect(function()
				write(veh, accel)
			end))
		end

		table.insert(rec.conns, veh.DescendantAdded:Connect(function(d)
			if d.Name == CONFIG.Key and d:IsA("ValueBase") then
				task.defer(attach, veh, d)
			end
		end))
	end

	table.insert(rec.conns, veh.AncestryChanged:Connect(function()
		if not veh:IsDescendantOf(workspace) then release(veh) end
	end))

	log("infected", veh.Name, "| owner:", rec.owner, "|", accel == "attribute" and "attr" or accel.ClassName)

	stats.infected = stats.infected + 1
	stats.owners[rec.owner] = (stats.owners[rec.owner] or 0) + 1
end

------------------------------------------------------------
-- ติดเชื้อ
------------------------------------------------------------
local function infect(obj)
	if not running then return end
	if not obj or not obj:IsA("Model") then return end
	if registry[obj] then return end

	local owner = ownerOf(obj)
	if not owner then return end
	if not isTargeted(owner) then
		if CONFIG.OnNotListed == "kick" then
			kickOut(owner)
		elseif CONFIG.OnNotListed == "log" then
			log("skip (not in list):", owner)
		end
		return
	end
	if CONFIG.OnlyOther and owner:lower() == LocalPlayer.Name:lower() then return end

	registry[obj] = { conns = {}, owner = owner }

	local accel = findAccel(obj)
	if accel then
		return attach(obj, accel)
	end

	-- ยังไม่มี BaseAccel (เพิ่งสปอว์น) -> ดักรอสั้นๆ
	task.spawn(function()
		local waited = 0
		while running and registry[obj] and waited < 4 do
			task.wait(0.2)
			waited = waited + 0.2
			local a = findAccel(obj)
			if a then return attach(obj, a) end
			if not obj.Parent then break end
		end
		if registry[obj] then release(obj) end
	end)
end

------------------------------------------------------------
-- หา container เอง (ไม่ต้องใส่ชื่อรถ)
------------------------------------------------------------
local function getContainer()
	-- cache ไว้ ไม่งั้นสแกนทุกวิจะไล่ workspace ใหม่ตลอด
	if container then
		if container == workspace or container:IsDescendantOf(workspace) then
			return container
		end
		container = nil
	end

	if CONFIG.Container then
		local c = workspace:FindFirstChild(CONFIG.Container)
		if c then container = c end
		return c
	end

	local named = workspace:FindFirstChild("SpawnedVehicles")
	if named then
		container = named
		return named
	end

	-- ไล่หา folder/model ที่มีลูกซึ่งข้างในมี BaseAccel
	for _, o in ipairs(workspace:GetChildren()) do
		if o:IsA("Folder") or o:IsA("Model") then
			for _, c in ipairs(o:GetChildren()) do
				if c:IsA("Model") and c:FindFirstChild(CONFIG.Key, true) then
					log("container =", o:GetFullName())
					container = o
					return o
				end
			end
		end
	end

	-- สุดท้าย: สแกนทั้ง workspace (เอาแค่ Model ที่มี BaseAccel)
	log("ไม่เจอ container -> สแกน workspace ตรงๆ")
	container = workspace
	return workspace
end

local function scan()
	if not running then return end
	local sv = getContainer()
	if not sv then return end
	container = sv

	if sv == workspace then
		-- fallback: กรองเอาแต่ Model ที่มี BaseAccel ข้างใน
		for _, o in ipairs(workspace:GetChildren()) do
			if o:IsA("Model") and o:FindFirstChild(CONFIG.Key, true) then
				infect(o)
			end
		end
	else
		for _, o in ipairs(sv:GetChildren()) do
			infect(o)
		end
	end
end

------------------------------------------------------------
-- watcher
------------------------------------------------------------
task.spawn(function()
	while running do
		local sv = getContainer()
		if not sv then
			task.wait(2)
		else
			container = sv
			table.insert(conns, sv.ChildAdded:Connect(function(o)
				task.defer(infect, o)
			end))
			scan()

			local gone = false
			local c = sv.AncestryChanged:Connect(function()
				if not sv:IsDescendantOf(workspace) then gone = true end
			end)
			while running and not gone do task.wait(1) end
			c:Disconnect()
		end
	end
end)

if CONFIG.Poll then
	task.spawn(function()
		while running do
			task.wait(CONFIG.Poll)
			if running then pcall(scan) end
		end
	end)
end

------------------------------------------------------------
-- สรุปการติดเชื้อลง webhook เป็นช่วงๆ
------------------------------------------------------------
if CONFIG.LogInfect and CONFIG.LogInterval then
	local lastCount = 0
	task.spawn(function()
		while running do
			task.wait(CONFIG.LogInterval)
			if running and stats.infected ~= lastCount then
				lastCount = stats.infected
				local lines, ownerCount = {}, 0
				for owner, n in pairs(stats.owners) do
					ownerCount = ownerCount + 1
					lines[#lines + 1] = ("%s — %d คัน"):format(owner, n)
				end
				queue(embed("สรุปการติดเชื้อ", table.concat(lines, "\n"), 15844367, {
					{ name = "รวม", value = tostring(stats.infected) .. " คัน", inline = true },
					{ name = "เจ้าของ", value = tostring(ownerCount) .. " คน", inline = true },
				}))
			end
		end
	end)
end

local function purge()
	for veh, rec in pairs(registry) do
		if not isTargeted(rec.owner) then
			release(veh)
			log("released", veh.Name)
		end
	end
end

------------------------------------------------------------
-- API
------------------------------------------------------------
getgenv().VESPA_VIRUS = {
	config = CONFIG,
	scan   = scan,
	infect = infect,

	add = function(...)
		for _, n in ipairs({ ... }) do
			local name = tostring(n):gsub("^%s*(.-)%s*$", "")
			if name ~= "" then table.insert(CONFIG.Players, name) end
		end
		rebuildTargets()
		log("targets =", table.concat(CONFIG.Players, ", "))
		scan()
		return CONFIG.Players
	end,

	remove = function(...)
		local drop = {}
		for _, n in ipairs({ ... }) do drop[norm(n)] = true end
		for i = #CONFIG.Players, 1, -1 do
			if drop[norm(CONFIG.Players[i])] then
				table.remove(CONFIG.Players, i)
			end
		end
		rebuildTargets()
		purge()
		log("targets =", #CONFIG.Players > 0 and table.concat(CONFIG.Players, ", ") or "(ทุกคน)")
		return CONFIG.Players
	end,

	setPlayers = function(...)
		CONFIG.Players = { ... }
		rebuildTargets()
		purge()
		scan()
		log("targets =", #CONFIG.Players > 0 and table.concat(CONFIG.Players, ", ") or "(ทุกคน)")
		return CONFIG.Players
	end,

	list = function()
		return CONFIG.Players, targets and "whitelist" or "everyone"
	end,

	-- ดูว่ารถคันนี้ระบบคิดว่าเจ้าของเป็นใคร
	who = function(obj)
		return obj and ownerOf(obj)
	end,

	getContainer = getContainer,
	container = function() return container end,

	kickLocal   = kickLocal,
	kickMe      = function(msg) kickLocal(msg or CONFIG.KickMessage) end,
	kickOut     = kickOut,
	enforceSelf = enforceSelf,
	findKickRemotes = findKickRemotes,

	stop = function()
		running = false
		for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		for veh in pairs(registry) do release(veh) end
		table.clear(conns)
		log("stopped")
		queue(embed("หยุดทำงาน", ("รวม %d คัน | ใช้งาน %.0f วินาที"):format(
			stats.infected, os.clock() - stats.started
		), 9807270, {
			{ name = "Player", value = LocalPlayer.Name, inline = true },
		}))
	end,

	-- ทดสอบ webhook
	webhookTest = function()
		if not webhookReady() then
			warn("[VIRUS] ยังไม่ได้ใส่ CONFIG.Webhook")
			return false
		end
		local ok = postNow({
			username = CONFIG.WebhookName,
			embeds = { embed("ทดสอบ webhook", "ถ้าเห็นข้อความนี้ = ต่อติดแล้ว", 3066993, {
				{ name = "Player", value = LocalPlayer.Name, inline = true },
				{ name = "Executor", value = executorName(), inline = true },
			}) },
		})
		print("[VIRUS] webhook test ->", ok and "sent" or "failed")
		return ok
	end,
}
