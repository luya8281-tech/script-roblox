-- ULTIMATE HUB LOADER V10.3 (NO KEY SYSTEM)
if getgenv().UHLoaded then
    pcall(function() getgenv().UH:Destroy() end)
    pcall(function() game:GetService("CoreGui"):FindFirstChild("Rayfield"):Destroy() end)
    getgenv().UH, getgenv().UHCore, getgenv().UHLoaded = nil, nil, nil
    task.wait(0.3)
end
getgenv().UHLoaded = true

print("=== ULTIMATE HUB LOADER V10.3 STARTING ===")

local CFG = {
    CU = "https://raw.githubusercontent.com/luya8281-tech/script-roblox/main/core.lua",
}

local HS, TS, PL, CG, SG = game:GetService("HttpService"), game:GetService("TweenService"), game:GetService("Players"), game:GetService("CoreGui"), game:GetService("StarterGui")
local LP = PL.LocalPlayer

local function SN(t, x, d) pcall(function() SG:SetCore("SendNotification", {Title = t or "Ultimate Hub", Text = x or "", Duration = d or 5}) end) end

local function LH()
    print("=== LOADING HUB ===")
    
    local C = getgenv().UHCore
    if not C then
        print("=== LOADING CORE FROM URL ===")
        local success, err = pcall(function() loadstring(game:HttpGet(CFG.CU .. "?v=" .. tostring(tick())))() end)
        if not success then warn("Core Load Error:", err); SN("Ultimate Hub", "Failed to load core!", 5); return end
        task.wait(0.5)
        C = getgenv().UHCore
        if not C then warn("Core not found"); SN("Ultimate Hub", "Core not found!", 5); return end
    end
    
    print("=== CORE LOADED ===")
    task.wait(0.2)
    
    local S = C.Settings
    local R
    local success, err = pcall(function() R = loadstring(game:HttpGet("https://sirius.menu/rayfield"))() end)
    if not success or not R then warn("Rayfield Error:", err); SN("Ultimate Hub", "Failed to load UI!", 5); return end
    
    print("=== RAYFIELD LOADED ===")
    R.Notify = function() end
    
    local W = R:CreateWindow({Name = "Ultimate Hub V10 | ToingDC", LoadingTitle = "Ultimate Hub", LoadingSubtitle = "by ToingDC", ConfigurationSaving = {Enabled = false}, KeySystem = false})
    getgenv().UH = W
    
    -------------------------------------------------
    -- ESP TAB
    -------------------------------------------------
    local E = W:CreateTab("ESP", 4483362458)
    E:CreateSection("Player ESP")
    E:CreateToggle({Name = "Killer ESP", CurrentValue = false, Callback = function(v) pcall(function() if v then C.StartKillerESP() else C.StopKillerESP() end end) end})
    E:CreateToggle({Name = "Survivor ESP", CurrentValue = false, Callback = function(v) pcall(function() if v then C.StartSurvivorESP() else C.StopSurvivorESP() end end) end})
    E:CreateSection("Object ESP")
    E:CreateToggle({Name = "Generator ESP", CurrentValue = false, Callback = function(v) pcall(function() if v then C.StartGenESP() else C.StopGenESP() end end) end})
    E:CreateToggle({Name = "Pallet ESP", CurrentValue = false, Callback = function(v) pcall(function() if v then C.StartPalletESP() else C.StopPalletESP() end end) end})
    E:CreateSection("ESP Settings")
    E:CreateSlider({Name = "Fill Transparency", Range = {0, 1}, Increment = 0.1, CurrentValue = 0.85, Callback = function(v) pcall(function() C.SetESPFillTransparency(v) end) end})
    E:CreateSlider({Name = "Outline Transparency", Range = {0, 1}, Increment = 0.1, CurrentValue = 0.5, Callback = function(v) pcall(function() C.SetESPOutlineTransparency(v) end) end})
    
    -------------------------------------------------
    -- SURVIVOR TAB
    -------------------------------------------------
    local SV = W:CreateTab("Survivor", 4483362458)
    SV:CreateSection("Auto Actions")
    SV:CreateToggle({Name = "Auto Generator Repair", CurrentValue = false, Callback = function(v) pcall(function() if v then C.StartAutoRepairGen() else C.StopAutoRepairGen() end end) end})
    SV:CreateToggle({Name = "Auto Heal Teammate", CurrentValue = false, Callback = function(v) pcall(function() if v then C.StartAutoHeal() else C.StopAutoHeal() end end) end})
    SV:CreateToggle({Name = "Auto Unhook Teammate", CurrentValue = false, Callback = function(v) pcall(function() if v then C.StartAutoUnhook() else C.StopAutoUnhook() end end) end})
    SV:CreateToggle({Name = "Auto Parry Killer", CurrentValue = false, Callback = function(v) pcall(function() if v then C.StartAutoParry() else C.StopAutoParry() end end) end})
    SV:CreateSlider({Name = "Parry Distance", Range = {5, 25}, Increment = 1, CurrentValue = 12, Callback = function(v) pcall(function() C.SetAutoParryDistance(v) end) end})
    SV:CreateSection("Environment")
    SV:CreateToggle({Name = "No Fog", CurrentValue = false, Callback = function(v) pcall(function() if v then C.StartNoFog() else C.StopNoFog() end end) end})
    SV:CreateToggle({Name = "Fullbright", CurrentValue = false, Callback = function(v) pcall(function() C.SetFullbright(v) end) end})
    SV:CreateSection("Performance")
    SV:CreateToggle({Name = "Anti-Lag Mode", CurrentValue = false, Callback = function(v) pcall(function() if v then C.StartAntiLag() else C.StopAntiLag() end end) end})
    
    -------------------------------------------------
    -- KILLER TAB
    -------------------------------------------------
    local K = W:CreateTab("Killer", 4483362458)
    K:CreateSection("Auto Attack")
    K:CreateToggle({Name = "Enable Auto Attack", CurrentValue = false, Callback = function(v) pcall(function() if v then C.StartAutoAttack() else C.StopAutoAttack() end end) end})
    K:CreateSlider({Name = "Attack Distance", Range = {5, 30}, Increment = 1, CurrentValue = 15, Callback = function(v) pcall(function() C.SetAutoAttackDistance(v) end) end})
    K:CreateSlider({Name = "Attack Cooldown", Range = {0.5, 5}, Increment = 0.1, CurrentValue = 1.5, Callback = function(v) pcall(function() C.SetAutoAttackCooldown(v) end) end})
    K:CreateSection("Protection")
    K:CreateToggle({Name = "Anti-Blind", CurrentValue = false, Callback = function(v) pcall(function() if v then C.StartAntiBlind() else C.StopAntiBlind() end end) end})
    K:CreateSection("Camera Mode")
    K:CreateDropdown({Name = "Camera View", Options = C.CameraModes or {"Default", "FirstPerson", "ThirdPerson"}, CurrentOption = {"Default"}, Callback = function(o) pcall(function() if o and #o > 0 then C.SetCameraMode(o[1]) end end) end})
    
    -------------------------------------------------
    -- PLAYER TAB
    -------------------------------------------------
    local P = W:CreateTab("Player", 4483362458)
    P:CreateSection("Speed Boost")
    
    local currentSpeed = 16
    pcall(function() if C.WalkspeedSystem and C.WalkspeedSystem.Spd then currentSpeed = C.WalkspeedSystem.Spd end end)
    
    local SPL = P:CreateLabel("Speed: " .. currentSpeed)
    
    P:CreateSlider({Name = "Set Speed", Range = {1, 100}, Increment = 1, CurrentValue = currentSpeed, Callback = function(v)
        pcall(function()
            local ns = C.WalkspeedSystem:SetSpeed(v)
            if ns then SPL:Set("Speed: " .. ns) end
        end)
    end})
    
    P:CreateButton({Name = "Speed -5", Callback = function()
        pcall(function()
            local ns = C.WalkspeedSystem:SetSpeed(C.WalkspeedSystem.Spd - 5)
            if ns then SPL:Set("Speed: " .. ns) end
        end)
    end})
    
    P:CreateButton({Name = "Speed +5", Callback = function()
        pcall(function()
            local ns = C.WalkspeedSystem:SetSpeed(C.WalkspeedSystem.Spd + 5)
            if ns then SPL:Set("Speed: " .. ns) end
        end)
    end})
    
    P:CreateToggle({Name = "Enable Speed Boost", CurrentValue = false, Callback = function(v)
        pcall(function()
            if v then C.WalkspeedSystem:Start() else C.WalkspeedSystem:Stop() end
        end)
    end})
    
    P:CreateSection("Teleport")
    local SP = nil
    local PD = P:CreateDropdown({Name = "Select Player", Options = C.GetPlayerList(), Callback = function(o) if o and #o > 0 then SP = o[1] end end})
    P:CreateButton({Name = "Refresh Player List", Callback = function() pcall(function() PD:Set(C.GetPlayerList()) end) end})
    P:CreateButton({Name = "Teleport to Player", Callback = function() pcall(function() if SP then C.TeleportTo(SP) end end) end})
    
    -------------------------------------------------
    -- AIM TAB
    -------------------------------------------------
    local A = W:CreateTab("Aim", 4483362458)
    
    A:CreateSection("Target Settings")
    A:CreateDropdown({Name = "Target Role", Options = {"Everyone", "Survivor", "Killer"}, CurrentOption = {"Everyone"}, Callback = function(o) pcall(function() if o and #o > 0 then C.AimSystem:SetMode(o[1]) end end) end})
    A:CreateDropdown({Name = "Target Part", Options = C.TargetParts or {"Head", "Body", "RightArm", "LeftArm"}, CurrentOption = {"Head"}, Callback = function(o) pcall(function() if o and #o > 0 then C.AimSystem:SetPart(o[1]) end end) end})
    
    A:CreateSection("Auto Aim")
    A:CreateToggle({Name = "Enable Auto Aim", CurrentValue = false, Callback = function(v) pcall(function() if v then C.AimSystem:Start() else C.AimSystem:Stop() end end) end})
    A:CreateSlider({Name = "Auto Aim Distance", Range = {10, 150}, Increment = 5, CurrentValue = 50, Callback = function(v) pcall(function() C.AimSystem:SetDist(v) end) end})
    A:CreateToggle({Name = "Lock Camera to Target", CurrentValue = true, Callback = function(v) pcall(function() C.AimSystem:SetLock(v) end) end})
    
    A:CreateSection("Crosshair")
    A:CreateToggle({Name = "Enable Crosshair", CurrentValue = false, Callback = function(v) pcall(function() if v then C.StartCrosshair() else C.StopCrosshair() end end) end})
    A:CreateDropdown({Name = "Crosshair Style", Options = C.CrosshairTypes or {"Sniper", "Weapon", "Dot"}, CurrentOption = {"Sniper"}, Callback = function(o) pcall(function() if o and #o > 0 then C.CrosshairSystem:Style(o[1]) end end) end})
    A:CreateSlider({Name = "Crosshair Size", Range = {5, 50}, Increment = 1, CurrentValue = 12, Callback = function(v) pcall(function() C.SetCrosshairSize(v) end) end})
    A:CreateSlider({Name = "Crosshair Gap", Range = {0, 30}, Increment = 1, CurrentValue = 6, Callback = function(v) pcall(function() C.SetCrosshairGap(v) end) end})
    A:CreateSlider({Name = "Crosshair Dot Size", Range = {1, 15}, Increment = 1, CurrentValue = 3, Callback = function(v) pcall(function() C.SetCrosshairDotSize(v) end) end})
    A:CreateSlider({Name = "Crosshair Thickness", Range = {1, 10}, Increment = 1, CurrentValue = 2, Callback = function(v) pcall(function() C.SetCrosshairThickness(v) end) end})
    
    -------------------------------------------------
    -- SETTINGS TAB
    -------------------------------------------------
    local STT = W:CreateTab("Settings", 4483362458)
    STT:CreateSection("ESP Colors")
    STT:CreateColorPicker({Name = "Killer Color", Color = (S and S.Col and S.Col.K) or Color3.fromRGB(255,80,80), Callback = function(c) pcall(function() C.SetKillerColor(c); C.RefreshESPColors() end) end})
    STT:CreateColorPicker({Name = "Survivor Color", Color = (S and S.Col and S.Col.SV) or Color3.fromRGB(80,255,80), Callback = function(c) pcall(function() C.SetSurvivorColor(c); C.RefreshESPColors() end) end})
    STT:CreateColorPicker({Name = "Pallet Color", Color = (S and S.Col and S.Col.PL) or Color3.fromRGB(255,200,80), Callback = function(c) pcall(function() C.SetPalletColor(c); C.RefreshESPColors() end) end})
    STT:CreateSection("Generator ESP Colors")
    STT:CreateColorPicker({Name = "Gen Low (0-49%)", Color = (S and S.Col and S.Col.GL) or Color3.fromRGB(255,0,0), Callback = function(c) pcall(function() C.SetGenLowColor(c) end) end})
    STT:CreateColorPicker({Name = "Gen Progress (50-99%)", Color = (S and S.Col and S.Col.GM) or Color3.fromRGB(255,255,0), Callback = function(c) pcall(function() C.SetGenMidColor(c) end) end})
    STT:CreateColorPicker({Name = "Gen Complete (100%)", Color = (S and S.Col and S.Col.GH) or Color3.fromRGB(0,255,0), Callback = function(c) pcall(function() C.SetGenHighColor(c) end) end})
    STT:CreateSection("Crosshair Colors")
    STT:CreateColorPicker({Name = "Crosshair Normal", Color = (S and S.Col and S.Col.CR) or Color3.fromRGB(255,255,255), Callback = function(c) pcall(function() C.SetCrosshairColor(c) end) end})
    STT:CreateColorPicker({Name = "Crosshair Locked", Color = (S and S.Col and S.Col.CL) or Color3.fromRGB(255,0,0), Callback = function(c) pcall(function() C.SetCrosshairLockColor(c) end) end})
    STT:CreateSection("Controls")
    STT:CreateButton({Name = "Rejoin Server", Callback = function() pcall(function() C.Rejoin() end) end})
    STT:CreateButton({Name = "Refresh ESP Colors", Callback = function() pcall(function() C.RefreshESPColors() end) end})
    STT:CreateButton({Name = "Stop All Features", Callback = function() pcall(function() C.StopAll() end) end})
    STT:CreateButton({Name = "Destroy Hub", Callback = function() pcall(function() C.StopAll(); R:Destroy(); getgenv().UH = nil; getgenv().UHLoaded = nil end) end})
    
    print("=== ULTIMATE HUB V10.3 LOADED ===")
    SN("Ultimate Hub", "V10.3 Loaded!", 3)
end

-- LANGSUNG LOAD TANPA KEY SYSTEM
print("=== LOADING HUB (NO KEY) ===")
LH()