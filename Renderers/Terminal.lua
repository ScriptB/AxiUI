-- AxiUI Terminal Renderer v2.0.0 — green-on-black CLI aesthetic, ASCII borders

local Renderer = {}

local UIS     = game:GetService("UserInputService")
local Players = game:GetService("Players")

-- ═══════════════════════════════════════════════════════════════
--  PALETTE
-- ═══════════════════════════════════════════════════════════════
local C = {
    Bg       = Color3.fromRGB(8,   12,  8),
    GbBg     = Color3.fromRGB(10,  16,  10),
    ElemBg   = Color3.fromRGB(12,  20,  12),
    Border   = Color3.fromRGB(30,  80,  30),
    Green    = Color3.fromRGB(0,   220, 80),
    GreenDim = Color3.fromRGB(0,   120, 40),
    GreenMut = Color3.fromRGB(0,   70,  25),
    White    = Color3.fromRGB(200, 240, 200),
    Off      = Color3.fromRGB(60,  100, 60),
}

-- ═══════════════════════════════════════════════════════════════
--  STATE
-- ═══════════════════════════════════════════════════════════════
Renderer._core        = nil
Renderer._connections = {}
Renderer._notifSG     = nil
Renderer._notifHolder = nil
Renderer._popupSG     = nil

-- ═══════════════════════════════════════════════════════════════
--  HELPERS
-- ═══════════════════════════════════════════════════════════════
local function SafeParent(gui)
    local ok = pcall(function()
        if typeof(gethui) == "function" then gui.Parent = gethui()
        else gui.Parent = game:GetService("CoreGui") end
    end)
    if not ok or not gui.Parent then
        local lp = Players.LocalPlayer
        gui.Parent = lp:FindFirstChildOfClass("PlayerGui") or lp.PlayerGui
    end
end

local function TrackR(self, conn)
    table.insert(self._connections, conn)
    return conn
end

local function Box(parent, bg, size, pos)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = bg
    f.BorderColor3     = C.Border
    f.BorderSizePixel  = 1
    if size then f.Size = size end
    if pos  then f.Position = pos end
    f.Parent           = parent
    return f
end

local function MkList(parent, pad, dir)
    local l = Instance.new("UIListLayout")
    l.Padding       = UDim.new(0, pad or 1)
    l.SortOrder     = Enum.SortOrder.LayoutOrder
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.Parent        = parent
    return l
end

local function MkPad(parent, t, b, l, r)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, t or 0)
    p.PaddingBottom = UDim.new(0, b or 0)
    p.PaddingLeft   = UDim.new(0, l or 0)
    p.PaddingRight  = UDim.new(0, r or 0)
    p.Parent        = parent
    return p
end

local function Txt(parent, text, size, color, xAlign)
    local l = Instance.new("TextLabel")
    l.Text               = text or ""
    l.Font               = Enum.Font.Code
    l.TextSize           = size or 11
    l.TextColor3         = color or C.Green
    l.BackgroundTransparency = 1
    l.BorderSizePixel    = 0
    l.TextXAlignment     = xAlign or Enum.TextXAlignment.Left
    l.TextTruncate       = Enum.TextTruncate.AtEnd
    l.Parent             = parent
    return l
end

local function Row(parent, h)
    local f = Box(parent, C.ElemBg, UDim2.new(1, 0, 0, h or 20))
    f.BorderSizePixel = 0
    return f
end

local function MkOverlay(sg, onClose)
    local ov = Instance.new("TextButton")
    ov.Size                  = UDim2.new(1, 0, 1, 0)
    ov.BackgroundTransparency = 1
    ov.Text                  = ""
    ov.ZIndex                = 98
    ov.BorderSizePixel       = 0
    ov.Parent                = sg
    ov.MouseButton1Click:Connect(function()
        ov:Destroy(); if onClose then onClose() end
    end)
    return ov
end

-- ═══════════════════════════════════════════════════════════════
--  POPUP LAYER
-- ═══════════════════════════════════════════════════════════════
function Renderer:_GetPopupSG()
    if self._popupSG and self._popupSG.Parent then return self._popupSG end
    self._popupSG = Instance.new("ScreenGui")
    self._popupSG.Name           = "AxiUITerm_Popups"
    self._popupSG.ResetOnSpawn   = false
    self._popupSG.IgnoreGuiInset = true
    self._popupSG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self._popupSG.DisplayOrder   = 10100
    SafeParent(self._popupSG)
    return self._popupSG
end

-- ═══════════════════════════════════════════════════════════════
--  NOTIFICATION
-- ═══════════════════════════════════════════════════════════════
function Renderer:_EnsureNotifSG()
    if self._notifSG and self._notifSG.Parent then return end
    self._notifSG = Instance.new("ScreenGui")
    self._notifSG.Name           = "AxiUITerm_Notifs"
    self._notifSG.ResetOnSpawn   = false
    self._notifSG.IgnoreGuiInset = true
    self._notifSG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self._notifSG.DisplayOrder   = 10050
    SafeParent(self._notifSG)

    self._notifHolder = Instance.new("Frame")
    self._notifHolder.AnchorPoint           = Vector2.new(1, 1)
    self._notifHolder.Position              = UDim2.new(1, -10, 1, -10)
    self._notifHolder.Size                  = UDim2.fromOffset(260, 0)
    self._notifHolder.AutomaticSize         = Enum.AutomaticSize.Y
    self._notifHolder.BackgroundTransparency = 1
    self._notifHolder.BorderSizePixel       = 0
    self._notifHolder.Parent                = self._notifSG
    MkList(self._notifHolder, 3)
end

function Renderer:Notify(title, message, duration)
    self:_EnsureNotifSG()
    duration = duration or 4

    local card = Box(self._notifHolder, C.GbBg,
        UDim2.new(1, 0, 0, 0))
    card.AutomaticSize  = Enum.AutomaticSize.Y
    card.BorderSizePixel = 1

    local inner = Instance.new("Frame")
    inner.BackgroundTransparency = 1
    inner.BorderSizePixel        = 0
    inner.Size                   = UDim2.new(1, -8, 0, 0)
    inner.Position               = UDim2.fromOffset(4, 2)
    inner.AutomaticSize          = Enum.AutomaticSize.Y
    inner.Parent                 = card
    MkList(inner, 0)

    local t = Txt(inner, "> " .. (title or "INFO"), 11, C.Green)
    t.Size = UDim2.new(1, 0, 0, 14)

    local m = Txt(inner, "  " .. (message or ""), 10, C.GreenDim)
    m.Size         = UDim2.new(1, 0, 0, 0)
    m.AutomaticSize = Enum.AutomaticSize.Y
    m.TextWrapped  = true

    local gap = Instance.new("Frame")
    gap.BackgroundTransparency = 1; gap.BorderSizePixel = 0
    gap.Size = UDim2.new(1, 0, 0, 2); gap.Parent = inner

    task.delay(duration, function() pcall(function() card:Destroy() end) end)
end

-- ═══════════════════════════════════════════════════════════════
--  LIFECYCLE
-- ═══════════════════════════════════════════════════════════════
function Renderer:Init(core)
    self._core = core
end

function Renderer:Unload()
    for _, c in ipairs(self._connections) do pcall(function() c:Disconnect() end) end
    self._connections = {}
    if self._popupSG then pcall(function() self._popupSG:Destroy() end); self._popupSG = nil end
    if self._notifSG then pcall(function() self._notifSG:Destroy() end); self._notifSG = nil end
    self._notifHolder = nil
    for _, win in ipairs((self._core and self._core.Windows) or {}) do
        if win.Gui then pcall(function() win.Gui:Destroy() end); win.Gui = nil end
    end
end

-- ═══════════════════════════════════════════════════════════════
--  WINDOW
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountWindow(window)
    local opts = window.Options or {}
    local w = opts.Width  or 380
    local h = opts.Height or 420

    local gui = Instance.new("ScreenGui")
    gui.Name           = "AxiTerm_" .. (window.Title or "Win"):gsub("%s+", "")
    gui.ResetOnSpawn   = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.DisplayOrder   = 999
    SafeParent(gui)

    local vp = workspace.CurrentCamera.ViewportSize
    local defaultPos = window.Position or UDim2.fromOffset(
        math.floor(vp.X / 2 - w / 2),
        math.floor(vp.Y / 2 - h / 2)
    )

    local frame = Box(gui, C.Bg, UDim2.fromOffset(w, h), defaultPos)
    frame.Name             = "TermWindow"
    frame.ClipsDescendants = true
    window.Gui   = gui
    window.Frame = frame

    -- ASCII title bar
    local bar = Box(frame, C.GbBg, UDim2.new(1, 0, 0, 20))
    bar.BorderSizePixel = 0

    local topBorder = Box(frame, C.Border, UDim2.new(1, 0, 0, 1),
        UDim2.fromOffset(0, 20))
    topBorder.BorderSizePixel = 0

    local titleStr = "[ " .. (window.Title or "AxiUI"):upper() .. " ]"
    local tl = Txt(bar, titleStr, 11, C.Green, Enum.TextXAlignment.Center)
    tl.Size = UDim2.new(1, 0, 1, 0)

    local verStr = "v" .. ((self._core and self._core.Version) or "2")
    local verLbl = Txt(bar, verStr, 9, C.GreenMut, Enum.TextXAlignment.Right)
    verLbl.Size     = UDim2.new(1, -6, 1, 0)
    window.TitleBar = bar

    -- Tab row
    local tabRow = Instance.new("ScrollingFrame")
    tabRow.Size                  = UDim2.new(1, 0, 0, 18)
    tabRow.Position              = UDim2.fromOffset(0, 21)
    tabRow.BackgroundColor3      = C.Bg
    tabRow.BorderColor3          = C.Border
    tabRow.BorderSizePixel       = 1
    tabRow.ScrollBarThickness    = 0
    tabRow.CanvasSize            = UDim2.new(0, 0, 0, 0)
    tabRow.AutomaticCanvasSize   = Enum.AutomaticSize.X
    tabRow.Parent                = frame
    MkList(tabRow, 0, Enum.FillDirection.Horizontal)
    MkPad(tabRow, 0, 0, 2, 2)
    window.TabRow = tabRow

    local tabDiv = Box(frame, C.Border, UDim2.new(1, 0, 0, 1),
        UDim2.fromOffset(0, 39))
    tabDiv.BorderSizePixel = 0

    local contentArea = Instance.new("Frame")
    contentArea.BackgroundTransparency = 1
    contentArea.BorderSizePixel        = 0
    contentArea.Size                   = UDim2.new(1, 0, 1, -40)
    contentArea.Position               = UDim2.fromOffset(0, 40)
    contentArea.Parent                 = frame
    window.ContentArea = contentArea

    -- Drag
    local dragging, dragInput, mousePos, startPos = false, nil, nil, nil
    TrackR(self, bar.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging = true; mousePos = inp.Position; startPos = frame.Position
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end))
    TrackR(self, bar.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement then dragInput = inp end
    end))
    TrackR(self, UIS.InputChanged:Connect(function(inp)
        if inp ~= dragInput or not dragging then return end
        local d = inp.Position - mousePos
        frame.Position = UDim2.fromOffset(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
        window.Position = frame.Position
    end))
end

function Renderer:OnWindowToggled(window)
    if window.Gui then window.Gui.Enabled = window.Visible end
end

-- ═══════════════════════════════════════════════════════════════
--  TAB
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountTab(tab)
    local win = tab.Window

    local btn = Instance.new("TextButton")
    btn.Text             = tab.Name
    btn.Font             = Enum.Font.Code
    btn.TextSize         = 10
    btn.BackgroundColor3 = C.Bg
    btn.TextColor3       = C.Off
    btn.AutoButtonColor  = false
    btn.BorderSizePixel  = 0
    btn.AutomaticSize    = Enum.AutomaticSize.X
    btn.Size             = UDim2.new(0, 0, 1, 0)
    btn.Parent           = win.TabRow
    MkPad(btn, 0, 0, 7, 7)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size                     = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency   = 1
    scroll.BorderSizePixel          = 0
    scroll.ScrollBarThickness       = 2
    scroll.ScrollBarImageColor3     = C.GreenDim
    scroll.CanvasSize               = UDim2.new(0, 0, 0, 0)
    scroll.Visible                  = false
    scroll.Parent                   = win.ContentArea

    local layout = MkList(scroll, 2)
    MkPad(scroll, 4, 4, 4, 4)

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 8)
    end)

    tab.Button = btn
    tab.Scroll = scroll
    btn.MouseButton1Click:Connect(function() win:_SelectTab(tab) end)
end

function Renderer:OnTabSelected(tab)
    local win = tab.Window
    for _, t in ipairs(win.Tabs) do
        t.Button.BackgroundColor3 = C.Bg
        t.Button.TextColor3       = C.Off
        t.Scroll.Visible          = false
    end
    tab.Button.BackgroundColor3 = C.GbBg
    tab.Button.TextColor3       = C.Green
    tab.Scroll.Visible          = true
end

-- ═══════════════════════════════════════════════════════════════
--  GROUPBOX BUILDER
-- ═══════════════════════════════════════════════════════════════
local function BuildGroup(gb, parent)
    local container = Box(parent, C.GbBg,
        UDim2.new(1, 0, 0, 0))
    container.AutomaticSize = Enum.AutomaticSize.Y

    local header = Instance.new("TextButton")
    header.BackgroundColor3 = C.GbBg
    header.BorderColor3     = C.Border
    header.BorderSizePixel  = 1
    header.Size             = UDim2.new(1, 0, 0, 17)
    header.Text             = ""
    header.AutoButtonColor  = false
    header.Parent           = container

    local prefix = Txt(header, "+--[ ", 10, C.GreenMut)
    prefix.Size = UDim2.fromOffset(36, 17)

    local nameL = Txt(header, (gb.Name or ""):upper(), 10, C.Green)
    nameL.Size     = UDim2.new(1, -66, 17/17, 0)
    nameL.Position = UDim2.fromOffset(36, 0)

    local suffix = Txt(header, " ]--", 10, C.GreenMut, Enum.TextXAlignment.Right)
    suffix.Size     = UDim2.fromOffset(30, 17)
    suffix.Position = UDim2.new(1, -30, 0, 0)

    local body = Instance.new("Frame")
    body.BackgroundTransparency = 1
    body.BorderSizePixel        = 0
    body.Size                   = UDim2.new(1, 0, 0, 0)
    body.AutomaticSize          = Enum.AutomaticSize.Y
    body.Position               = UDim2.fromOffset(0, 17)
    body.Parent                 = container
    MkList(body, 1)
    MkPad(body, 2, 2, 3, 3)

    local open = true
    header.MouseButton1Click:Connect(function()
        open = not open
        body.Visible = open
        prefix.Text  = open and "+--[ " or "---[ "
    end)

    gb.Container = container
    gb.Body      = body
end

function Renderer:MountGroupbox(gb) BuildGroup(gb, gb.Tab.Scroll) end
function Renderer:MountSubBox(sb)   BuildGroup(sb, sb.ParentGroupbox.Body) end

-- ═══════════════════════════════════════════════════════════════
--  TOGGLE
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountToggle(toggle)
    local row = Row(toggle.Groupbox.Body)

    local indicator = Txt(row, "[OFF]", 10, C.Off)
    indicator.Size     = UDim2.fromOffset(36, 20)
    indicator.Position = UDim2.fromOffset(2, 0)
    indicator.TextXAlignment = Enum.TextXAlignment.Left

    local lbl = Txt(row, " " .. toggle.Text, 10, C.GreenDim)
    lbl.Size     = UDim2.new(1, -40, 1, 0)
    lbl.Position = UDim2.fromOffset(38, 0)

    local clickBtn = Instance.new("TextButton")
    clickBtn.Size                  = UDim2.new(1, 0, 1, 0)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text                  = ""
    clickBtn.BorderSizePixel       = 0
    clickBtn.Parent                = row
    clickBtn.MouseButton1Click:Connect(function() toggle:Set(not toggle.Value) end)

    toggle.OnStateChanged:Connect(function(val)
        indicator.Text       = val and "[ ON]" or "[OFF]"
        indicator.TextColor3 = val and C.Green or C.Off
        lbl.TextColor3       = val and C.White or C.GreenDim
    end)
end

-- ═══════════════════════════════════════════════════════════════
--  SLIDER
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountSlider(slider)
    local row = Row(slider.Groupbox.Body)

    local lbl = Txt(row, slider.Text, 10, C.GreenDim)
    lbl.Size     = UDim2.new(0.42, 0, 1, 0)
    lbl.Position = UDim2.fromOffset(4, 0)

    local BARW = 72
    local track = Box(row, C.Bg, UDim2.fromOffset(BARW, 8),
        UDim2.new(0.42, 0, 0.5, -4))
    track.BorderSizePixel = 1
    track.BorderColor3    = C.Border

    local fill = Box(track, C.GreenDim, UDim2.fromScale(0, 1))
    fill.BorderSizePixel = 0

    local valLbl = Txt(row, tostring(slider.Value) .. slider.Suffix, 10, C.Green, Enum.TextXAlignment.Right)
    valLbl.Size     = UDim2.fromOffset(40, 20)
    valLbl.Position = UDim2.new(1, -42, 0, 0)

    slider.OnStateChanged:Connect(function(val)
        local pct = (val - slider.Min) / (slider.Max - slider.Min)
        fill.Size   = UDim2.fromScale(pct, 1)
        valLbl.Text = tostring(val) .. slider.Suffix
    end)

    local dragging = false
    local function fromX(x)
        local pct = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        slider:Set(slider.Min + pct * (slider.Max - slider.Min))
    end
    TrackR(self, track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; fromX(inp.Position.X) end
    end))
    TrackR(self, UIS.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then fromX(inp.Position.X) end
    end))
    TrackR(self, UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end))
end

-- ═══════════════════════════════════════════════════════════════
--  BUTTON
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountButton(button)
    local row = Row(button.Groupbox.Body)

    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(1, -8, 1, -4)
    btn.Position         = UDim2.fromOffset(4, 2)
    btn.Text             = "> " .. button.Text
    btn.Font             = Enum.Font.Code
    btn.TextSize         = 10
    btn.TextColor3       = C.Green
    btn.TextXAlignment   = Enum.TextXAlignment.Left
    btn.BackgroundColor3 = C.GbBg
    btn.BorderColor3     = C.Border
    btn.BorderSizePixel  = 1
    btn.AutoButtonColor  = false
    btn.Parent           = row
    MkPad(btn, 0, 0, 6, 0)

    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = C.ElemBg; btn.TextColor3 = C.White end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = C.GbBg;  btn.TextColor3 = C.Green end)
    btn.MouseButton1Click:Connect(function() button:Click() end)
end

-- ═══════════════════════════════════════════════════════════════
--  DROPDOWN
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountDropdown(dropdown)
    local row = Row(dropdown.Groupbox.Body)

    local lbl = Txt(row, dropdown.Text, 10, C.GreenDim)
    lbl.Size     = UDim2.new(0.44, 0, 1, 0)
    lbl.Position = UDim2.fromOffset(4, 0)

    local selBtn = Instance.new("TextButton")
    selBtn.Text             = "[" .. tostring(dropdown.Value) .. "]"
    selBtn.Font             = Enum.Font.Code
    selBtn.TextSize         = 10
    selBtn.TextColor3       = C.Green
    selBtn.TextXAlignment   = Enum.TextXAlignment.Left
    selBtn.BackgroundColor3 = C.GbBg
    selBtn.BorderColor3     = C.Border
    selBtn.BorderSizePixel  = 1
    selBtn.AutoButtonColor  = false
    selBtn.Size             = UDim2.new(0.54, 0, 1, -4)
    selBtn.Position         = UDim2.new(0.44, 0, 0, 2)
    selBtn.Parent           = row
    MkPad(selBtn, 0, 0, 4, 0)

    local popupFrame, overlayBtn
    local open = false

    local function CloseDD()
        if popupFrame then pcall(function() popupFrame:Destroy() end); popupFrame = nil end
        if overlayBtn then pcall(function() overlayBtn:Destroy() end); overlayBtn = nil end
        selBtn.Text = "[" .. tostring(dropdown.Value) .. "]"
        open = false
    end

    local function BuildItems()
        if not popupFrame then return end
        for _, c in ipairs(popupFrame:GetChildren()) do
            if c:IsA("ScrollingFrame") then c:Destroy() end
        end
        local items = dropdown.Items
        local listS = Instance.new("ScrollingFrame")
        listS.BackgroundColor3     = C.GbBg
        listS.BorderColor3         = C.Border
        listS.BorderSizePixel      = 1
        listS.ScrollBarThickness   = 2
        listS.ScrollBarImageColor3 = C.GreenDim
        listS.CanvasSize           = UDim2.new(0, 0, 0, 0)
        listS.AutomaticCanvasSize  = Enum.AutomaticSize.Y
        listS.Size                 = UDim2.new(1, 0, 0, math.min(#items * 18 + 4, 130))
        listS.ZIndex               = 99
        listS.Parent               = popupFrame
        MkList(listS, 0)
        MkPad(listS, 2, 2, 2, 2)
        for _, item in ipairs(items) do
            local b = Instance.new("TextButton")
            b.Text             = (item == dropdown.Value and "> " or "  ") .. tostring(item)
            b.Font             = Enum.Font.Code
            b.TextSize         = 10
            b.TextXAlignment   = Enum.TextXAlignment.Left
            b.TextColor3       = item == dropdown.Value and C.Green or C.GreenDim
            b.BackgroundColor3 = C.GbBg
            b.BorderSizePixel  = 0
            b.AutoButtonColor  = false
            b.Size             = UDim2.new(1, 0, 0, 16)
            b.ZIndex           = 100
            b.Parent           = listS
            MkPad(b, 0, 0, 4, 0)
            b.MouseEnter:Connect(function() b.BackgroundColor3 = C.ElemBg; b.TextColor3 = C.White end)
            b.MouseLeave:Connect(function()
                b.BackgroundColor3 = C.GbBg
                b.TextColor3 = item == dropdown.Value and C.Green or C.GreenDim
            end)
            b.MouseButton1Click:Connect(function() dropdown:Set(item); CloseDD() end)
        end
    end

    local function OpenDD()
        if open then CloseDD(); return end
        open = true
        selBtn.Text = "[" .. tostring(dropdown.Value) .. " ^]"
        local ap = row.AbsolutePosition
        local as = row.AbsoluteSize
        local sg = self:_GetPopupSG()
        overlayBtn = MkOverlay(sg, CloseDD)
        popupFrame = Instance.new("Frame")
        popupFrame.BackgroundTransparency = 1
        popupFrame.BorderSizePixel        = 0
        popupFrame.Size                   = UDim2.fromOffset(as.X, 0)
        popupFrame.AutomaticSize          = Enum.AutomaticSize.Y
        popupFrame.Position               = UDim2.fromOffset(ap.X, ap.Y + as.Y + 1)
        popupFrame.ZIndex                 = 98
        popupFrame.Parent                 = sg
        BuildItems()
    end

    dropdown.OnStateChanged:Connect(function(val) selBtn.Text = "[" .. tostring(val) .. "]" end)
    dropdown.OnItemsChanged:Connect(function() if open then BuildItems() end end)
    selBtn.MouseButton1Click:Connect(OpenDD)
end

-- ═══════════════════════════════════════════════════════════════
--  INPUT
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountInput(input)
    local row = Row(input.Groupbox.Body, 34)

    local prompt = Txt(row, input.Text .. " >", 10, C.GreenMut)
    prompt.Size     = UDim2.new(1, -10, 0, 12)
    prompt.Position = UDim2.fromOffset(4, 1)

    local box = Instance.new("TextBox")
    box.Size              = UDim2.new(1, -10, 0, 16)
    box.Position          = UDim2.fromOffset(5, 15)
    box.Text              = tostring(input.Value)
    box.PlaceholderText   = input.Placeholder or ""
    box.Font              = Enum.Font.Code
    box.TextSize          = 10
    box.TextColor3        = C.White
    box.PlaceholderColor3 = C.Off
    box.BackgroundColor3  = C.Bg
    box.BorderColor3      = C.GreenMut
    box.BorderSizePixel   = 1
    box.TextXAlignment    = Enum.TextXAlignment.Left
    box.ClearTextOnFocus  = false
    box.Parent            = row
    MkPad(box, 0, 0, 4, 0)

    local ignoring = false

    if input.Numeric then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            if ignoring then return end
            local clean = box.Text:match("^-?%d*%.?%d*") or ""
            if clean ~= box.Text then ignoring = true; box.Text = clean; ignoring = false end
        end)
    end

    if not input.Finished then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            if ignoring then return end
            input:Set(box.Text)
        end)
    end

    box.FocusLost:Connect(function() if not ignoring then input:Set(box.Text) end end)

    input.OnStateChanged:Connect(function(val)
        if box.Text ~= tostring(val) then
            ignoring = true; box.Text = tostring(val); ignoring = false
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════
--  KEYBIND
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountKeybind(keybind)
    local row = Row(keybind.Groupbox.Body)

    local lbl = Txt(row, keybind.Text, 10, C.GreenDim)
    lbl.Size     = UDim2.new(0.56, 0, 1, 0)
    lbl.Position = UDim2.fromOffset(4, 0)

    local pill = Instance.new("TextButton")
    pill.Size             = UDim2.fromOffset(68, 16)
    pill.AnchorPoint      = Vector2.new(1, 0.5)
    pill.Position         = UDim2.new(1, -4, 0.5, 0)
    pill.Font             = Enum.Font.Code
    pill.TextSize         = 9
    pill.TextColor3       = C.Green
    pill.Text             = "{" .. (keybind.Value == Enum.KeyCode.Unknown and "---" or keybind.Value.Name) .. "}"
    pill.TextXAlignment   = Enum.TextXAlignment.Center
    pill.BackgroundColor3 = C.GbBg
    pill.BorderColor3     = C.GreenMut
    pill.BorderSizePixel  = 1
    pill.AutoButtonColor  = false
    pill.Parent           = row

    local listening = false
    pill.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        pill.Text       = "{...}"
        pill.TextColor3 = C.Off
        local conn
        conn = TrackR(self, UIS.InputBegan:Connect(function(inp, gpe)
            if gpe then return end
            if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if inp.KeyCode == Enum.KeyCode.Escape then
                listening = false
                pill.TextColor3 = C.Green
                pill.Text = "{" .. (keybind.Value == Enum.KeyCode.Unknown and "---" or keybind.Value.Name) .. "}"
                conn:Disconnect(); return
            end
            keybind:Set(inp.KeyCode)
            listening = false
            conn:Disconnect()
        end))
    end)

    keybind.OnStateChanged:Connect(function(k)
        pill.Text       = "{" .. (k == Enum.KeyCode.Unknown and "---" or k.Name) .. "}"
        pill.TextColor3 = C.Green
    end)
end

-- ═══════════════════════════════════════════════════════════════
--  COLOR PICKER  (hex only)
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountColorPicker(colorPicker)
    local row = Row(colorPicker.Groupbox.Body)

    local prompt = Txt(row, colorPicker.Text .. " > #", 10, C.GreenMut)
    prompt.Size     = UDim2.new(0.5, 0, 1, 0)
    prompt.Position = UDim2.fromOffset(4, 0)

    local swatch = Box(row, colorPicker.Value, UDim2.fromOffset(14, 12),
        UDim2.new(0.5, 0, 0.5, -6))
    swatch.BorderSizePixel = 1
    swatch.BorderColor3    = C.GreenMut

    local hexBox = Instance.new("TextBox")
    hexBox.Size              = UDim2.fromOffset(52, 14)
    hexBox.Position          = UDim2.new(0.5, 16, 0.5, -7)
    hexBox.Text              = ""
    hexBox.PlaceholderText   = "RRGGBB"
    hexBox.Font              = Enum.Font.Code
    hexBox.TextSize          = 9
    hexBox.TextColor3        = C.White
    hexBox.PlaceholderColor3 = C.Off
    hexBox.BackgroundColor3  = C.Bg
    hexBox.BorderColor3      = C.GreenMut
    hexBox.BorderSizePixel   = 1
    hexBox.ClearTextOnFocus  = false
    hexBox.Parent            = row
    MkPad(hexBox, 0, 0, 3, 0)

    local function c2h(c)
        return string.format("%02X%02X%02X",
            math.floor(c.R * 255 + .5),
            math.floor(c.G * 255 + .5),
            math.floor(c.B * 255 + .5))
    end
    hexBox.Text = c2h(colorPicker.Value)

    hexBox.FocusLost:Connect(function()
        local hex = hexBox.Text:match("^#?(%x%x%x%x%x%x)$")
        if not hex then hexBox.Text = c2h(colorPicker.Value); return end
        colorPicker:Set(Color3.new(
            tonumber(hex:sub(1,2),16)/255,
            tonumber(hex:sub(3,4),16)/255,
            tonumber(hex:sub(5,6),16)/255))
    end)

    colorPicker.OnStateChanged:Connect(function(c)
        swatch.BackgroundColor3 = c
        hexBox.Text = c2h(c)
    end)
end

-- ═══════════════════════════════════════════════════════════════
--  LABEL
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountLabel(label)
    local f = Instance.new("Frame")
    f.BackgroundTransparency = 1
    f.BorderSizePixel        = 0
    f.Size                   = UDim2.new(1, 0, 0, 0)
    f.AutomaticSize          = Enum.AutomaticSize.Y
    f.Parent                 = label.Groupbox.Body

    local l = Txt(f, "# " .. label.Text, label.Size or 10,
        label.Color or C.GreenMut,
        label.Align or Enum.TextXAlignment.Left)
    l.Size         = UDim2.new(1, -6, 0, 0)
    l.Position     = UDim2.fromOffset(3, 0)
    l.TextWrapped  = true
    l.AutomaticSize = Enum.AutomaticSize.Y
end

-- ═══════════════════════════════════════════════════════════════
--  DIVIDER
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountDivider(divider)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.BorderSizePixel        = 0
    row.Size                   = UDim2.new(1, 0, 0, 10)
    row.Parent                 = divider.Groupbox.Body

    local l = Txt(row, string.rep("-", 50), 10, C.GreenMut, Enum.TextXAlignment.Center)
    l.Size = UDim2.new(1, 0, 1, 0)
end

return Renderer
