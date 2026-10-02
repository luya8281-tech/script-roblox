-- ============================================================
--  REMOTE LOGGER v2.0  |  by luya8281-tech
--  Rekam semua RemoteEvent/Function, filter keyword,
--  simpan ke file atau clipboard
--  Paste script ini di executor (Delta / Fluxus / Synapse dll)
-- ============================================================

-- ⚙️ KONFIGURASI — EDIT DI SINI
local CFG = {
    -- Keyword filter: hanya rekam remote yang mengandung salah satu kata ini
    -- Kosongkan {} untuk rekam SEMUA remote
    Filter = {
        "attack", "hit", "parry", "block", "damage",
        "skill", "repair", "hook", "unhook", "carry",
        "escape", "vault", "gate", "heal", "basic",
        "after", "slow", "fall", "knock", "down"
    },

    -- Keyword BLACKLIST: remote ini TIDAK direkam (terlalu spam)
    Blacklist = {
        "mouse", "camera", "render", "heartbeat",
        "ping", "chat", "network", "position", "move"
    },

    -- Max rekaman disimpan di memory
    MaxLogs = 300,

    -- Simpan ke file (butuh executor yang support writefile)
    SaveToFile = true,
    FileName = "remote_log.txt",

    -- Tombol shortcut (keyboard)
    KeyExport = Enum.KeyCode.F7,   -- export ke file
    KeyClear  = Enum.KeyCode.F8,   -- hapus semua log
    KeyToggle = Enum.KeyCode.F6,   -- pause/resume rekaman
}

-- ============================================================
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local Logs = {}
local Recording = true
local TotalCaught = 0

-- Helper: cek apakah string mengandung keyword
local function matchAny(str, list)
    str = str:lower()
    for _, kw in ipairs(list) do
        if str:find(kw:lower(), 1, true) then return true end
    end
    return false
end

-- Helper: format args menjadi string yang bisa dibaca
local function formatArgs(args)
    local parts = {}
    for i, v in ipairs(args) do
        local t = type(v)
        local s
        if t == "string" then
            s = '"' .. tostring(v) .. '"'
        elseif t == "number" then
            s = tostring(math.floor(v * 1000) / 1000)
        elseif t == "boolean" then
            s = tostring(v)
        elseif t == "table" then
            s = "{table #" .. #v .. "}"
        elseif typeof and typeof(v) == "Instance" then
            s = "[" .. v.ClassName .. "] " .. v.Name
        elseif typeof and typeof(v) == "Vector3" then
            s = string.format("V3(%.1f,%.1f,%.1f)", v.X, v.Y, v.Z)
        else
            local ok, str2 = pcall(tostring, v)
            s = ok and str2 or "?"
        end
        table.insert(parts, "arg" .. i .. "=" .. s)
    end
    return #parts > 0 and table.concat(parts, ", ") or "(no args)"
end

-- Rekam log baru
local function addLog(remoteName, remotePath, method, args)
    if not Recording then return end

    -- Cek blacklist dulu
    if #CFG.Blacklist > 0 and matchAny(remoteName .. remotePath, CFG.Blacklist) then return end

    -- Cek filter
    if #CFG.Filter > 0 and not matchAny(remoteName .. remotePath, CFG.Filter) then return end

    TotalCaught = TotalCaught + 1
    local entry = string.format(
        "[%03d] [%s] %s | Path: %s | %s",
        TotalCaught,
        method,
        remoteName,
        remotePath,
        formatArgs(args)
    )

    table.insert(Logs, entry)
    if #Logs > CFG.MaxLogs then table.remove(Logs, 1) end

    print("📡 " .. entry)
end

-- ============================================================
-- HOOK __namecall (tangkap FireServer, InvokeServer, dll)
-- ============================================================
local hookedOK = false
pcall(function()
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    local oldNC = mt.__namecall
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        -- Hanya tangkap method yang relevan
        if method == "FireServer" or method == "InvokeServer"
        or method == "FireClient" or method == "FireAllClients" then
            if typeof(self) == "Instance" and
               (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
                local args = {...}
                local name = self.Name
                local path = pcall(function() return self:GetFullName() end) and self:GetFullName() or name
                -- Jalankan rekam di background agar tidak delay game
                task.defer(function()
                    addLog(name, path, method, args)
                end)
            end
        end
        return oldNC(self, ...)
    end)
    setreadonly(mt, true)
    hookedOK = true
end)

-- ============================================================
-- EXPORT ke file / clipboard
-- ============================================================
local function exportLogs()
    if #Logs == 0 then
        warn("📭 Tidak ada log yang direkam.")
        return
    end

    local header = string.format(
        "=== REMOTE LOG | %d entries | Game: %s (PlaceId: %d) ===\n",
        #Logs,
        game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name or "Unknown",
        game.PlaceId
    )
    local content = header .. table.concat(Logs, "\n")

    -- Coba simpan ke file
    if CFG.SaveToFile then
        local ok = pcall(writefile, CFG.FileName, content)
        if ok then
            print("💾 Log disimpan ke: " .. CFG.FileName)
        else
            warn("⚠️ writefile tidak didukung executor ini.")
        end
    end

    -- Coba copy ke clipboard
    local ok2 = pcall(setclipboard, content)
    if ok2 then
        print("📋 Log disalin ke clipboard!")
    else
        warn("⚠️ setclipboard tidak didukung, cek file saja.")
    end

    print(string.format("📊 Total: %d log | Filter aktif: %s",
        #Logs,
        #CFG.Filter > 0 and table.concat(CFG.Filter, ", ") or "SEMUA"
    ))
end

-- ============================================================
-- SEARCH: cari log berdasarkan keyword
-- ============================================================
local function searchLogs(keyword)
    local found = {}
    for _, entry in ipairs(Logs) do
        if entry:lower():find(keyword:lower(), 1, true) then
            table.insert(found, entry)
        end
    end
    if #found == 0 then
        print("🔍 Tidak ada hasil untuk: " .. keyword)
    else
        print(string.format("🔍 Ditemukan %d hasil untuk '%s':", #found, keyword))
        for _, e in ipairs(found) do print("  " .. e) end
    end
    return found
end

-- ============================================================
-- GUI SEDERHANA (tombol di layar)
-- ============================================================
local function makeGUI()
    pcall(function()
        local old = game:GetService("CoreGui"):FindFirstChild("RemoteLoggerGUI")
        if old then old:Destroy() end
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "RemoteLoggerGUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() gui.Parent = game:GetService("CoreGui") end)

    -- Frame utama
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 260, 0, 160)
    frame.Position = UDim2.new(0, 10, 0.5, -80)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -30, 0, 30)
    title.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
    title.Text = "📡 Remote Logger v2.0"
    title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.Parent = frame
    local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(0,8) tc.Parent = title

    -- Minimize Button
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 30, 0, 30)
    minBtn.Position = UDim2.new(1, -30, 0, 0)
    minBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 180)
    minBtn.Text = "—"
    minBtn.TextColor3 = Color3.new(1,1,1)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 14
    minBtn.Parent = frame
    local mbc = Instance.new("UICorner") mbc.CornerRadius = UDim.new(0,8) mbc.Parent = minBtn

    local isMinimized = false
    minBtn.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        minBtn.Text = isMinimized and "◻" or "—"
        frame.Size = isMinimized and UDim2.new(0, 260, 0, 30) or UDim2.new(0, 260, 0, 160)
        -- Sembunyikan semua elemen kecuali title & minBtn
        for _, ch in pairs(frame:GetChildren()) do
            if ch ~= title and ch ~= minBtn and not ch:IsA("UICorner") then
                ch.Visible = not isMinimized
            end
        end
    end)

    -- Status label
    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1, -10, 0, 20)
    statusLbl.Position = UDim2.new(0, 5, 0, 33)
    statusLbl.BackgroundTransparency = 1
    statusLbl.TextColor3 = Color3.fromRGB(100, 255, 100)
    statusLbl.Font = Enum.Font.Gotham
    statusLbl.TextSize = 11
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.Parent = frame

    local function updateStatus()
        statusLbl.Text = string.format(
            "● %s | Caught: %d | Stored: %d",
            Recording and "RECORDING" or "PAUSED",
            TotalCaught, #Logs
        )
        statusLbl.TextColor3 = Recording
            and Color3.fromRGB(100,255,100)
            or Color3.fromRGB(255,200,50)
    end
    updateStatus()

    -- Buat tombol
    local function makeBtn(text, posY, color, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.47, 0, 0, 28)
        btn.Position = UDim2.new(posY > 90 and 0.51 or 0.01, 0, 0, posY)
        if posY > 90 then
            btn.Position = UDim2.new(0.51, 0, 0, posY - 34)
        end
        btn.BackgroundColor3 = color
        btn.Text = text
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.BorderSizePixel = 0
        btn.Parent = frame
        local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0,6) bc.Parent = btn
        btn.MouseButton1Click:Connect(function()
            pcall(callback)
            updateStatus()
        end)
        return btn
    end

    -- Layout 2 kolom
    local btnY = 60
    makeBtn("⏸ Pause/Resume", btnY, Color3.fromRGB(80,130,80), function()
        Recording = not Recording
        print(Recording and "▶ Recording ON" or "⏸ Recording PAUSED")
    end)

    local b2 = Instance.new("TextButton")
    b2.Size = UDim2.new(0.47, 0, 0, 28)
    b2.Position = UDim2.new(0.51, 0, 0, btnY)
    b2.BackgroundColor3 = Color3.fromRGB(60, 60, 180)
    b2.Text = "💾 Export"
    b2.TextColor3 = Color3.new(1,1,1)
    b2.Font = Enum.Font.GothamBold
    b2.TextSize = 11
    b2.BorderSizePixel = 0
    b2.Parent = frame
    local bc2 = Instance.new("UICorner") bc2.CornerRadius = UDim.new(0,6) bc2.Parent = b2
    b2.MouseButton1Click:Connect(function() pcall(exportLogs) updateStatus() end)

    local b3 = Instance.new("TextButton")
    b3.Size = UDim2.new(0.47, 0, 0, 28)
    b3.Position = UDim2.new(0.01, 0, 0, btnY + 34)
    b3.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
    b3.Text = "🗑 Clear"
    b3.TextColor3 = Color3.new(1,1,1)
    b3.Font = Enum.Font.GothamBold
    b3.TextSize = 11
    b3.BorderSizePixel = 0
    b3.Parent = frame
    local bc3 = Instance.new("UICorner") bc3.CornerRadius = UDim.new(0,6) bc3.Parent = b3
    b3.MouseButton1Click:Connect(function()
        Logs = {} TotalCaught = 0
        print("🗑 Log dibersihkan")
        updateStatus()
    end)

    -- Search box
    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(0.47, 0, 0, 28)
    searchBox.Position = UDim2.new(0.51, 0, 0, btnY + 34)
    searchBox.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    searchBox.PlaceholderText = "🔍 Cari keyword..."
    searchBox.Text = ""
    searchBox.TextColor3 = Color3.new(1,1,1)
    searchBox.PlaceholderColor3 = Color3.fromRGB(150,150,150)
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 11
    searchBox.BorderSizePixel = 0
    searchBox.ClearTextOnFocus = false
    searchBox.Parent = frame
    local bcs = Instance.new("UICorner") bcs.CornerRadius = UDim.new(0,6) bcs.Parent = searchBox
    searchBox.FocusLost:Connect(function(enterPressed)
        if enterPressed and searchBox.Text ~= "" then
            searchLogs(searchBox.Text)
        end
    end)

    -- Info shortcut
    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -10, 0, 18)
    info.Position = UDim2.new(0, 5, 0, btnY + 68)
    info.BackgroundTransparency = 1
    info.TextColor3 = Color3.fromRGB(120,120,150)
    info.Font = Enum.Font.Gotham
    info.TextSize = 10
    info.Text = "F6=Toggle F7=Export F8=Clear | Drag to move"
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.Parent = frame

    -- Auto-update status tiap 2 detik
    task.spawn(function()
        while gui and gui.Parent do
            task.wait(2)
            pcall(updateStatus)
        end
    end)
end

-- ============================================================
-- KEYBOARD SHORTCUTS
-- ============================================================
UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == CFG.KeyToggle then
        Recording = not Recording
        print(Recording and "▶ Remote Logger: ON" or "⏸ Remote Logger: PAUSED")
    elseif input.KeyCode == CFG.KeyExport then
        exportLogs()
    elseif input.KeyCode == CFG.KeyClear then
        Logs = {} TotalCaught = 0
        print("🗑 Log dibersihkan (F8)")
    end
end)

-- ============================================================
-- GLOBAL FUNCTIONS (bisa diketik di console executor)
-- ============================================================
getgenv().RL = {
    Export  = exportLogs,
    Search  = searchLogs,
    Clear   = function() Logs = {} TotalCaught = 0 print("Cleared") end,
    Pause   = function() Recording = false print("Paused") end,
    Resume  = function() Recording = true print("Resumed") end,
    Logs    = Logs,

    -- Filter cepat: ubah keyword tanpa restart
    SetFilter = function(tbl)
        CFG.Filter = tbl
        print("Filter diset: " .. table.concat(tbl, ", "))
    end,
}

-- ============================================================
-- START
-- ============================================================
makeGUI()
print(string.format([[
📡 Remote Logger v2.0 AKTIF
━━━━━━━━━━━━━━━━━━━━━━━━━━
Hook status : %s
Filter aktif: %s
Max log     : %d entries
━━━━━━━━━━━━━━━━━━━━━━━━━━
Shortcut:
  F6 = Pause/Resume
  F7 = Export ke file/clipboard
  F8 = Clear semua log
━━━━━━━━━━━━━━━━━━━━━━━━━━
Console commands:
  RL.Search("parry")   → cari log
  RL.SetFilter({"parry","hit"})
  RL.Export()
  RL.Clear()
]],
    hookedOK and "✅ Berhasil hook __namecall" or "❌ Gagal hook (coba executor lain)",
    #CFG.Filter > 0 and table.concat(CFG.Filter, ", ") or "SEMUA REMOTE",
    CFG.MaxLogs
))
