-- ================================================================
-- TITAN FISHING v17
-- 2 mang click doc lap | Fix tam click | Panel nho goc trai
-- ================================================================
local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local RS      = game:GetService("RunService")
local PFS     = game:GetService("PathfindingService")
local TS      = game:GetService("TweenService")
local VIM     = game:GetService("VirtualInputManager")
local LP      = Players.LocalPlayer

-- ================================================================
-- STATE
-- ================================================================
local isRunning    = false
local statusText   = "Chua bat"
local sellCount    = 0
local fishCaught   = 0
local fishSession  = 0
local fishMinutes  = 1
local countdownSec = 0
local isSelling    = false

-- Toa do da luu (Vector2)
local savedFishPos  = nil   -- vi tri 3D cau ca
local savedNPCPos   = nil   -- vi tri 3D NPC
local savedSellPos  = nil   -- toa do 2D nut SellAll
local savedClosePos = nil   -- toa do 2D nut X dong
local savedCastPos  = nil   -- toa do 2D nut Fishing

-- ZXCV
local zxcvPos      = {nil,nil,nil,nil}   -- toa do 2D tung chieu
local zxcvCooldown = {1.0,1.0,1.0,1.0}  -- cooldown (giay)
local zxcvNames    = {"Z","X","C","V"}
local zxcvColors   = {
    Color3.fromRGB(80,160,255),
    Color3.fromRGB(200,80,255),
    Color3.fromRGB(255,110,40),
    Color3.fromRGB(40,220,170),
}

-- ================================================================
-- MANG CLICK 1: NEM CAN (TouchEvent - nut game)
-- Hoan toan doc lap, co toggle rieng
-- ================================================================
local castActive = false

local function doCastClick(x, y)
    -- Chi dung TouchEvent, khong dung mouse
    -- Khong co wait ngoai giua cac lan click
    pcall(function()
        VIM:SendTouchEvent(x, y, Enum.UserInputState.Begin, 0)
    end)
    task.wait(0.06)
    pcall(function()
        VIM:SendTouchEvent(x, y, Enum.UserInputState.End, 0)
    end)
end

local function startCastLoop()
    task.spawn(function()
        while castActive do
            if savedCastPos and not isSelling then
                doCastClick(savedCastPos.X, savedCastPos.Y)
            end
            task.wait(0.5)
        end
    end)
end

-- ================================================================
-- MANG CLICK 2: CHIEU ZXCV (MouseButtonEvent - nut UI)
-- Moi chieu 1 goroutine rieng, cooldown rieng
-- KHONG dung wait chung, KHONG doi nhau
-- ================================================================
local skillActive = false

local function doSkillClick(x, y)
    -- Dung MouseButton, di chuyen den dung tam truoc
    pcall(function()
        VIM:SendMouseMoveEvent(x, y, game)
    end)
    task.wait(0.03)
    pcall(function()
        VIM:SendMouseButtonEvent(x, y, 0, true,  game, 0)
    end)
    task.wait(0.05)
    pcall(function()
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

local function startSkillLoop(idx)
    task.spawn(function()
        -- Offset nho de cac chieu khong bat dau cung luc
        task.wait((idx - 1) * 0.05)
        while skillActive do
            if zxcvPos[idx] and not isSelling then
                doSkillClick(zxcvPos[idx].X, zxcvPos[idx].Y)
                -- Doi dung cooldown cua chieu nay (khong block chieu khac)
                local cd = zxcvCooldown[idx] or 1.0
                local t  = 0
                while t < cd and skillActive do
                    task.wait(0.05)
                    t = t + 0.05
                end
            else
                task.wait(0.1)
            end
        end
    end)
end

local function startAllSkills()
    for i = 1, 4 do
        startSkillLoop(i)
    end
end

-- ================================================================
-- WALK / PATHFINDING
-- ================================================================
local function walkTo(pos, lbl)
    local char = LP.Character; if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    statusText = lbl or "Dang di..."
    hum.WalkSpeed = 24
    local path = PFS:CreatePath({AgentHeight=5,AgentRadius=2,AgentCanJump=true})
    local ok   = pcall(function() path:ComputeAsync(hrp.Position, pos) end)
    if ok and path.Status == Enum.PathStatus.Success then
        for _, wp in ipairs(path:GetWaypoints()) do
            if not isRunning then return end
            if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
            hum:MoveTo(wp.Position)
            hum.MoveToFinished:Wait(3)
            if (hrp.Position - pos).Magnitude < 8 then break end
        end
    else
        hum:MoveTo(pos)
        local t = 0
        while t < 12 and isRunning do
            task.wait(0.2); t = t + 0.2
            if (hrp.Position - pos).Magnitude < 8 then break end
        end
    end
end

local function stopWalk()
    local c = LP.Character
    local h = c and c:FindFirstChild("Humanoid")
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if h and r then h:MoveTo(r.Position) end
end

-- ================================================================
-- INTERACT + SELL (dung mouse bĂ¬nh thuong cho UI)
-- ================================================================
local function uiClick(x, y)
    pcall(function() VIM:SendMouseMoveEvent(x, y, game) end)
    task.wait(0.04)
    pcall(function() VIM:SendMouseButtonEvent(x, y, 0, true,  game, 0) end)
    task.wait(0.1)
    pcall(function() VIM:SendMouseButtonEvent(x, y, 0, false, game, 0) end)
    task.wait(0.05)
end

local function doInteract()
    statusText = "Mo cua hang..."
    local char = LP.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local best, bestD = nil, math.huge
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ProximityPrompt") then
                local p = v.Parent
                if p and p:IsA("BasePart") then
                    local d = (hrp.Position - p.Position).Magnitude
                    if d < bestD then bestD = d; best = v end
                end
            end
        end
        if best and bestD < 20 then
            pcall(function() fireproximityprompt(best) end)
            task.wait(0.5)
        end
    end
    task.wait(0.8)
end

local function doSellAll()
    if not savedSellPos or not savedClosePos then
        statusText = "Chua luu SellAll/X!"; task.wait(2); return
    end
    statusText = "Cho popup..."
    task.wait(0.8)
    uiClick(savedSellPos.X,  savedSellPos.Y)
    task.wait(1.2)
    uiClick(savedClosePos.X, savedClosePos.Y)
    task.wait(0.5)
    statusText = "Da ban xong!"
end

-- ================================================================
-- MAIN LOOP: cau X phut -> dung -> ban -> quay lai
-- ================================================================
local function mainLoop()
    local miss = {}
    if not savedFishPos  then table.insert(miss, "Vi tri cau") end
    if not savedNPCPos   then table.insert(miss, "Vi tri NPC") end
    if not savedSellPos  then table.insert(miss, "SellAll") end
    if not savedClosePos then table.insert(miss, "X dong") end
    if not savedCastPos  then table.insert(miss, "Nut Fishing") end
    local hz = false
    for i = 1, 4 do if zxcvPos[i] then hz = true end end
    if not hz then table.insert(miss, "ZXCV") end
    if #miss > 0 then
        statusText = "Thieu: " .. table.concat(miss, ", ") .. "!"
        isRunning = false; return
    end

    while isRunning do
        -- 1. Di ve vi tri cau
        isSelling    = false
        castActive   = false
        skillActive  = false
        task.wait(0.3)  -- dam bao goroutine cu da dung truoc khi spawn moi

        local char = LP.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and savedFishPos and (hrp.Position - savedFishPos).Magnitude > 5 then
            walkTo(savedFishPos, "Di ve vi tri cau...")
            if not isRunning then break end
            stopWalk(); task.wait(0.5)
        end

        -- 2. Bat 2 mang spam (spawn MOI moi chu ky, sach se)
        castActive  = true
        skillActive = true
        startCastLoop()
        startAllSkills()

        -- 3. Dem nguoc thoi gian cau
        countdownSec = fishMinutes * 60
        while countdownSec > 0 and isRunning do
            local m = math.floor(countdownSec / 60)
            local s = countdownSec % 60
            statusText = m .. ":" .. string.format("%02d", s) .. " | Ca:" .. fishCaught .. " Ban:" .. sellCount
            task.wait(1)
            countdownSec = countdownSec - 1
        end
        if not isRunning then break end

        -- 4. Het gio: dung spam truoc, doi goroutine ket thuc, roi di ban
        isSelling   = true
        castActive  = false
        skillActive = false
        task.wait(0.6)  -- cho du thoi gian cac goroutine thoat vong while

        statusText = "Het gio! Di ban..."
        fishCaught  = fishCaught  + 1
        fishSession = fishSession + 1

        walkTo(savedNPCPos, "Di toi NPC...")
        if not isRunning then break end
        task.wait(0.3); stopWalk(); task.wait(0.5)
        doInteract(); task.wait(0.5)
        doSellAll();  task.wait(0.5)

        sellCount = sellCount + 1
        statusText = "Da ban lan " .. sellCount .. "! Quay lai..."
        task.wait(1)
    end

    -- Tat het
    castActive   = false
    skillActive  = false
    isSelling    = false
    countdownSec = 0
    statusText   = "Da tat"
end

-- ================================================================
-- GUI
-- ================================================================
local old = LP.PlayerGui:FindFirstChild("TFHub")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "TFHub"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = LP.PlayerGui

-- ===== MARKERS =====
-- Khi bam vao marker: lay TAM cua marker (AbsolutePosition + Size/2)
-- Day la toa do chinh xac, khong bi lech
local function makeMarker(col, tag)
    local S = 62
    local m = Instance.new("TextButton")
    m.Size = UDim2.new(0,S,0,S)
    m.Position = UDim2.new(0.5,-S/2, 0.5,-S/2)
    m.BackgroundColor3 = col
    m.BackgroundTransparency = 0.15
    m.BorderSizePixel = 0
    m.Text = ""; m.ZIndex = 50
    m.Active = true; m.Draggable = true
    m.Visible = false; m.Parent = sg
    Instance.new("UICorner", m).CornerRadius = UDim.new(1,0)
    local sk = Instance.new("UIStroke", m)
    sk.Color = Color3.new(1,1,1); sk.Thickness = 2.5

    -- Duong ngam (crosshair)
    local function bar(sz, ps)
        local f = Instance.new("Frame", m)
        f.Size = sz; f.Position = ps
        f.BackgroundColor3 = Color3.new(1,1,0)
        f.BorderSizePixel = 0; f.ZIndex = 51
    end
    bar(UDim2.new(0.65,0,0,2.5), UDim2.new(0.175,0, 0.5,-1.25))
    bar(UDim2.new(0,2.5,0.65,0), UDim2.new(0.5,-1.25, 0.175,0))

    -- Diem tam do (chinh xac = tam se click)
    local dot = Instance.new("Frame", m)
    dot.Size = UDim2.new(0,8,0,8)
    dot.Position = UDim2.new(0.5,-4, 0.5,-4)
    dot.BackgroundColor3 = Color3.fromRGB(255,50,50)
    dot.BorderSizePixel = 0; dot.ZIndex = 52
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)

    -- Nhan tag
    local tl = Instance.new("TextLabel", m)
    tl.Size = UDim2.new(1,0,0,15)
    tl.Position = UDim2.new(0,0, 1,3)
    tl.BackgroundTransparency = 1
    tl.Text = tag
    tl.TextColor3 = Color3.new(1,1,0)
    tl.Font = Enum.Font.GothamBlack
    tl.TextSize = 11; tl.ZIndex = 52

    -- (nhip tim xu ly boi 1 Heartbeat chung o cuoi file)
    return m
end

local markerSell  = makeMarker(Color3.fromRGB(20,200,100),  "SELL")
local markerClose = makeMarker(Color3.fromRGB(220,40,60),   "CLOSE")
local markerCast  = makeMarker(Color3.fromRGB(255,200,0),   "FISHING")
local zxcvMarkers = {}
for i = 1,4 do
    zxcvMarkers[i] = makeMarker(zxcvColors[i], zxcvNames[i])
end

-- ===== PANEL 220x480 GOC TRAI =====
local PW = 220
local PH = 490

local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.Size = UDim2.new(0,PW, 0,PH)
panel.Position = UDim2.new(0,0, 0,36)
panel.BackgroundColor3 = Color3.fromRGB(8,8,20)
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel = 0
panel.Active = true; panel.Draggable = true
panel.ClipsDescendants = true
panel.ZIndex = 10; panel.Parent = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0,12)
local psk = Instance.new("UIStroke", panel)
psk.Color = Color3.fromRGB(255,140,0); psk.Thickness = 1.5
psk.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- ===== NUT TAB (nam ngoai panel, LUON HIEN) =====
local panelOpen = true

local tabBtn = Instance.new("TextButton")
tabBtn.Size = UDim2.new(0,44,0,60)
tabBtn.Position = UDim2.new(0,PW, 0, 36 + PH/2 - 30)
tabBtn.BackgroundColor3 = Color3.fromRGB(255,130,0)
tabBtn.BackgroundTransparency = 0
tabBtn.BorderSizePixel = 0
tabBtn.Text = "X"
tabBtn.TextColor3 = Color3.new(1,1,1)
tabBtn.Font = Enum.Font.GothamBlack
tabBtn.TextSize = 18
tabBtn.ZIndex = 20; tabBtn.Active = true; tabBtn.Parent = sg
Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0,10)
local tabStroke = Instance.new("UIStroke", tabBtn)
tabStroke.Color = Color3.fromRGB(255,200,80); tabStroke.Thickness = 2

local function setPanel(open)
    panelOpen = open
    local panelX = open and 0 or -(PW + 6)
    local tabX   = open and PW or 0
    local tabY   = 36 + PH/2 - 30
    TS:Create(panel,  TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {Position = UDim2.new(0, panelX, 0, 36)}):Play()
    TS:Create(tabBtn, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {Position = UDim2.new(0, tabX,   0, tabY)}):Play()
    -- "X" khi menu dang mo (de dong lai), "OPEN" khi menu da thu
    tabBtn.Text = open and "X" or "OPEN"
    tabBtn.TextSize = open and 18 or 12
    tabBtn.BackgroundColor3 = open
        and Color3.fromRGB(200,50,50)
        or  Color3.fromRGB(40,160,40)
end

tabBtn.MouseButton1Click:Connect(function()
    setPanel(not panelOpen)
end)

-- ===== SCROLL =====
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1,-4, 1,0)
scroll.Position = UDim2.new(0,0, 0,0)
scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = Color3.fromRGB(255,140,0)
scroll.ZIndex = 11; scroll.Parent = panel

-- ===== WIDGET BUILDERS =====
local Y   = 5
local W   = PW - 12

local function mkTitle(txt)
    local f = Instance.new("Frame", scroll)
    f.Size = UDim2.new(0,W, 0,30); f.Position = UDim2.new(0,6, 0,Y)
    f.BorderSizePixel = 0; f.ZIndex = 12
    Instance.new("UICorner",f).CornerRadius = UDim.new(0,8)
    local g = Instance.new("UIGradient",f)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255,100,0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(160,30,200)),
    }); g.Rotation = 90
    local l = Instance.new("TextLabel",f)
    l.Size = UDim2.new(1,0, 1,0); l.BackgroundTransparency = 1
    l.Text = txt; l.TextColor3 = Color3.new(1,1,1)
    l.Font = Enum.Font.GothamBlack; l.TextSize = 13; l.ZIndex = 13
    Y = Y + 35
end

local function mkSec(txt)
    local l = Instance.new("TextLabel", scroll)
    l.Size = UDim2.new(0,W, 0,18); l.Position = UDim2.new(0,6, 0,Y)
    l.BackgroundTransparency = 1; l.Text = txt
    l.TextColor3 = Color3.fromRGB(160,160,255)
    l.Font = Enum.Font.GothamBold; l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd
    l.ZIndex = 12
    Y = Y + 21
end

local function mkDiv()
    local d = Instance.new("Frame", scroll)
    d.Size = UDim2.new(0,W, 0,1); d.Position = UDim2.new(0,6, 0,Y)
    d.BackgroundColor3 = Color3.fromRGB(38,38,70); d.BorderSizePixel = 0; d.ZIndex = 12
    Y = Y + 8
end

-- Nut full width
local function mkBtn(h, bg, txt, fs)
    local b = Instance.new("TextButton", scroll)
    b.Size = UDim2.new(0,W, 0,h); b.Position = UDim2.new(0,6, 0,Y)
    b.BackgroundColor3 = bg; b.BorderSizePixel = 0
    b.Text = txt; b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamBold; b.TextSize = fs or 12
    b.TextWrapped = true
    b.TextTruncate = Enum.TextTruncate.None
    b.ZIndex = 12
    Instance.new("UICorner",b).CornerRadius = UDim.new(0,8)
    Y = Y + h + 5
    return b
end

-- Info row
local function mkInfo(icon, txt, col)
    local f = Instance.new("Frame", scroll)
    f.Size = UDim2.new(0,W, 0,24); f.Position = UDim2.new(0,6, 0,Y)
    f.BackgroundColor3 = Color3.fromRGB(12,12,30); f.BorderSizePixel = 0; f.ZIndex = 12
    Instance.new("UICorner",f).CornerRadius = UDim.new(0,6)
    local il = Instance.new("TextLabel",f)
    il.Size = UDim2.new(0,22, 1,0); il.BackgroundTransparency = 1
    il.Text = icon; il.TextScaled = true; il.ZIndex = 13
    local vl = Instance.new("TextLabel",f)
    vl.Size = UDim2.new(1,-26, 1,0); vl.Position = UDim2.new(0,24, 0,0)
    vl.BackgroundTransparency = 1; vl.Text = txt; vl.TextColor3 = col
    vl.Font = Enum.Font.GothamBold; vl.TextSize = 10
    vl.TextXAlignment = Enum.TextXAlignment.Left
    vl.TextTruncate = Enum.TextTruncate.AtEnd; vl.ZIndex = 13
    Y = Y + 28
    return vl
end

-- Stepper [label] [val] [-] [+]
local function mkStepper(lbl, initVal, col)
    local f = Instance.new("Frame", scroll)
    f.Size = UDim2.new(0,W, 0,30); f.Position = UDim2.new(0,6, 0,Y)
    f.BackgroundColor3 = Color3.fromRGB(12,12,30); f.BorderSizePixel = 0; f.ZIndex = 12
    Instance.new("UICorner",f).CornerRadius = UDim.new(0,7)
    local ll = Instance.new("TextLabel",f)
    ll.Size = UDim2.new(0,82, 1,0); ll.Position = UDim2.new(0,6, 0,0)
    ll.BackgroundTransparency = 1; ll.Text = lbl
    ll.TextColor3 = Color3.fromRGB(200,200,255)
    ll.Font = Enum.Font.GothamBold; ll.TextSize = 11
    ll.TextXAlignment = Enum.TextXAlignment.Left; ll.ZIndex = 13
    local vl = Instance.new("TextLabel",f)
    vl.Size = UDim2.new(0,36, 1,0); vl.Position = UDim2.new(0,90, 0,0)
    vl.BackgroundTransparency = 1; vl.Text = initVal
    vl.TextColor3 = col or Color3.fromRGB(255,220,80)
    vl.Font = Enum.Font.GothamBold; vl.TextSize = 12; vl.ZIndex = 13
    local bm = Instance.new("TextButton",f)
    bm.Size = UDim2.new(0,24, 0,22); bm.Position = UDim2.new(1,-52, 0.5,-11)
    bm.BackgroundColor3 = Color3.fromRGB(160,30,30); bm.BorderSizePixel = 0
    bm.Text = "-"; bm.TextColor3 = Color3.new(1,1,1)
    bm.Font = Enum.Font.GothamBold; bm.TextSize = 15; bm.ZIndex = 13
    Instance.new("UICorner",bm).CornerRadius = UDim.new(0,5)
    local bp = Instance.new("TextButton",f)
    bp.Size = UDim2.new(0,24, 0,22); bp.Position = UDim2.new(1,-26, 0.5,-11)
    bp.BackgroundColor3 = Color3.fromRGB(25,140,50); bp.BorderSizePixel = 0
    bp.Text = "+"; bp.TextColor3 = Color3.new(1,1,1)
    bp.Font = Enum.Font.GothamBold; bp.TextSize = 15; bp.ZIndex = 13
    Instance.new("UICorner",bp).CornerRadius = UDim.new(0,5)
    Y = Y + 35
    return vl, bm, bp
end

-- ===== BUILD UI =====

mkTitle("đŸ£ TITAN FISHING v17")

-- Status
local statusBox = Instance.new("Frame", scroll)
statusBox.Size = UDim2.new(0,W, 0,34); statusBox.Position = UDim2.new(0,6, 0,Y)
statusBox.BackgroundColor3 = Color3.fromRGB(10,10,28); statusBox.BorderSizePixel = 0; statusBox.ZIndex = 12
Instance.new("UICorner",statusBox).CornerRadius = UDim.new(0,8)
Instance.new("UIStroke",statusBox).Color = Color3.fromRGB(40,40,80)
local sDot = Instance.new("Frame",statusBox)
sDot.Size = UDim2.new(0,8,0,8); sDot.Position = UDim2.new(0,7, 0.5,-4)
sDot.BackgroundColor3 = Color3.fromRGB(255,80,80); sDot.BorderSizePixel = 0; sDot.ZIndex = 13
Instance.new("UICorner",sDot).CornerRadius = UDim.new(1,0)
local sLbl = Instance.new("TextLabel",statusBox)
sLbl.Size = UDim2.new(1,-22, 1,0); sLbl.Position = UDim2.new(0,19, 0,0)
sLbl.BackgroundTransparency = 1; sLbl.Text = "Chua bat"
sLbl.TextColor3 = Color3.fromRGB(255,100,100)
sLbl.Font = Enum.Font.GothamBold; sLbl.TextSize = 11
sLbl.TextXAlignment = Enum.TextXAlignment.Left
sLbl.TextWrapped = true
sLbl.TextTruncate = Enum.TextTruncate.None
sLbl.ZIndex = 13
Y = Y + 40

-- Stats (countdown + fish + sell)
local stBox = Instance.new("Frame",scroll)
stBox.Size = UDim2.new(0,W, 0,26); stBox.Position = UDim2.new(0,6, 0,Y)
stBox.BackgroundColor3 = Color3.fromRGB(10,10,28); stBox.BorderSizePixel = 0; stBox.ZIndex = 12
Instance.new("UICorner",stBox).CornerRadius = UDim.new(0,7)
local function stCell(xp, icon, col)
    local f = Instance.new("Frame",stBox)
    f.Size = UDim2.new(0.33,0, 1,0); f.Position = UDim2.new(xp,0, 0,0)
    f.BackgroundTransparency = 1; f.ZIndex = 13
    local il = Instance.new("TextLabel",f)
    il.Size = UDim2.new(0,15, 1,0); il.BackgroundTransparency = 1
    il.Text = icon; il.TextScaled = true; il.ZIndex = 14
    local vl = Instance.new("TextLabel",f)
    vl.Size = UDim2.new(1,-18, 1,0); vl.Position = UDim2.new(0,17, 0,0)
    vl.BackgroundTransparency = 1; vl.TextColor3 = col
    vl.Font = Enum.Font.GothamBold; vl.TextSize = 11
    vl.TextXAlignment = Enum.TextXAlignment.Left; vl.ZIndex = 14
    return vl
end
local stCd   = stCell(0,    "â±", Color3.fromRGB(255,220,80))
local stFish = stCell(0.34, "đŸŸ", Color3.fromRGB(100,220,255))
local stSell = stCell(0.67, "đŸ›’", Color3.fromRGB(100,255,160))
Y = Y + 32

mkDiv()

-- NUT BAT/TAT CHINH
local toggleBtn = mkBtn(40, Color3.fromRGB(30,180,65), "â–¶  BAT TU DONG", 13)
local tGrad = Instance.new("UIGradient",toggleBtn); tGrad.Rotation = 90
tGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(50,220,85)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(18,145,48)),
})

-- BAN NGAY
local sellNowBtn = mkBtn(28, Color3.fromRGB(200,100,0), "đŸ’°  BAN NGAY", 11)

mkDiv()
mkSec("đŸ•¹ SPAM DOC LAP")

-- TOGGLE NEM CAN
local castToggleBtn = mkBtn(30, Color3.fromRGB(160,110,0), "đŸ£  NEM CAN: TAT", 11)

-- TOGGLE CHIEU ZXCV
local skillToggleBtn = mkBtn(30, Color3.fromRGB(70,30,180), "â¡  CHIEU ZXCV: TAT", 11)

mkDiv()
mkSec("đŸ“Œ VI TRI")

local p1Lbl     = mkInfo("đŸ¯","Cau: Chua luu", Color3.fromRGB(120,180,255))
local saveFishBtn = mkBtn(26, Color3.fromRGB(25,100,210), "đŸ“ SAVE vi tri cau hien tai", 10)

local p2Lbl     = mkInfo("đŸª","NPC: Chua luu", Color3.fromRGB(255,180,80))
local saveNPCBtn  = mkBtn(26, Color3.fromRGB(110,35,180), "đŸª SAVE vi tri NPC hien tai", 10)

mkDiv()
mkSec("đŸ›’ NUT BAN CA")

local p3Lbl      = mkInfo("đŸ’","SellAll: Chua luu", Color3.fromRGB(80,255,180))
local showSellBtn  = mkBtn(24, Color3.fromRGB(18,140,72),  "HIEN vong SellAll", 10)

local p4Lbl      = mkInfo("âŒ","X dong: Chua luu", Color3.fromRGB(255,130,180))
local showCloseBtn = mkBtn(24, Color3.fromRGB(175,35,55),  "HIEN vong X dong", 10)

mkDiv()
mkSec("đŸ£ NUT NEM CAN")

local p5Lbl      = mkInfo("đŸŸ¡","Fishing: Chua luu", Color3.fromRGB(255,230,80))
local showCastBtn  = mkBtn(24, Color3.fromRGB(155,115,0),  "HIEN vong Fishing", 10)

mkDiv()
mkSec("â¡ CHIEU Z X C V")

local zxcvToggleBtns = {}
local zxcvInfoLbls   = {}
local zxcvCdLbls     = {}

for i = 1, 4 do
    local nm  = zxcvNames[i]
    local col = zxcvColors[i]

    -- Badge + info toa do
    local rowF = Instance.new("Frame",scroll)
    rowF.Size = UDim2.new(0,W, 0,22); rowF.Position = UDim2.new(0,6, 0,Y)
    rowF.BackgroundTransparency = 1; rowF.ZIndex = 12
    local badge = Instance.new("Frame",rowF)
    badge.Size = UDim2.new(0,22,0,22); badge.BackgroundColor3 = col
    badge.BorderSizePixel = 0; badge.ZIndex = 13
    Instance.new("UICorner",badge).CornerRadius = UDim.new(0,5)
    local bl = Instance.new("TextLabel",badge)
    bl.Size = UDim2.new(1,0,1,0); bl.BackgroundTransparency = 1
    bl.Text = nm; bl.Font = Enum.Font.GothamBlack; bl.TextSize = 13
    bl.TextColor3 = Color3.new(1,1,1); bl.ZIndex = 14
    local sl = Instance.new("TextLabel",rowF)
    sl.Size = UDim2.new(1,-26, 1,0); sl.Position = UDim2.new(0,25, 0,0)
    sl.BackgroundTransparency = 1; sl.Text = "Chua luu"
    sl.TextColor3 = Color3.fromRGB(160,160,160)
    sl.Font = Enum.Font.GothamBold; sl.TextSize = 10
    sl.TextXAlignment = Enum.TextXAlignment.Left
    sl.TextTruncate = Enum.TextTruncate.AtEnd; sl.ZIndex = 13
    zxcvInfoLbls[i] = sl
    Y = Y + 26

    -- Nut hien marker
    local tb = Instance.new("TextButton",scroll)
    tb.Size = UDim2.new(0,W, 0,22); tb.Position = UDim2.new(0,6, 0,Y)
    tb.BackgroundColor3 = col; tb.BorderSizePixel = 0
    tb.Text = "HIEN " .. nm; tb.TextColor3 = Color3.new(1,1,1)
    tb.Font = Enum.Font.GothamBold; tb.TextSize = 10; tb.ZIndex = 12
    Instance.new("UICorner",tb).CornerRadius = UDim.new(0,7)
    zxcvToggleBtns[i] = tb
    Y = Y + 27

    -- Cooldown stepper
    local cdL, cdMin, cdPlus = mkStepper("CD "..nm..":", string.format("%.1fs",zxcvCooldown[i]), col)
    zxcvCdLbls[i] = cdL

    local idx = i
    cdMin.MouseButton1Click:Connect(function()
        zxcvCooldown[idx] = math.max(0.1, math.floor((zxcvCooldown[idx]-0.1)*10+0.5)/10)
        cdL.Text = string.format("%.1fs", zxcvCooldown[idx])
    end)
    cdPlus.MouseButton1Click:Connect(function()
        zxcvCooldown[idx] = math.floor((zxcvCooldown[idx]+0.1)*10+0.5)/10
        cdL.Text = string.format("%.1fs", zxcvCooldown[idx])
    end)
    Y = Y + 4
end

mkDiv()
mkSec("â™ THOI GIAN CAU")

local timLbl, timMin, timPlus = mkStepper("Phut cau:", fishMinutes.."p", Color3.fromRGB(255,220,80))
timMin.MouseButton1Click:Connect(function()
    fishMinutes = math.max(1, fishMinutes-1); timLbl.Text = fishMinutes.."p"
end)
timPlus.MouseButton1Click:Connect(function()
    fishMinutes = fishMinutes+1; timLbl.Text = fishMinutes.."p"
end)

-- Checklist
mkDiv()
mkSec("âœ… TRANG THAI")
local checkLabels = {}
for _, c in ipairs({
    {k="fish",  l="Vi tri cau"},
    {k="npc",   l="Vi tri NPC"},
    {k="sell",  l="SellAll"},
    {k="close", l="X dong"},
    {k="cast",  l="Fishing"},
    {k="zxcv",  l="ZXCV"},
}) do
    local f = Instance.new("Frame",scroll)
    f.Size = UDim2.new(0,W, 0,17); f.Position = UDim2.new(0,6, 0,Y)
    f.BackgroundTransparency = 1; f.ZIndex = 12
    local lbl = Instance.new("TextLabel",f)
    lbl.Size = UDim2.new(1,0, 1,0); lbl.BackgroundTransparency = 1
    lbl.Text = "â—‹ "..c.l; lbl.TextColor3 = Color3.fromRGB(200,60,60)
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 13
    checkLabels[c.k] = lbl; Y = Y + 21
end

Y = Y + 10
scroll.CanvasSize = UDim2.new(0,0, 0,Y)

-- ===== MARKER BINDINGS =====
-- Lay TAM marker (AbsolutePosition + AbsoluteSize/2) = toa do chinh xac
local function markerCenter(m)
    local ap = m.AbsolutePosition
    local as = m.AbsoluteSize
    -- AbsolutePosition la goc tren trai, cong them nua kich thuoc = TAM
    return ap.X + as.X * 0.5, ap.Y + as.Y * 0.5
end

local function bindMarker(marker, showBtn, infoLbl, onSave)
    showBtn.MouseButton1Click:Connect(function()
        marker.Visible = not marker.Visible
        if marker.Visible then
            showBtn.BackgroundColor3 = Color3.fromRGB(120,50,10)
        end
    end)
    marker.MouseButton1Click:Connect(function()
        local cx, cy = markerCenter(marker)
        onSave(Vector2.new(cx,cy), cx, cy)
        marker.BackgroundColor3 = Color3.fromRGB(30,60,170)
        showBtn.BackgroundColor3 = Color3.fromRGB(18,80,18)
        statusText = "Luu tam (" .. math.floor(cx) .. "," .. math.floor(cy) .. ")"
    end)
end

bindMarker(markerSell, showSellBtn, p3Lbl, function(v2,x,y)
    savedSellPos = v2
    p3Lbl.Text = "âœ“ (" .. math.floor(x) .. "," .. math.floor(y) .. ")"
    p3Lbl.TextColor3 = Color3.fromRGB(80,255,180)
    showSellBtn.Text = "âœ“ SellAll da luu"
end)

bindMarker(markerClose, showCloseBtn, p4Lbl, function(v2,x,y)
    savedClosePos = v2
    p4Lbl.Text = "âœ“ (" .. math.floor(x) .. "," .. math.floor(y) .. ")"
    p4Lbl.TextColor3 = Color3.fromRGB(255,150,200)
    showCloseBtn.Text = "âœ“ X dong da luu"
end)

bindMarker(markerCast, showCastBtn, p5Lbl, function(v2,x,y)
    savedCastPos = v2
    p5Lbl.Text = "âœ“ (" .. math.floor(x) .. "," .. math.floor(y) .. ")"
    p5Lbl.TextColor3 = Color3.fromRGB(255,230,80)
    showCastBtn.Text = "âœ“ Fishing da luu"
end)

for i = 1, 4 do
    local m   = zxcvMarkers[i]
    local tb  = zxcvToggleBtns[i]
    local sl  = zxcvInfoLbls[i]
    local col = zxcvColors[i]
    local nm  = zxcvNames[i]

    tb.MouseButton1Click:Connect(function()
        m.Visible = not m.Visible
        if m.Visible then tb.BackgroundColor3 = Color3.fromRGB(120,50,10)
        else          tb.BackgroundColor3 = col end
        tb.Text = m.Visible and ("AN " .. nm) or ("HIEN " .. nm)
    end)

    m.MouseButton1Click:Connect(function()
        local cx, cy = markerCenter(m)
        zxcvPos[i] = Vector2.new(cx, cy)
        sl.Text = "âœ“ (" .. math.floor(cx) .. "," .. math.floor(cy) .. ")"
        sl.TextColor3 = Color3.fromRGB(150,255,150)
        m.BackgroundColor3 = Color3.fromRGB(30,60,170)
        tb.Text = "âœ“ " .. nm; tb.BackgroundColor3 = Color3.fromRGB(18,80,18)
        statusText = "Luu tam " .. nm .. " (" .. math.floor(cx) .. "," .. math.floor(cy) .. ")"
    end)
end

-- ===== SAVE VI TRI =====
saveFishBtn.MouseButton1Click:Connect(function()
    local c = LP.Character; local r = c and c:FindFirstChild("HumanoidRootPart")
    if r then
        savedFishPos = r.Position
        p1Lbl.Text = "âœ“ (" .. math.floor(r.Position.X) .. "," .. math.floor(r.Position.Z) .. ")"
        p1Lbl.TextColor3 = Color3.fromRGB(80,255,120)
        saveFishBtn.Text = "âœ“ Da luu vi tri cau"
        saveFishBtn.BackgroundColor3 = Color3.fromRGB(12,90,40)
    end
end)

saveNPCBtn.MouseButton1Click:Connect(function()
    local c = LP.Character; local r = c and c:FindFirstChild("HumanoidRootPart")
    if r then
        savedNPCPos = r.Position
        p2Lbl.Text = "âœ“ (" .. math.floor(r.Position.X) .. "," .. math.floor(r.Position.Z) .. ")"
        p2Lbl.TextColor3 = Color3.fromRGB(255,220,60)
        saveNPCBtn.Text = "âœ“ Da luu vi tri NPC"
        saveNPCBtn.BackgroundColor3 = Color3.fromRGB(70,15,120)
    end
end)

-- ===== BAT/TAT CHINH =====
toggleBtn.MouseButton1Click:Connect(function()
    isRunning = not isRunning
    if isRunning then
        fishCaught = 0; fishSession = 0; sellCount = 0
        statusText = "Dang khoi dong..."
        task.spawn(mainLoop)
    else
        isRunning   = false
        castActive  = false
        skillActive = false
        stopWalk()
        statusText = "Da tat"
    end
end)

sellNowBtn.MouseButton1Click:Connect(function()
    if not isRunning then statusText = "Bat tu dong truoc!"; return end
    countdownSec = 0
    sellNowBtn.BackgroundColor3 = Color3.fromRGB(255,60,0)
    task.delay(0.8, function() sellNowBtn.BackgroundColor3 = Color3.fromRGB(200,100,0) end)
end)

-- ===== TOGGLE DOC LAP: NEM CAN =====
castToggleBtn.MouseButton1Click:Connect(function()
    castActive = not castActive
    if castActive then
        castToggleBtn.Text = "đŸ£  NEM CAN: BAT âœ“"
        castToggleBtn.BackgroundColor3 = Color3.fromRGB(220,160,0)
        startCastLoop()
    else
        castToggleBtn.Text = "đŸ£  NEM CAN: TAT"
        castToggleBtn.BackgroundColor3 = Color3.fromRGB(160,110,0)
    end
end)

-- ===== TOGGLE DOC LAP: CHIEU ZXCV =====
skillToggleBtn.MouseButton1Click:Connect(function()
    skillActive = not skillActive
    if skillActive then
        skillToggleBtn.Text = "â¡  CHIEU ZXCV: BAT âœ“"
        skillToggleBtn.BackgroundColor3 = Color3.fromRGB(120,60,255)
        startAllSkills()
    else
        skillToggleBtn.Text = "â¡  CHIEU ZXCV: TAT"
        skillToggleBtn.BackgroundColor3 = Color3.fromRGB(70,30,180)
    end
end)

-- ===== PHIM TAT =====
UIS.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.F then toggleBtn.MouseButton1Click:Fire() end
    if inp.KeyCode == Enum.KeyCode.H then setPanel(not panelOpen) end
end)

-- ===== UPDATE LOOP - Chi cap nhat khi thay doi, 4fps =====
-- Luu gia tri cu de so sanh, tranh write UI moi frame
local _prevStatus   = ""
local _prevRunning  = nil
local _prevCd       = -1
local _prevFish     = -1
local _prevSell     = -1
local _prevCast     = nil
local _prevSkill    = nil
local _prevSelling  = nil

-- Mau gradient bat/tat (tao 1 lan, dung lai)
local COLOR_RUN_ON  = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(225,50,50)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(155,18,18)),
})
local COLOR_RUN_OFF = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(50,220,85)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(18,145,48)),
})

-- Checklist: luu trang thai cu
local _chkPrev = {}

task.spawn(function()
    while true do
        task.wait(0.25)  -- cap nhat 4 lan/giay, du dung, khong lag

        -- Status text
        if statusText ~= _prevStatus then
            _prevStatus = statusText
            sLbl.Text   = statusText
        end

        -- Running state (thay doi hiem, chi set khi can)
        if isRunning ~= _prevRunning then
            _prevRunning = isRunning
            if isRunning then
                sLbl.TextColor3           = Color3.fromRGB(80,255,140)
                sDot.BackgroundColor3     = Color3.fromRGB(60,255,80)
                toggleBtn.Text            = "STOP"
                tGrad.Color               = COLOR_RUN_ON
            else
                sLbl.TextColor3           = Color3.fromRGB(255,100,100)
                sDot.BackgroundColor3     = Color3.fromRGB(255,80,80)
                toggleBtn.Text            = "BAT TU DONG"
                tGrad.Color               = COLOR_RUN_OFF
            end
        end

        -- Dem nguoc (chi doi so giay, khong doi frame)
        local cdNow = isSelling and -1 or countdownSec
        if cdNow ~= _prevCd or isSelling ~= _prevSelling then
            _prevCd      = cdNow
            _prevSelling = isSelling
            if isSelling then
                stCd.Text = "Di ban..."
            else
                local m2 = math.floor(countdownSec/60)
                local s2 = countdownSec % 60
                stCd.Text = string.format("%d:%02d", m2, s2)
            end
        end

        -- Ca / ban
        if fishCaught ~= _prevFish then
            _prevFish   = fishCaught
            stFish.Text = tostring(fishCaught)
        end
        if sellCount ~= _prevSell then
            _prevSell   = sellCount
            stSell.Text = tostring(sellCount)
        end

        -- Toggle buttons (chi set text khi thay doi)
        if castActive ~= _prevCast then
            _prevCast = castActive
            castToggleBtn.Text            = castActive and "NEM CAN: BAT" or "NEM CAN: TAT"
            castToggleBtn.BackgroundColor3= castActive
                and Color3.fromRGB(220,160,0)
                or  Color3.fromRGB(160,110,0)
        end
        if skillActive ~= _prevSkill then
            _prevSkill = skillActive
            skillToggleBtn.Text            = skillActive and "CHIEU ZXCV: BAT" or "CHIEU ZXCV: TAT"
            skillToggleBtn.BackgroundColor3= skillActive
                and Color3.fromRGB(120,60,255)
                or  Color3.fromRGB(70,30,180)
        end

        -- Checklist (chi cap nhat o that su thay doi)
        local checks = {
            fish  = savedFishPos  ~= nil,
            npc   = savedNPCPos   ~= nil,
            sell  = savedSellPos  ~= nil,
            close = savedClosePos ~= nil,
            cast  = savedCastPos  ~= nil,
            zxcv  = (function()
                for i=1,4 do if zxcvPos[i] then return true end end
                return false
            end)(),
        }
        for k, v in pairs(checks) do
            if v ~= _chkPrev[k] and checkLabels[k] then
                _chkPrev[k] = v
                checkLabels[k].Text = (v and "âœ“ " or "â—‹ ") .. checkLabels[k].Text:sub(3)
                checkLabels[k].TextColor3 = v
                    and Color3.fromRGB(80,255,120)
                    or  Color3.fromRGB(200,60,60)
            end
        end
    end
end)

-- Nhip tim marker: dung 1 Heartbeat chung, chi cho marker dang hien
local allMarkers = {markerSell, markerClose, markerCast,
    zxcvMarkers[1], zxcvMarkers[2], zxcvMarkers[3], zxcvMarkers[4]}
RS.Heartbeat:Connect(function()
    local t = math.abs(math.sin(tick() * 2.5))
    for _, m in ipairs(allMarkers) do
        if m.Visible then
            m.BackgroundTransparency = 0.1 + t * 0.35
        end
    end
end)

print("[TF v17] H=an/hien | F=bat/tat | 2 mang click doc lap")
