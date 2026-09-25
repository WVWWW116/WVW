-- VERSION: 1.0.0
-- ===== НАСТРОЙКИ =====
local NAME = "WVW"
local toggleKey = Enum.KeyCode.RightControl
local AIM_KEY = Enum.KeyCode.E
local SHOT_KEY = Enum.KeyCode.Q
local FOV_RADIUS = 200
local BG_IMAGE = ""  -- ← фон меню: "rbxassetid://ID" или getcustomasset("bg.png")

-- ===== UI =====
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Win = Rayfield:CreateWindow({
    Name = NAME,
    LoadingTitle = NAME,
    KeySystem = false,
    ConfigurationSaving = {Enabled = true, FolderName = NAME, FileName = "cfg"}
})
local Tab = Win:CreateTab("Основное", 4483362458)
local VisTab = Win:CreateTab("Визуалы", 4483362458)
local WorldTab = Win:CreateTab("Мир", 4483362458)
local SkinTab = Win:CreateTab("Скины", 4483362458)

-- ===== ФОН МЕНЮ =====
if BG_IMAGE ~= "" then
    task.spawn(function()
        task.wait(0.5)
        local coreGui = (gethui and gethui()) or game:GetService("CoreGui")
        local rayGui
        for _, v in ipairs(coreGui:GetChildren()) do
            if v:IsA("ScreenGui") and v.Name:lower():find("ray") then rayGui = v break end
        end
        if rayGui then
            local mainFrame
            for _, v in ipairs(rayGui:GetDescendants()) do
                if v:IsA("Frame") and v.Size.X.Offset > 400 and v.Size.Y.Offset > 300 then
                    mainFrame = v break
                end
            end
            if mainFrame then
                local bg = Instance.new("ImageLabel")
                bg.Size, bg.Position = UDim2.new(1,0,1,0), UDim2.new(0,0,0,0)
                bg.BackgroundTransparency, bg.Image = 1, BG_IMAGE
                bg.ImageTransparency, bg.ScaleType, bg.ZIndex = 0.35, Enum.ScaleType.Crop, 0
                bg.Parent = mainFrame
                Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

                local darken = Instance.new("Frame")
                darken.Size, darken.BackgroundColor3 = UDim2.new(1,0,1,0), Color3.fromRGB(0,0,0)
                darken.BackgroundTransparency, darken.BorderSizePixel, darken.ZIndex = 0.4, 0, 1
                darken.Parent = mainFrame
                Instance.new("UICorner", darken).CornerRadius = UDim.new(0, 8)
            end
        end
    end)
end

-- ===== СЕРВИСЫ =====
local P = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local Stats = game:GetService("Stats")
local LP = P.LocalPlayer
local Cam = workspace.CurrentCamera
local Lighting = game:GetService("Lighting")

-- ===== ПЕРЕМЕННЫЕ =====
local espOn, aimOn, shotOn = true, false, false
local tracersOn, namesOn, distOn, fovOn = true, true, true, true
local hatOn, statsOn = true, true
local list, drawings, hats = {}, {}, {}
local waiting = false

local C_M = Color3.fromRGB(255,50,50)
local C_S = Color3.fromRGB(50,130,255)
local C_I = Color3.fromRGB(60,200,90)
local C_U = Color3.fromRGB(200,200,60)

-- ===== STATS OVERLAY =====
local fps, ping, playerCount = 0, 0, 0
local frames, lastTime = 0, tick()

local statsFrame = Drawing.new("Square")
statsFrame.Color, statsFrame.Filled, statsFrame.Transparency = Color3.fromRGB(30,30,30), true, 0.6
statsFrame.Size, statsFrame.Position, statsFrame.Visible = Vector2.new(180,72), Vector2.new(10,10), true

local statsBorder = Drawing.new("Square")
statsBorder.Color, statsBorder.Filled, statsBorder.Thickness = Color3.fromRGB(80,80,80), false, 1
statsBorder.Size, statsBorder.Position, statsBorder.Visible = Vector2.new(180,72), Vector2.new(10,10), true

local statsText = Drawing.new("Text")
statsText.Size, statsText.Font, statsText.Outline = 14, 2, true
statsText.Color, statsText.Position, statsText.Visible = Color3.fromRGB(255,255,255), Vector2.new(18,16), true

task.spawn(function()
    while task.wait(0.5) do
        local now = tick()
        fps = math.floor(frames / (now - lastTime))
        frames, lastTime = 0, now
        local ok, p = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
        ping = ok and math.floor(p) or 0
        playerCount = #P:GetPlayers()
    end
end)

RS.RenderStepped:Connect(function()
    frames = frames + 1
    if not statsOn then
        statsFrame.Visible, statsBorder.Visible, statsText.Visible = false, false, false
        return
    end
    statsFrame.Visible, statsBorder.Visible, statsText.Visible = true, true, true
    statsText.Text = string.format("FPS: %d\nPing: %d ms\nИгроков: %d", fps, ping, playerCount)
end)

-- ===== РОЛЬ =====
local function role(p)
    local a = p:GetAttribute("Role") or (p.Character and p.Character:GetAttribute("Role"))
    if a then
        a = tostring(a):lower()
        if a:find("murder") then return "m" end
        if a:find("sheriff") then return "s" end
        if a:find("innocent") then return "i" end
    end
    local function has(c, n)
        if not c then return false end
        for _, i in ipairs(c:GetChildren()) do
            if i:IsA("Tool") and i.Name:lower():find(n) then return true end
        end
        return false
    end
    local bp, ch = p:FindFirstChild("Backpack"), p.Character
    if has(bp,"knife") or has(ch,"knife") then return "m" end
    if has(bp,"gun") or has(ch,"gun") or has(bp,"pistol") or has(ch,"pistol") then return "s" end
    return "i"
end

local function color(r)
    if r == "m" then return C_M end
    if r == "s" then return C_S end
    if r == "i" then return C_I end
    return C_U
end

local function roleName(r)
    if r == "m" then return "Murderer" end
    if r == "s" then return "Sheriff" end
    if r == "i" then return "Innocent" end
    return "Unknown"
end

-- ===== ESP =====
local function clr(p) if list[p] then list[p]:Destroy() list[p] = nil end end
local function draw(p)
    if p == LP or not p.Character then return end
    clr(p)
    local h = Instance.new("Highlight", p.Character)
    h.FillColor, h.FillTransparency = color(role(p)), 0.45
    h.OutlineColor, h.OutlineTransparency = Color3.new(1,1,1), 0.1
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    list[p] = h
end

-- ===== CHINA HAT =====
local function makeHat(p)
    if p == LP or not p.Character then return end
    local head = p.Character:FindFirstChild("Head")
    if not head then return end
    if hats[p] and hats[p].Parent then return end

    local hat = Instance.new("Part")
    hat.Name = "ChinaHat_" .. p.Name
    hat.Shape = Enum.PartType.Cylinder
    hat.Size = Vector3.new(0.4, 1.6, 1.6)
    hat.Color = color(role(p))
    hat.Material = Enum.Material.Neon
    hat.CanCollide, hat.Massless, hat.Anchored = false, true, false
    hat.CFrame = head.CFrame * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90))
    hat.Parent = p.Character
    local weld = Instance.new("WeldConstraint", hat)
    weld.Part0, weld.Part1 = hat, head
    hats[p] = hat
end

local function removeHat(p)
    if hats[p] then pcall(function() hats[p]:Destroy() end) hats[p] = nil end
end

local function refreshHats()
    for _, p in ipairs(P:GetPlayers()) do
        if p ~= LP and p.Character then
            if hatOn and role(p) == "m" then makeHat(p) else removeHat(p) end
        end
    end
end

-- ===== DRAWING ВИЗУАЛЫ =====
local function newDraw(p)
    local d = {}
    d.tracer = Drawing.new("Line")
    d.tracer.Thickness, d.tracer.Transparency, d.tracer.Visible = 2, 0.8, false
    d.name = Drawing.new("Text")
    d.name.Size, d.name.Center, d.name.Outline = 14, true, true
    d.name.Font, d.name.Visible = 2, false
    d.dist = Drawing.new("Text")
    d.dist.Size, d.dist.Center, d.dist.Outline = 12, true, true
    d.dist.Font, d.dist.Visible = 2, false
    drawings[p] = d
    return d
end

local function clearDraw(p)
    if drawings[p] then
        for _, obj in pairs(drawings[p]) do obj:Remove() end
        drawings[p] = nil
    end
end

local fovCircle = Drawing.new("Circle")
fovCircle.Color, fovCircle.Thickness = Color3.fromRGB(255,255,255), 1
fovCircle.Filled, fovCircle.NumSides = false, 60
fovCircle.Radius, fovCircle.Transparency, fovCircle.Visible = FOV_RADIUS, 0.4, false

RS.RenderStepped:Connect(function()
    fovCircle.Position = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)
    fovCircle.Visible = fovOn and aimOn

    for _, p in ipairs(P:GetPlayers()) do
        if hats[p] and hats[p].Parent and espOn then hats[p].Color = color(role(p)) end
    end

    if not espOn then
        for _, d in pairs(drawings) do
            d.tracer.Visible, d.name.Visible, d.dist.Visible = false, false, false
        end
        return
    end

    local myPos = Cam.CFrame.Position
    local bottom = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y)

    for _, p in ipairs(P:GetPlayers()) do
        if p == LP or not p.Character then continue end
        local hum = p.Character:FindFirstChildOfClass("Humanoid")
        local root = p.Character:FindFirstChild("HumanoidRootPart")
        local head = p.Character:FindFirstChild("Head")
        if not hum or hum.Health <= 0 or not root or not head then
            if drawings[p] then
                drawings[p].tracer.Visible, drawings[p].name.Visible, drawings[p].dist.Visible = false, false, false
            end
            continue
        end
        local d = drawings[p] or newDraw(p)
        local r = role(p)
        local col = color(r)
        local headScreen, onScreen = Cam:WorldToViewportPoint(head.Position)
        if onScreen then
            d.tracer.From, d.tracer.To = bottom, Vector2.new(headScreen.X, headScreen.Y)
            d.tracer.Color, d.tracer.Visible = col, tracersOn
            d.name.Text = p.Name .. " [" .. roleName(r) .. "]"
            d.name.Position, d.name.Color, d.name.Visible = Vector2.new(headScreen.X, headScreen.Y - 30), col, namesOn
            local dist = (myPos - root.Position).Magnitude
            d.dist.Text, d.dist.Position = string.format("%d m", math.floor(dist)), Vector2.new(headScreen.X, headScreen.Y - 12)
            d.dist.Color, d.dist.Visible = Color3.fromRGB(255,255,255), distOn
        else
            d.tracer.Visible, d.name.Visible, d.dist.Visible = false, false, false
        end
    end
end)

-- ===== ПОИСК ЦЕЛИ =====
local function findMurderer()
    local best, bd = nil, math.huge
    local center = Vector2.new(Cam.ViewportSize.X/2, Cam.ViewportSize.Y/2)
    for _, p in ipairs(P:GetPlayers()) do
        if p ~= LP and p.Character and role(p) == "m" then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local part = p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and part then
                local sp, on = Cam:WorldToViewportPoint(part.Position)
                if on then
                    local dd = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if dd <= FOV_RADIUS and dd < bd then best, bd = p, dd end
                end
            end
        end
    end
    return best
end

local function aimPart(p)
    if not p or not p.Character then return nil end
    return p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("HumanoidRootPart")
end

-- ===== SILENT AIM =====
local mt = getrawmetatable(game)
local oldIndex = mt.__index
setreadonly(mt, false)
mt.__index = newcclosure(function(self, key)
    if aimOn and checkcaller() then
        local mouse = LP:GetMouse()
        if self == mouse and (key == "Hit" or key == "Target") then
            local m = findMurderer()
            local part = aimPart(m)
            if part then
                if key == "Hit" then return CFrame.new(part.Position) end
                if key == "Target" then return part end
            end
        end
    end
    return oldIndex(self, key)
end)
setreadonly(mt, true)

-- ===== AUTO SHOT =====
local function shotMurderer()
    local m = findMurderer()
    if not m or not m.Character then return end
    local char = LP.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return end
    local n = tool.Name:lower()
    if not n:find("gun") and not n:find("pistol") then return end
    local part = aimPart(m)
    if part then Cam.CFrame = CFrame.new(Cam.CFrame.Position, part.Position) end
    pcall(function() tool:Activate() end)
end

-- ===== МИР =====
local orig = {
    Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
    FogColor = Lighting.FogColor, FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
    ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness
}
local function setSkyColor(c)
    Lighting.Ambient, Lighting.OutdoorAmbient = c, c
    Lighting.ClockTime, Lighting.Brightness = 14, 2
end
local function setFogColor(c)
    Lighting.FogColor, Lighting.FogStart, Lighting.FogEnd = c, 0, 500
end
local function resetWorld()
    Lighting.Ambient, Lighting.OutdoorAmbient = orig.Ambient, orig.OutdoorAmbient
    Lighting.FogColor, Lighting.FogEnd, Lighting.FogStart = orig.FogColor, orig.FogEnd, orig.FogStart
    Lighting.ClockTime, Lighting.Brightness = orig.ClockTime, orig.Brightness
end

-- ===== СКИН ЧЕЙНДЖЕР ОРУЖИЯ =====
local weaponSkins = {
    Knife = {Default = nil},
    Gun = {Default = nil}
}
local currentSkin = {Knife = "Default", Gun = "Default"}
local skinOn = {Knife = false, Gun = false}
local originals = {}

local function getWeaponType(tool)
    if not tool or not tool:IsA("Tool") then return nil end
    local n = tool.Name:lower()
    if n:find("knife") then return "Knife" end
    if n:find("gun") or n:find("pistol") or n:find("revolver") then return "Gun" end
    return nil
end

local function applyWeaponSkin(tool)
    local wtype = getWeaponType(tool)
    if not wtype or not skinOn[wtype] then return end
    local skinId = weaponSkins[wtype][currentSkin[wtype]]
    if not skinId or skinId == "" then return end
    local handle = tool:FindFirstChild("Handle")
    if not handle then return end
    if not originals[tool] then
        originals[tool] = {Transparency = handle.Transparency}
    end
    handle.Transparency = 1
    for _, v in ipairs(handle:GetChildren()) do
        if v:IsA("SpecialMesh") or v:IsA("MeshPart") then v.Transparency = 1 end
    end
    local old = handle:FindFirstChild("CustomSkinMesh")
    if old then old:Destroy() end
    local mesh = Instance.new("SpecialMesh")
    mesh.Name, mesh.MeshType, mesh.MeshId = "CustomSkinMesh", Enum.MeshType.FileMesh, skinId
    mesh.Scale = Vector3.new(1, 1, 1)
    mesh.Parent = handle
end

local function resetWeaponSkin(tool)
    local handle = tool:FindFirstChild("Handle")
    if not handle then return end
    local custom = handle:FindFirstChild("CustomSkinMesh")
    if custom then custom:Destroy() end
    if originals[tool] then
        handle.Transparency = originals[tool].Transparency
        originals[tool] = nil
    end
end

-- ===== ТРЕКИНГ ОРУЖИЯ =====
local function watchTools(p)
    if p == LP then return end
    local function rebind()
        if espOn and list[p] then list[p].FillColor = color(role(p)) end
        if hatOn and role(p) == "m" then makeHat(p) else removeHat(p) end
    end
    local function bind(c)
        if not c then return end
        c.ChildAdded:Connect(function() task.wait(0.1) rebind() end)
        c.ChildRemoved:Connect(function() task.wait(0.1) rebind() end)
    end
    p.ChildAdded:Connect(function(c) if c.Name == "Backpack" then bind(c) end end)
    bind(p:FindFirstChild("Backpack"))
    p.CharacterAdded:Connect(function(ch)
        ch.ChildAdded:Connect(function() task.wait(0.1) rebind() end)
        ch.ChildRemoved:Connect(function() task.wait(0.1) rebind() end)
    end)
end

-- Следим за своим оружием для скин чейнджера
LP.CharacterAdded:Connect(function(char)
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            task.wait(0.2)
            applyWeaponSkin(child)
        end
    end)
    char.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") then originals[child] = nil end
    end)
end)

-- ===== МЕНЮ: ОСНОВНОЕ =====
Tab:CreateToggle({Name = "ESP ролей", CurrentValue = true, Flag = "esp",
    Callback = function(v) espOn = v if not v then for p in pairs(list) do clr(p) end end end})
Tab:CreateToggle({Name = "Silent Aim", CurrentValue = false, Flag = "aim", Callback = function(v) aimOn = v end})
Tab:CreateToggle({Name = "Auto Shot (шериф)", CurrentValue = false, Flag = "shot", Callback = function(v) shotOn = v end})
Tab:CreateParagraph({Title = "Клавиши",
    Content = "Silent Aim: " .. AIM_KEY.Name .. "\nAuto Shot: " .. SHOT_KEY.Name})
Tab:CreateSection("Меню")
local keyBtn
keyBtn = Tab:CreateButton({Name = "Клавиша меню: " .. toggleKey.Name, Callback = function()
    waiting = true
    keyBtn:Set("Нажми клавишу...")
end})

-- ===== МЕНЮ: ВИЗУАЛЫ =====
VisTab:CreateToggle({Name = "Tracers", CurrentValue = true, Flag = "tracers", Callback = function(v) tracersOn = v end})
VisTab:CreateToggle({Name = "NameTag", CurrentValue = true, Flag = "names", Callback = function(v) namesOn = v end})
VisTab:CreateToggle({Name = "Distance", CurrentValue = true, Flag = "dist", Callback = function(v) distOn = v end})
VisTab:CreateToggle({Name = "FOV круг", CurrentValue = true, Flag = "fov", Callback = function(v) fovOn = v end})
VisTab:CreateToggle({Name = "China Hat (мурдер)", CurrentValue = true, Flag = "hat", Callback = function(v)
    hatOn = v refreshHats() end})
VisTab:CreateToggle({Name = "Stats (FPS/Ping/Игроки)", CurrentValue = true, Flag = "stats", Callback = function(v) statsOn = v end})

-- ===== МЕНЮ: МИР =====
WorldTab:CreateColorPicker({Name = "Цвет неба", Color = Color3.fromRGB(135,206,235), Flag = "skyColor",
    Callback = function(c) setSkyColor(c) end})
WorldTab:CreateColorPicker({Name = "Цвет тумана", Color = Color3.fromRGB(200,200,200), Flag = "fogColor",
    Callback = function(c) setFogColor(c) end})
WorldTab:CreateButton({Name = "Сбросить мир", Callback = function() resetWorld() end})

-- ===== МЕНЮ: СКИНЫ =====
SkinTab:CreateSection("Скин ножа")
SkinTab:CreateInput({Name = "ID меша ножа", PlaceholderText = "rbxassetid://0",
    CurrentValue = "", RemoveTextAfterFocusLost = false, Flag = "knifeId",
    Callback = function(t) if t ~= "" then weaponSkins.Knife.Custom = t end end})
SkinTab:CreateDropdown({Name = "Пресет ножа", Options = {"Default", "Custom"}, CurrentOption = {"Default"},
    Flag = "knifePreset", Callback = function(o) currentSkin.Knife = o end})
SkinTab:CreateToggle({Name = "Включить скин ножа", CurrentValue = false, Flag = "knifeOn",
    Callback = function(v)
        skinOn.Knife = v
        local char = LP.Character
        if char then
            for _, t in ipairs(char:GetChildren()) do
                if t:IsA("Tool") then
                    if v then applyWeaponSkin(t) else resetWeaponSkin(t) end
                end
            end
        end
    end})

SkinTab:CreateSection("Скин револьвера")
SkinTab:CreateInput({Name = "ID меша револьвера", PlaceholderText = "rbxassetid://0",
    CurrentValue = "", RemoveTextAfterFocusLost = false, Flag = "gunId",
    Callback = function(t) if t ~= "" then weaponSkins.Gun.Custom = t end end})
SkinTab:CreateDropdown({Name = "Пресет револьвера", Options = {"Default", "Custom"}, CurrentOption = {"Default"},
    Flag = "gunPreset", Callback = function(o) currentSkin.Gun = o end})
SkinTab:CreateToggle({Name = "Включить скин револьвера", CurrentValue = false, Flag = "gunOn",
    Callback = function(v)
        skinOn.Gun = v
        local char = LP.Character
        if char then
            for _, t in ipairs(char:GetChildren()) do
                if t:IsA("Tool") then
                    if v then applyWeaponSkin(t) else resetWeaponSkin(t) end
                end
            end
        end
    end})

-- ===== ПОДПИСКИ =====
P.PlayerAdded:Connect(function(p)
    watchTools(p)
    p.CharacterAdded:Connect(function() task.wait(0.3) if espOn then draw(p) end end)
end)
P.PlayerRemoving:Connect(function(p) clr(p) clearDraw(p) removeHat(p) end)
for _, p in 
