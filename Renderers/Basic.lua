-- AxiUI Basic Renderer v2.0.0 — flat, zero-transparency, high-performance

local Renderer = {}

local UIS     = game:GetService("UserInputService")
local Players = game:GetService("Players")

-- ═══════════════════════════════════════════════════════════════
--  PALETTE
-- ═══════════════════════════════════════════════════════════════
local C = {
    WindowBg    = Color3.fromRGB(30,  30,  30),
    GroupboxBg  = Color3.fromRGB(38,  38,  38),
    ElementBg   = Color3.fromRGB(45,  45,  45),
    Accent      = Color3.fromRGB(100, 180, 255),
    AccentOff   = Color3.fromRGB(55,  55,  75),
    Border      = Color3.fromRGB(60,  60,  60),
    TextOn      = Color3.fromRGB(230, 230, 230),
    TextOff     = Color3.fromRGB(150, 150, 150),
    TextLabel   = Color3.fromRGB(180, 180, 180),
    ThumbOn     = Color3.fromRGB(255, 255, 255),
    ThumbOff    = Color3.fromRGB(100, 100, 100),
}

-- ═══════════════════════════════════════════════════════════════
--  RENDERER STATE
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
        if typeof(gethui) == "function" then
            gui.Parent = gethui()
        else
            gui.Parent = game:GetService("CoreGui")
        end
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

local function MkFrame(parent, bg, size, pos, border)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = bg
    f.BorderColor3     = border or C.Border
    f.BorderSizePixel  = 1
    if size then f.Size = size end
    if pos  then f.Position = pos end
    f.Parent           = parent
    return f
end

local function MkList(parent, pad, dir)
    local l = Instance.new("UIListLayout")
    l.Padding       = UDim.new(0, pad or 2)
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

local function MkLabel(parent, text, size, color, xAlign)
    local l = Instance.new("TextLabel")
    l.Text               = text or ""
    l.Font               = Enum.Font.Code
    l.TextSize           = size or 11
    l.TextColor3         = color or C.TextLabel
    l.BackgroundTransparency = 1
    l.BorderSizePixel    = 0
    l.TextXAlignment     = xAlign or Enum.TextXAlignment.Left
    l.TextTruncate       = Enum.TextTruncate.AtEnd
    l.Parent             = parent
    return l
end

local function MkRow(parent, h)
    return MkFrame(parent, C.ElementBg, UDim2.new(1, 0, 0, h or 24))
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
--  POPUP LAYER (reused for dropdowns)
-- ═══════════════════════════════════════════════════════════════
function Renderer:_GetPopupSG()
    if self._popupSG and self._popupSG.Parent then return self._popupSG end
    self._popupSG = Instance.new("ScreenGui")
    self._popupSG.Name           = "AxiUIBasic_Popups"
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
    self._notifSG.Name           = "AxiUIBasic_Notifs"
    self._notifSG.ResetOnSpawn   = false
    self._notifSG.IgnoreGuiInset = true
    self._notifSG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self._notifSG.DisplayOrder   = 10050
    SafeParent(self._notifSG)

    self._notifHolder = Instance.new("Frame")
    self._notifHolder.AnchorPoint           = Vector2.new(1, 1)
    self._notifHolder.Position              = UDim2.new(1, -10, 1, -10)
    self._notifHolder.Size                  = UDim2.fromOffset(240, 0)
    self._notifHolder.AutomaticSize         = Enum.AutomaticSize.Y
    self._notifHolder.BackgroundTransparency = 1
    self._notifHolder.BorderSizePixel       = 0
    self._notifHolder.Parent                = self._notifSG
    MkList(self._notifHolder, 3)
end

function Renderer:Notify(title, message, duration)
    self:_EnsureNotifSG()
    duration = duration or 4

    local card = MkFrame(self._notifHolder, C.GroupboxBg,
        UDim2.new(1, 0, 0, 0))
    card.AutomaticSize = Enum.AutomaticSize.Y

    local body = Instance.new("Frame")
    body.BackgroundTransparency = 1
    body.BorderSizePixel        = 0
    body.Size                   = UDim2.new(1, -8, 0, 0)
    body.Position               = UDim2.fromOffset(4, 3)
    body.AutomaticSize          = Enum.AutomaticSize.Y
    body.Parent                 = card
    MkList(body, 1)

    local t = MkLabel(body, "[ " .. (title or "Info") .. " ]", 11, C.Accent)
    t.Size = UDim2.new(1, 0, 0, 14)

    local m = MkLabel(body, message or "", 10, C.TextLabel)
    m.Size         = UDim2.new(1, 0, 0, 0)
    m.AutomaticSize = Enum.AutomaticSize.Y
    m.TextWrapped  = true

    local spacer = Instance.new("Frame")
    spacer.BackgroundTransparency = 1
    spacer.BorderSizePixel        = 0
    spacer.Size                   = UDim2.new(1, 0, 0, 3)
    spacer.Parent                 = body

    task.delay(duration, function()
        pcall(function() card:Destroy() end)
    end)
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
    if self._popupSG  then pcall(function() self._popupSG:Destroy()  end); self._popupSG  = nil end
    if self._notifSG  then pcall(function() self._notifSG:Destroy()  end); self._notifSG  = nil end
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
    local w = opts.Width  or 360
    local h = opts.Height or 400

    local gui = Instance.new("ScreenGui")
    gui.Name           = "AxiUIB_" .. (window.Title or "Win"):gsub("%s+", "")
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

    local frame = MkFrame(gui, C.WindowBg, UDim2.fromOffset(w, h), defaultPos)
    frame.Name             = "AxiBasicWindow"
    frame.ClipsDescendants = true
    window.Gui   = gui
    window.Frame = frame

    -- Title bar
    local bar = MkFrame(frame, C.GroupboxBg, UDim2.new(1, 0, 0, 22))
    bar.Name = "TitleBar"
    local tl = MkLabel(bar, (window.Title or "AxiUI"):upper(), 11, C.TextOn, Enum.TextXAlignment.Center)
    tl.Size = UDim2.new(1, 0, 1, 0)
    window.TitleBar = bar

    -- Tab row
    local tabRow = Instance.new("ScrollingFrame")
    tabRow.Size                  = UDim2.new(1, 0, 0, 20)
    tabRow.Position              = UDim2.fromOffset(0, 22)
    tabRow.BackgroundColor3      = C.WindowBg
    tabRow.BorderColor3          = C.Border
    tabRow.BorderSizePixel       = 1
    tabRow.ScrollBarThickness    = 0
    tabRow.CanvasSize            = UDim2.new(0, 0, 0, 0)
    tabRow.AutomaticCanvasSize   = Enum.AutomaticSize.X
    tabRow.Parent                = frame
    MkList(tabRow, 0, Enum.FillDirection.Horizontal)
    MkPad(tabRow, 0, 0, 4, 4)
    window.TabRow = tabRow

    local div = MkFrame(frame, C.Border, UDim2.new(1, 0, 0, 1),
        UDim2.fromOffset(0, 41))
    div.BorderSizePixel = 0

    local contentArea = Instance.new("Frame")
    contentArea.BackgroundTransparency = 1
    contentArea.BorderSizePixel        = 0
    contentArea.Size                   = UDim2.new(1, 0, 1, -42)
    contentArea.Position               = UDim2.fromOffset(0, 42)
    contentArea.Parent                 = frame
    window.ContentArea = contentArea

    -- Drag
    local dragging, dragInput, mousePos, startPos = false, nil, nil, nil
    TrackR(self, bar.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        dragging = true
        mousePos = inp.Position
        startPos = frame.Position
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
    btn.Text                  = tab.Name
    btn.Font                  = Enum.Font.Code
    btn.TextSize              = 10
    btn.BackgroundColor3      = C.WindowBg
    btn.TextColor3            = C.TextOff
    btn.AutoButtonColor       = false
    btn.BorderColor3          = C.Border
    btn.BorderSizePixel       = 0
    btn.AutomaticSize         = Enum.AutomaticSize.X
    btn.Size                  = UDim2.new(0, 0, 1, 0)
    btn.Parent                = win.TabRow
    MkPad(btn, 0, 0, 8, 8)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size                     = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency   = 1
    scroll.BorderSizePixel          = 0
    scroll.ScrollBarThickness       = 3
    scroll.ScrollBarImageColor3     = C.Accent
    scroll.CanvasSize               = UDim2.new(0, 0, 0, 0)
    scroll.Visible                  = false
    scroll.Parent                   = win.ContentArea

    local layout = MkList(scroll, 3)
    MkPad(scroll, 5, 5, 5, 5)

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 10)
    end)

    tab.Button = btn
    tab.Scroll = scroll
    btn.MouseButton1Click:Connect(function() win:_SelectTab(tab) end)
end

function Renderer:OnTabSelected(tab)
    local win = tab.Window
    for _, t in ipairs(win.Tabs) do
        t.Button.BackgroundColor3 = C.WindowBg
        t.Button.TextColor3       = C.TextOff
        t.Scroll.Visible          = false
    end
    tab.Button.BackgroundColor3 = C.GroupboxBg
    tab.Button.TextColor3       = C.TextOn
    tab.Scroll.Visible          = true
end

-- ═══════════════════════════════════════════════════════════════
--  GROUPBOX BUILDER
-- ═══════════════════════════════════════════════════════════════
local function BuildGroup(gb, parent)
    local container = Instance.new("Frame")
    container.BackgroundColor3 = C.GroupboxBg
    container.BorderColor3     = C.Border
    container.BorderSizePixel  = 1
    container.Size             = UDim2.new(1, 0, 0, 0)
    container.AutomaticSize    = Enum.AutomaticSize.Y
    container.Parent           = parent

    local header = Instance.new("TextButton")
    header.BackgroundColor3 = C.GroupboxBg
    header.BorderSizePixel  = 0
    header.Size             = UDim2.new(1, 0, 0, 18)
    header.Text             = ""
    header.AutoButtonColor  = false
    header.Parent           = container

    local hLbl = MkLabel(header, "  " .. (gb.Name or ""):upper(), 10, C.Accent)
    hLbl.Size = UDim2.new(1, -22, 1, 0)

    local chevron = MkLabel(header, "[-]", 10, C.TextOff, Enum.TextXAlignment.Right)
    chevron.Size     = UDim2.fromOffset(22, 18)
    chevron.Position = UDim2.new(1, -22, 0, 0)

    local hDiv = MkFrame(container, C.Border, UDim2.new(1, 0, 0, 1),
        UDim2.fromOffset(0, 18))
    hDiv.BorderSizePixel = 0

    local body = Instance.new("Frame")
    body.BackgroundTransparency = 1
    body.BorderSizePixel        = 0
    body.Size                   = UDim2.new(1, 0, 0, 0)
    body.AutomaticSize          = Enum.AutomaticSize.Y
    body.Position               = UDim2.fromOffset(0, 19)
    body.Parent                 = container
    MkList(body, 2)
    MkPad(body, 3, 3, 4, 4)

    local open = true
    header.MouseButton1Click:Connect(function()
        open = not open
        body.Visible  = open
        chevron.Text  = open and "[-]" or "[+]"
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
    local row = MkRow(toggle.Groupbox.Body)

    local lbl = MkLabel(row, toggle.Text, 10, C.TextLabel)
    lbl.Size     = UDim2.new(1, -52, 1, 0)
    lbl.Position = UDim2.fromOffset(5, 0)

    local indicator = MkFrame(row, C.AccentOff, UDim2.fromOffset(38, 14),
        UDim2.new(1, -44, 0.5, -7))

    local thumb = MkFrame(indicator, C.ThumbOff, UDim2.fromOffset(12, 12),
        UDim2.fromOffset(1, 1))
    thumb.BorderSizePixel = 0

    local clickBtn = Instance.new("TextButton")
    clickBtn.Size                  = UDim2.new(1, 0, 1, 0)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text                  = ""
    clickBtn.BorderSizePixel       = 0
    clickBtn.Parent                = row
    clickBtn.MouseButton1Click:Connect(function() toggle:Set(not toggle.Value) end)

    toggle.OnStateChanged:Connect(function(val)
        indicator.BackgroundColor3 = val and C.Accent or C.AccentOff
        thumb.BackgroundColor3     = val and C.ThumbOn or C.ThumbOff
        thumb.Position             = val and UDim2.fromOffset(25, 1) or UDim2.fromOffset(1, 1)
    end)
end

-- ═══════════════════════════════════════════════════════════════
--  SLIDER
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountSlider(slider)
    local row = MkRow(slider.Groupbox.Body)

    local lbl = MkLabel(row, slider.Text, 10, C.TextLabel)
    lbl.Size     = UDim2.new(0.5, 0, 1, 0)
    lbl.Position = UDim2.fromOffset(5, 0)

    local valLbl = MkLabel(row, tostring(slider.Value) .. slider.Suffix, 10, C.Accent,
        Enum.TextXAlignment.Right)
    valLbl.Size     = UDim2.fromOffset(34, 24)
    valLbl.Position = UDim2.new(1, -36, 0, 0)

    local track = MkFrame(row, C.WindowBg, UDim2.fromOffset(80, 8),
        UDim2.new(0.5, 0, 0.5, -4))
    track.BorderSizePixel = 0

    local fill = MkFrame(track, C.Accent, UDim2.fromScale(0, 1))
    fill.BorderSizePixel = 0

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
    local row = MkRow(button.Groupbox.Body)

    local btn = Instance.new("TextButton")
    btn.Size            = UDim2.new(1, -8, 1, -4)
    btn.Position        = UDim2.fromOffset(4, 2)
    btn.Text            = button.Text
    btn.Font            = Enum.Font.Code
    btn.TextSize        = 10
    btn.TextColor3      = C.TextOn
    btn.BackgroundColor3 = C.ElementBg
    btn.BorderColor3    = C.Border
    btn.BorderSizePixel = 1
    btn.AutoButtonColor = false
    btn.Parent          = row

    btn.MouseEnter:Connect(function() btn.BackgroundColor3 = C.AccentOff end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3 = C.ElementBg end)
    btn.MouseButton1Click:Connect(function() button:Click() end)
end

-- ═══════════════════════════════════════════════════════════════
--  DROPDOWN
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountDropdown(dropdown)
    local row = MkRow(dropdown.Groupbox.Body)

    local lbl = MkLabel(row, dropdown.Text, 10, C.TextLabel)
    lbl.Size     = UDim2.new(0.46, 0, 1, 0)
    lbl.Position = UDim2.fromOffset(5, 0)

    local selBtn = Instance.new("TextButton")
    selBtn.Size            = UDim2.new(0.52, 0, 1, -4)
    selBtn.Position        = UDim2.new(0.46, 0, 0, 2)
    selBtn.Font            = Enum.Font.Code
    selBtn.TextSize        = 10
    selBtn.TextColor3      = C.Accent
    selBtn.Text            = tostring(dropdown.Value) .. " ▾"
    selBtn.BackgroundColor3 = C.WindowBg
    selBtn.BorderColor3    = C.Border
    selBtn.BorderSizePixel = 1
    selBtn.AutoButtonColor = false
    selBtn.Parent          = row

    local popupFrame, overlayBtn
    local open = false

    local function CloseDD()
        if popupFrame then pcall(function() popupFrame:Destroy() end); popupFrame = nil end
        if overlayBtn then pcall(function() overlayBtn:Destroy() end); overlayBtn = nil end
        selBtn.Text = tostring(dropdown.Value) .. " ▾"
        open = false
    end

    local function BuildItems()
        if not popupFrame then return end
        for _, c in ipairs(popupFrame:GetChildren()) do
            if c:IsA("ScrollingFrame") then c:Destroy() end
        end
        local items = dropdown.Items
        local listS = Instance.new("ScrollingFrame")
        listS.BackgroundColor3      = C.GroupboxBg
        listS.BorderColor3          = C.Border
        listS.BorderSizePixel       = 1
        listS.ScrollBarThickness    = 2
        listS.ScrollBarImageColor3  = C.Accent
        listS.CanvasSize            = UDim2.new(0, 0, 0, 0)
        listS.AutomaticCanvasSize   = Enum.AutomaticSize.Y
        listS.Size                  = UDim2.new(1, 0, 0, math.min(#items * 20 + 6, 140))
        listS.ZIndex                = 99
        listS.Parent                = popupFrame
        MkList(listS, 1)
        MkPad(listS, 2, 2, 2, 2)
        for _, item in ipairs(items) do
            local b = Instance.new("TextButton")
            b.Text            = tostring(item)
            b.Font            = Enum.Font.Code
            b.TextSize        = 10
            b.TextXAlignment  = Enum.TextXAlignment.Left
            b.TextColor3      = item == dropdown.Value and C.Accent or C.TextLabel
            b.BackgroundColor3 = C.GroupboxBg
            b.BorderSizePixel = 0
            b.AutoButtonColor = false
            b.Size            = UDim2.new(1, 0, 0, 18)
            b.ZIndex          = 100
            b.Parent          = listS
            MkPad(b, 0, 0, 5, 0)
            b.MouseEnter:Connect(function() b.BackgroundColor3 = C.ElementBg end)
            b.MouseLeave:Connect(function() b.BackgroundColor3 = C.GroupboxBg end)
            b.MouseButton1Click:Connect(function() dropdown:Set(item); CloseDD() end)
        end
    end

    local function OpenDD()
        if open then CloseDD(); return end
        open = true
        selBtn.Text = tostring(dropdown.Value) .. " ▴"
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

    dropdown.OnStateChanged:Connect(function(val) selBtn.Text = tostring(val) .. " ▾" end)
    dropdown.OnItemsChanged:Connect(function() if open then BuildItems() end end)
    selBtn.MouseButton1Click:Connect(OpenDD)
end

-- ═══════════════════════════════════════════════════════════════
--  INPUT
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountInput(input)
    local row = MkRow(input.Groupbox.Body, 36)

    local lbl = MkLabel(row, input.Text, 10, C.TextLabel)
    lbl.Size     = UDim2.new(1, -10, 0, 12)
    lbl.Position = UDim2.fromOffset(5, 2)

    local box = Instance.new("TextBox")
    box.Size              = UDim2.new(1, -10, 0, 16)
    box.Position          = UDim2.fromOffset(5, 16)
    box.Text              = tostring(input.Value)
    box.PlaceholderText   = input.Placeholder or ""
    box.Font              = Enum.Font.Code
    box.TextSize          = 10
    box.TextColor3        = C.TextOn
    box.PlaceholderColor3 = C.TextOff
    box.BackgroundColor3  = C.WindowBg
    box.BorderColor3      = C.Border
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
    local row = MkRow(keybind.Groupbox.Body)

    local lbl = MkLabel(row, keybind.Text, 10, C.TextLabel)
    lbl.Size     = UDim2.new(0.58, 0, 1, 0)
    lbl.Position = UDim2.fromOffset(5, 0)

    local pill = Instance.new("TextButton")
    pill.Size             = UDim2.fromOffset(62, 16)
    pill.AnchorPoint      = Vector2.new(1, 0.5)
    pill.Position         = UDim2.new(1, -4, 0.5, 0)
    pill.Font             = Enum.Font.Code
    pill.TextSize         = 9
    pill.TextColor3       = C.Accent
    pill.Text             = keybind.Value == Enum.KeyCode.Unknown and "[None]" or ("[" .. keybind.Value.Name .. "]")
    pill.BackgroundColor3 = C.WindowBg
    pill.BorderColor3     = C.Accent
    pill.BorderSizePixel  = 1
    pill.AutoButtonColor  = false
    pill.Parent           = row

    local listening = false
    pill.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        pill.Text      = "[...]"
        pill.TextColor3 = C.TextOff
        local conn
        conn = TrackR(self, UIS.InputBegan:Connect(function(inp, gpe)
            if gpe then return end
            if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if inp.KeyCode == Enum.KeyCode.Escape then
                listening = false
                pill.TextColor3 = C.Accent
                pill.Text = keybind.Value == Enum.KeyCode.Unknown and "[None]" or ("[" .. keybind.Value.Name .. "]")
                conn:Disconnect(); return
            end
            keybind:Set(inp.KeyCode)
            listening = false
            conn:Disconnect()
        end))
    end)

    keybind.OnStateChanged:Connect(function(k)
        pill.Text       = k == Enum.KeyCode.Unknown and "[None]" or ("[" .. k.Name .. "]")
        pill.TextColor3 = C.Accent
    end)
end

-- ═══════════════════════════════════════════════════════════════
--  COLOR PICKER  (hex-input only — no HSV picker popup)
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountColorPicker(colorPicker)
    local row = MkRow(colorPicker.Groupbox.Body)

    local lbl = MkLabel(row, colorPicker.Text, 10, C.TextLabel)
    lbl.Size     = UDim2.new(0.48, 0, 1, 0)
    lbl.Position = UDim2.fromOffset(5, 0)

    local swatch = MkFrame(row, colorPicker.Value, UDim2.fromOffset(20, 14),
        UDim2.new(0.5, 0, 0.5, -7))
    swatch.BorderSizePixel = 1

    local hexBox = Instance.new("TextBox")
    hexBox.Size              = UDim2.fromOffset(52, 14)
    hexBox.Position          = UDim2.new(0.5, 22, 0.5, -7)
    hexBox.Text              = ""
    hexBox.PlaceholderText   = "RRGGBB"
    hexBox.Font              = Enum.Font.Code
    hexBox.TextSize          = 9
    hexBox.TextColor3        = C.TextOn
    hexBox.PlaceholderColor3 = C.TextOff
    hexBox.BackgroundColor3  = C.WindowBg
    hexBox.BorderColor3      = C.Border
    hexBox.BorderSizePixel   = 1
    hexBox.ClearTextOnFocus  = false
    hexBox.Parent            = row
    MkPad(hexBox, 0, 0, 3, 0)

    local function colorToHex(c)
        return string.format("%02X%02X%02X",
            math.floor(c.R * 255 + .5),
            math.floor(c.G * 255 + .5),
            math.floor(c.B * 255 + .5))
    end

    hexBox.Text = colorToHex(colorPicker.Value)

    hexBox.FocusLost:Connect(function()
        local hex = hexBox.Text:match("^#?(%x%x%x%x%x%x)$")
        if not hex then hexBox.Text = colorToHex(colorPicker.Value); return end
        local c = Color3.new(
            tonumber(hex:sub(1,2),16)/255,
            tonumber(hex:sub(3,4),16)/255,
            tonumber(hex:sub(5,6),16)/255)
        colorPicker:Set(c)
    end)

    colorPicker.OnStateChanged:Connect(function(c)
        swatch.BackgroundColor3 = c
        hexBox.Text = colorToHex(c)
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

    local l = MkLabel(f, label.Text, label.Size or 10,
        label.Color or C.TextLabel,
        label.Align or Enum.TextXAlignment.Left)
    l.Size         = UDim2.new(1, -8, 0, 0)
    l.Position     = UDim2.fromOffset(4, 0)
    l.TextWrapped  = true
    l.AutomaticSize = Enum.AutomaticSize.Y
end

-- ═══════════════════════════════════════════════════════════════
--  DIVIDER
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountDivider(divider)
    local d = MkFrame(divider.Groupbox.Body, C.Border,
        UDim2.new(1, -8, 0, 1), UDim2.fromOffset(4, 0))
    d.BorderSizePixel = 0
end

return Renderer
