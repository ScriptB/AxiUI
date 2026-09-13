--[[
    AxiUI — Core v2.0.0 (Universal)
    Pure state machine. Zero visual output. Renderer-agnostic.

    Load order:
        local AxiUI = loadstring(game:HttpGet("...AxiUI_Core.lua"))()
        local Renderer = loadstring(game:HttpGet("...Renderers/AxiUI_Renderer_Modern.lua"))()
        AxiUI:SetRenderer(Renderer)

    Optional extras:
        loadstring(game:HttpGet("...AxiUI_ThemeManager.lua"))()
        loadstring(game:HttpGet("...AxiUI_Binder.lua"))()
]]

local AxiUI       = {}
AxiUI.__index     = AxiUI
AxiUI.Version     = "2.0.0"
AxiUI.Windows     = {}
AxiUI.Flags       = {}
AxiUI.Connections = {}
AxiUI.Renderer    = nil

local UIS     = game:GetService("UserInputService")
local HttpSvc = game:GetService("HttpService")

-- ═══════════════════════════════════════════════════════════════
--  SIGNAL
--  Deactivated listeners are pruned lazily on next Fire().
-- ═══════════════════════════════════════════════════════════════
local function CreateSignal()
    local sig = { _listeners = {} }

    function sig:Connect(fn)
        local entry = { fn = fn, active = true }
        table.insert(self._listeners, entry)
        return {
            Disconnect = function()
                entry.active = false
            end,
        }
    end

    function sig:Fire(...)
        local args = { ... }
        local i = 1
        while i <= #self._listeners do
            local e = self._listeners[i]
            if not e.active then
                table.remove(self._listeners, i)
            else
                task.spawn(e.fn, table.unpack(args))
                i = i + 1
            end
        end
    end

    function sig:DisconnectAll()
        for _, e in ipairs(self._listeners) do
            e.active = false
        end
        self._listeners = {}
    end

    return sig
end

-- ═══════════════════════════════════════════════════════════════
--  INTERNAL HELPERS
-- ═══════════════════════════════════════════════════════════════
local function TrackConn(conn)
    table.insert(AxiUI.Connections, conn)
    return conn
end

-- ═══════════════════════════════════════════════════════════════
--  RENDERER MANAGEMENT
-- ═══════════════════════════════════════════════════════════════
function AxiUI:SetRenderer(renderer)
    self.Renderer = renderer
    if renderer and renderer.Init then
        renderer:Init(self)
    end
end

-- Called by ThemeManager to swap the entire visual layer without
-- destroying the virtual DOM or losing flag values.
function AxiUI:RemountAll(newRenderer)
    self.Renderer = newRenderer
    if newRenderer and newRenderer.Init then
        newRenderer:Init(self)
    end
    for _, win in ipairs(self.Windows) do
        if newRenderer and newRenderer.MountWindow then
            newRenderer:MountWindow(win)
        end
        for _, tab in ipairs(win.Tabs) do
            if newRenderer and newRenderer.MountTab then
                newRenderer:MountTab(tab)
            end
            for _, gb in ipairs(tab.Groupboxes) do
                self:_RemountGroupbox(newRenderer, gb)
            end
        end
        if win.ActiveTab and newRenderer and newRenderer.OnTabSelected then
            newRenderer:OnTabSelected(win.ActiveTab)
        end
    end
end

function AxiUI:_RemountGroupbox(renderer, gb)
    if not renderer then return end
    local mountFn = (gb.Type == "SubBox") and renderer.MountSubBox or renderer.MountGroupbox
    if mountFn then mountFn(renderer, gb) end
    for _, el in ipairs(gb.Elements) do
        if el.Type == "SubBox" then
            self:_RemountGroupbox(renderer, el)
        else
            local fn = renderer["Mount" .. (el.Type or "")]
            if fn then
                fn(renderer, el)
                -- Restore current visual state via the signal
                if el.Set then el:Set(el.Value, true) end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
--  WINDOW
-- ═══════════════════════════════════════════════════════════════
local Window = {}
Window.__index = Window

function AxiUI:CreateWindow(options)
    options = options or {}

    local win         = setmetatable({}, Window)
    win.Type          = "Window"
    win.Title         = options.Title    or "AxiUI"
    win.Options       = options
    win.Tabs          = {}
    win.ActiveTab     = nil
    win.Visible       = true
    win.Position      = options.Position -- stored/updated by renderer on drag

    local key = options.ToggleKey or Enum.KeyCode.RightShift
    TrackConn(UIS.InputBegan:Connect(function(inp, gpe)
        if gpe or inp.KeyCode ~= key then return end
        win.Visible = not win.Visible
        local r = AxiUI.Renderer
        if r and r.OnWindowToggled then r:OnWindowToggled(win) end
    end))

    table.insert(AxiUI.Windows, win)

    local r = AxiUI.Renderer
    if r and r.MountWindow then r:MountWindow(win) end

    return win
end

-- ═══════════════════════════════════════════════════════════════
--  TAB
-- ═══════════════════════════════════════════════════════════════
local Tab = {}
Tab.__index = Tab

function Window:AddTab(name)
    local tab      = setmetatable({}, Tab)
    tab.Type       = "Tab"
    tab.Name       = name
    tab.Window     = self
    tab.Groupboxes = {}

    table.insert(self.Tabs, tab)

    local r = AxiUI.Renderer
    if r and r.MountTab then r:MountTab(tab) end

    if #self.Tabs == 1 then self:_SelectTab(tab) end
    return tab
end

function Window:_SelectTab(tab)
    self.ActiveTab = tab
    local r = AxiUI.Renderer
    if r and r.OnTabSelected then r:OnTabSelected(tab) end
end

-- ═══════════════════════════════════════════════════════════════
--  GROUPBOX
-- ═══════════════════════════════════════════════════════════════
local Groupbox = {}
Groupbox.__index = Groupbox

function Tab:AddGroupbox(name, options)
    options = options or {}

    local gb      = setmetatable({}, Groupbox)
    gb.Type       = "Groupbox"
    gb.Name       = name or ""
    gb.Tab        = self
    gb.Elements   = {}
    gb.Options    = options

    table.insert(self.Groupboxes, gb)

    local r = AxiUI.Renderer
    if r and r.MountGroupbox then r:MountGroupbox(gb) end

    return gb
end

function Groupbox:AddSubBox(name)
    local sb             = setmetatable({}, Groupbox)
    sb.Type              = "SubBox"
    sb.Name              = name or ""
    sb.ParentGroupbox    = self
    sb.Tab               = self.Tab
    sb.Elements          = {}

    table.insert(self.Elements, sb)

    local r = AxiUI.Renderer
    if r and r.MountSubBox then r:MountSubBox(sb) end

    return sb
end

-- ═══════════════════════════════════════════════════════════════
--  ELEMENTS
--  Pattern for all stateful elements:
--    1. Build the data object with Value, OnStateChanged, Set()
--    2. Register in Flags
--    3. Call renderer mount (renderer connects OnStateChanged)
--    4. Call Set(def, true) — fires signal so renderer sets initial visual
-- ═══════════════════════════════════════════════════════════════

-- ── TOGGLE ─────────────────────────────────────────────────────
function Groupbox:AddToggle(key, opts)
    opts = opts or {}
    local def = opts.Default == true

    local el = {
        Type           = "Toggle",
        Key            = key,
        Text           = opts.Text    or key,
        Tooltip        = opts.Tooltip,
        Value          = def,
        OnStateChanged = CreateSignal(),
        Groupbox       = self,
    }

    function el:Set(val, silent)
        val = val == true
        self.Value = val
        AxiUI.Flags[key] = val
        self.OnStateChanged:Fire(val)
        if not silent and opts.Callback then pcall(opts.Callback, val) end
    end

    AxiUI.Flags[key]           = def
    AxiUI.Flags[key .. "_obj"] = el
    table.insert(self.Elements, el)

    local r = AxiUI.Renderer
    if r and r.MountToggle then r:MountToggle(el) end
    el:Set(def, true)

    return el
end

-- ── SLIDER ──────────────────────────────────────────────────────
function Groupbox:AddSlider(key, opts)
    opts = opts or {}
    local min = opts.Min or 0
    local max = opts.Max or 100
    local def = math.clamp(opts.Default or min, min, max)

    local el = {
        Type           = "Slider",
        Key            = key,
        Text           = opts.Text    or key,
        Min            = min,
        Max            = max,
        Rounding       = opts.Rounding ~= false,
        Suffix         = opts.Suffix  or "",
        Value          = def,
        OnStateChanged = CreateSignal(),
        Groupbox       = self,
    }

    function el:Set(val, silent)
        if self.Rounding then val = math.round(val) end
        val = math.clamp(val, self.Min, self.Max)
        self.Value = val
        AxiUI.Flags[key] = val
        self.OnStateChanged:Fire(val)
        if not silent and opts.Callback then pcall(opts.Callback, val) end
    end

    AxiUI.Flags[key]           = def
    AxiUI.Flags[key .. "_obj"] = el
    table.insert(self.Elements, el)

    local r = AxiUI.Renderer
    if r and r.MountSlider then r:MountSlider(el) end
    el:Set(def, true)

    return el
end

-- ── BUTTON ──────────────────────────────────────────────────────
function Groupbox:AddButton(opts)
    opts = type(opts) == "string" and { Text = opts } or (opts or {})

    local el = {
        Type     = "Button",
        Text     = opts.Text or "Button",
        Groupbox = self,
    }

    function el:Click()
        if opts.Callback then pcall(opts.Callback) end
    end

    table.insert(self.Elements, el)

    local r = AxiUI.Renderer
    if r and r.MountButton then r:MountButton(el) end

    return el
end

-- ── DROPDOWN ────────────────────────────────────────────────────
function Groupbox:AddDropdown(key, opts)
    opts = opts or {}
    local items = opts.Items   or {}
    local def   = opts.Default or items[1] or ""

    local el = {
        Type           = "Dropdown",
        Key            = key,
        Text           = opts.Text or key,
        Items          = items,
        Value          = def,
        OnStateChanged = CreateSignal(),
        OnItemsChanged = CreateSignal(),
        Groupbox       = self,
    }

    function el:Set(val, silent)
        self.Value = val
        AxiUI.Flags[key] = val
        self.OnStateChanged:Fire(val)
        if not silent and opts.Callback then pcall(opts.Callback, val) end
    end

    function el:SetItems(newItems)
        self.Items = newItems
        self.OnItemsChanged:Fire(newItems)
        self:Set(newItems[1] or "")
    end

    AxiUI.Flags[key]           = def
    AxiUI.Flags[key .. "_obj"] = el
    table.insert(self.Elements, el)

    local r = AxiUI.Renderer
    if r and r.MountDropdown then r:MountDropdown(el) end
    el:Set(def, true)

    return el
end

-- ── INPUT ───────────────────────────────────────────────────────
function Groupbox:AddInput(key, opts)
    opts = opts or {}
    local def = opts.Default or ""

    local el = {
        Type           = "Input",
        Key            = key,
        Text           = opts.Text        or key,
        Placeholder    = opts.Placeholder or "...",
        Numeric        = opts.Numeric     == true,
        Finished       = opts.Finished    == true,
        Value          = def,
        OnStateChanged = CreateSignal(),
        Groupbox       = self,
    }

    function el:Set(val, silent)
        self.Value = tostring(val)
        AxiUI.Flags[key] = self.Value
        self.OnStateChanged:Fire(self.Value)
        if not silent and opts.Callback then pcall(opts.Callback, self.Value) end
    end

    AxiUI.Flags[key]           = def
    AxiUI.Flags[key .. "_obj"] = el
    table.insert(self.Elements, el)

    local r = AxiUI.Renderer
    if r and r.MountInput then r:MountInput(el) end
    el:Set(def, true)

    return el
end

-- ── KEYBIND ─────────────────────────────────────────────────────
function Groupbox:AddKeybind(key, opts)
    opts = opts or {}
    local def = opts.Default or Enum.KeyCode.Unknown

    local el = {
        Type           = "Keybind",
        Key            = key,
        Text           = opts.Text or key,
        Value          = def,
        OnStateChanged = CreateSignal(),
        Groupbox       = self,
    }

    function el:Set(newKey, silent)
        self.Value = newKey
        AxiUI.Flags[key] = newKey
        self.OnStateChanged:Fire(newKey)
        if not silent and opts.Callback then pcall(opts.Callback, newKey) end
    end

    function el:Get()
        return AxiUI.Flags[key]
    end

    AxiUI.Flags[key]           = def
    AxiUI.Flags[key .. "_obj"] = el
    table.insert(self.Elements, el)

    local r = AxiUI.Renderer
    if r and r.MountKeybind then r:MountKeybind(el) end
    el:Set(def, true)

    return el
end

-- ── COLOR PICKER ────────────────────────────────────────────────
function Groupbox:AddColorPicker(key, opts)
    opts = opts or {}
    local def = opts.Default or Color3.fromRGB(255, 255, 255)

    local el = {
        Type           = "ColorPicker",
        Key            = key,
        Text           = opts.Text or key,
        Value          = def,
        OnStateChanged = CreateSignal(),
        Groupbox       = self,
    }

    function el:Set(c, silent)
        self.Value = c
        AxiUI.Flags[key] = c
        self.OnStateChanged:Fire(c)
        if not silent and opts.Callback then pcall(opts.Callback, c) end
    end

    AxiUI.Flags[key]           = def
    AxiUI.Flags[key .. "_obj"] = el
    table.insert(self.Elements, el)

    local r = AxiUI.Renderer
    if r and r.MountColorPicker then r:MountColorPicker(el) end
    el:Set(def, true)

    return el
end

-- ── LABEL ───────────────────────────────────────────────────────
function Groupbox:AddLabel(text, opts)
    opts = opts or {}

    local el = {
        Type     = "Label",
        Text     = text,
        Size     = opts.Size  or 10,
        Color    = opts.Color,
        Align    = opts.Align or Enum.TextXAlignment.Left,
        Groupbox = self,
    }

    table.insert(self.Elements, el)

    local r = AxiUI.Renderer
    if r and r.MountLabel then r:MountLabel(el) end

    return el
end

-- ── DIVIDER ─────────────────────────────────────────────────────
function Groupbox:AddDivider()
    local el = {
        Type     = "Divider",
        Groupbox = self,
    }

    table.insert(self.Elements, el)

    local r = AxiUI.Renderer
    if r and r.MountDivider then r:MountDivider(el) end

    return el
end

-- ═══════════════════════════════════════════════════════════════
--  NOTIFY — delegates to renderer
-- ═══════════════════════════════════════════════════════════════
function AxiUI:Notify(title, message, duration)
    local r = AxiUI.Renderer
    if r and r.Notify then
        r:Notify(title, message, duration)
    end
end

-- ═══════════════════════════════════════════════════════════════
--  CONFIG  SAVE / LOAD
-- ═══════════════════════════════════════════════════════════════
function AxiUI:SaveConfig(name)
    local data = {}
    for k, v in pairs(self.Flags) do
        if not k:find("_obj$") then
            local t = type(v)
            if t == "boolean" or t == "number" or t == "string" then
                data[k] = v
            elseif typeof(v) == "EnumItem" then
                data[k] = { __enum = tostring(v) }
            elseif typeof(v) == "Color3" then
                data[k] = { __col = true, r = v.R, g = v.G, b = v.B }
            end
        end
    end
    local ok, err = pcall(writefile, "axiui_" .. name .. ".json", HttpSvc:JSONEncode(data))
    if not ok then warn("[AxiUI] SaveConfig failed:", err) end
end

function AxiUI:LoadConfig(name)
    if not (typeof(isfile) == "function" and isfile("axiui_" .. name .. ".json")) then
        return false
    end
    local ok, raw = pcall(readfile, "axiui_" .. name .. ".json")
    if not ok then return false end
    local ok2, data = pcall(function() return HttpSvc:JSONDecode(raw) end)
    if not ok2 then return false end
    for k, v in pairs(data) do
        local obj = self.Flags[k .. "_obj"]
        if obj and obj.Set then
            if type(v) == "table" and v.__col then
                pcall(obj.Set, obj, Color3.new(v.r, v.g, v.b))
            elseif type(v) == "table" and v.__enum then
                local parts = v.__enum:split(".")
                pcall(function()
                    pcall(obj.Set, obj, (Enum :: any)[parts[2]][parts[3]])
                end)
            else
                pcall(obj.Set, obj, v)
            end
        end
    end
    return true
end

-- ═══════════════════════════════════════════════════════════════
--  UNLOAD
-- ═══════════════════════════════════════════════════════════════
function AxiUI:Unload()
    for _, conn in ipairs(self.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    if self.Renderer and self.Renderer.Unload then
        pcall(self.Renderer.Unload, self.Renderer)
    end
    for _, win in ipairs(self.Windows) do
        for _, tab in ipairs(win.Tabs) do
            for _, gb in ipairs(tab.Groupboxes) do
                for _, el in ipairs(gb.Elements) do
                    if el.OnStateChanged then el.OnStateChanged:DisconnectAll() end
                    if el.OnItemsChanged then el.OnItemsChanged:DisconnectAll() end
                end
            end
        end
    end
    self.Windows     = {}
    self.Flags       = {}
    self.Connections = {}
    self.Renderer    = nil
    if self.OnUnload then pcall(self.OnUnload) end
end

-- ═══════════════════════════════════════════════════════════════
--  GLOBAL PUBLISH
-- ═══════════════════════════════════════════════════════════════
pcall(function()
    local _genv = typeof(getgenv) == "function" and getgenv() or _G
    _genv.AxiUI = AxiUI
end)

return AxiUI
