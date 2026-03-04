-- TITAN FISHING AUTO SELL v15b
-- GUI NGANG 2 cot | Fix: touchAt cho Fishing/ZXCV | ZXCV cach nhau 1s moi chieu
-- Logic: nem can -> ca can -> Z(1s)->X(1s)->C(1s)->V(1s) -> ca len -> ban -> lap lai

local Players = game:GetService("Players")
local UIS     = game:GetService("UserInputService")
local RS      = game:GetService("RunService")
local PFS     = game:GetService("PathfindingService")
local TS      = game:GetService("TweenService")
local VIM     = game:GetService("VirtualInputManager")
local LP      = Players.LocalPlayer

-- ============================================================
-- STATE
-- ============================================================
local isRunning    = false
local menuOpen     = true
local statusText   = "Chua bat"
local sellCount    = 0
local fishCaught   = 0
local fishSession  = 0

local savedFishPos  = nil
local savedNPCPos   = nil
local savedSellPos  = nil
local savedClosePos = nil
local savedCastPos  = nil
local zxcvPos       = {nil,nil,nil,nil}

local zxcvInterval = 0.12
local sellEveryN   = 1

-- ============================================================
-- DETECT
-- ============================================================
local function isFishBiting()
    for _, o in ipairs(LP.PlayerGui:GetDescendants()) do
        if o:IsA("Frame") and o.Visible then
            local n = o.Name:lower()
            if n:find("fish") or n:find("battle") or n:find("hp") or n:find("health") or n:find("combat") then return true end
        end
        if o:IsA("TextLabel") and o.Visible then
            local t = o.Text:lower()
            if t:find("rare") or t:find("common") or t:find("uncommon") or t:find("epic") or t:find("legendary") or t:find("mythic") or t:find("runaway") then return true end
        end
    end
    return false
end

local function isZXCVVisible()
    for _, o in ipairs(LP.PlayerGui:GetDescendants()) do
        if (o:IsA("TextButton") or o:IsA("ImageButton")) and o.Visible then
            local n = o.Name:lower()
            local t = o:IsA("TextButton") and o.Text:lower() or ""
            if n=="z" or n=="x" or n=="c" or n=="v" or t=="z" or t=="x" or t=="c" or t=="v" then return true end
        end
    end
    return false
end

local function isFishCaught()
    for _, o in ipairs(LP.PlayerGui:GetDescendants()) do
        if o:IsA("TextLabel") and o.Visible then
            local t = o.Text:lower()
            if t:find("caught") or t:find("you got") or t:find("obtained") or t:find("added") then return true end
        end
    end
    return false
end

-- ============================================================
-- CLICK / TOUCH
-- ============================================================

-- Mouse click (dung cho SellAll, X dong - nut GUI thuong)
local function clickAt(x, y)
    VIM:SendMouseButtonEvent(x, y, 0, true,  game, 0)
    task.wait(0.08)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    task.wait(0.08)
end

-- Touch tap (dung cho nut game mobile: Fishing, Z X C V)
local function touchAt(x, y)
    -- Cach 1: SendTouchEvent (mobile)
    pcall(function()
        VIM:SendTouchEvent(x, y, Enum.UserInputState.Begin, 0)
        task.wait(0.04)
        VIM:SendTouchEvent(x, y, Enum.UserInputState.End, 0)
    end)
    -- Cach 2: Mouse click kem theo
    pcall(function()
        VIM:SendMouseButtonEvent(x, y, 0, true,  game, 0)
        task.wait(0.03)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
    task.wait(0.04)
end

-- ============================================================
-- WALK
-- ============================================================
local function walkTo(pos, lbl)
    local char = LP.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    statusText = lbl or "Dang di..."
    hum.WalkSpeed = 24
    local path = PFS:CreatePath({AgentHeight=5,AgentRadius=2,AgentCanJump=true})
    local ok = pcall(function() path:ComputeAsync(hrp.Position, pos) end)
    if ok and path.Status == Enum.PathStatus.Success then
        for _, wp in ipairs(path:GetWaypoints()) do
            if not isRunning then return end
            if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
            hum:MoveTo(wp.Position); hum.MoveToFinished:Wait(3)
            if (hrp.Position - pos).Magnitude < 8 then break end
        end
    else
        hum:MoveTo(pos)
        local t = 0
        while t < 12 and isRunning do task.wait(0.2); t+=0.2
            if (hrp.Position - pos).Magnitude < 8 then break end
        end
    end
end

local function stopWalk()
    local c=LP.Character; local h=c and c:FindFirstChild("Humanoid"); local r=c and c:FindFirstChild("HumanoidRootPart")
    if h and r then h:MoveTo(r.Position) end
end

-- ============================================================
-- INTERACT + SELL
-- ============================================================
local function doInteract()
    statusText = "Mo cua hang..."
    local char=LP.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local best,bestD=nil,math.huge
        for _,v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ProximityPrompt") then
                local p=v.Parent
                if p and p:IsA("BasePart") then
                    local d=(hrp.Position-p.Position).Magnitude
                    if d<bestD then bestD=d; best=v end
                end
            end
        end
        if best and bestD<20 then pcall(function() fireproximityprompt(best) end); task.wait(0.5) end
    end
    task.wait(0.8)
end

local function doSellAll()
    if not savedSellPos or not savedClosePos then statusText="Chua luu SellAll/X!"; task.wait(2); return false end
    statusText="Cho popup..."; task.wait(0.8)
    touchAt(savedSellPos.X, savedSellPos.Y); task.wait(1.2)
    touchAt(savedClosePos.X,savedClosePos.Y); task.wait(0.5)
    statusText="Da ban xong!"; return true
end

-- ============================================================
-- SPAM LOOPS (chay song song)
-- ============================================================

-- Vong spam nut Fishing (nem can) - chay lien tuc
local function loop_Cast()
    while isRunning do
        if savedCastPos then
            touchAt(savedCastPos.X, savedCastPos.Y)
        end
        task.wait(0.5)  -- nem can moi 0.5s
    end
end

-- Vong spam chieu ZXCV - lan luot Z->X->C->V, cach nhau 0.1s, lien tuc
local function loop_ZXCV()
    while isRunning do
        local fired = false
        for i = 1, 4 do
            if not isRunning then break end
            if zxcvPos[i] then
                fired = true
                touchAt(zxcvPos[i].X, zxcvPos[i].Y)
                task.wait(0.1)  -- khoang nho giua cac chieu, du de k bi chen
            end
        end
        if not fired then task.wait(0.1) end
        -- Khong co delay them sau vong -> spam lien tuc nhanh nhat co the
    end
end

-- ============================================================
-- BIEN TIMER
-- ============================================================
local fishMinutes  = 1      -- so phut cau truoc khi ban (chinh duoc)
local countdownSec = 0      -- dem nguoc hien thi
local isSelling    = false  -- dang trong qua trinh di ban

-- ============================================================
-- SPAM LOOPS
-- ============================================================
local function loop_Cast()
    while isRunning and not isSelling do
        if savedCastPos then
            touchAt(savedCastPos.X, savedCastPos.Y)
        end
        task.wait(0.5)
    end
end

local function loop_ZXCV()
    while isRunning and not isSelling do
        for i = 1, 4 do
            if not isRunning or isSelling then break end
            if zxcvPos[i] then
                touchAt(zxcvPos[i].X, zxcvPos[i].Y)
                task.wait(0.1)
            end
        end
    end
end

-- ============================================================
-- MAIN LOOP - Don gian: cau X phut -> ban -> lap lai
-- ============================================================
local function mainLoop()
    -- Validate
    local miss = {}
    if not savedFishPos  then table.insert(miss,"vi tri cau") end
    if not savedNPCPos   then table.insert(miss,"vi tri NPC") end
    if not savedSellPos  then table.insert(miss,"SellAll") end
    if not savedClosePos then table.insert(miss,"X dong") end
    if not savedCastPos  then table.insert(miss,"nut Fishing") end
    local hz=false; for i=1,4 do if zxcvPos[i] then hz=true end end
    if not hz then table.insert(miss,"it nhat 1 nut ZXCV") end
    if #miss > 0 then
        statusText="Thieu: "..table.concat(miss,", ").."!"
        isRunning=false; return
    end

    while isRunning do
        -- ===== GIAI DOAN 1: DI VE VI TRI CAU =====
        isSelling = false
        local char = LP.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and savedFishPos and (hrp.Position-savedFishPos).Magnitude > 5 then
            statusText = "Di ve vi tri cau..."
            walkTo(savedFishPos, "Di ve vi tri cau...")
            if not isRunning then break end
            stopWalk(); task.wait(0.5)
        end

        -- ===== GIAI DOAN 2: CAU CA TRONG X PHUT =====
        local totalSec = fishMinutes * 60
        countdownSec   = totalSec

        -- Bat spam song song
        task.spawn(loop_Cast)
        task.spawn(loop_ZXCV)

        -- Dem nguoc
        while countdownSec > 0 and isRunning do
            local m = math.floor(countdownSec / 60)
            local s = countdownSec % 60
            statusText = string.format("đŸ£ Dang cau... %d:%02d | Ca:%d Ban:%d", m, s, fishCaught, sellCount)
            task.wait(1)
            countdownSec -= 1
        end

        if not isRunning then break end

        -- ===== GIAI DOAN 3: HET GIO - DUNG SPAM & DI BAN =====
        isSelling = true
        task.wait(0.3)  -- cho loop_Cast va loop_ZXCV dung

        statusText = "â° Het gio! Dung cau - Di ban ca..."
        fishCaught += 1  -- tinh them 1 con cho session vua roi
        fishSession += 1

        -- Di toi NPC
        walkTo(savedNPCPos, "Di toi NPC ban ca...")
        if not isRunning then break end
        task.wait(0.3); stopWalk(); task.wait(0.4)

        doInteract(); task.wait(0.5)
        doSellAll();  task.wait(0.5)

        sellCount += 1
        statusText = "âœ“ Da ban lan "..sellCount.."! Quay lai cau "..fishMinutes.." phut..."
        task.wait(1)
        -- Lap lai tu dau
    end

    isSelling    = false
    countdownSec = 0
    statusText   = "Da tat"
end

-- ============================================================
-- GUI - NGANG RONG
-- ============================================================
local old=LP.PlayerGui:FindFirstChild("TFHub"); if old then old:Destroy() end

local sg=Instance.new("ScreenGui")
sg.Name="TFHub"; sg.ResetOnSpawn=false
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.Parent=LP.PlayerGui

-- ======== MARKERS (vong tron danh dau) ========
local function makeMarker(color, tag)
    local S=64
    local m=Instance.new("TextButton")
    m.Size=UDim2.new(0,S,0,S); m.Position=UDim2.new(0.5,-S/2,0.5,-S/2)
    m.BackgroundColor3=color; m.BackgroundTransparency=0.1
    m.BorderSizePixel=0; m.Text=""; m.ZIndex=40
    m.Active=true; m.Draggable=true; m.Visible=false; m.Parent=sg
    Instance.new("UICorner",m).CornerRadius=UDim.new(1,0)
    local sk=Instance.new("UIStroke",m); sk.Color=Color3.new(1,1,1); sk.Thickness=3
    local function bar(sz,ps)
        local f=Instance.new("Frame",m); f.Size=sz; f.Position=ps
        f.BackgroundColor3=Color3.new(1,1,0); f.BorderSizePixel=0; f.ZIndex=41
    end
    bar(UDim2.new(0.6,0,0,2.5),UDim2.new(0.2,0,0.5,-1.25))
    bar(UDim2.new(0,2.5,0.6,0),UDim2.new(0.5,-1.25,0.2,0))
    local dot=Instance.new("Frame",m); dot.Size=UDim2.new(0,9,0,9); dot.Position=UDim2.new(0.5,-4.5,0.5,-4.5)
    dot.BackgroundColor3=Color3.new(1,0,0); dot.BorderSizePixel=0; dot.ZIndex=42
    Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
    local tl=Instance.new("TextLabel",m); tl.Size=UDim2.new(1,0,0,18); tl.Position=UDim2.new(0,0,1,3)
    tl.BackgroundTransparency=1; tl.Text=tag; tl.TextColor3=Color3.new(1,1,0)
    tl.Font=Enum.Font.GothamBlack; tl.TextSize=12; tl.ZIndex=42
    return m
end

local markerSell  = makeMarker(Color3.fromRGB(20,200,100),  "SELL")
local markerClose = makeMarker(Color3.fromRGB(220,40,60),   "CLOSE")
local markerCast  = makeMarker(Color3.fromRGB(255,200,0),   "FISHING")
local zxcvColors  = {Color3.fromRGB(80,160,255),Color3.fromRGB(200,80,255),Color3.fromRGB(255,110,40),Color3.fromRGB(40,220,170)}
local zxcvNames   = {"Z","X","C","V"}
local zxcvMarkers = {}
for i=1,4 do zxcvMarkers[i]=makeMarker(zxcvColors[i], zxcvNames[i]) end

-- Nhip tim markers
RS.Heartbeat:Connect(function()
    local a=math.abs(math.sin(tick()*math.pi))
    for _,m in ipairs({markerSell,markerClose,markerCast,zxcvMarkers[1],zxcvMarkers[2],zxcvMarkers[3],zxcvMarkers[4]}) do
        if m.Visible then m.BackgroundTransparency=0.05+a*0.3 end
    end
end)

-- ======== BUBBLE (nu mo menu) ========
local bubble=Instance.new("TextButton")
bubble.Size=UDim2.new(0,60,0,60); bubble.Position=UDim2.new(0,12,0.5,-30)
bubble.BackgroundColor3=Color3.fromRGB(255,140,0); bubble.BorderSizePixel=0
bubble.Text="đŸ£"; bubble.TextScaled=true; bubble.Font=Enum.Font.GothamBold
bubble.Visible=false; bubble.ZIndex=12; bubble.Active=true; bubble.Draggable=true; bubble.Parent=sg
Instance.new("UICorner",bubble).CornerRadius=UDim.new(1,0)
Instance.new("UIStroke",bubble).Color=Color3.fromRGB(255,210,80)

-- ======== FRAME CHINH - RONG ========
-- Chieu ngang lon: 580px, chieu cao vua du
local W,H = 580, 520
local frame=Instance.new("Frame")
frame.Size=UDim2.new(0,W,0,H)
frame.Position=UDim2.new(0.5,-W/2, 0.5,-H/2)  -- giua man hinh
frame.BackgroundColor3=Color3.fromRGB(10,10,22)
frame.BorderSizePixel=0; frame.Active=true; frame.Draggable=true
frame.ClipsDescendants=true; frame.ZIndex=5; frame.Parent=sg
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,18)
local msk=Instance.new("UIStroke",frame); msk.Color=Color3.fromRGB(255,140,0); msk.Thickness=1.8
Instance.new("UIGradient",frame).Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(20,15,40)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(8,8,18)),
})

-- ======== HEADER (toan chieu ngang) ========
local hdr=Instance.new("Frame",frame)
hdr.Size=UDim2.new(1,0,0,52); hdr.Position=UDim2.new(0,0,0,0)
hdr.BackgroundColor3=Color3.fromRGB(15,10,35); hdr.BorderSizePixel=0; hdr.ZIndex=6
Instance.new("UICorner",hdr).CornerRadius=UDim.new(0,18)
local hgr=Instance.new("UIGradient",hdr)
hgr.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(255,120,0)),
    ColorSequenceKeypoint.new(0.4,Color3.fromRGB(200,50,120)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(90,30,200)),
}); hgr.Rotation=90

local function hl(p,sz,ps,tx,fn,fs,col,xa)
    local l=Instance.new("TextLabel",p); l.Size=sz; l.Position=ps; l.BackgroundTransparency=1
    l.Text=tx; l.Font=fn; l.TextSize=fs; l.TextColor3=col or Color3.new(1,1,1)
    l.TextXAlignment=xa or Enum.TextXAlignment.Left; l.ZIndex=7; return l
end
hl(hdr,UDim2.new(0,38,0,38),UDim2.new(0,10,0.5,-19),"đŸ£",Enum.Font.GothamBold,22,Color3.new(1,1,1),Enum.TextXAlignment.Center)
hl(hdr,UDim2.new(0,200,0,28),UDim2.new(0,54,0,7),"TITAN FISHING",Enum.Font.GothamBlack,18)
hl(hdr,UDim2.new(0,200,0,15),UDim2.new(0,54,0,30),"Auto Loop v15",Enum.Font.Gotham,11,Color3.fromRGB(255,200,150))

-- Status inline o header (giua)
local hStatus=Instance.new("TextLabel",hdr)
hStatus.Size=UDim2.new(0,220,0,34); hStatus.Position=UDim2.new(0.5,-110,0.5,-17)
hStatus.BackgroundColor3=Color3.fromRGB(0,0,0); hStatus.BackgroundTransparency=0.45
hStatus.BorderSizePixel=0; hStatus.Text="â— Chua bat"
hStatus.TextColor3=Color3.fromRGB(255,100,100); hStatus.Font=Enum.Font.GothamBold
hStatus.TextSize=12; hStatus.ZIndex=7
Instance.new("UICorner",hStatus).CornerRadius=UDim.new(0,8)

-- Stat pills o header phai
local function hPill(xoff, icon, col)
    local p=Instance.new("Frame",hdr)
    p.Size=UDim2.new(0,78,0,32); p.Position=UDim2.new(1,xoff,0.5,-16)
    p.BackgroundColor3=Color3.fromRGB(0,0,0); p.BackgroundTransparency=0.45
    p.BorderSizePixel=0; p.ZIndex=7
    Instance.new("UICorner",p).CornerRadius=UDim.new(0,8)
    local il=Instance.new("TextLabel",p); il.Size=UDim2.new(0,22,1,0); il.Position=UDim2.new(0,4,0,0)
    il.BackgroundTransparency=1; il.Text=icon; il.TextScaled=true; il.ZIndex=8
    local vl=Instance.new("TextLabel",p); vl.Size=UDim2.new(1,-28,1,0); vl.Position=UDim2.new(0,26,0,0)
    vl.BackgroundTransparency=1; vl.TextColor3=col; vl.Font=Enum.Font.GothamBold; vl.TextSize=12
    vl.TextXAlignment=Enum.TextXAlignment.Left; vl.ZIndex=8
    return vl
end
local hCaughtLbl = hPill(-258,"đŸŸ",Color3.fromRGB(100,220,255))
local hSellLbl   = hPill(-174,"đŸ›’",Color3.fromRGB(100,255,160))
local hSesLbl    = hPill(-90, "đŸ”„",Color3.fromRGB(255,200,80))

-- Nut dong menu
local closeBtn=Instance.new("TextButton",hdr)
closeBtn.Size=UDim2.new(0,34,0,34); closeBtn.Position=UDim2.new(1,-44,0.5,-17)
closeBtn.BackgroundColor3=Color3.fromRGB(210,45,45); closeBtn.BorderSizePixel=0
closeBtn.Text="âœ•"; closeBtn.TextColor3=Color3.new(1,1,1)
closeBtn.Font=Enum.Font.GothamBold; closeBtn.TextSize=14; closeBtn.ZIndex=8
Instance.new("UICorner",closeBtn).CornerRadius=UDim.new(1,0)

-- ======== BODY: 2 COT ========
local body=Instance.new("Frame",frame)
body.Size=UDim2.new(1,-16,1,-60); body.Position=UDim2.new(0,8,0,56)
body.BackgroundTransparency=1; body.ZIndex=5

-- COT TRAI (vi tri + ban ca)
local colL=Instance.new("ScrollingFrame",body)
colL.Size=UDim2.new(0.48,0,1,0); colL.Position=UDim2.new(0,0,0,0)
colL.BackgroundTransparency=1; colL.BorderSizePixel=0
colL.ScrollBarThickness=3; colL.ScrollBarImageColor3=Color3.fromRGB(255,140,0)
colL.CanvasSize=UDim2.new(0,0,0,520); colL.ZIndex=6

-- COT PHAI (ZXCV + cai dat)
local colR=Instance.new("ScrollingFrame",body)
colR.Size=UDim2.new(0.50,0,1,0); colR.Position=UDim2.new(0.50,0,0,0)
colR.BackgroundTransparency=1; colR.BorderSizePixel=0
colR.ScrollBarThickness=3; colR.ScrollBarImageColor3=Color3.fromRGB(100,100,255)
colR.CanvasSize=UDim2.new(0,0,0,520); colR.ZIndex=6

-- Duong ke giua
local sep=Instance.new("Frame",body)
sep.Size=UDim2.new(0,1,1,-4); sep.Position=UDim2.new(0.485,0,0,2)
sep.BackgroundColor3=Color3.fromRGB(50,50,80); sep.BorderSizePixel=0; sep.ZIndex=6

-- ======== WIDGET BUILDER ========
local function mkSec(parent, y, txt)
    local l=Instance.new("TextLabel",parent)
    l.Size=UDim2.new(1,-8,0,18); l.Position=UDim2.new(0,4,0,y)
    l.BackgroundTransparency=1; l.Text=txt
    l.TextColor3=Color3.fromRGB(150,150,255); l.Font=Enum.Font.GothamBold; l.TextSize=11
    l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=6
    return y+22
end

local function mkDiv(parent, y)
    local d=Instance.new("Frame",parent)
    d.Size=UDim2.new(1,-8,0,1); d.Position=UDim2.new(0,4,0,y)
    d.BackgroundColor3=Color3.fromRGB(45,45,75); d.BorderSizePixel=0; d.ZIndex=6
    return y+8
end

-- Row 2 cot ben trong 1 cot
local function mkRow2(parent, y, h)
    local r=Instance.new("Frame",parent)
    r.Size=UDim2.new(1,-8,0,h); r.Position=UDim2.new(0,4,0,y)
    r.BackgroundTransparency=1; r.ZIndex=6
    return r, y+h+5
end

local function mkCard(parent, y, h, bg)
    local c=Instance.new("Frame",parent)
    c.Size=UDim2.new(1,-8,0,h); c.Position=UDim2.new(0,4,0,y)
    c.BackgroundColor3=bg or Color3.fromRGB(14,14,30); c.BorderSizePixel=0; c.ZIndex=6
    Instance.new("UICorner",c).CornerRadius=UDim.new(0,9)
    Instance.new("UIStroke",c).Color=Color3.fromRGB(45,45,80)
    return c, y+h+6
end

local function mkBtn(parent, y, w, xoff, h, bg, txt, fs)
    local b=Instance.new("TextButton",parent)
    b.Size=UDim2.new(0,w,0,h or 34); b.Position=UDim2.new(0,xoff,0,y)
    b.BackgroundColor3=bg; b.BorderSizePixel=0
    b.Text=txt; b.TextColor3=Color3.new(1,1,1)
    b.Font=Enum.Font.GothamBold; b.TextSize=fs or 12; b.ZIndex=6
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,9)
    return b
end

local function mkLabel(parent, x, y, w, h, txt, col, fs, xa)
    local l=Instance.new("TextLabel",parent)
    l.Size=UDim2.new(0,w,0,h); l.Position=UDim2.new(0,x,0,y)
    l.BackgroundTransparency=1; l.Text=txt; l.TextColor3=col
    l.Font=Enum.Font.Gotham; l.TextSize=fs or 11
    l.TextXAlignment=xa or Enum.TextXAlignment.Left
    l.TextWrapped=true; l.ZIndex=7; return l
end

-- ============================================================
-- COT TRAI
-- ============================================================
local YL = 4

-- SECTION: VI TRI
YL = mkSec(colL, YL, "đŸ“Œ  VI TRI DI CHUYEN")

-- Vi tri cau card
local cFish, YL2 = mkCard(colL, YL, 58, Color3.fromRGB(12,20,40))
YL = YL2
local p1Dot=Instance.new("Frame",cFish); p1Dot.Size=UDim2.new(0,8,0,8); p1Dot.Position=UDim2.new(0,8,0,8)
p1Dot.BackgroundColor3=Color3.fromRGB(80,130,255); p1Dot.BorderSizePixel=0
Instance.new("UICorner",p1Dot).CornerRadius=UDim.new(1,0)
local p1Title=mkLabel(cFish,20,4,130,16,"VI TRI CAU",Color3.fromRGB(80,160,255),11)
p1Title.Font=Enum.Font.GothamBold
local p1Lbl=mkLabel(cFish,8,22,180,16,"Chua luu",Color3.fromRGB(150,180,255),10)
local saveFishBtn=mkBtn(cFish,38,nil,6,16,Color3.fromRGB(25,100,210),"đŸ“ SAVE vi tri hien tai",10)
saveFishBtn.Size=UDim2.new(1,-12,0,16)

-- Vi tri NPC card
local cNPC, YL2 = mkCard(colL, YL, 58, Color3.fromRGB(20,12,35))
YL = YL2
local p2Title=mkLabel(cNPC,20,4,130,16,"VI TRI NPC BAN CA",Color3.fromRGB(255,180,80),11)
p2Title.Font=Enum.Font.GothamBold
local p2Lbl=mkLabel(cNPC,8,22,180,16,"Chua luu",Color3.fromRGB(255,200,120),10)
local saveNPCBtn=mkBtn(cNPC,38,nil,6,16,Color3.fromRGB(110,35,180),"đŸª SAVE vi tri hien tai",10)
saveNPCBtn.Size=UDim2.new(1,-12,0,16)

YL = mkDiv(colL, YL)
YL = mkSec(colL, YL, "đŸ›’  NUT BAN CA")

-- SellAll + X trong 1 card
local cSell, YL2 = mkCard(colL, YL, 92, Color3.fromRGB(12,18,14))
YL = YL2
local p3Lbl=mkLabel(cSell,8,4,220,14,"SellAll: Chua luu",Color3.fromRGB(80,255,180),10)
local toggleSellBtn=mkBtn(cSell,20,nil,6,26,Color3.fromRGB(18,140,72),"đŸ›’  HIEN vong tron SellAll",11)
toggleSellBtn.Size=UDim2.new(1,-12,0,26)
local p4Lbl=mkLabel(cSell,8,50,220,14,"X dong: Chua luu",Color3.fromRGB(255,130,180),10)
local toggleCloseBtn=mkBtn(cSell,66,nil,6,22,Color3.fromRGB(175,35,55),"âŒ  HIEN vong tron X dong",10)
toggleCloseBtn.Size=UDim2.new(1,-12,0,22)

YL = mkDiv(colL, YL)
YL = mkSec(colL, YL, "đŸ£  NUT NEM CAN")

local cCast, YL2 = mkCard(colL, YL, 58, Color3.fromRGB(20,18,8))
YL = YL2
local p5Lbl=mkLabel(cCast,8,4,220,14,"Nut Fishing: Chua luu",Color3.fromRGB(255,230,80),10)
local toggleCastBtn=mkBtn(cCast,20,nil,6,34,Color3.fromRGB(155,115,0),"đŸŸ¡  HIEN vong tron nut Fishing",11)
toggleCastBtn.Size=UDim2.new(1,-12,0,34)

YL = mkDiv(colL, YL)
YL = mkSec(colL, YL, "â™  CAI DAT THOI GIAN")

-- So phut cau truoc khi ban
local cTimer, YL2 = mkCard(colL, YL, 52, Color3.fromRGB(14,14,30))
YL = YL2
mkLabel(cTimer,6,4,140,16,"Cau bao nhieu phut:",Color3.fromRGB(255,200,80),11)
local timerValLbl=mkLabel(cTimer,6,22,200,20,tostring(fishMinutes).." phut",Color3.fromRGB(255,240,100),16)
timerValLbl.Font=Enum.Font.GothamBlack
local tMinBtn =mkBtn(cTimer,34,40,6,14,Color3.fromRGB(160,40,40)," âˆ’ ",12)
local tPlusBtn=mkBtn(cTimer,34,50,6,14,Color3.fromRGB(30,150,55)," + ",12)
-- dat lai vi tri cho dep
tMinBtn.Size=UDim2.new(0,44,0,26); tMinBtn.Position=UDim2.new(0,6,0,22)
tPlusBtn.Size=UDim2.new(0,44,0,26); tPlusBtn.Position=UDim2.new(0,54,0,22)

-- Ban sau N con +/-
local cSellN, YL2 = mkCard(colL, YL, 42, Color3.fromRGB(14,14,30))
YL = YL2
mkLabel(cSellN,6,4,115,16,"Ban sau N lan:",Color3.fromRGB(100,255,160),11)
local sellNValLbl=mkLabel(cSellN,125,4,60,16,tostring(sellEveryN).." lan",Color3.fromRGB(255,220,80),12)
sellNValLbl.Font=Enum.Font.GothamBold
local nMinBtn=mkBtn(cSellN,22,28,6,16,Color3.fromRGB(160,40,40),"âˆ’",13)
local nPlusBtn=mkBtn(cSellN,22,28,38,16,Color3.fromRGB(30,150,55),"+",13)

YL = mkDiv(colL, YL)

-- Nut ban ngay
local sellNowBtn=mkBtn(colL,YL,nil,4,34,Color3.fromRGB(200,100,0),"đŸ’°  BAN NGAY (bo qua dem nguoc)",12)
sellNowBtn.Size=UDim2.new(1,-8,0,34)
YL = YL+40

-- NUT BAT/TAT chinh
YL = mkDiv(colL, YL)
local toggleBtn=mkBtn(colL,YL,nil,4,50,Color3.fromRGB(30,180,65),"â–¶   BAT TU DONG",15)
toggleBtn.Size=UDim2.new(1,-8,0,50)
local tGrad=Instance.new("UIGradient",toggleBtn)
tGrad.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(50,220,85)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(18,145,48)),
}); tGrad.Rotation=90
YL = YL+58

colL.CanvasSize=UDim2.new(0,0,0,YL+10)

-- ============================================================
-- COT PHAI: ZXCV GRID
-- ============================================================
local YR = 4
YR = mkSec(colR, YR, "â¡  NUT CHIEU Z / X / C / V")

-- Ghi chu
local noteCard,YR2=mkCard(colR,YR,30,Color3.fromRGB(16,16,36)); YR=YR2
mkLabel(noteCard,6,2,260,24,"Keo vong mau â†’ nut chieu â†’ bam tam de luu\nTu dong spam Zâ†’Xâ†’Câ†’V khi ca can",Color3.fromRGB(180,180,255),9)

-- Grid 2x2 cho ZXCV
local zxcvToggleBtns = {}
local zxcvInfoLbls   = {}

local gridW = (colR.AbsoluteSize.X > 0) and colR.AbsoluteSize.X or 270
local cw = math.floor((gridW - 16) / 2) - 4  -- chieu rong moi o

local gridRows = {{1,2},{3,4}}
for ri, pair in ipairs(gridRows) do
    for ci, i in ipairs(pair) do
        local nm  = zxcvNames[i]
        local col = zxcvColors[i]
        local xOff = (ci-1) * (cw + 6) + 4
        local h = 76

        local card=Instance.new("Frame",colR)
        card.Size=UDim2.new(0,cw,0,h); card.Position=UDim2.new(0,xOff,0,YR)
        card.BackgroundColor3=Color3.fromRGB(14,14,30); card.BorderSizePixel=0; card.ZIndex=6
        Instance.new("UICorner",card).CornerRadius=UDim.new(0,10)
        local csk=Instance.new("UIStroke",card); csk.Color=col; csk.Thickness=1.5

        -- Badge
        local badge=Instance.new("Frame",card)
        badge.Size=UDim2.new(0,28,0,28); badge.Position=UDim2.new(0,6,0,6)
        badge.BackgroundColor3=col; badge.BorderSizePixel=0; badge.ZIndex=7
        Instance.new("UICorner",badge).CornerRadius=UDim.new(0,7)
        local bl=Instance.new("TextLabel",badge); bl.Size=UDim2.new(1,0,1,0)
        bl.BackgroundTransparency=1; bl.Text=nm; bl.Font=Enum.Font.GothamBlack
        bl.TextSize=16; bl.TextColor3=Color3.new(1,1,1); bl.ZIndex=8

        -- Info
        local sl=Instance.new("TextLabel",card)
        sl.Size=UDim2.new(1,-40,0,14); sl.Position=UDim2.new(0,38,0,8)
        sl.BackgroundTransparency=1; sl.Text="Chua luu"
        sl.TextColor3=Color3.fromRGB(180,180,180); sl.Font=Enum.Font.Gotham; sl.TextSize=10
        sl.TextXAlignment=Enum.TextXAlignment.Left; sl.TextTruncate=Enum.TextTruncate.AtEnd; sl.ZIndex=7
        zxcvInfoLbls[i]=sl

        -- Nut hien marker
        local tb=Instance.new("TextButton",card)
        tb.Size=UDim2.new(1,-10,0,24); tb.Position=UDim2.new(0,5,0,26)
        tb.BackgroundColor3=col; tb.BorderSizePixel=0
        tb.Text="HIEN "..nm; tb.TextColor3=Color3.new(1,1,1)
        tb.Font=Enum.Font.GothamBold; tb.TextSize=11; tb.ZIndex=7
        Instance.new("UICorner",tb).CornerRadius=UDim.new(0,7)
        zxcvToggleBtns[i]=tb

        -- Trang thai da luu
        local stLbl=Instance.new("TextLabel",card)
        stLbl.Size=UDim2.new(1,-10,0,16); stLbl.Position=UDim2.new(0,5,0,54)
        stLbl.BackgroundTransparency=1; stLbl.Text="â¬¤ Chua luu"
        stLbl.TextColor3=Color3.fromRGB(150,150,150); stLbl.Font=Enum.Font.Gotham; stLbl.TextSize=9
        stLbl.TextXAlignment=Enum.TextXAlignment.Left; stLbl.ZIndex=7
        -- luu tham chieu de cap nhat
        zxcvMarkers[i]:SetAttribute("statusLabel", tostring(i))
        card:SetAttribute("statusIdx", tostring(i))
        -- store stLbl reference
        zxcvData_stLbl = zxcvData_stLbl or {}
        zxcvData_stLbl[i] = stLbl
    end
    YR = YR + 76 + 8
end

YR = mkDiv(colR, YR)

-- PHAN: NU TU DONG
YR = mkSec(colR, YR, "đŸ”„  THONG TIN SESSION")

local sessCard,YR2=mkCard(colR,YR,80,Color3.fromRGB(12,12,28)); YR=YR2
local sesRow1=mkLabel(sessCard,8,6,250,16,"Ca da cau: 0",Color3.fromRGB(100,220,255),12)
sesRow1.Font=Enum.Font.GothamBold
local sesRow2=mkLabel(sessCard,8,24,250,16,"Da ban: 0 lan",Color3.fromRGB(100,255,160),12)
sesRow2.Font=Enum.Font.GothamBold
local sesRow3=mkLabel(sessCard,8,42,250,16,"Session: 0 / 1",Color3.fromRGB(255,200,80),12)
sesRow3.Font=Enum.Font.GothamBold
local sesBar=Instance.new("Frame",sessCard)
sesBar.Size=UDim2.new(0,4,0,70); sesBar.Position=UDim2.new(1,-16,0.5,-35)
sesBar.BackgroundColor3=Color3.fromRGB(30,30,60); sesBar.BorderSizePixel=0; sesBar.ZIndex=7
Instance.new("UICorner",sesBar).CornerRadius=UDim.new(0,3)
local sesBarFill=Instance.new("Frame",sesBar)
sesBarFill.Size=UDim2.new(1,0,0,0); sesBarFill.Position=UDim2.new(0,0,1,0)
sesBarFill.BackgroundColor3=Color3.fromRGB(100,255,160); sesBarFill.BorderSizePixel=0; sesBarFill.ZIndex=8
Instance.new("UICorner",sesBarFill).CornerRadius=UDim.new(0,3)

YR = mkDiv(colR, YR)

-- Checklist trang thai
YR = mkSec(colR, YR, "âœ…  TRANG THAI SETUP")
local checkCard,YR2=mkCard(colR,YR,100,Color3.fromRGB(12,12,28)); YR=YR2
local checks = {
    {key="fish", lbl="Vi tri cau"},
    {key="npc",  lbl="Vi tri NPC"},
    {key="sell", lbl="Nut SellAll"},
    {key="close",lbl="Nut X dong"},
    {key="cast", lbl="Nut Fishing"},
    {key="zxcv", lbl="Nut ZXCV (it nhat 1)"},
}
local checkLabels={}
for i,c in ipairs(checks) do
    local row=math.ceil(i/2); local col2=((i-1)%2)
    local cl=Instance.new("TextLabel",checkCard)
    cl.Size=UDim2.new(0.48,0,0,14)
    cl.Position=UDim2.new(col2*0.5,4,(row-1)*0.33,3)
    cl.BackgroundTransparency=1; cl.Text="â—‹ "..c.lbl
    cl.TextColor3=Color3.fromRGB(180,60,60); cl.Font=Enum.Font.Gotham; cl.TextSize=9
    cl.TextXAlignment=Enum.TextXAlignment.Left; cl.ZIndex=7
    checkLabels[c.key]=cl
end

colR.CanvasSize=UDim2.new(0,0,0,YR+10)

-- ============================================================
-- OPEN / CLOSE MENU
-- ============================================================
local twI=TweenInfo.new(0.22,Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
local pingA=nil

local function openMenu()
    menuOpen=true
    if pingA then pingA:Cancel() end
    bubble.Visible=false; bubble.Size=UDim2.new(0,60,0,60)
    frame.Visible=true; frame.Size=UDim2.new(0,0,0,0)
    TS:Create(frame,twI,{Size=UDim2.new(0,W,0,H)}):Play()
end

local function closeMenu()
    menuOpen=false
    local tw=TS:Create(frame,twI,{Size=UDim2.new(0,0,0,0)})
    tw:Play()
    tw.Completed:Connect(function()
        if not menuOpen then
            frame.Visible=false; bubble.Visible=true
            pingA=TS:Create(bubble,TweenInfo.new(0.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Size=UDim2.new(0,68,0,68)})
            pingA:Play()
        end
    end)
end

closeBtn.MouseButton1Click:Connect(closeMenu)
bubble.MouseButton1Click:Connect(openMenu)

-- ============================================================
-- SAVE VI TRI
-- ============================================================
saveFishBtn.MouseButton1Click:Connect(function()
    local c=LP.Character; local r=c and c:FindFirstChild("HumanoidRootPart")
    if r then
        savedFishPos=r.Position
        p1Lbl.Text="âœ“ ("..math.floor(r.Position.X)..","..math.floor(r.Position.Z)..")"
        p1Lbl.TextColor3=Color3.fromRGB(80,255,120)
        saveFishBtn.Text="âœ“ Da luu!"; saveFishBtn.BackgroundColor3=Color3.fromRGB(12,95,42)
    end
end)

saveNPCBtn.MouseButton1Click:Connect(function()
    local c=LP.Character; local r=c and c:FindFirstChild("HumanoidRootPart")
    if r then
        savedNPCPos=r.Position
        p2Lbl.Text="âœ“ ("..math.floor(r.Position.X)..","..math.floor(r.Position.Z)..")"
        p2Lbl.TextColor3=Color3.fromRGB(255,220,60)
        saveNPCBtn.Text="âœ“ Da luu!"; saveNPCBtn.BackgroundColor3=Color3.fromRGB(70,15,120)
    end
end)

-- ============================================================
-- MARKER LOGIC (helper chung)
-- ============================================================
local function bindMarker(marker, tBtn, infoLbl, onSave)
    tBtn.MouseButton1Click:Connect(function()
        marker.Visible=not marker.Visible
        tBtn.Text=marker.Visible and "AN vong tron" or tBtn.Text:gsub("^AN","HIEN"):gsub("^âœ“.*","HIEN vong tron")
        if marker.Visible then tBtn.BackgroundColor3=Color3.fromRGB(130,55,15) end
    end)
    marker.MouseButton1Click:Connect(function()
        local mp=UIS:GetMouseLocation()
        local v2=Vector2.new(mp.X,mp.Y)
        onSave(v2, mp.X, mp.Y)
        marker.BackgroundColor3=Color3.fromRGB(30,60,170)
        tBtn.BackgroundColor3=Color3.fromRGB(18,80,18)
        statusText="Da luu! ("..math.floor(mp.X)..","..math.floor(mp.Y)..")"
    end)
end

-- SellAll
bindMarker(markerSell, toggleSellBtn, p3Lbl, function(v2,x,y)
    savedSellPos=v2
    p3Lbl.Text="âœ“ SellAll ("..math.floor(x)..","..math.floor(y)..")"
    p3Lbl.TextColor3=Color3.fromRGB(80,255,180)
    toggleSellBtn.Text="âœ“ SellAll da luu!"
end)

-- X dong
bindMarker(markerClose, toggleCloseBtn, p4Lbl, function(v2,x,y)
    savedClosePos=v2
    p4Lbl.Text="âœ“ X dong ("..math.floor(x)..","..math.floor(y)..")"
    p4Lbl.TextColor3=Color3.fromRGB(255,150,200)
    toggleCloseBtn.Text="âœ“ X dong da luu!"
end)

-- Fishing
bindMarker(markerCast, toggleCastBtn, p5Lbl, function(v2,x,y)
    savedCastPos=v2
    p5Lbl.Text="âœ“ Fishing ("..math.floor(x)..","..math.floor(y)..")"
    p5Lbl.TextColor3=Color3.fromRGB(255,230,80)
    toggleCastBtn.Text="âœ“ Fishing da luu!"
end)

-- ZXCV markers
for i=1,4 do
    local m=zxcvMarkers[i]; local tb=zxcvToggleBtns[i]
    local sl=zxcvInfoLbls[i]; local stl=zxcvData_stLbl[i]
    local col=zxcvColors[i]; local nm=zxcvNames[i]

    tb.MouseButton1Click:Connect(function()
        m.Visible=not m.Visible
        tb.Text=m.Visible and ("AN "..nm) or ("HIEN "..nm)
        if m.Visible then tb.BackgroundColor3=Color3.fromRGB(130,55,15)
        else tb.BackgroundColor3=col end
    end)
    m.MouseButton1Click:Connect(function()
        local mp=UIS:GetMouseLocation()
        zxcvPos[i]=Vector2.new(mp.X,mp.Y)
        sl.Text="âœ“ ("..math.floor(mp.X)..","..math.floor(mp.Y)..")"
        sl.TextColor3=Color3.fromRGB(200,255,200)
        stl.Text="â¬¤ Da luu âœ“"
        stl.TextColor3=Color3.fromRGB(80,255,120)
        m.BackgroundColor3=Color3.fromRGB(30,60,170)
        tb.Text="âœ“ "..nm.." luu xong!"; tb.BackgroundColor3=Color3.fromRGB(18,80,18)
        statusText="Da luu nut "..nm.."!"
    end)
end

-- ============================================================
-- CAI DAT +/-
-- ============================================================
-- Phut +/-
tMinBtn.MouseButton1Click:Connect(function()
    fishMinutes = math.max(1, fishMinutes - 1)
    timerValLbl.Text = fishMinutes .. " phut"
end)
tPlusBtn.MouseButton1Click:Connect(function()
    fishMinutes = fishMinutes + 1
    timerValLbl.Text = fishMinutes .. " phut"
end)

-- Ban sau N lan +/-
nMinBtn.MouseButton1Click:Connect(function()
    sellEveryN = math.max(1, sellEveryN - 1)
    sellNValLbl.Text = sellEveryN .. " lan"
end)
nPlusBtn.MouseButton1Click:Connect(function()
    sellEveryN = sellEveryN + 1
    sellNValLbl.Text = sellEveryN .. " lan"
end)

-- Ban ngay: set dem nguoc ve 0 de vong chinh xu ly
sellNowBtn.MouseButton1Click:Connect(function()
    if not isRunning then statusText = "Bat tu dong truoc!"; return end
    countdownSec = 0
    statusText = "đŸ’° Ban ngay duoc kich hoat!"
    sellNowBtn.BackgroundColor3 = Color3.fromRGB(255,60,0)
    task.delay(0.8, function() sellNowBtn.BackgroundColor3 = Color3.fromRGB(200,100,0) end)
end)

-- ============================================================
-- BAT / TAT
-- ============================================================
toggleBtn.MouseButton1Click:Connect(function()
    isRunning=not isRunning
    if isRunning then
        fishCaught=0; fishSession=0; sellCount=0
        statusText="Khoi dong..."
        task.spawn(mainLoop)
    else
        statusText="Da tat"; stopWalk()
    end
end)

UIS.InputBegan:Connect(function(i,gp)
    if gp then return end
    if i.KeyCode==Enum.KeyCode.F then toggleBtn.MouseButton1Click:Fire() end
    if i.KeyCode==Enum.KeyCode.H then if menuOpen then closeMenu() else openMenu() end end
end)

-- ============================================================
-- UPDATE LOOP
-- ============================================================
RS.Heartbeat:Connect(function()
    -- Header status
    if isRunning then
        hStatus.Text="â— "..statusText
        hStatus.TextColor3=Color3.fromRGB(80,255,140)
        hStatus.BackgroundTransparency=0.35
    else
        hStatus.Text="â— "..statusText
        hStatus.TextColor3=Color3.fromRGB(255,100,100)
        hStatus.BackgroundTransparency=0.45
    end

    -- Header pills
    hCaughtLbl.Text="Ca: "..fishCaught
    hSellLbl.Text="Ban: "..sellCount
    hSesLbl.Text=fishSession.."/"..sellEveryN

    -- Cot phai stat
    sesRow1.Text = "Ca da cau: " .. fishCaught
    sesRow2.Text = "Da ban: "    .. sellCount .. " lan"
    local m2 = math.floor(countdownSec/60)
    local s2 = countdownSec % 60
    sesRow3.Text = isSelling
        and "â¸ Dang di ban..."
        or  string.format("â± Con lai: %d:%02d", m2, s2)

    -- Progress bar session
    local pct = sellEveryN>0 and (fishSession/sellEveryN) or 0
    sesBarFill.Size=UDim2.new(1,0,pct,0)
    sesBarFill.Position=UDim2.new(0,0,1-pct,0)
    sesBarFill.BackgroundColor3 = pct>=1
        and Color3.fromRGB(255,200,50)
        or  Color3.fromRGB(80,255,160)

    -- Checklist
    local function chk(key, val) 
        if checkLabels[key] then
            checkLabels[key].Text=(val and "âœ“ " or "â—‹ ")..checkLabels[key].Text:sub(3)
            checkLabels[key].TextColor3=val and Color3.fromRGB(80,255,120) or Color3.fromRGB(200,60,60)
        end
    end
    chk("fish",  savedFishPos~=nil)
    chk("npc",   savedNPCPos~=nil)
    chk("sell",  savedSellPos~=nil)
    chk("close", savedClosePos~=nil)
    chk("cast",  savedCastPos~=nil)
    local hz=false; for i=1,4 do if zxcvPos[i] then hz=true end end
    chk("zxcv",  hz)

    -- Toggle btn
    if isRunning then
        toggleBtn.Text="â¹   TAT VONG LAP"
        tGrad.Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(225,50,50)),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(155,18,18)),
        })
    else
        toggleBtn.Text="â–¶   BAT VONG LAP TU DONG"
        tGrad.Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(50,220,85)),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(18,145,48)),
        })
    end

    -- Bubble
    if not menuOpen then
        bubble.Text=isRunning and "â–¶" or "đŸ£"
        bubble.BackgroundColor3=isRunning and Color3.fromRGB(200,45,45) or Color3.fromRGB(255,140,0)
    end
end)

print("[TF v15] H=menu | F=bat/tat | Layout ngang 2 cot")
