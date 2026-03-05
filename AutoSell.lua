-- TITAN FISHING v16
-- GUI nho gon goc trai | Logic: cau X phut -> ban -> lap lai

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

local fishMinutes   = 1
local countdownSec  = 0
local isSelling     = false
local zxcvCooldown  = {1.0, 1.0, 1.0, 1.0}
local zxcvNames     = {"Z","X","C","V"}
local zxcvColors    = {
    Color3.fromRGB(80,160,255),
    Color3.fromRGB(200,80,255),
    Color3.fromRGB(255,110,40),
    Color3.fromRGB(40,220,170),
}

-- ============================================================
-- CLICK / TOUCH
-- ============================================================
local function clickAt(x,y)
    VIM:SendMouseButtonEvent(x,y,0,true,game,0); task.wait(0.07)
    VIM:SendMouseButtonEvent(x,y,0,false,game,0); task.wait(0.07)
end

local function touchAt(x,y)
    pcall(function()
        VIM:SendTouchEvent(x,y,Enum.UserInputState.Begin,0); task.wait(0.04)
        VIM:SendTouchEvent(x,y,Enum.UserInputState.End,0)
    end)
    pcall(function()
        VIM:SendMouseButtonEvent(x,y,0,true,game,0); task.wait(0.03)
        VIM:SendMouseButtonEvent(x,y,0,false,game,0)
    end)
    task.wait(0.04)
end

-- ============================================================
-- WALK
-- ============================================================
local function walkTo(pos,lbl)
    local char=LP.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart")
    local hum=char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    statusText=lbl or "Dang di..."
    hum.WalkSpeed=24
    local path=PFS:CreatePath({AgentHeight=5,AgentRadius=2,AgentCanJump=true})
    local ok=pcall(function() path:ComputeAsync(hrp.Position,pos) end)
    if ok and path.Status==Enum.PathStatus.Success then
        for _,wp in ipairs(path:GetWaypoints()) do
            if not isRunning then return end
            if wp.Action==Enum.PathWaypointAction.Jump then hum.Jump=true end
            hum:MoveTo(wp.Position); hum.MoveToFinished:Wait(3)
            if (hrp.Position-pos).Magnitude<8 then break end
        end
    else
        hum:MoveTo(pos); local t=0
        while t<12 and isRunning do task.wait(0.2); t+=0.2
            if (hrp.Position-pos).Magnitude<8 then break end
        end
    end
end

local function stopWalk()
    local c=LP.Character
    local h=c and c:FindFirstChild("Humanoid")
    local r=c and c:FindFirstChild("HumanoidRootPart")
    if h and r then h:MoveTo(r.Position) end
end

-- ============================================================
-- INTERACT + SELL
-- ============================================================
local function doInteract()
    statusText="Mo cua hang..."
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
    if not savedSellPos or not savedClosePos then
        statusText="Chua luu SellAll/X!"; task.wait(2); return false
    end
    statusText="Cho popup..."; task.wait(0.8)
    touchAt(savedSellPos.X,savedSellPos.Y); task.wait(1.2)
    touchAt(savedClosePos.X,savedClosePos.Y); task.wait(0.5)
    statusText="Da ban xong!"; return true
end

-- ============================================================
-- SPAM LOOPS
-- ============================================================
local function loop_Cast()
    while isRunning and not isSelling do
        if savedCastPos then
            pcall(function()
                VIM:SendMouseButtonEvent(savedCastPos.X,savedCastPos.Y,0,true,game,0)
                task.wait(0.06)
                VIM:SendMouseButtonEvent(savedCastPos.X,savedCastPos.Y,0,false,game,0)
            end)
            pcall(function()
                VIM:SendTouchEvent(savedCastPos.X,savedCastPos.Y,Enum.UserInputState.Begin,0)
                task.wait(0.04)
                VIM:SendTouchEvent(savedCastPos.X,savedCastPos.Y,Enum.UserInputState.End,0)
            end)
        end
        task.wait(0.4)
    end
end

local function loop_OneSkill(idx)
    while isRunning and not isSelling do
        if zxcvPos[idx] then
            local x,y=zxcvPos[idx].X,zxcvPos[idx].Y
            pcall(function()
                VIM:SendTouchEvent(x,y,Enum.UserInputState.Begin,0); task.wait(0.04)
                VIM:SendTouchEvent(x,y,Enum.UserInputState.End,0)
            end)
            pcall(function()
                VIM:SendMouseButtonEvent(x,y,0,true,game,0); task.wait(0.04)
                VIM:SendMouseButtonEvent(x,y,0,false,game,0)
            end)
            local cd=zxcvCooldown[idx] or 1.0
            local w=0
            while w<cd and isRunning and not isSelling do
                task.wait(0.05); w+=0.05
            end
        else
            task.wait(0.1)
        end
    end
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local function mainLoop()
    local miss={}
    if not savedFishPos  then table.insert(miss,"Vi tri cau") end
    if not savedNPCPos   then table.insert(miss,"Vi tri NPC") end
    if not savedSellPos  then table.insert(miss,"SellAll") end
    if not savedClosePos then table.insert(miss,"X dong") end
    if not savedCastPos  then table.insert(miss,"Nut Fishing") end
    local hz=false; for i=1,4 do if zxcvPos[i] then hz=true end end
    if not hz then table.insert(miss,"ZXCV") end
    if #miss>0 then
        statusText="Thieu: "..table.concat(miss,", ").."!"
        isRunning=false; return
    end

    while isRunning do
        isSelling=false
        local char=LP.Character
        local hrp=char and char:FindFirstChild("HumanoidRootPart")
        if hrp and savedFishPos and (hrp.Position-savedFishPos).Magnitude>5 then
            walkTo(savedFishPos,"Di ve vi tri cau...")
            if not isRunning then break end
            stopWalk(); task.wait(0.5)
        end

        countdownSec=fishMinutes*60
        task.spawn(loop_Cast)
        for i=1,4 do task.spawn(function() loop_OneSkill(i) end) end

        while countdownSec>0 and isRunning do
            local m=math.floor(countdownSec/60)
            local s=countdownSec%60
            statusText=string.format("đŸ£ %d:%02d | đŸŸ%d đŸ›’%d",m,s,fishCaught,sellCount)
            task.wait(1); countdownSec-=1
        end
        if not isRunning then break end

        isSelling=true; task.wait(0.3)
        statusText="â° Di ban ca..."
        fishCaught+=1; fishSession+=1

        walkTo(savedNPCPos,"Di toi NPC...")
        if not isRunning then break end
        task.wait(0.3); stopWalk(); task.wait(0.4)
        doInteract(); task.wait(0.5)
        doSellAll();  task.wait(0.5)
        sellCount+=1
        statusText="âœ“ Ban lan "..sellCount.."!"
        task.wait(1)
    end

    isSelling=false; countdownSec=0; statusText="Da tat"
end

-- ============================================================
-- GUI - PANEL NHO GAN GOC TRAI
-- ============================================================
local old=LP.PlayerGui:FindFirstChild("TFHub"); if old then old:Destroy() end
local sg=Instance.new("ScreenGui")
sg.Name="TFHub"; sg.ResetOnSpawn=false
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.Parent=LP.PlayerGui

-- ======== MARKERS ========
local function makeMarker(col, tag)
    local S=60
    local m=Instance.new("TextButton")
    m.Size=UDim2.new(0,S,0,S); m.Position=UDim2.new(0.5,-S/2,0.5,-S/2)
    m.BackgroundColor3=col; m.BackgroundTransparency=0.15
    m.BorderSizePixel=0; m.Text=""; m.ZIndex=50
    m.Active=true; m.Draggable=true; m.Visible=false; m.Parent=sg
    Instance.new("UICorner",m).CornerRadius=UDim.new(1,0)
    local sk=Instance.new("UIStroke",m); sk.Color=Color3.new(1,1,1); sk.Thickness=2.5
    local function bar(sz,ps)
        local f=Instance.new("Frame",m); f.Size=sz; f.Position=ps
        f.BackgroundColor3=Color3.new(1,1,0); f.BorderSizePixel=0; f.ZIndex=51
    end
    bar(UDim2.new(0.6,0,0,2),UDim2.new(0.2,0,0.5,-1))
    bar(UDim2.new(0,2,0.6,0),UDim2.new(0.5,-1,0.2,0))
    local dot=Instance.new("Frame",m)
    dot.Size=UDim2.new(0,8,0,8); dot.Position=UDim2.new(0.5,-4,0.5,-4)
    dot.BackgroundColor3=Color3.new(1,0,0); dot.BorderSizePixel=0; dot.ZIndex=52
    Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
    local tl=Instance.new("TextLabel",m)
    tl.Size=UDim2.new(1,0,0,16); tl.Position=UDim2.new(0,0,1,2)
    tl.BackgroundTransparency=1; tl.Text=tag
    tl.TextColor3=Color3.new(1,1,0); tl.Font=Enum.Font.GothamBlack; tl.TextSize=11; tl.ZIndex=52
    RS.Heartbeat:Connect(function()
        if m.Visible then m.BackgroundTransparency=0.1+math.abs(math.sin(tick()*2))*0.3 end
    end)
    return m
end

local markerSell  = makeMarker(Color3.fromRGB(20,200,100),"SELL")
local markerClose = makeMarker(Color3.fromRGB(220,40,60),"CLOSE")
local markerCast  = makeMarker(Color3.fromRGB(255,200,0),"FISHING")
local zxcvMarkers = {}
for i=1,4 do zxcvMarkers[i]=makeMarker(zxcvColors[i],zxcvNames[i]) end

-- ======== PANEL CHINH: 220px, doc, goc trai ========
local PW = 220   -- chieu rong panel
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0,PW,1,0)        -- cao toan man hinh doc
panel.Position = UDim2.new(0,0,0,0)     -- goc trai
panel.BackgroundColor3 = Color3.fromRGB(8,8,18)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Active = true; panel.Draggable = false
panel.ClipsDescendants = true; panel.ZIndex = 10; panel.Parent = sg
local psk=Instance.new("UIStroke",panel)
psk.Color=Color3.fromRGB(255,140,0); psk.Thickness=1.5; psk.ApplyStrokeMode=Enum.ApplyStrokeMode.Border

-- Thu/mo panel
local panelOpen = true
local function setPanel(open)
    panelOpen = open
    TS:Create(panel, TweenInfo.new(0.2,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
        {Position=UDim2.new(0, open and 0 or -(PW+4), 0, 0)}):Play()
end

-- ======== NUT MO (tab nho ben phai panel) ========
local tabBtn = Instance.new("TextButton")
tabBtn.Size = UDim2.new(0,28,0,60)
tabBtn.Position = UDim2.new(0,PW,0.5,-30)
tabBtn.BackgroundColor3 = Color3.fromRGB(255,140,0)
tabBtn.BorderSizePixel = 0; tabBtn.Text = "â—€"; tabBtn.TextColor3 = Color3.new(1,1,1)
tabBtn.Font = Enum.Font.GothamBold; tabBtn.TextSize = 14; tabBtn.ZIndex = 11; tabBtn.Parent = panel
Instance.new("UICorner",tabBtn).CornerRadius = UDim.new(0,8)
tabBtn.MouseButton1Click:Connect(function()
    setPanel(not panelOpen)
    tabBtn.Text = panelOpen and "â–¶" or "â—€"
end)

-- ======== SCROLLING CONTENT ========
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1,-2,1,0); scroll.Position = UDim2.new(0,0,0,0)
scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 3; scroll.ScrollBarImageColor3 = Color3.fromRGB(255,140,0)
scroll.CanvasSize = UDim2.new(0,0,0,900); scroll.ZIndex = 11; scroll.Parent = panel

-- ======== WIDGET HELPERS ========
local Y = 6
local W = PW - 10  -- usable width

local function mkTitle(txt)
    local l=Instance.new("TextLabel",scroll)
    l.Size=UDim2.new(0,W,0,28); l.Position=UDim2.new(0,5,0,Y)
    l.BackgroundColor3=Color3.fromRGB(20,15,45); l.BorderSizePixel=0
    l.Text=txt; l.TextColor3=Color3.new(1,1,1); l.Font=Enum.Font.GothamBlack
    l.TextSize=12; l.ZIndex=12
    Instance.new("UICorner",l).CornerRadius=UDim.new(0,7)
    local g=Instance.new("UIGradient",l)
    g.Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(255,120,0)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(180,40,180)),
    }); g.Rotation=90
    Y=Y+32
end

local function mkSec(txt)
    local l=Instance.new("TextLabel",scroll)
    l.Size=UDim2.new(0,W,0,16); l.Position=UDim2.new(0,5,0,Y)
    l.BackgroundTransparency=1; l.Text=txt
    l.TextColor3=Color3.fromRGB(140,140,255); l.Font=Enum.Font.GothamBold
    l.TextSize=10; l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=12
    Y=Y+19
end

local function mkDiv()
    local d=Instance.new("Frame",scroll)
    d.Size=UDim2.new(0,W,0,1); d.Position=UDim2.new(0,5,0,Y)
    d.BackgroundColor3=Color3.fromRGB(40,40,70); d.BorderSizePixel=0; d.ZIndex=12
    Y=Y+7
end

-- Row info: icon + label (returns label ref)
local function mkInfo(icon, txt, col)
    local f=Instance.new("Frame",scroll)
    f.Size=UDim2.new(0,W,0,22); f.Position=UDim2.new(0,5,0,Y)
    f.BackgroundColor3=Color3.fromRGB(12,12,28); f.BorderSizePixel=0; f.ZIndex=12
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,6)
    local il=Instance.new("TextLabel",f)
    il.Size=UDim2.new(0,20,1,0); il.Position=UDim2.new(0,2,0,0)
    il.BackgroundTransparency=1; il.Text=icon; il.TextScaled=true; il.ZIndex=13
    local vl=Instance.new("TextLabel",f)
    vl.Size=UDim2.new(1,-24,1,0); vl.Position=UDim2.new(0,22,0,0)
    vl.BackgroundTransparency=1; vl.Text=txt; vl.TextColor3=col
    vl.Font=Enum.Font.Gotham; vl.TextSize=9
    vl.TextXAlignment=Enum.TextXAlignment.Left
    vl.TextTruncate=Enum.TextTruncate.AtEnd; vl.ZIndex=13
    Y=Y+26
    return vl
end

-- Button full width
local function mkBtn(h, bg, txt, fs)
    local b=Instance.new("TextButton",scroll)
    b.Size=UDim2.new(0,W,0,h); b.Position=UDim2.new(0,5,0,Y)
    b.BackgroundColor3=bg; b.BorderSizePixel=0
    b.Text=txt; b.TextColor3=Color3.new(1,1,1)
    b.Font=Enum.Font.GothamBold; b.TextSize=fs or 11; b.ZIndex=12
    b.TextWrapped=true
    Instance.new("UICorner",b).CornerRadius=UDim.new(0,8)
    Y=Y+h+5
    return b
end

-- Button half width (left/right)
local function mkBtn2(bg1,txt1,bg2,txt2,h)
    h=h or 28
    local b1=Instance.new("TextButton",scroll)
    b1.Size=UDim2.new(0,math.floor(W/2)-2,0,h); b1.Position=UDim2.new(0,5,0,Y)
    b1.BackgroundColor3=bg1; b1.BorderSizePixel=0
    b1.Text=txt1; b1.TextColor3=Color3.new(1,1,1)
    b1.Font=Enum.Font.GothamBold; b1.TextSize=11; b1.ZIndex=12
    Instance.new("UICorner",b1).CornerRadius=UDim.new(0,8)
    local b2=Instance.new("TextButton",scroll)
    b2.Size=UDim2.new(0,math.floor(W/2)-2,0,h)
    b2.Position=UDim2.new(0,5+math.floor(W/2)+2,0,Y)
    b2.BackgroundColor3=bg2; b2.BorderSizePixel=0
    b2.Text=txt2; b2.TextColor3=Color3.new(1,1,1)
    b2.Font=Enum.Font.GothamBold; b2.TextSize=11; b2.ZIndex=12
    Instance.new("UICorner",b2).CornerRadius=UDim.new(0,8)
    Y=Y+h+5
    return b1,b2
end

-- Stepper row: [label val] [âˆ’] [+]
local function mkStepper(lbl, val, col)
    local f=Instance.new("Frame",scroll)
    f.Size=UDim2.new(0,W,0,28); f.Position=UDim2.new(0,5,0,Y)
    f.BackgroundColor3=Color3.fromRGB(12,12,28); f.BorderSizePixel=0; f.ZIndex=12
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,7)
    local ll=Instance.new("TextLabel",f)
    ll.Size=UDim2.new(0,80,1,0); ll.Position=UDim2.new(0,6,0,0)
    ll.BackgroundTransparency=1; ll.Text=lbl
    ll.TextColor3=Color3.fromRGB(180,180,255); ll.Font=Enum.Font.Gotham
    ll.TextSize=10; ll.TextXAlignment=Enum.TextXAlignment.Left; ll.ZIndex=13
    local vl=Instance.new("TextLabel",f)
    vl.Size=UDim2.new(0,40,1,0); vl.Position=UDim2.new(0,88,0,0)
    vl.BackgroundTransparency=1; vl.Text=val
    vl.TextColor3=col or Color3.fromRGB(255,220,80)
    vl.Font=Enum.Font.GothamBold; vl.TextSize=11; vl.ZIndex=13
    local bm=Instance.new("TextButton",f)
    bm.Size=UDim2.new(0,22,0,22); bm.Position=UDim2.new(1,-52,0.5,-11)
    bm.BackgroundColor3=Color3.fromRGB(140,30,30); bm.BorderSizePixel=0
    bm.Text="âˆ’"; bm.TextColor3=Color3.new(1,1,1)
    bm.Font=Enum.Font.GothamBold; bm.TextSize=13; bm.ZIndex=13
    Instance.new("UICorner",bm).CornerRadius=UDim.new(0,5)
    local bp=Instance.new("TextButton",f)
    bp.Size=UDim2.new(0,22,0,22); bp.Position=UDim2.new(1,-27,0.5,-11)
    bp.BackgroundColor3=Color3.fromRGB(25,130,50); bp.BorderSizePixel=0
    bp.Text="+"; bp.TextColor3=Color3.new(1,1,1)
    bp.Font=Enum.Font.GothamBold; bp.TextSize=13; bp.ZIndex=13
    Instance.new("UICorner",bp).CornerRadius=UDim.new(0,5)
    Y=Y+33
    return vl, bm, bp
end

-- ======== BUILD UI ========

-- HEADER
mkTitle("đŸ£ TITAN FISHING")

-- STATUS BOX
local statusBox=Instance.new("Frame",scroll)
statusBox.Size=UDim2.new(0,W,0,36); statusBox.Position=UDim2.new(0,5,0,Y)
statusBox.BackgroundColor3=Color3.fromRGB(10,10,30); statusBox.BorderSizePixel=0; statusBox.ZIndex=12
Instance.new("UICorner",statusBox).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",statusBox).Color=Color3.fromRGB(40,40,80)
local statusDot=Instance.new("Frame",statusBox)
statusDot.Size=UDim2.new(0,8,0,8); statusDot.Position=UDim2.new(0,8,0.5,-4)
statusDot.BackgroundColor3=Color3.fromRGB(255,80,80); statusDot.BorderSizePixel=0; statusDot.ZIndex=13
Instance.new("UICorner",statusDot).CornerRadius=UDim.new(1,0)
local statusLbl=Instance.new("TextLabel",statusBox)
statusLbl.Size=UDim2.new(1,-22,1,0); statusLbl.Position=UDim2.new(0,20,0,0)
statusLbl.BackgroundTransparency=1; statusLbl.Text="Chua bat"
statusLbl.TextColor3=Color3.fromRGB(255,100,100); statusLbl.Font=Enum.Font.GothamBold
statusLbl.TextSize=10; statusLbl.TextXAlignment=Enum.TextXAlignment.Left
statusLbl.TextWrapped=true; statusLbl.ZIndex=13
Y=Y+42

-- STATS ROW
local statsBox=Instance.new("Frame",scroll)
statsBox.Size=UDim2.new(0,W,0,28); statsBox.Position=UDim2.new(0,5,0,Y)
statsBox.BackgroundColor3=Color3.fromRGB(10,10,30); statsBox.BorderSizePixel=0; statsBox.ZIndex=12
Instance.new("UICorner",statsBox).CornerRadius=UDim.new(0,8)
local function statCell(xp, icon, col)
    local f=Instance.new("Frame",statsBox)
    f.Size=UDim2.new(0.33,0,1,0); f.Position=UDim2.new(xp,0,0,0)
    f.BackgroundTransparency=1; f.ZIndex=13
    local il=Instance.new("TextLabel",f)
    il.Size=UDim2.new(0,16,1,0); il.Position=UDim2.new(0,2,0,0)
    il.BackgroundTransparency=1; il.Text=icon; il.TextScaled=true; il.ZIndex=14
    local vl=Instance.new("TextLabel",f)
    vl.Size=UDim2.new(1,-20,1,0); vl.Position=UDim2.new(0,18,0,0)
    vl.BackgroundTransparency=1; vl.TextColor3=col
    vl.Font=Enum.Font.GothamBold; vl.TextSize=10
    vl.TextXAlignment=Enum.TextXAlignment.Left; vl.ZIndex=14
    return vl
end
local statCd  = statCell(0,    "â±", Color3.fromRGB(255,220,80))
local statFish= statCell(0.33, "đŸŸ", Color3.fromRGB(100,220,255))
local statSell= statCell(0.66, "đŸ›’", Color3.fromRGB(100,255,160))
Y=Y+34

mkDiv()

-- NUT BAT/TAT CHINH
local toggleBtn = mkBtn(38, Color3.fromRGB(30,180,65), "â–¶  BAT TU DONG", 13)
local tg=Instance.new("UIGradient",toggleBtn)
tg.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(50,220,85)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(18,145,48)),
}); tg.Rotation=90

-- BAN NGAY
local sellNowBtn = mkBtn(26, Color3.fromRGB(200,100,0), "đŸ’°  BAN NGAY", 11)

mkDiv()
mkSec("đŸ“Œ VI TRI")

-- VI TRI CAU
local p1Lbl = mkInfo("đŸ¯","Cau: Chua luu",Color3.fromRGB(120,180,255))
local saveFishBtn = mkBtn(26, Color3.fromRGB(25,100,210), "đŸ“ SAVE vi tri cau", 10)

-- VI TRI NPC
local p2Lbl = mkInfo("đŸª","NPC: Chua luu",Color3.fromRGB(255,180,80))
local saveNPCBtn = mkBtn(26, Color3.fromRGB(110,35,180), "đŸª SAVE vi tri NPC", 10)

mkDiv()
mkSec("đŸ›’ NUT BAN (danh dau)")

local p3Lbl = mkInfo("đŸ’","SellAll: Chua luu",Color3.fromRGB(80,255,180))
local showSellBtn = mkBtn(24, Color3.fromRGB(18,140,72), "HIEN vong SellAll", 10)

local p4Lbl = mkInfo("âŒ","X dong: Chua luu",Color3.fromRGB(255,130,180))
local showCloseBtn = mkBtn(24, Color3.fromRGB(175,35,55), "HIEN vong X dong", 10)

mkDiv()
mkSec("đŸ£ NUT NEM CAN")

local p5Lbl = mkInfo("đŸŸ¡","Fishing: Chua luu",Color3.fromRGB(255,230,80))
local showCastBtn = mkBtn(24, Color3.fromRGB(155,115,0), "HIEN vong Fishing", 10)

mkDiv()
mkSec("â¡ CHIEU Z X C V")

-- 4 hang ZXCV
local zxcvToggleBtns = {}
local zxcvInfoLbls   = {}
local zxcvCdLbls     = {}

for i = 1, 4 do
    local nm  = zxcvNames[i]
    local col = zxcvColors[i]

    -- Row: badge + info
    local rowF=Instance.new("Frame",scroll)
    rowF.Size=UDim2.new(0,W,0,22); rowF.Position=UDim2.new(0,5,0,Y)
    rowF.BackgroundTransparency=1; rowF.ZIndex=12
    local badge=Instance.new("Frame",rowF)
    badge.Size=UDim2.new(0,22,0,22); badge.Position=UDim2.new(0,0,0,0)
    badge.BackgroundColor3=col; badge.BorderSizePixel=0; badge.ZIndex=13
    Instance.new("UICorner",badge).CornerRadius=UDim.new(0,5)
    local bl=Instance.new("TextLabel",badge)
    bl.Size=UDim2.new(1,0,1,0); bl.BackgroundTransparency=1
    bl.Text=nm; bl.Font=Enum.Font.GothamBlack; bl.TextSize=13
    bl.TextColor3=Color3.new(1,1,1); bl.ZIndex=14
    local sl=Instance.new("TextLabel",rowF)
    sl.Size=UDim2.new(1,-26,1,0); sl.Position=UDim2.new(0,25,0,0)
    sl.BackgroundTransparency=1; sl.Text="Chua luu"
    sl.TextColor3=Color3.fromRGB(160,160,160); sl.Font=Enum.Font.Gotham; sl.TextSize=9
    sl.TextXAlignment=Enum.TextXAlignment.Left
    sl.TextTruncate=Enum.TextTruncate.AtEnd; sl.ZIndex=13
    zxcvInfoLbls[i]=sl
    Y=Y+26

    -- HIEN marker btn
    local tb=Instance.new("TextButton",scroll)
    tb.Size=UDim2.new(0,W,0,22); tb.Position=UDim2.new(0,5,0,Y)
    tb.BackgroundColor3=col; tb.BorderSizePixel=0
    tb.Text="HIEN "..nm; tb.TextColor3=Color3.new(1,1,1)
    tb.Font=Enum.Font.GothamBold; tb.TextSize=10; tb.ZIndex=12
    Instance.new("UICorner",tb).CornerRadius=UDim.new(0,7)
    zxcvToggleBtns[i]=tb
    Y=Y+26

    -- Cooldown stepper
    local cdLbl,cdMin,cdPlus = mkStepper("CD "..nm..":", string.format("%.1fs",zxcvCooldown[i]), col)
    zxcvCdLbls[i]=cdLbl

    local idx=i
    cdMin.MouseButton1Click:Connect(function()
        zxcvCooldown[idx]=math.max(0.1,math.floor((zxcvCooldown[idx]-0.1)*10+0.5)/10)
        cdLbl.Text=string.format("%.1fs",zxcvCooldown[idx])
    end)
    cdPlus.MouseButton1Click:Connect(function()
        zxcvCooldown[idx]=math.floor((zxcvCooldown[idx]+0.1)*10+0.5)/10
        cdLbl.Text=string.format("%.1fs",zxcvCooldown[idx])
    end)

    if i<4 then Y=Y+4 end
end

mkDiv()
mkSec("â™ CAI DAT THOI GIAN")

local timerLbl,timerMin,timerPlus = mkStepper("Cau (phut):", fishMinutes.."p",Color3.fromRGB(255,220,80))
timerMin.MouseButton1Click:Connect(function()
    fishMinutes=math.max(1,fishMinutes-1); timerLbl.Text=fishMinutes.."p"
end)
timerPlus.MouseButton1Click:Connect(function()
    fishMinutes=fishMinutes+1; timerLbl.Text=fishMinutes.."p"
end)

-- Checklist setup
mkDiv()
mkSec("âœ… TRANG THAI SETUP")
local checkLabels={}
local checks={
    {k="fish",  l="Vi tri cau"},
    {k="npc",   l="Vi tri NPC"},
    {k="sell",  l="SellAll"},
    {k="close", l="X dong"},
    {k="cast",  l="Fishing"},
    {k="zxcv",  l="ZXCV (>=1)"},
}
for _,c in ipairs(checks) do
    local f=Instance.new("Frame",scroll)
    f.Size=UDim2.new(0,W,0,18); f.Position=UDim2.new(0,5,0,Y)
    f.BackgroundTransparency=1; f.ZIndex=12
    local lbl=Instance.new("TextLabel",f)
    lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1
    lbl.Text="â—‹ "..c.l; lbl.TextColor3=Color3.fromRGB(200,60,60)
    lbl.Font=Enum.Font.Gotham; lbl.TextSize=10
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=13
    checkLabels[c.k]=lbl; Y=Y+20
end

Y=Y+8
scroll.CanvasSize=UDim2.new(0,0,0,Y)

-- ======== MARKER BINDINGS ========
local function bindShowMarker(marker, showBtn, infoLbl, onSave)
    showBtn.MouseButton1Click:Connect(function()
        marker.Visible=not marker.Visible
        showBtn.Text=marker.Visible and "AN vong tron" or showBtn.Text:gsub("^AN","HIEN"):gsub("^âœ“.*","HIEN")
        if marker.Visible then showBtn.BackgroundColor3=Color3.fromRGB(120,50,10) end
    end)
    marker.MouseButton1Click:Connect(function()
        local mp=UIS:GetMouseLocation()
        onSave(Vector2.new(mp.X,mp.Y), mp.X, mp.Y)
        marker.BackgroundColor3=Color3.fromRGB(30,60,170)
        showBtn.BackgroundColor3=Color3.fromRGB(18,80,18)
        statusText="Da luu! ("..math.floor(mp.X)..","..math.floor(mp.Y)..")"
    end)
end

bindShowMarker(markerSell, showSellBtn, p3Lbl, function(v2,x,y)
    savedSellPos=v2
    p3Lbl.Text="âœ“ ("..math.floor(x)..","..math.floor(y)..")"
    p3Lbl.TextColor3=Color3.fromRGB(80,255,180)
    showSellBtn.Text="âœ“ SellAll da luu"
end)

bindShowMarker(markerClose, showCloseBtn, p4Lbl, function(v2,x,y)
    savedClosePos=v2
    p4Lbl.Text="âœ“ ("..math.floor(x)..","..math.floor(y)..")"
    p4Lbl.TextColor3=Color3.fromRGB(255,150,200)
    showCloseBtn.Text="âœ“ X dong da luu"
end)

bindShowMarker(markerCast, showCastBtn, p5Lbl, function(v2,x,y)
    savedCastPos=v2
    p5Lbl.Text="âœ“ ("..math.floor(x)..","..math.floor(y)..")"
    p5Lbl.TextColor3=Color3.fromRGB(255,230,80)
    showCastBtn.Text="âœ“ Fishing da luu"
end)

for i=1,4 do
    local m=zxcvMarkers[i]; local tb=zxcvToggleBtns[i]
    local sl=zxcvInfoLbls[i]; local col=zxcvColors[i]; local nm=zxcvNames[i]
    tb.MouseButton1Click:Connect(function()
        m.Visible=not m.Visible
        tb.Text=m.Visible and ("AN "..nm) or ("HIEN "..nm)
        if m.Visible then tb.BackgroundColor3=Color3.fromRGB(120,50,10)
        else tb.BackgroundColor3=col end
    end)
    m.MouseButton1Click:Connect(function()
        local mp=UIS:GetMouseLocation()
        zxcvPos[i]=Vector2.new(mp.X,mp.Y)
        sl.Text="âœ“ ("..math.floor(mp.X)..","..math.floor(mp.Y)..")"
        sl.TextColor3=Color3.fromRGB(150,255,150)
        m.BackgroundColor3=Color3.fromRGB(30,60,170)
        tb.Text="âœ“ "..nm; tb.BackgroundColor3=Color3.fromRGB(18,80,18)
        statusText="Luu "..nm.." xong!"
    end)
end

-- ======== SAVE VI TRI ========
saveFishBtn.MouseButton1Click:Connect(function()
    local c=LP.Character; local r=c and c:FindFirstChild("HumanoidRootPart")
    if r then
        savedFishPos=r.Position
        p1Lbl.Text="âœ“ ("..math.floor(r.Position.X)..","..math.floor(r.Position.Z)..")"
        p1Lbl.TextColor3=Color3.fromRGB(80,255,120)
        saveFishBtn.Text="âœ“ Cau da luu"
        saveFishBtn.BackgroundColor3=Color3.fromRGB(12,90,40)
    end
end)

saveNPCBtn.MouseButton1Click:Connect(function()
    local c=LP.Character; local r=c and c:FindFirstChild("HumanoidRootPart")
    if r then
        savedNPCPos=r.Position
        p2Lbl.Text="âœ“ ("..math.floor(r.Position.X)..","..math.floor(r.Position.Z)..")"
        p2Lbl.TextColor3=Color3.fromRGB(255,220,60)
        saveNPCBtn.Text="âœ“ NPC da luu"
        saveNPCBtn.BackgroundColor3=Color3.fromRGB(70,15,120)
    end
end)

-- ======== BAT/TAT ========
toggleBtn.MouseButton1Click:Connect(function()
    isRunning=not isRunning
    if isRunning then
        fishCaught=0; fishSession=0; sellCount=0
        statusText="Dang khoi dong..."
        task.spawn(mainLoop)
    else
        statusText="Da tat"; stopWalk()
    end
end)

sellNowBtn.MouseButton1Click:Connect(function()
    if not isRunning then statusText="Bat tu dong truoc!"; return end
    countdownSec=0
    sellNowBtn.BackgroundColor3=Color3.fromRGB(255,60,0)
    task.delay(0.8,function() sellNowBtn.BackgroundColor3=Color3.fromRGB(200,100,0) end)
end)

UIS.InputBegan:Connect(function(inp,gp)
    if gp then return end
    if inp.KeyCode==Enum.KeyCode.F then toggleBtn.MouseButton1Click:Fire() end
    if inp.KeyCode==Enum.KeyCode.H then setPanel(not panelOpen); tabBtn.Text=panelOpen and "â–¶" or "â—€" end
end)

-- ======== UPDATE LOOP ========
RS.Heartbeat:Connect(function()
    -- Status
    statusLbl.Text=statusText
    if isRunning then
        statusLbl.TextColor3=Color3.fromRGB(80,255,140)
        statusDot.BackgroundColor3=Color3.fromRGB(60,255,80)
        toggleBtn.Text="â¹  TAT TU DONG"
        tg.Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(225,50,50)),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(155,18,18)),
        })
    else
        statusLbl.TextColor3=Color3.fromRGB(255,100,100)
        statusDot.BackgroundColor3=Color3.fromRGB(255,80,80)
        toggleBtn.Text="â–¶  BAT TU DONG"
        tg.Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(50,220,85)),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(18,145,48)),
        })
    end

    -- Stats
    local m2=math.floor(countdownSec/60)
    local s2=countdownSec%60
    statCd.Text  = isSelling and "Ban..." or string.format("%d:%02d",m2,s2)
    statFish.Text= "đŸŸ"..fishCaught
    statSell.Text= "đŸ›’"..sellCount

    -- Checklist
    local function chk(k,v)
        if not checkLabels[k] then return end
        checkLabels[k].Text=(v and "âœ“ " or "â—‹ ")..checkLabels[k].Text:sub(3)
        checkLabels[k].TextColor3=v and Color3.fromRGB(80,255,120) or Color3.fromRGB(200,60,60)
    end
    chk("fish",  savedFishPos~=nil)
    chk("npc",   savedNPCPos~=nil)
    chk("sell",  savedSellPos~=nil)
    chk("close", savedClosePos~=nil)
    chk("cast",  savedCastPos~=nil)
    local hz=false; for i=1,4 do if zxcvPos[i] then hz=true end end
    chk("zxcv",  hz)
end)

print("[TF v16] H=an/hien panel | F=bat/tat | Panel nho goc trai")
