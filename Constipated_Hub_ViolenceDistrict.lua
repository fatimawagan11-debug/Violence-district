--[[
    Constipated Hub — Violence District
    Orion UI · OxioHub-class features
]]

local ENV = (typeof(getgenv) == "function" and getgenv()) or _G
if ENV.ConstipatedVDUnload then pcall(ENV.ConstipatedVDUnload) end

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

local LP = Players.LocalPlayer
while not LP do task.wait() LP = Players.LocalPlayer end
local Camera = Workspace.CurrentCamera
local Mouse = LP:GetMouse()

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local F = {
	-- Combat / survivor
	autoParry = false,
	parryRadius = 18,
	autoPallet = false,
	autoVault = false,
	speedBoost = false,
	speedValue = 22,
	godMode = false,
	noSlowdown = false,
	antiBlind = false,

	-- Aim
	survivorAimbot = false,
	survivorFov = 160,
	survivorSmooth = 0.15,
	killerAimbot = false,
	killerFov = 180,
	silentFlask = false,
	predictAim = true,

	-- Killer
	infLunge = false,
	autoStalk = false,
	silentVeil = false,

	-- ESP
	esp = true,
	espPlayers = true,
	espKillers = true,
	espGens = true,
	espHooks = false,
	espPallets = false,
	espGates = false,
	espColor = Color3.fromRGB(0, 200, 255),
	espKillerColor = Color3.fromRGB(255, 50, 50),
	espGenColor = Color3.fromRGB(80, 255, 80),

	-- Misc
	antiAfk = true,
	infZoom = false,
	fly = false,
	flySpeed = 40,
}

local S = {
	unloaded = false,
	chams = {},
	objChams = {},
	draws = {},
	conns = {},
	lastParry = 0,
	flyBV = nil,
	silentFov = nil,
	aimFov = nil,
}

local function track(c) if c then table.insert(S.conns, c) end return c end
local function char() return LP.Character end
local function root()
	local c = char()
	return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso"))
end
local function hum()
	local c = char()
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function getFovCenter()
	if IS_MOBILE then
		local vs = Camera.ViewportSize
		return Vector2.new(vs.X / 2, vs.Y / 2)
	end
	return UserInputService:GetMouseLocation()
end

-- ========== PARRY ==========
local function executeParry()
	pcall(function()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local items = remotes and remotes:FindFirstChild("Items")
		local dagger = items and items:FindFirstChild("Parrying Dagger")
		local parry = dagger and dagger:FindFirstChild("parry")
		if parry then
			for i = 1, 6 do
				pcall(function() parry:FireServer() end)
			end
		end
	end)
	pcall(function()
		if mouse2click then mouse2click()
		elseif mouse2press and mouse2release then
			mouse2press()
			task.wait(0.02)
			mouse2release()
		else
			VirtualInputManager:SendMouseButtonEvent(0, 0, 1, true, game, 0)
			task.wait(0.02)
			VirtualInputManager:SendMouseButtonEvent(0, 0, 1, false, game, 0)
		end
	end)
end

local function nearestThreat()
	local my = root()
	if not my then return nil, math.huge end
	local best, bd
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= LP and pl.Character then
			local r = pl.Character:FindFirstChild("HumanoidRootPart")
			if r then
				local d = (r.Position - my.Position).Magnitude
				-- Prefer tagged killers / red team-ish
				local isKiller = pl:GetAttribute("IsKiller") or pl:GetAttribute("Killer")
					or (pl.Team and tostring(pl.Team):lower():find("kill"))
				if isKiller or d < 25 then
					if not bd or d < bd then bd, best = d, pl end
				end
			end
		end
	end
	return best, bd or math.huge
end

track(RunService.Heartbeat:Connect(function()
	if S.unloaded or not F.autoParry then return end
	local now = os.clock()
	if now - S.lastParry < 0.15 then return end
	local threat, dist = nearestThreat()
	if threat and dist <= F.parryRadius then
		executeParry()
		S.lastParry = now
	end
end))

-- ========== AIMBOT ==========
local function isAlive(pl)
	local c = pl.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return c and h and h.Health > 0 and c:FindFirstChild("HumanoidRootPart")
end

local function getClosestInFov(fov, preferKiller)
	local mp = getFovCenter()
	local best, bestPart, bestDist
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl == LP or not isAlive(pl) then continue end
		local isKiller = pl:GetAttribute("IsKiller") or pl:GetAttribute("Killer")
		if preferKiller and not isKiller then continue end
		if not preferKiller and isKiller then continue end
		local part = pl.Character:FindFirstChild("Head") or pl.Character:FindFirstChild("HumanoidRootPart")
		if not part then continue end
		local sp, on = Camera:WorldToViewportPoint(part.Position)
		if not on then continue end
		local d = (Vector2.new(sp.X, sp.Y) - mp).Magnitude
		if d <= fov and (not bestDist or d < bestDist) then
			bestDist, best, bestPart = d, pl, part
		end
	end
	return best, bestPart
end

track(RunService.RenderStepped:Connect(function(dt)
	if S.unloaded then return end
	if F.survivorAimbot then
		local _, part = getClosestInFov(F.survivorFov, true) -- aim at killers as survivor
		if part then
			local pred = part.Position
			pcall(function()
				if F.predictAim then pred = pred + part.AssemblyLinearVelocity * 0.12 end
			end)
			local cam = Camera.CFrame
			Camera.CFrame = cam:Lerp(CFrame.new(cam.Position, pred), 1 - math.clamp(F.survivorSmooth, 0.05, 1))
		end
	end
	if F.killerAimbot then
		local _, part = getClosestInFov(F.killerFov, false) -- aim at survivors as killer
		if part then
			local pred = part.Position
			pcall(function()
				if F.predictAim then pred = pred + part.AssemblyLinearVelocity * 0.12 end
			end)
			local cam = Camera.CFrame
			Camera.CFrame = cam:Lerp(CFrame.new(cam.Position, pred), 0.85)
		end
	end
end))

-- Silent flask (Mouse.Hit style best-effort)
pcall(function()
	local mt = getrawmetatable(game)
	local old = mt.__index
	if setreadonly then setreadonly(mt, false) end
	local function wrap(self, key)
		if not S.unloaded and F.silentFlask and self == Mouse and (key == "Hit" or key == "Target") then
			local _, part = getClosestInFov(200, false)
			if part then
				if key == "Hit" then return CFrame.new(part.Position) end
				return part
			end
		end
		return old(self, key)
	end
	mt.__index = (newcclosure and newcclosure(wrap)) or wrap
	if setreadonly then setreadonly(mt, true) end
end)

-- ========== MAP OBJECTS ==========
local function findMapObjects(keywords)
	local list = {}
	local map = Workspace:FindFirstChild("Map") or Workspace
	for _, obj in ipairs(map:GetDescendants()) do
		if obj:IsA("Model") or obj:IsA("BasePart") then
			local n = string.lower(obj.Name)
			for _, k in ipairs(keywords) do
				if n:find(k) then
					local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
					if part then table.insert(list, { model = obj, part = part }) end
					break
				end
			end
		end
	end
	return list
end

local function nearestObject(keywords)
	local my = root()
	if not my then return nil end
	local best, bd
	for _, e in ipairs(findMapObjects(keywords)) do
		local d = (e.part.Position - my.Position).Magnitude
		if not bd or d < bd then bd, best = d, e end
	end
	return best
end

local function tpTo(part)
	local r = root()
	if r and part then
		r.CFrame = part.CFrame + Vector3.new(0, 3, 0)
	end
end

-- Auto pallet drop (proximity + prompt)
local function tryDropPallet()
	pcall(function()
		local my = root()
		if not my then return end
		for _, e in ipairs(findMapObjects({"pallet"})) do
			if (e.part.Position - my.Position).Magnitude < 12 then
				local prompt = e.model:FindFirstChildWhichIsA("ProximityPrompt", true)
				if prompt then
					if fireproximityprompt then fireproximityprompt(prompt)
					else
						prompt:InputHoldBegin()
						task.wait(0.05)
						prompt:InputHoldEnd()
					end
				end
			end
		end
	end)
end

track(RunService.Heartbeat:Connect(function()
	if S.unloaded then return end
	if F.autoPallet then tryDropPallet() end
	if F.speedBoost then
		local h = hum()
		if h then pcall(function() h.WalkSpeed = F.speedValue end) end
	end
	if F.godMode then
		local h = hum()
		if h then pcall(function() h.Health = h.MaxHealth end) end
	end
	if F.noSlowdown then
		local h = hum()
		if h and h.WalkSpeed < 16 then pcall(function() h.WalkSpeed = 16 end) end
	end
end))

-- ========== ESP ==========
local function clearEsp()
	for _, hl in pairs(S.chams) do pcall(function() hl:Destroy() end) end
	S.chams = {}
	for _, hl in pairs(S.objChams) do pcall(function() hl:Destroy() end) end
	S.objChams = {}
	for _, d in pairs(S.draws) do
		for _, o in pairs(d) do pcall(function() o:Remove() end) end
	end
	S.draws = {}
end

local function ensurePlayerChams(pl, color)
	local c = pl.Character
	if not c then return end
	local hl = S.chams[pl]
	if not hl or not hl.Parent then
		hl = Instance.new("Highlight")
		hl.Name = "_CO_VD"
		hl.FillTransparency = 0.5
		hl.OutlineTransparency = 0
		hl.FillColor = color
		hl.OutlineColor = Color3.new(1, 1, 1)
		hl.Adornee = c
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		pcall(function() hl.Parent = (gethui and gethui()) or CoreGui end)
		if not hl.Parent then pcall(function() hl.Parent = LP.PlayerGui end) end
		S.chams[pl] = hl
	else
		hl.Adornee = c
		hl.FillColor = color
	end
end

local function ensureObjChams(key, model, color)
	local hl = S.objChams[key]
	if not hl or not hl.Parent then
		hl = Instance.new("Highlight")
		hl.Name = "_CO_VD_OBJ"
		hl.FillTransparency = 0.6
		hl.OutlineTransparency = 0.2
		hl.FillColor = color
		hl.OutlineColor = Color3.new(1, 1, 1)
		hl.Adornee = model
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		pcall(function() hl.Parent = (gethui and gethui()) or CoreGui end)
		S.objChams[key] = hl
	else
		hl.Adornee = model
		hl.FillColor = color
	end
end

track(RunService.RenderStepped:Connect(function()
	if S.unloaded or not F.esp then
		clearEsp()
		return
	end
	local seenP, seenO = {}, {}
	if F.espPlayers or F.espKillers then
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl ~= LP and isAlive(pl) then
				local isKiller = pl:GetAttribute("IsKiller") or pl:GetAttribute("Killer")
				if isKiller and F.espKillers then
					seenP[pl] = true
					ensurePlayerChams(pl, F.espKillerColor)
				elseif not isKiller and F.espPlayers then
					seenP[pl] = true
					ensurePlayerChams(pl, F.espColor)
				end
			end
		end
	end
	for pl in pairs(S.chams) do if not seenP[pl] then pcall(function() S.chams[pl]:Destroy() end) S.chams[pl] = nil end end

	if F.espGens then
		for i, e in ipairs(findMapObjects({"generator", "gen_"})) do
			local key = "gen_" .. tostring(e.model)
			seenO[key] = true
			ensureObjChams(key, e.model, F.espGenColor)
		end
	end
	if F.espHooks then
		for i, e in ipairs(findMapObjects({"hook"})) do
			local key = "hook_" .. tostring(e.model)
			seenO[key] = true
			ensureObjChams(key, e.model, Color3.fromRGB(255, 200, 50))
		end
	end
	if F.espPallets then
		for i, e in ipairs(findMapObjects({"pallet"})) do
			local key = "pal_" .. tostring(e.model)
			seenO[key] = true
			ensureObjChams(key, e.model, Color3.fromRGB(200, 160, 80))
		end
	end
	if F.espGates then
		for i, e in ipairs(findMapObjects({"gate", "exit"})) do
			local key = "gate_" .. tostring(e.model)
			seenO[key] = true
			ensureObjChams(key, e.model, Color3.fromRGB(100, 255, 180))
		end
	end
	for k in pairs(S.objChams) do
		if not seenO[k] then pcall(function() S.objChams[k]:Destroy() end) S.objChams[k] = nil end
	end
end))

-- Anti AFK
pcall(function()
	track(LP.Idled:Connect(function()
		if F.antiAfk and not S.unloaded then
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end)
		end
	end))
end)

-- Fly simple
local function setFly(on)
	pcall(function() if S.flyBV then S.flyBV:Destroy() S.flyBV = nil end end)
	if not on then return end
	local r = root()
	if not r then return end
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
	bv.Velocity = Vector3.zero
	bv.Parent = r
	S.flyBV = bv
end

track(RunService.RenderStepped:Connect(function()
	if S.unloaded or not F.fly or not S.flyBV or not S.flyBV.Parent then return end
	local cam = Camera.CFrame
	local dir = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
	S.flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * F.flySpeed or Vector3.zero
end))

-- ========== ORION ==========
local OrionLib
do
	local urls = {
		"https://raw.githubusercontent.com/jensonhirst/Orion/main/source",
		"https://raw.githubusercontent.com/shlexware/Orion/main/source",
		"https://raw.githubusercontent.com/Seven7-lua/Roblox/refs/heads/main/Librarys/Orion/Orion.lua",
		"https://raw.githubusercontent.com/Robloxexploiter691/Mobilefriendlyorion/main/Orion",
	}
	for _, u in ipairs(urls) do
		local ok, res = pcall(function() return loadstring(game:HttpGet(u))() end)
		if ok and res then OrionLib = res break end
	end
end
if not OrionLib then warn("[Constipated Hub] Orion failed") return end

local Window = OrionLib:MakeWindow({
	Name = "Constipated Hub | Violence District",
	HidePremium = true,
	SaveConfig = false,
	ConfigFolder = "ConstipatedVD",
	IntroEnabled = true,
	IntroText = "Constipated Hub",
})

local TSurv = Window:MakeTab({ Name = "Survivor", Icon = "rbxassetid://6034287594", PremiumOnly = false })
local TKill = Window:MakeTab({ Name = "Killer", Icon = "rbxassetid://6034508291", PremiumOnly = false })
local TAim = Window:MakeTab({ Name = "Aim", Icon = "rbxassetid://6034684937", PremiumOnly = false })
local TEsp = Window:MakeTab({ Name = "ESP", Icon = "rbxassetid://6031075931", PremiumOnly = false })
local TTp = Window:MakeTab({ Name = "Teleport", Icon = "rbxassetid://6031260796", PremiumOnly = false })
local TMisc = Window:MakeTab({ Name = "Misc", Icon = "rbxassetid://6031280882", PremiumOnly = false })

TSurv:AddParagraph("Survivor", "Parry · pallet · vault · speed")
TSurv:AddToggle({ Name = "Auto Parry", Default = false, Callback = function(v) F.autoParry = v end })
TSurv:AddSlider({ Name = "Parry Radius", Min = 8, Max = 40, Default = 18, Color = Color3.fromRGB(255,255,255), Increment = 1, ValueName = "studs", Callback = function(v) F.parryRadius = v end })
TSurv:AddButton({ Name = "Parry Now", Callback = function() executeParry() end })
TSurv:AddToggle({ Name = "Auto Drop Pallet", Default = false, Callback = function(v) F.autoPallet = v end })
TSurv:AddToggle({ Name = "Speed Boost", Default = false, Callback = function(v) F.speedBoost = v end })
TSurv:AddSlider({ Name = "Speed Value", Min = 16, Max = 40, Default = 22, Color = Color3.fromRGB(255,255,255), Increment = 1, ValueName = "", Callback = function(v) F.speedValue = v end })
TSurv:AddToggle({ Name = "God Mode (regen)", Default = false, Callback = function(v) F.godMode = v end })
TSurv:AddToggle({ Name = "No Slowdown", Default = false, Callback = function(v) F.noSlowdown = v end })

TKill:AddParagraph("Killer", "Lunge · stalk · veil")
TKill:AddToggle({ Name = "Killer Aimbot", Default = false, Callback = function(v) F.killerAimbot = v end })
TKill:AddSlider({ Name = "Killer Aim FOV", Min = 50, Max = 400, Default = 180, Color = Color3.fromRGB(255,255,255), Increment = 1, ValueName = "px", Callback = function(v) F.killerFov = v end })
TKill:AddToggle({ Name = "Silent Aim Flask", Default = false, Callback = function(v) F.silentFlask = v end })
TKill:AddToggle({ Name = "Infinite Lunge (flag)", Default = false, Callback = function(v) F.infLunge = v end })
TKill:AddToggle({ Name = "Auto Stalk (flag)", Default = false, Callback = function(v) F.autoStalk = v end })

TAim:AddParagraph("Aimbot", "Survivor aims killers · predict")
TAim:AddToggle({ Name = "Survivor Aimbot", Default = false, Callback = function(v) F.survivorAimbot = v end })
TAim:AddSlider({ Name = "Survivor FOV", Min = 50, Max = 400, Default = 160, Color = Color3.fromRGB(255,255,255), Increment = 1, ValueName = "px", Callback = function(v) F.survivorFov = v end })
TAim:AddSlider({ Name = "Smoothness", Min = 5, Max = 50, Default = 15, Color = Color3.fromRGB(255,255,255), Increment = 1, ValueName = "", Callback = function(v) F.survivorSmooth = v / 100 end })
TAim:AddToggle({ Name = "Predict Aim", Default = true, Callback = function(v) F.predictAim = v end })

TEsp:AddToggle({ Name = "Enable ESP", Default = true, Callback = function(v) F.esp = v end })
TEsp:AddToggle({ Name = "Player ESP", Default = true, Callback = function(v) F.espPlayers = v end })
TEsp:AddToggle({ Name = "Killer ESP", Default = true, Callback = function(v) F.espKillers = v end })
TEsp:AddToggle({ Name = "Generator ESP", Default = true, Callback = function(v) F.espGens = v end })
TEsp:AddToggle({ Name = "Hook ESP", Default = false, Callback = function(v) F.espHooks = v end })
TEsp:AddToggle({ Name = "Pallet ESP", Default = false, Callback = function(v) F.espPallets = v end })
TEsp:AddToggle({ Name = "Gate ESP", Default = false, Callback = function(v) F.espGates = v end })

TTp:AddParagraph("Teleport", "Nearest map objects")
TTp:AddButton({ Name = "TP Generator", Callback = function()
	local e = nearestObject({"generator", "gen_"})
	if e then tpTo(e.part) end
end })
TTp:AddButton({ Name = "TP Hook", Callback = function()
	local e = nearestObject({"hook"})
	if e then tpTo(e.part) end
end })
TTp:AddButton({ Name = "TP Pallet", Callback = function()
	local e = nearestObject({"pallet"})
	if e then tpTo(e.part) end
end })
TTp:AddButton({ Name = "TP Gate", Callback = function()
	local e = nearestObject({"gate", "exit"})
	if e then tpTo(e.part) end
end })
TTp:AddButton({ Name = "TP Window", Callback = function()
	local e = nearestObject({"window"})
	if e then tpTo(e.part) end
end })

TMisc:AddToggle({ Name = "Anti AFK", Default = true, Callback = function(v) F.antiAfk = v end })
TMisc:AddToggle({ Name = "Fly", Default = false, Callback = function(v) F.fly = v setFly(v) end })
TMisc:AddSlider({ Name = "Fly Speed", Min = 10, Max = 120, Default = 40, Color = Color3.fromRGB(255,255,255), Increment = 1, ValueName = "", Callback = function(v) F.flySpeed = v end })
TMisc:AddButton({
	Name = "Unload Hub",
	Callback = function()
		S.unloaded = true
		F.fly = false
		setFly(false)
		clearEsp()
		for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
		S.conns = {}
		pcall(function() OrionLib:Destroy() end)
		ENV.ConstipatedVDUnload = nil
	end,
})

ENV.ConstipatedVDUnload = function()
	S.unloaded = true
	pcall(function() OrionLib:Destroy() end)
end

OrionLib:MakeNotification({
	Name = "Constipated Hub",
	Content = "Violence District · Orion loaded",
	Image = "rbxassetid://6034508291",
	Time = 4,
})
pcall(function() OrionLib:Init() end)
print("[Constipated Hub] Violence District ready")
