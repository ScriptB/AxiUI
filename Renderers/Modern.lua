--[[
    AxiUI — Modern Renderer v2.0.0
    Sleek translucent glass aesthetic. Full feature set.
    Requires AxiUI_Core to be loaded first.

    Colour themes (within this renderer, zero tree-crawling):
        Renderer:ApplyColorTheme("Ocean")
        Renderer:ApplyColorTheme("Rose")
        -- etc. — see ColorThemes table below.

    Usage:
        local AxiUI    = loadstring(game:HttpGet("...AxiUI_Core.lua"))()
        local Renderer = loadstring(game:HttpGet("...Renderers/AxiUI_Renderer_Modern.lua"))()
        AxiUI:SetRenderer(Renderer)
]]

local Renderer = {}

local TweenSvc = game:GetService("TweenService")
local UIS      = game:GetService("UserInputService")
local Players  = game:GetService("Players")

-- ═══════════════════════════════════════════════════════════════
--  COLOUR PALETTE  (live reference — ApplyColorTheme mutates T)
-- ═══════════════════════════════════════════════════════════════
local T = {
    WindowBg        = Color3.fromRGB(14,  16,  26),   WindowBgAlpha   = 0.82,
    GroupboxBg      = Color3.fromRGB(255, 255, 255),   GroupboxBgAlpha = 0.035,
    SubBoxBg        = Color3.fromRGB(255, 255, 255),   SubBoxBgAlpha   = 0.025,
    ElementBg       = Color3.fromRGB(255, 255, 255),   ElementBgAlpha  = 0.03,
    Accent          = Color3.fromRGB(160, 130, 255),   AccentAlpha     = 0.35,
    AccentStrong    = Color3.fromRGB(200, 185, 255),
    Border          = Color3.fromRGB(255, 255, 255),   BorderAlpha     = 0.08,
    TextPrimary     = Color3.fromRGB(220, 215, 255),
    TextSecondary   = Color3.fromRGB(140, 130, 160),
    TextMuted       = Color3.fromRGB(80,  75,  100),
    RadiusWindow    = UDim.new(0, 12),
    RadiusGroupbox  = UDim.new(0, 8),
    RadiusElement   = UDim.new(0, 6),
    RadiusSubBox    = UDim.new(0, 6),
    RadiusPill      = UDim.new(1, 0),
}

-- ── Colour themes (colour keys only) ────────────────────────────
local ColorThemes = {
    Default = {
        WindowBg = Color3.fromRGB(14,16,26),   WindowBgAlpha = 0.82,
        Accent = Color3.fromRGB(160,130,255),  AccentAlpha = 0.35,
        AccentStrong = Color3.fromRGB(200,185,255),
        TextPrimary = Color3.fromRGB(220,215,255),
        TextSecondary = Color3.fromRGB(140,130,160),
        TextMuted = Color3.fromRGB(80,75,100),
    },
    Ocean = {
        WindowBg = Color3.fromRGB(6,14,22),    WindowBgAlpha = 0.84,
        Accent = Color3.fromRGB(50,200,180),   AccentAlpha = 0.35,
        AccentStrong = Color3.fromRGB(90,230,210),
        TextPrimary = Color3.fromRGB(210,230,235),
        TextSecondary = Color3.fromRGB(100,140,155),
        TextMuted = Color3.fromRGB(55,80,95),
    },
    Rose = {
        WindowBg = Color3.fromRGB(22,10,18),   WindowBgAlpha = 0.84,
        Accent = Color3.fromRGB(255,110,160),  AccentAlpha = 0.38,
        AccentStrong = Color3.fromRGB(255,150,190),
        TextPrimary = Color3.fromRGB(240,220,230),
        TextSecondary = Color3.fromRGB(160,110,140),
        TextMuted = Color3.fromRGB(90,55,80),
    },
    Midnight = {
        WindowBg = Color3.fromRGB(4,8,22),     WindowBgAlpha = 0.86,
        Accent = Color3.fromRGB(115,155,255),  AccentAlpha = 0.38,
        AccentStrong = Color3.fromRGB(160,195,255),
        TextPrimary = Color3.fromRGB(218,228,255),
        TextSecondary = Color3.fromRGB(125,145,200),
        TextMuted = Color3.fromRGB(65,82,130),
    },
    Emerald = {
        WindowBg = Color3.fromRGB(6,14,10),    WindowBgAlpha = 0.84,
        Accent = Color3.fromRGB(48,218,138),   AccentAlpha = 0.35,
        AccentStrong = Color3.fromRGB(88,255,168),
        TextPrimary = Color3.fromRGB(212,240,222),
        TextSecondary = Color3.fromRGB(118,162,138),
        TextMuted = Color3.fromRGB(62,98,78),
    },
    Neon = {
        WindowBg = Color3.fromRGB(8,8,14),     WindowBgAlpha = 0.84,
        Accent = Color3.fromRGB(180,80,255),   AccentAlpha = 0.38,
        AccentStrong = Color3.fromRGB(210,120,255),
        TextPrimary = Color3.fromRGB(230,220,255),
        TextSecondary = Color3.fromRGB(140,120,190),
        TextMuted = Color3.fromRGB(75,60,110),
    },
    Carbon = {
        WindowBg = Color3.fromRGB(12,12,12),   WindowBgAlpha = 0.88,
        Accent = Color3.fromRGB(228,228,228),  AccentAlpha = 0.32,
        AccentStrong = Color3.fromRGB(248,248,250),
        TextPrimary = Color3.fromRGB(235,235,235),
        TextSecondary = Color3.fromRGB(155,155,155),
        TextMuted = Color3.fromRGB(88,88,88),
    },
    Sunset = {
        WindowBg = Color3.fromRGB(22,10,8),    WindowBgAlpha = 0.84,
        Accent = Color3.fromRGB(255,130,60),   AccentAlpha = 0.38,
        AccentStrong = Color3.fromRGB(255,175,100),
        TextPrimary = Color3.fromRGB(255,235,220),
        TextSecondary = Color3.fromRGB(180,130,110),
        TextMuted = Color3.fromRGB(100,65,55),
    },
}

-- Binding table: {inst, prop, themeKey}
-- Every coloured Instance property registers here so ApplyColorTheme
-- can update them without crawling the tree or matching Color3 values.
local _bindings = {}

-- Register a coloured property on an instance.
local function TC(inst, prop, themeKey)
    table.insert(_bindings, { inst, prop, themeKey })
    if T[themeKey] ~= nil then
        pcall(function() inst[prop] = T[themeKey] end)
    end
end

-- ═══════════════════════════════════════════════════════════════
--  RENDERER STATE
-- ═══════════════════════════════════════════════════════════════
Renderer._core        = nil
Renderer._connections = {}  -- renderer-owned RBXScriptConnections
Renderer._popupSG     = nil
Renderer._notifSG     = nil
Renderer._notifHolder = nil

-- ═══════════════════════════════════════════════════════════════
--  COLOUR THEME  (renderer-level, no tree crawling)
-- ═══════════════════════════════════════════════════════════════
function Renderer:GetColorThemeNames()
    local n = {}
    for k in pairs(ColorThemes) do n[#n+1] = k end
    table.sort(n)
    return n
end

function Renderer:ApplyColorTheme(name)
    local theme = ColorThemes[name]
    if not theme then warn("[AxiUI Modern] Unknown colour theme:", name); return end
    for k, v in pairs(theme) do T[k] = v end
    for i = #_bindings, 1, -1 do
        local b = _bindings[i]
        local inst, prop, key = b[1], b[2], b[3]
        if not inst or not inst.Parent then
            table.remove(_bindings, i)
        elseif T[key] ~= nil then
            pcall(function() inst[prop] = T[key] end)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
--  INTERNAL HELPERS
-- ═══════════════════════════════════════════════════════════════
local function Tw(obj, props, t, style)
    TweenSvc:Create(obj,
        TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quart),
        props):Play()
end

local function Corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = radius or T.RadiusElement
    c.Parent = parent
    return c
end

local function Stroke(parent, color, alpha, thickness)
    local s = Instance.new("UIStroke")
    s.Color           = color or T.Border
    s.Transparency    = 1 - (alpha or T.BorderAlpha)
    s.Thickness       = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent          = parent
    return s
end

local function List(parent, pad, dir)
    local l = Instance.new("UIListLayout")
    l.Padding       = UDim.new(0, pad or 4)
    l.SortOrder     = Enum.SortOrder.LayoutOrder
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.Parent        = parent
    return l
end

local function Pad(parent, all, t, b, l, r)
    local p = Instance.new("UIPadding")
    if all then
        p.PaddingTop    = UDim.new(0, all)
        p.PaddingBottom = UDim.new(0, all)
        p.PaddingLeft   = UDim.new(0, all)
        p.PaddingRight  = UDim.new(0, all)
    else
        if t then p.PaddingTop    = UDim.new(0, t) end
        if b then p.PaddingBottom = UDim.new(0, b) end
        if l then p.PaddingLeft   = UDim.new(0, l) end
        if r then p.PaddingRight  = UDim.new(0, r) end
    end
    p.Parent = parent
    return p
end

local function Lbl(parent, text, size, color, xAlign, font)
    local l = Instance.new("TextLabel")
    l.Text                  = text or ""
    l.Font                  = font  or Enum.Font.GothamMedium
    l.TextSize              = size  or 11
    l.TextColor3            = color or T.TextSecondary
    l.BackgroundTransparency = 1
    l.BorderSizePixel       = 0
    l.TextXAlignment        = xAlign or Enum.TextXAlignment.Left
    l.TextTruncate          = Enum.TextTruncate.AtEnd
    l.Parent                = parent
    return l
end

local function Row(parent, height)
    local f = Instance.new("Frame")
    f.BackgroundColor3      = T.ElementBg
    f.BackgroundTransparency = 1 - T.ElementBgAlpha
    f.BorderSizePixel       = 0
    f.Size                  = UDim2.new(1, 0, 0, height or 30)
    f.Parent                = parent
    Corner(f, T.RadiusElement)
    Stroke(f)
    return f
end

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

-- ═══════════════════════════════════════════════════════════════
--  POPUP LAYER
-- ═══════════════════════════════════════════════════════════════
function Renderer:_GetPopupSG()
    if self._popupSG and self._popupSG.Parent then return self._popupSG end
    self._popupSG = Instance.new("ScreenGui")
    self._popupSG.Name           = "AxiUI_Popups"
    self._popupSG.ResetOnSpawn   = false
    self._popupSG.IgnoreGuiInset = true
    self._popupSG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self._popupSG.DisplayOrder   = 10100
    SafeParent(self._popupSG)
    return self._popupSG
end

local function MakeOverlay(sg, onClose)
    local ov = Instance.new("TextButton")
    ov.Size                  = UDim2.new(1, 0, 1, 0)
    ov.BackgroundTransparency = 1
    ov.Text                  = ""
    ov.ZIndex                = 98
    ov.BorderSizePixel       = 0
    ov.Parent                = sg
    ov.MouseButton1Click:Connect(function()
        ov:Destroy()
        if onClose then onClose() end
    end)
    return ov
end

-- ═══════════════════════════════════════════════════════════════
--  COLOUR PICKER POPUP
-- ═══════════════════════════════════════════════════════════════
local function BuildColorPopup(self, anchor, initColor, onChange, onClose)
    local sg = self:_GetPopupSG()
    local h, s, v = initColor:ToHSV()
    local W, SVH, HUEH = 188, 132, 12

    local obj
    local ov = MakeOverlay(sg, function()
        if obj then obj:Destroy() end
    end)

    local ap = anchor.AbsolutePosition
    local as = anchor.AbsoluteSize

    local popup = Instance.new("Frame")
    popup.BackgroundColor3      = T.WindowBg
    popup.BackgroundTransparency = 0.04
    popup.BorderSizePixel       = 0
    popup.Size                  = UDim2.fromOffset(W, SVH + HUEH + 46)
    popup.Position              = UDim2.fromOffset(ap.X, ap.Y + as.Y + 4)
    popup.ZIndex                = 99
    popup.Parent                = sg
    Corner(popup, UDim.new(0, 8))
    Stroke(popup, T.Border, 0.12)
    Pad(popup, 8)
    List(popup, 6)

    -- SV square
    local svBase = Instance.new("Frame")
    svBase.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
    svBase.BorderSizePixel  = 0
    svBase.Size             = UDim2.new(1, 0, 0, SVH)
    svBase.ZIndex           = 100
    svBase.Parent           = popup
    Corner(svBase, UDim.new(0, 4))

    local whiteOv = Instance.new("Frame")
    whiteOv.BackgroundColor3 = Color3.new(1, 1, 1)
    whiteOv.BorderSizePixel  = 0
    whiteOv.Size             = UDim2.new(1, 0, 1, 0)
    whiteOv.ZIndex           = 101
    whiteOv.Parent           = svBase
    Corner(whiteOv, UDim.new(0, 4))
    do
        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new(Color3.new(1, 1, 1))
        g.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        g.Rotation = 0
        g.Parent   = whiteOv
    end

    local blackOv = Instance.new("Frame")
    blackOv.BackgroundColor3 = Color3.new(0, 0, 0)
    blackOv.BorderSizePixel  = 0
    blackOv.Size             = UDim2.new(1, 0, 1, 0)
    blackOv.ZIndex           = 102
    blackOv.Parent           = svBase
    Corner(blackOv, UDim.new(0, 4))
    do
        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new(Color3.new(0, 0, 0))
        g.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        })
        g.Rotation = 90
        g.Parent   = blackOv
    end

    local svKnob = Instance.new("Frame")
    svKnob.BackgroundColor3 = Color3.new(1, 1, 1)
    svKnob.BorderSizePixel  = 0
    svKnob.Size             = UDim2.fromOffset(10, 10)
    svKnob.AnchorPoint      = Vector2.new(0.5, 0.5)
    svKnob.Position         = UDim2.new(s, 0, 1 - v, 0)
    svKnob.ZIndex           = 104
    svKnob.Parent           = svBase
    Corner(svKnob, UDim.new(1, 0))
    Stroke(svKnob, Color3.new(0, 0, 0), 0.25, 1)

    -- Hue bar
    local hueBar = Instance.new("Frame")
    hueBar.BackgroundColor3 = Color3.new(1, 1, 1)
    hueBar.BorderSizePixel  = 0
    hueBar.Size             = UDim2.new(1, 0, 0, HUEH)
    hueBar.ZIndex           = 100
    hueBar.Parent           = popup
    Corner(hueBar, UDim.new(1, 0))
    do
        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 0,   0)),
            ColorSequenceKeypoint.new(1/6, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(2/6, Color3.fromRGB(0,   255, 0)),
            ColorSequenceKeypoint.new(3/6, Color3.fromRGB(0,   255, 255)),
            ColorSequenceKeypoint.new(4/6, Color3.fromRGB(0,   0,   255)),
            ColorSequenceKeypoint.new(5/6, Color3.fromRGB(255, 0,   255)),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 0,   0)),
        })
        g.Parent = hueBar
    end

    local hueKnob = Instance.new("Frame")
    hueKnob.BackgroundColor3 = Color3.new(1, 1, 1)
    hueKnob.BorderSizePixel  = 0
    hueKnob.Size             = UDim2.fromOffset(HUEH, HUEH)
    hueKnob.AnchorPoint      = Vector2.new(0.5, 0.5)
    hueKnob.Position         = UDim2.new(h, 0, 0.5, 0)
    hueKnob.ZIndex           = 101
    hueKnob.Parent           = hueBar
    Corner(hueKnob, UDim.new(1, 0))
    Stroke(hueKnob, Color3.new(0, 0, 0), 0.25, 1)

    -- Hex row
    local hexRow = Instance.new("Frame")
    hexRow.BackgroundTransparency = 1
    hexRow.BorderSizePixel        = 0
    hexRow.Size                   = UDim2.new(1, 0, 0, 22)
    hexRow.ZIndex                 = 100
    hexRow.Parent                 = popup
    List(hexRow, 6, Enum.FillDirection.Horizontal)

    local hexBox = Instance.new("TextBox")
    hexBox.Size              = UDim2.new(1, -32, 1, 0)
    hexBox.Font              = Enum.Font.Code
    hexBox.TextSize          = 10
    hexBox.TextColor3        = T.TextPrimary
    hexBox.PlaceholderColor3 = T.TextMuted
    hexBox.PlaceholderText   = "RRGGBB"
    hexBox.BackgroundColor3  = Color3.fromRGB(255, 255, 255)
    hexBox.BackgroundTransparency = 0.95
    hexBox.BorderSizePixel   = 0
    hexBox.ClearTextOnFocus  = false
    hexBox.ZIndex            = 101
    hexBox.Parent            = hexRow
    Corner(hexBox, UDim.new(0, 4))
    Pad(hexBox, nil, 0, 0, 6, 0)

    local swatch = Instance.new("Frame")
    swatch.BackgroundColor3 = Color3.fromHSV(h, s, v)
    swatch.BorderSizePixel  = 0
    swatch.Size             = UDim2.fromOffset(24, 22)
    swatch.ZIndex           = 101
    swatch.Parent           = hexRow
    Corner(swatch, UDim.new(0, 4))
    Stroke(swatch, T.Border, 0.12)

    local function refreshUI()
        local c = Color3.fromHSV(h, s, v)
        svBase.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svKnob.Position  = UDim2.new(s, 0, 1 - v, 0)
        hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
        swatch.BackgroundColor3 = c
        hexBox.Text = string.format("%02X%02X%02X",
            math.floor(c.R * 255 + .5),
            math.floor(c.G * 255 + .5),
            math.floor(c.B * 255 + .5))
        pcall(onChange, c)
    end

    local svDrag, hueDrag = false, false

    svBase.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        svDrag = true
        s = math.clamp((i.Position.X - svBase.AbsolutePosition.X) / svBase.AbsoluteSize.X, 0, 1)
        v = 1 - math.clamp((i.Position.Y - svBase.AbsolutePosition.Y) / svBase.AbsoluteSize.Y, 0, 1)
        refreshUI()
    end)

    hueBar.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        hueDrag = true
        h = math.clamp((i.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
        refreshUI()
    end)

    local mc = UIS.InputChanged:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if svDrag then
            s = math.clamp((i.Position.X - svBase.AbsolutePosition.X) / svBase.AbsoluteSize.X, 0, 1)
            v = 1 - math.clamp((i.Position.Y - svBase.AbsolutePosition.Y) / svBase.AbsoluteSize.Y, 0, 1)
            refreshUI()
        elseif hueDrag then
            h = math.clamp((i.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
            refreshUI()
        end
    end)

    local me = UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            svDrag = false; hueDrag = false
        end
    end)

    hexBox.FocusLost:Connect(function()
        local hex = hexBox.Text:match("^#?(%x%x%x%x%x%x)$")
        if not hex then return end
        local r2 = tonumber(hex:sub(1, 2), 16) / 255
        local g2 = tonumber(hex:sub(3, 4), 16) / 255
        local b2 = tonumber(hex:sub(5, 6), 16) / 255
        h, s, v = Color3.new(r2, g2, b2):ToHSV()
        refreshUI()
    end)

    refreshUI()

    local _destroyed = false
    obj = {}
    function obj:Destroy()
        if _destroyed then return end
        _destroyed = true
        mc:Disconnect()
        me:Disconnect()
        pcall(function() popup:Destroy() end)
        pcall(function() ov:Destroy() end)
        if onClose then onClose() end
    end
    function obj:SetColor(c)
        h, s, v = c:ToHSV()
        refreshUI()
    end
    return obj
end

-- ═══════════════════════════════════════════════════════════════
--  NOTIFICATION SYSTEM
-- ═══════════════════════════════════════════════════════════════
function Renderer:_EnsureNotifSG()
    if self._notifSG and self._notifSG.Parent then return end
    self._notifSG = Instance.new("ScreenGui")
    self._notifSG.Name           = "AxiUI_Notifs"
    self._notifSG.ResetOnSpawn   = false
    self._notifSG.IgnoreGuiInset = true
    self._notifSG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self._notifSG.DisplayOrder   = 10050
    SafeParent(self._notifSG)

    self._notifHolder = Instance.new("Frame")
    self._notifHolder.AnchorPoint           = Vector2.new(1, 1)
    self._notifHolder.Position              = UDim2.new(1, -12, 1, -12)
    self._notifHolder.Size                  = UDim2.fromOffset(260, 0)
    self._notifHolder.AutomaticSize         = Enum.AutomaticSize.Y
    self._notifHolder.BackgroundTransparency = 1
    self._notifHolder.BorderSizePixel       = 0
    self._notifHolder.Parent                = self._notifSG
    List(self._notifHolder, 5)
end

function Renderer:Notify(title, message, duration)
    self:_EnsureNotifSG()
    duration = duration or 4

    local card = Instance.new("Frame")
    card.BackgroundColor3       = T.WindowBg
    card.BackgroundTransparency = 1 - 0.88
    card.BorderSizePixel        = 0
    card.Size                   = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize          = Enum.AutomaticSize.Y
    card.Parent                 = self._notifHolder
    Corner(card, UDim.new(0, 7))
    local stroke = Stroke(card, T.Accent, 0.22)
    TC(card, "BackgroundColor3", "WindowBg")

    local accentBar = Instance.new("Frame")
    accentBar.BackgroundColor3 = T.AccentStrong
    accentBar.BorderSizePixel  = 0
    accentBar.Size             = UDim2.fromOffset(3, 0)
    accentBar.Position         = UDim2.fromOffset(0, 5)
    accentBar.Parent           = card
    Corner(accentBar, UDim.new(1, 0))
    TC(accentBar, "BackgroundColor3", "AccentStrong")

    local body = Instance.new("Frame")
    body.BackgroundTransparency = 1
    body.BorderSizePixel        = 0
    body.Size                   = UDim2.new(1, -10, 0, 0)
    body.Position               = UDim2.fromOffset(10, 6)
    body.AutomaticSize          = Enum.AutomaticSize.Y
    body.Parent                 = card
    List(body, 2)
    Pad(body, 0, 6, 0, 0)

    local titleL = Lbl(body, title or "Notification", 11, T.AccentStrong,
        Enum.TextXAlignment.Left, Enum.Font.GothamBold)
    titleL.Size = UDim2.new(1, 0, 0, 14)
    TC(titleL, "TextColor3", "AccentStrong")

    local msgL = Lbl(body, message or "", 10, T.TextSecondary)
    msgL.Size         = UDim2.new(1, 0, 0, 0)
    msgL.AutomaticSize = Enum.AutomaticSize.Y
    msgL.TextWrapped  = true
    TC(msgL, "TextColor3", "TextSecondary")

    card:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        accentBar.Size = UDim2.fromOffset(3, math.max(0, card.AbsoluteSize.Y - 10))
    end)

    task.delay(duration, function()
        if not card.Parent then return end
        Tw(card,      { BackgroundTransparency = 1 }, 0.3)
        Tw(stroke,    { Transparency = 1 }, 0.3)
        Tw(accentBar, { BackgroundTransparency = 1 }, 0.3)
        Tw(titleL,    { TextTransparency = 1 }, 0.3)
        Tw(msgL,      { TextTransparency = 1 }, 0.3)
        task.wait(0.32)
        pcall(function() card:Destroy() end)
    end)
end

-- ═══════════════════════════════════════════════════════════════
--  LIFECYCLE
-- ═══════════════════════════════════════════════════════════════
function Renderer:Init(core)
    self._core = core
    -- Clear binding table on re-init (renderer remount clears stale refs)
    _bindings = {}
end

function Renderer:Unload()
    for _, conn in ipairs(self._connections) do
        pcall(function() conn:Disconnect() end)
    end
    self._connections = {}

    if self._popupSG  then pcall(function() self._popupSG:Destroy()  end); self._popupSG  = nil end
    if self._notifSG  then pcall(function() self._notifSG:Destroy()  end); self._notifSG  = nil end
    self._notifHolder = nil

    -- Destroy all window GUIs
    for _, win in ipairs((self._core and self._core.Windows) or {}) do
        if win.Gui then pcall(function() win.Gui:Destroy() end); win.Gui = nil end
    end

    _bindings = {}
end

-- ═══════════════════════════════════════════════════════════════
--  WINDOW
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountWindow(window)
    local opts = window.Options or {}
    local w    = opts.Width  or 420
    local h    = opts.Height or 480

    local gui = Instance.new("ScreenGui")
    gui.Name           = "AxiUI_" .. (window.Title or "Window"):gsub("%s+", "")
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

    local frame = Instance.new("Frame")
    frame.Name                   = "AxiWindow"
    frame.Size                   = UDim2.fromOffset(w, h)
    frame.Position               = defaultPos
    frame.BackgroundColor3       = T.WindowBg
    frame.BackgroundTransparency = 1 - T.WindowBgAlpha
    frame.BorderSizePixel        = 0
    frame.ClipsDescendants       = true
    frame.Parent                 = gui
    Corner(frame, T.RadiusWindow)
    Stroke(frame, T.Border, 0.10, 1)
    TC(frame, "BackgroundColor3", "WindowBg")

    window.Gui   = gui
    window.Frame = frame

    self:_BuildTitleBar(window)
    self:_BuildTabRow(window)
    self:_BuildContentArea(window)
    self:_MakeDraggable(window)
end

function Renderer:_BuildTitleBar(window)
    local bar = Instance.new("Frame")
    bar.Name                   = "TitleBar"
    bar.Size                   = UDim2.new(1, 0, 0, 34)
    bar.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
    bar.BackgroundTransparency = 0.97
    bar.BorderSizePixel        = 0
    bar.Parent                 = window.Frame

    local div = Instance.new("Frame")
    div.Size                   = UDim2.new(1, 0, 0, 1)
    div.Position               = UDim2.new(0, 0, 1, -1)
    div.BackgroundColor3       = T.Border
    div.BackgroundTransparency = 1 - T.BorderAlpha
    div.BorderSizePixel        = 0
    div.Parent                 = bar
    TC(div, "BackgroundColor3", "Border")

    -- macOS dots
    local dotRow = Instance.new("Frame")
    dotRow.Size                   = UDim2.fromOffset(46, 10)
    dotRow.Position               = UDim2.fromOffset(10, 12)
    dotRow.BackgroundTransparency = 1
    dotRow.BorderSizePixel        = 0
    dotRow.Parent                 = bar
    List(dotRow, 5, Enum.FillDirection.Horizontal)
    for _, col in ipairs({
        Color3.fromRGB(255, 95,  87),
        Color3.fromRGB(254, 188, 46),
        Color3.fromRGB(40,  200, 64),
    }) do
        local dot = Instance.new("Frame")
        dot.Size             = UDim2.fromOffset(10, 10)
        dot.BackgroundColor3 = col
        dot.BorderSizePixel  = 0
        dot.Parent           = dotRow
        Corner(dot, UDim.new(1, 0))
    end

    local title = Lbl(bar, window.Title, 12, T.TextPrimary,
        Enum.TextXAlignment.Center, Enum.Font.GothamBold)
    title.Size = UDim2.new(1, 0, 1, 0)
    TC(title, "TextColor3", "TextPrimary")

    local ver = Lbl(bar, "v" .. ((self._core and self._core.Version) or "2"), 9, T.TextMuted,
        Enum.TextXAlignment.Right)
    ver.Size     = UDim2.new(1, -10, 1, 0)
    ver.Position = UDim2.fromOffset(0, 0)
    TC(ver, "TextColor3", "TextMuted")

    window.TitleBar = bar
end

function Renderer:_BuildTabRow(window)
    local row = Instance.new("ScrollingFrame")
    row.Name                   = "TabRow"
    row.Size                   = UDim2.new(1, 0, 0, 30)
    row.Position               = UDim2.fromOffset(0, 34)
    row.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
    row.BackgroundTransparency = 0.975
    row.BorderSizePixel        = 0
    row.ScrollBarThickness     = 0
    row.CanvasSize             = UDim2.new(0, 0, 0, 0)
    row.AutomaticCanvasSize    = Enum.AutomaticSize.X
    row.Parent                 = window.Frame
    List(row, 0, Enum.FillDirection.Horizontal)
    Pad(row, nil, 0, 0, 8, 8)
    window.TabRow = row

    local div = Instance.new("Frame")
    div.Name                   = "TabRowDivider"
    div.Size                   = UDim2.new(1, 0, 0, 1)
    div.Position               = UDim2.new(0, 0, 0, 63)
    div.BackgroundColor3       = T.Border
    div.BackgroundTransparency = 1 - T.BorderAlpha
    div.BorderSizePixel        = 0
    div.Parent                 = window.Frame
    TC(div, "BackgroundColor3", "Border")
end

function Renderer:_BuildContentArea(window)
    local area = Instance.new("Frame")
    area.Name                   = "ContentArea"
    area.Size                   = UDim2.new(1, 0, 1, -64)
    area.Position               = UDim2.fromOffset(0, 64)
    area.BackgroundTransparency = 1
    area.BorderSizePixel        = 0
    area.Parent                 = window.Frame
    window.ContentArea = area
end

function Renderer:_MakeDraggable(window)
    local bar   = window.TitleBar
    local frame = window.Frame
    local dragging  = false
    local dragInput = nil
    local mousePos
    local startPos

    TrackR(self, bar.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1
            and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging = true
        mousePos = inp.Position
        startPos = frame.Position
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end))

    TrackR(self, bar.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch then
            dragInput = inp
        end
    end))

    TrackR(self, UIS.InputChanged:Connect(function(inp)
        if inp ~= dragInput or not dragging then return end
        local delta = inp.Position - mousePos
        local newPos = UDim2.fromOffset(
            startPos.X.Offset + delta.X,
            startPos.Y.Offset + delta.Y
        )
        frame.Position    = newPos
        window.Position   = newPos  -- persist for RemountAll
    end))
end

function Renderer:OnWindowToggled(window)
    if window.Gui then
        window.Gui.Enabled = window.Visible
    end
end

-- ═══════════════════════════════════════════════════════════════
--  TAB
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountTab(tab)
    local win = tab.Window

    local btn = Instance.new("TextButton")
    btn.Text                  = tab.Name
    btn.Font                  = Enum.Font.GothamMedium
    btn.TextSize              = 11
    btn.BackgroundTransparency = 1
    btn.TextColor3            = T.TextMuted
    btn.AutoButtonColor       = false
    btn.BorderSizePixel       = 0
    btn.AutomaticSize         = Enum.AutomaticSize.X
    btn.Size                  = UDim2.new(0, 0, 1, 0)
    btn.Parent                = win.TabRow
    Pad(btn, nil, 0, 0, 10, 10)
    TC(btn, "TextColor3", "TextMuted")

    local line = Instance.new("Frame")
    line.Size                   = UDim2.new(1, -8, 0, 2)
    line.Position               = UDim2.new(0, 4, 1, -2)
    line.BackgroundColor3       = T.Accent
    line.BackgroundTransparency = 1
    line.BorderSizePixel        = 0
    line.Parent                 = btn
    Corner(line, UDim.new(1, 0))
    TC(line, "BackgroundColor3", "Accent")

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size                     = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency   = 1
    scroll.BorderSizePixel          = 0
    scroll.ScrollBarThickness       = 3
    scroll.ScrollBarImageColor3     = T.Accent
    scroll.ScrollBarImageTransparency = 0.55
    scroll.CanvasSize               = UDim2.new(0, 0, 0, 0)
    scroll.Visible                  = false
    scroll.Parent                   = win.ContentArea
    TC(scroll, "ScrollBarImageColor3", "Accent")

    local layout = List(scroll, 8)
    Pad(scroll, 10)

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 20)
    end)

    tab.Button = btn
    tab.Line   = line
    tab.Scroll = scroll

    btn.MouseButton1Click:Connect(function()
        win:_SelectTab(tab)
    end)
end

function Renderer:OnTabSelected(tab)
    local win = tab.Window
    for _, t in ipairs(win.Tabs) do
        Tw(t.Button, { TextColor3 = T.TextMuted }, 0.12)
        Tw(t.Line,   { BackgroundTransparency = 1 }, 0.12)
        t.Scroll.Visible = false
    end
    Tw(tab.Button, { TextColor3 = T.TextPrimary }, 0.12)
    Tw(tab.Line,   { BackgroundTransparency = 0.30 }, 0.12)
    tab.Scroll.Visible = true
end

-- ═══════════════════════════════════════════════════════════════
--  GROUPBOX BUILDER  (shared by MountGroupbox and MountSubBox)
-- ═══════════════════════════════════════════════════════════════
local function BuildGroup(gb, parent, bgColor, bgAlpha, radius, strokeAlpha)
    local container = Instance.new("Frame")
    container.Name                  = "GB_" .. (gb.Name or "")
    container.Size                  = UDim2.new(1, 0, 0, 0)
    container.AutomaticSize         = Enum.AutomaticSize.Y
    container.BackgroundColor3      = bgColor
    container.BackgroundTransparency = 1 - bgAlpha
    container.BorderSizePixel       = 0
    container.Parent                = parent
    Corner(container, radius)
    Stroke(container, T.Border, strokeAlpha or T.BorderAlpha)

    -- Header
    local header = Instance.new("TextButton")
    header.Name                   = "Header"
    header.Size                   = UDim2.new(1, 0, 0, 28)
    header.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
    header.BackgroundTransparency = 0.98
    header.Text                   = ""
    header.AutoButtonColor        = false
    header.BorderSizePixel        = 0
    header.Parent                 = container
    Corner(header, radius)

    -- Square off lower half so body meets header cleanly
    local hdrFill = Instance.new("Frame")
    hdrFill.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
    hdrFill.BackgroundTransparency = 0.98
    hdrFill.BorderSizePixel        = 0
    hdrFill.Size                   = UDim2.new(1, 0, 0.5, 0)
    hdrFill.Position               = UDim2.new(0, 0, 0.5, 0)
    hdrFill.Parent                 = header

    local hdrLbl = Lbl(header, (gb.Name or ""):upper(), 10, T.TextMuted,
        Enum.TextXAlignment.Left, Enum.Font.GothamBold)
    hdrLbl.Size     = UDim2.new(1, -28, 1, 0)
    hdrLbl.Position = UDim2.fromOffset(10, 0)
    TC(hdrLbl, "TextColor3", "TextMuted")

    local chevron = Lbl(header, "−", 13, T.TextMuted, Enum.TextXAlignment.Center)
    chevron.Size     = UDim2.fromOffset(20, 28)
    chevron.Position = UDim2.new(1, -24, 0, 0)
    TC(chevron, "TextColor3", "TextMuted")

    local hdrDiv = Instance.new("Frame")
    hdrDiv.Size                   = UDim2.new(1, 0, 0, 1)
    hdrDiv.Position               = UDim2.new(0, 0, 1, -1)
    hdrDiv.BackgroundColor3       = T.Border
    hdrDiv.BackgroundTransparency = 1 - (strokeAlpha or T.BorderAlpha)
    hdrDiv.BorderSizePixel        = 0
    hdrDiv.Parent                 = header
    TC(hdrDiv, "BackgroundColor3", "Border")

    -- Body
    local body = Instance.new("Frame")
    body.Name                   = "Body"
    body.Size                   = UDim2.new(1, 0, 0, 0)
    body.AutomaticSize          = Enum.AutomaticSize.Y
    body.BackgroundTransparency = 1
    body.BorderSizePixel        = 0
    body.Position               = UDim2.fromOffset(0, 28)
    body.Parent                 = container
    List(body, 4)
    Pad(body, 7)

    local open = true
    header.MouseButton1Click:Connect(function()
        open = not open
        body.Visible = open
        chevron.Text = open and "−" or "+"
    end)

    gb.Container = container
    gb.Body      = body
    gb.Header    = header
end

function Renderer:MountGroupbox(gb)
    BuildGroup(gb, gb.Tab.Scroll,
        T.GroupboxBg, T.GroupboxBgAlpha, T.RadiusGroupbox)
end

function Renderer:MountSubBox(sb)
    BuildGroup(sb, sb.ParentGroupbox.Body,
        T.SubBoxBg, T.SubBoxBgAlpha, T.RadiusSubBox, 0.055)
end

-- ═══════════════════════════════════════════════════════════════
--  TOGGLE
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountToggle(toggle)
    local row = Row(toggle.Groupbox.Body)

    local lFrame = Instance.new("Frame")
    lFrame.BackgroundTransparency = 1
    lFrame.BorderSizePixel        = 0
    lFrame.Size                   = UDim2.new(1, -54, 1, 0)
    lFrame.Position               = UDim2.fromOffset(9, 0)
    lFrame.Parent                 = row
    List(lFrame, 1)

    local lbl = Lbl(lFrame, toggle.Text, 11, T.TextSecondary)
    lbl.Size = UDim2.new(1, 0, 0, 16)
    TC(lbl, "TextColor3", "TextSecondary")

    if toggle.Tooltip then
        local sub = Lbl(lFrame, toggle.Tooltip, 9, T.TextMuted)
        sub.Size = UDim2.new(1, 0, 0, 11)
        TC(sub, "TextColor3", "TextMuted")
    end

    local pill = Instance.new("Frame")
    pill.Size                  = UDim2.fromOffset(32, 17)
    pill.AnchorPoint           = Vector2.new(1, 0.5)
    pill.Position              = UDim2.new(1, -9, 0.5, 0)
    pill.BackgroundColor3      = Color3.fromRGB(60, 55, 80)
    pill.BackgroundTransparency = 0.1
    pill.BorderSizePixel       = 0
    pill.Parent                = row
    Corner(pill, T.RadiusPill)
    Stroke(pill, T.Border, 0.12)

    local thumb = Instance.new("Frame")
    thumb.Size             = UDim2.fromOffset(11, 11)
    thumb.Position         = UDim2.fromOffset(2, 3)
    thumb.BackgroundColor3 = Color3.fromRGB(100, 95, 120)
    thumb.BorderSizePixel  = 0
    thumb.Parent           = pill
    Corner(thumb, T.RadiusPill)

    -- Transparent click layer
    local clickBtn = Instance.new("TextButton")
    clickBtn.Size                  = UDim2.new(1, 0, 1, 0)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text                  = ""
    clickBtn.BorderSizePixel       = 0
    clickBtn.Parent                = row
    clickBtn.MouseButton1Click:Connect(function()
        toggle:Set(not toggle.Value)
    end)
    clickBtn.MouseEnter:Connect(function()
        Tw(row, { BackgroundTransparency = 1 - T.ElementBgAlpha * 2.2 }, 0.1)
    end)
    clickBtn.MouseLeave:Connect(function()
        Tw(row, { BackgroundTransparency = 1 - T.ElementBgAlpha }, 0.1)
    end)

    toggle.OnStateChanged:Connect(function(val)
        if val then
            Tw(pill,  { BackgroundColor3 = T.Accent, BackgroundTransparency = 1 - T.AccentAlpha })
            Tw(thumb, { Position = UDim2.fromOffset(19, 3), BackgroundColor3 = T.AccentStrong })
        else
            Tw(pill,  { BackgroundColor3 = Color3.fromRGB(60, 55, 80), BackgroundTransparency = 0.1 })
            Tw(thumb, { Position = UDim2.fromOffset(2, 3),  BackgroundColor3 = Color3.fromRGB(100, 95, 120) })
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════
--  SLIDER
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountSlider(slider)
    local row = Row(slider.Groupbox.Body)

    local lbl = Lbl(row, slider.Text, 11, T.TextSecondary)
    lbl.Size     = UDim2.new(0.55, -10, 1, 0)
    lbl.Position = UDim2.fromOffset(9, 0)
    TC(lbl, "TextColor3", "TextSecondary")

    local valLbl = Lbl(row, tostring(slider.Value) .. slider.Suffix,
        10, T.Accent, Enum.TextXAlignment.Right)
    valLbl.Size     = UDim2.fromOffset(30, 30)
    valLbl.Position = UDim2.new(1, -38, 0, 0)
    TC(valLbl, "TextColor3", "Accent")

    local track = Instance.new("Frame")
    track.Size                  = UDim2.fromOffset(88, 28)
    track.AnchorPoint           = Vector2.new(1, 0.5)
    track.Position              = UDim2.new(1, -72, 0.5, 0)
    track.BackgroundTransparency = 1
    track.BorderSizePixel       = 0
    track.Parent                = row

    local trackBar = Instance.new("Frame")
    trackBar.Size                  = UDim2.new(1, 0, 0, 3)
    trackBar.AnchorPoint           = Vector2.new(0, 0.5)
    trackBar.Position              = UDim2.new(0, 0, 0.5, 0)
    trackBar.BackgroundColor3      = Color3.fromRGB(50, 45, 70)
    trackBar.BackgroundTransparency = 0.18
    trackBar.BorderSizePixel       = 0
    trackBar.Parent                = track
    Corner(trackBar, UDim.new(1, 0))

    local fill = Instance.new("Frame")
    fill.BackgroundColor3       = T.Accent
    fill.BackgroundTransparency = 1 - 0.62
    fill.BorderSizePixel        = 0
    fill.Size                   = UDim2.fromScale(0, 1)
    fill.Parent                 = trackBar
    Corner(fill, UDim.new(1, 0))
    TC(fill, "BackgroundColor3", "Accent")

    local thumb = Instance.new("Frame")
    thumb.Size             = UDim2.fromOffset(11, 11)
    thumb.AnchorPoint      = Vector2.new(0.5, 0.5)
    thumb.Position         = UDim2.new(0, 0, 0.5, 0)
    thumb.BackgroundColor3 = T.AccentStrong
    thumb.BorderSizePixel  = 0
    thumb.Parent           = track
    Corner(thumb, UDim.new(1, 0))
    Stroke(thumb, T.Border, 0.2)
    TC(thumb, "BackgroundColor3", "AccentStrong")

    -- Visual update via signal
    slider.OnStateChanged:Connect(function(val)
        local pct = (val - slider.Min) / (slider.Max - slider.Min)
        fill.Size      = UDim2.fromScale(pct, 1)
        thumb.Position = UDim2.new(pct, 0, 0.5, 0)
        valLbl.Text    = tostring(val) .. slider.Suffix
    end)

    -- Input
    local dragging = false
    local function fromX(x)
        local pct = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        slider:Set(slider.Min + pct * (slider.Max - slider.Min))
    end

    TrackR(self, track.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; fromX(inp.Position.X)
        end
    end))
    TrackR(self, UIS.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
            fromX(inp.Position.X)
        end
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
    btn.Size                  = UDim2.new(1, -16, 1, -8)
    btn.Position              = UDim2.fromOffset(8, 4)
    btn.Font                  = Enum.Font.GothamMedium
    btn.TextSize              = 11
    btn.TextColor3            = T.TextSecondary
    btn.Text                  = button.Text
    btn.BackgroundColor3      = Color3.fromRGB(255, 255, 255)
    btn.BackgroundTransparency = 0.945
    btn.BorderSizePixel       = 0
    btn.AutoButtonColor       = false
    btn.Parent                = row
    Corner(btn, UDim.new(0, 5))
    Stroke(btn, T.Border, 0.09)
    TC(btn, "TextColor3", "TextSecondary")

    btn.MouseEnter:Connect(function()
        Tw(btn, { BackgroundTransparency = 0.88, TextColor3 = T.TextPrimary }, 0.1)
    end)
    btn.MouseLeave:Connect(function()
        Tw(btn, { BackgroundTransparency = 0.945, TextColor3 = T.TextSecondary }, 0.1)
    end)
    btn.MouseButton1Click:Connect(function()
        button:Click()
    end)
end

-- ═══════════════════════════════════════════════════════════════
--  DROPDOWN
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountDropdown(dropdown)
    local row = Row(dropdown.Groupbox.Body)

    local lbl = Lbl(row, dropdown.Text, 11, T.TextSecondary)
    lbl.Size     = UDim2.new(0.48, 0, 1, 0)
    lbl.Position = UDim2.fromOffset(9, 0)
    TC(lbl, "TextColor3", "TextSecondary")

    local selLbl = Lbl(row, tostring(dropdown.Value), 10, T.Accent, Enum.TextXAlignment.Right)
    selLbl.Size     = UDim2.new(0.44, 0, 1, 0)
    selLbl.Position = UDim2.new(0.5, 0, 0, 0)
    TC(selLbl, "TextColor3", "Accent")

    local chevLbl = Lbl(row, "▾", 11, T.TextMuted, Enum.TextXAlignment.Center)
    chevLbl.Size     = UDim2.fromOffset(16, 30)
    chevLbl.Position = UDim2.new(1, -18, 0, 0)
    TC(chevLbl, "TextColor3", "TextMuted")

    local popupFrame, overlayBtn
    local open = false

    local function CloseDD()
        if popupFrame then pcall(function() popupFrame:Destroy() end); popupFrame = nil end
        if overlayBtn then pcall(function() overlayBtn:Destroy() end); overlayBtn = nil end
        chevLbl.Text = "▾"
        open = false
    end

    local function BuildItems()
        if not popupFrame then return end
        local listScroll = popupFrame:FindFirstChildOfClass("ScrollingFrame")
        if listScroll then listScroll:Destroy() end

        local items = dropdown.Items
        listScroll = Instance.new("ScrollingFrame")
        listScroll.BackgroundTransparency = 1
        listScroll.BorderSizePixel        = 0
        listScroll.ScrollBarThickness     = 2
        listScroll.ScrollBarImageColor3   = T.Accent
        listScroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
        listScroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
        listScroll.Size = UDim2.new(1, 0, 0, math.min(#items * 26 + 8, 160))
        listScroll.ZIndex = 100
        listScroll.Parent = popupFrame
        List(listScroll, 2)
        Pad(listScroll, 4)

        for _, item in ipairs(items) do
            local iBtn = Instance.new("TextButton")
            iBtn.Text                  = tostring(item)
            iBtn.Font                  = Enum.Font.GothamMedium
            iBtn.TextSize              = 10
            iBtn.TextColor3            = item == dropdown.Value and T.AccentStrong or T.TextSecondary
            iBtn.TextXAlignment        = Enum.TextXAlignment.Left
            iBtn.BackgroundTransparency = 1
            iBtn.BorderSizePixel       = 0
            iBtn.Size                  = UDim2.new(1, 0, 0, 24)
            iBtn.ZIndex                = 101
            iBtn.Parent                = listScroll
            Pad(iBtn, nil, 0, 0, 8, 0)
            iBtn.MouseEnter:Connect(function() Tw(iBtn, { TextColor3 = T.AccentStrong }, 0.1) end)
            iBtn.MouseLeave:Connect(function()
                Tw(iBtn, { TextColor3 = item == dropdown.Value and T.AccentStrong or T.TextSecondary }, 0.1)
            end)
            iBtn.MouseButton1Click:Connect(function()
                dropdown:Set(item)
                CloseDD()
            end)
        end
    end

    local function OpenDD()
        if open then CloseDD(); return end
        open = true
        chevLbl.Text = "▴"
        local ap = row.AbsolutePosition
        local as = row.AbsoluteSize
        local sg = self:_GetPopupSG()

        overlayBtn = MakeOverlay(sg, CloseDD)

        popupFrame = Instance.new("Frame")
        popupFrame.BackgroundColor3      = T.WindowBg
        popupFrame.BackgroundTransparency = 0.04
        popupFrame.BorderSizePixel       = 0
        popupFrame.Size                  = UDim2.fromOffset(as.X, 0)
        popupFrame.AutomaticSize         = Enum.AutomaticSize.Y
        popupFrame.Position              = UDim2.fromOffset(ap.X, ap.Y + as.Y + 2)
        popupFrame.ZIndex                = 99
        popupFrame.Parent                = sg
        Corner(popupFrame, UDim.new(0, 6))
        Stroke(popupFrame, T.Border, 0.12)

        BuildItems()
    end

    -- Update label on state change
    dropdown.OnStateChanged:Connect(function(val)
        selLbl.Text = tostring(val)
    end)

    -- Rebuild list if items change while open
    dropdown.OnItemsChanged:Connect(function()
        if open then BuildItems() end
    end)

    local clickBtn = Instance.new("TextButton")
    clickBtn.Size                  = UDim2.new(1, 0, 1, 0)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text                  = ""
    clickBtn.BorderSizePixel       = 0
    clickBtn.Parent                = row
    clickBtn.MouseButton1Click:Connect(OpenDD)
end

-- ═══════════════════════════════════════════════════════════════
--  INPUT
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountInput(input)
    local row = Row(input.Groupbox.Body, 44)

    local lbl = Lbl(row, input.Text, 11, T.TextSecondary)
    lbl.Size     = UDim2.new(1, -16, 0, 16)
    lbl.Position = UDim2.fromOffset(9, 4)
    TC(lbl, "TextColor3", "TextSecondary")

    local box = Instance.new("TextBox")
    box.Size              = UDim2.new(1, -18, 0, 18)
    box.Position          = UDim2.fromOffset(9, 21)
    box.Text              = tostring(input.Value)
    box.PlaceholderText   = input.Placeholder
    box.Font              = Enum.Font.GothamMedium
    box.TextSize          = 10
    box.TextColor3        = T.TextPrimary
    box.PlaceholderColor3 = T.TextMuted
    box.BackgroundColor3  = Color3.fromRGB(255, 255, 255)
    box.BackgroundTransparency = 0.955
    box.BorderSizePixel   = 0
    box.TextXAlignment    = Enum.TextXAlignment.Left
    box.ClearTextOnFocus  = false
    box.Parent            = row
    Corner(box, UDim.new(0, 4))
    Stroke(box, T.Border, 0.12)
    Pad(box, nil, 0, 0, 6, 0)
    TC(box, "TextColor3", "TextPrimary")
    TC(box, "PlaceholderColor3", "TextMuted")

    local ignoring = false

    if input.Numeric then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            if ignoring then return end
            local clean = box.Text:match("^-?%d*%.?%d*") or ""
            if clean ~= box.Text then
                ignoring = true; box.Text = clean; ignoring = false
            end
        end)
    end

    if not input.Finished then
        box:GetPropertyChangedSignal("Text"):Connect(function()
            if ignoring then return end
            input:Set(box.Text)
        end)
    end

    box.FocusLost:Connect(function(enter)
        if not ignoring then input:Set(box.Text) end
        if input.Finished and enter then
            -- Callback already fired by Set above via signal
        end
    end)

    -- Respond to external Set() calls
    input.OnStateChanged:Connect(function(val)
        if box.Text ~= tostring(val) then
            ignoring = true
            box.Text = tostring(val)
            ignoring = false
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════
--  KEYBIND
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountKeybind(keybind)
    local row = Row(keybind.Groupbox.Body)

    local lbl = Lbl(row, keybind.Text, 11, T.TextSecondary)
    lbl.Size     = UDim2.new(0.58, 0, 1, 0)
    lbl.Position = UDim2.fromOffset(9, 0)
    TC(lbl, "TextColor3", "TextSecondary")

    local pill = Instance.new("TextButton")
    pill.Size                  = UDim2.fromOffset(54, 18)
    pill.AnchorPoint           = Vector2.new(1, 0.5)
    pill.Position              = UDim2.new(1, -9, 0.5, 0)
    pill.Font                  = Enum.Font.GothamMedium
    pill.TextSize              = 9
    pill.TextColor3            = T.Accent
    pill.Text                  = keybind.Value == Enum.KeyCode.Unknown and "None" or keybind.Value.Name
    pill.BackgroundColor3      = Color3.fromRGB(50, 45, 70)
    pill.BackgroundTransparency = 0.2
    pill.BorderSizePixel       = 0
    pill.AutoButtonColor       = false
    pill.Parent                = row
    Corner(pill, UDim.new(0, 4))
    Stroke(pill, T.Accent, 0.42)
    TC(pill, "TextColor3", "Accent")

    local listening = false
    pill.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        pill.Text       = "..."
        pill.TextColor3 = T.TextMuted
        local conn
        conn = TrackR(self, UIS.InputBegan:Connect(function(inp, gpe)
            if gpe then return end
            if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if inp.KeyCode == Enum.KeyCode.Escape then
                listening = false
                pill.TextColor3 = T.Accent
                pill.Text = keybind.Value == Enum.KeyCode.Unknown and "None" or keybind.Value.Name
                conn:Disconnect(); return
            end
            keybind:Set(inp.KeyCode)
            listening = false
            conn:Disconnect()
        end))
    end)

    keybind.OnStateChanged:Connect(function(k)
        pill.Text       = k == Enum.KeyCode.Unknown and "None" or k.Name
        pill.TextColor3 = T.Accent
    end)
end

-- ═══════════════════════════════════════════════════════════════
--  COLOR PICKER
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountColorPicker(colorPicker)
    local row = Row(colorPicker.Groupbox.Body)

    local lbl = Lbl(row, colorPicker.Text, 11, T.TextSecondary)
    lbl.Size     = UDim2.new(1, -54, 1, 0)
    lbl.Position = UDim2.fromOffset(9, 0)
    TC(lbl, "TextColor3", "TextSecondary")

    local swatch = Instance.new("TextButton")
    swatch.Size             = UDim2.fromOffset(38, 20)
    swatch.AnchorPoint      = Vector2.new(1, 0.5)
    swatch.Position         = UDim2.new(1, -9, 0.5, 0)
    swatch.BackgroundColor3 = colorPicker.Value
    swatch.Text             = ""
    swatch.AutoButtonColor  = false
    swatch.BorderSizePixel  = 0
    swatch.Parent           = row
    Corner(swatch, UDim.new(0, 4))
    Stroke(swatch, T.Border, 0.14)

    local popup = nil
    swatch.MouseButton1Click:Connect(function()
        if popup then popup:Destroy(); popup = nil; return end
        popup = BuildColorPopup(self, swatch, colorPicker.Value,
            function(c)
                colorPicker:Set(c)
            end,
            function()
                popup = nil
            end
        )
    end)

    colorPicker.OnStateChanged:Connect(function(c)
        swatch.BackgroundColor3 = c
        if popup then popup:SetColor(c) end
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

    local l = Lbl(f, label.Text, label.Size or 10,
        label.Color or T.TextMuted,
        label.Align or Enum.TextXAlignment.Left)
    l.Size         = UDim2.new(1, -16, 0, 0)
    l.Position     = UDim2.fromOffset(8, 0)
    l.TextWrapped  = true
    l.AutomaticSize = Enum.AutomaticSize.Y
    if not label.Color then TC(l, "TextColor3", "TextMuted") end
end

-- ═══════════════════════════════════════════════════════════════
--  DIVIDER
-- ═══════════════════════════════════════════════════════════════
function Renderer:MountDivider(divider)
    local d = Instance.new("Frame")
    d.BackgroundColor3      = T.Border
    d.BackgroundTransparency = 1 - T.BorderAlpha
    d.BorderSizePixel        = 0
    d.Size                   = UDim2.new(1, -16, 0, 1)
    d.Position               = UDim2.fromOffset(8, 0)
    d.Parent                 = divider.Groupbox.Body
    TC(d, "BackgroundColor3", "Border")
end

return Renderer
