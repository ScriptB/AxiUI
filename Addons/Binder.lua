--[[
    AxiUI — Binder v2.0.0
    Maps AxiUI Core logic onto developer-built Studio GUI instances.
    No renderer required. No window/tab hierarchy required.

    Usage:
        local AxiUI  = loadstring(game:HttpGet("...AxiUI_Core.lua"))()
        local Binder = loadstring(game:HttpGet("...AxiUI_Binder.lua"))()

        -- Bind a Studio TextButton to a toggle flag:
        local toggleObj = Binder:BindToggle(myFrame, "SilentAim", {
            Default = false,
            OnStateChange = function(guiElement, isEnabled)
                -- animate your own GUI here
                myFrame.BackgroundColor3 = isEnabled and Color3.fromRGB(0,200,80)
                    or Color3.fromRGB(60,55,80)
            end,
            Callback = function(v) print("SilentAim:", v) end,
        })

        -- External Set (also works via config load):
        toggleObj:Set(true)

    All Bind functions return an object with a Set() method and register the
    flag in AxiUI.Flags so SaveConfig / LoadConfig work transparently.
]]

local _env  = (typeof(getgenv) == "function" and getgenv()) or _G
local AxiUI = _env.AxiUI
assert(AxiUI, "[AxiUI Binder] AxiUI Core must be loaded before Binder.")

local UIS = game:GetService("UserInputService")

local Binder = {}

-- ═══════════════════════════════════════════════════════════════
--  INTERNAL HELPERS
-- ═══════════════════════════════════════════════════════════════
local function findButton(gui)
    if gui:IsA("GuiButton") then return gui end
    return gui:FindFirstChildWhichIsA("GuiButton", true)
end

local function findTextBox(gui)
    if gui:IsA("TextBox") then return gui end
    return gui:FindFirstChildWhichIsA("TextBox", true)
end

-- ═══════════════════════════════════════════════════════════════
--  TOGGLE
-- ═══════════════════════════════════════════════════════════════
function Binder:BindToggle(guiElement, key, opts)
    opts = opts or {}
    local def = opts.Default == true
    local val = def

    local obj = {}

    function obj:Set(newVal, silent)
        newVal = newVal == true
        val = newVal
        AxiUI.Flags[key] = val
        if opts.OnStateChange then pcall(opts.OnStateChange, guiElement, val) end
        if not silent and opts.Callback then pcall(opts.Callback, val) end
    end

    local btn = findButton(guiElement)
    if btn then
        btn.MouseButton1Click:Connect(function()
            obj:Set(not val)
        end)
    else
        warn("[AxiUI Binder] BindToggle: no GuiButton found for key '" .. key .. "'")
    end

    AxiUI.Flags[key]           = def
    AxiUI.Flags[key .. "_obj"] = obj
    obj:Set(def, true)
    return obj
end

-- ═══════════════════════════════════════════════════════════════
--  BUTTON
-- ═══════════════════════════════════════════════════════════════
function Binder:BindButton(guiElement, opts)
    opts = opts or {}
    local btn = findButton(guiElement)
    if btn then
        btn.MouseButton1Click:Connect(function()
            if opts.Callback then pcall(opts.Callback, guiElement) end
        end)
    else
        warn("[AxiUI Binder] BindButton: no GuiButton found")
    end
end

-- ═══════════════════════════════════════════════════════════════
--  SLIDER
-- ═══════════════════════════════════════════════════════════════
function Binder:BindSlider(guiElement, key, opts)
    opts = opts or {}
    local min = opts.Min or 0
    local max = opts.Max or 100
    local def = math.clamp(opts.Default or min, min, max)

    local obj = {}

    function obj:Set(newVal, silent)
        if opts.Rounding ~= false then newVal = math.round(newVal) end
        newVal = math.clamp(newVal, min, max)
        AxiUI.Flags[key] = newVal
        local pct = (newVal - min) / (max - min)
        if opts.OnStateChange then pcall(opts.OnStateChange, guiElement, newVal, pct) end
        if not silent and opts.Callback then pcall(opts.Callback, newVal) end
    end

    local track = opts.Track or guiElement:FindFirstChild("Track", true)
    if track then
        local dragging = false
        local function fromX(x)
            local pct = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            obj:Set(min + pct * (max - min))
        end
        track.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true; fromX(inp.Position.X)
            end
        end)
        UIS.InputChanged:Connect(function(inp)
            if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
                fromX(inp.Position.X)
            end
        end)
        UIS.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
    else
        warn("[AxiUI Binder] BindSlider: no Track found for key '" .. key .. "'")
    end

    AxiUI.Flags[key]           = def
    AxiUI.Flags[key .. "_obj"] = obj
    obj:Set(def, true)
    return obj
end

-- ═══════════════════════════════════════════════════════════════
--  DROPDOWN
-- ═══════════════════════════════════════════════════════════════
function Binder:BindDropdown(guiElement, key, opts)
    opts = opts or {}
    local items = opts.Items   or {}
    local def   = opts.Default or items[1] or ""

    local obj = {}

    function obj:Set(newVal, silent)
        AxiUI.Flags[key] = newVal
        if opts.OnStateChange then pcall(opts.OnStateChange, guiElement, newVal) end
        if not silent and opts.Callback then pcall(opts.Callback, newVal) end
    end

    function obj:SetItems(newItems)
        items = newItems
        if opts.OnItemsChanged then pcall(opts.OnItemsChanged, guiElement, newItems) end
        self:Set(newItems[1] or "")
    end

    AxiUI.Flags[key]           = def
    AxiUI.Flags[key .. "_obj"] = obj
    obj:Set(def, true)
    return obj
end

-- ═══════════════════════════════════════════════════════════════
--  INPUT
-- ═══════════════════════════════════════════════════════════════
function Binder:BindInput(guiElement, key, opts)
    opts = opts or {}
    local def      = opts.Default or ""
    local numeric  = opts.Numeric  == true
    local finished = opts.Finished == true

    local box      = findTextBox(guiElement)
    local ignoring = false

    local obj = {}

    function obj:Set(newVal, silent)
        local s = tostring(newVal)
        AxiUI.Flags[key] = s
        if box and box.Text ~= s then
            ignoring = true
            box.Text = s
            ignoring = false
        end
        if opts.OnStateChange then pcall(opts.OnStateChange, guiElement, s) end
        if not silent and opts.Callback then pcall(opts.Callback, s) end
    end

    if box then
        if numeric then
            box:GetPropertyChangedSignal("Text"):Connect(function()
                if ignoring then return end
                local clean = box.Text:match("^-?%d*%.?%d*") or ""
                if clean ~= box.Text then
                    ignoring = true; box.Text = clean; ignoring = false
                end
            end)
        end
        if not finished then
            box:GetPropertyChangedSignal("Text"):Connect(function()
                if ignoring then return end
                AxiUI.Flags[key] = box.Text
                if opts.Callback then pcall(opts.Callback, box.Text) end
            end)
        end
        box.FocusLost:Connect(function(enter)
            AxiUI.Flags[key] = box.Text
            if finished and enter and opts.Callback then
                pcall(opts.Callback, box.Text)
            end
        end)
    else
        warn("[AxiUI Binder] BindInput: no TextBox found for key '" .. key .. "'")
    end

    AxiUI.Flags[key]           = def
    AxiUI.Flags[key .. "_obj"] = obj
    obj:Set(def, true)
    return obj
end

-- ═══════════════════════════════════════════════════════════════
--  KEYBIND
-- ═══════════════════════════════════════════════════════════════
function Binder:BindKeybind(guiElement, key, opts)
    opts = opts or {}
    local currentKey = opts.Default or Enum.KeyCode.Unknown

    local obj = {}

    function obj:Set(newKey, silent)
        currentKey = newKey
        AxiUI.Flags[key] = newKey
        if opts.OnStateChange then pcall(opts.OnStateChange, guiElement, newKey) end
        if not silent and opts.Callback then pcall(opts.Callback, newKey) end
    end

    function obj:Get()
        return AxiUI.Flags[key]
    end

    local btn = findButton(guiElement)
    if btn then
        local listening = false
        btn.MouseButton1Click:Connect(function()
            if listening then return end
            listening = true
            if opts.OnListening then pcall(opts.OnListening, guiElement, true) end
            local conn
            conn = UIS.InputBegan:Connect(function(inp, gpe)
                if gpe then return end
                if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
                if inp.KeyCode == Enum.KeyCode.Escape then
                    listening = false
                    if opts.OnListening then pcall(opts.OnListening, guiElement, false) end
                    conn:Disconnect(); return
                end
                obj:Set(inp.KeyCode)
                listening = false
                if opts.OnListening then pcall(opts.OnListening, guiElement, false) end
                conn:Disconnect()
            end)
        end)
    else
        warn("[AxiUI Binder] BindKeybind: no GuiButton found for key '" .. key .. "'")
    end

    AxiUI.Flags[key]           = currentKey
    AxiUI.Flags[key .. "_obj"] = obj
    obj:Set(currentKey, true)
    return obj
end

-- ═══════════════════════════════════════════════════════════════
--  COLOR PICKER
--  Binder does not provide a built-in color popup.
--  Hook your own color picker UI; call Set() when color changes.
-- ═══════════════════════════════════════════════════════════════
function Binder:BindColorPicker(guiElement, key, opts)
    opts = opts or {}
    local def = opts.Default or Color3.fromRGB(255, 255, 255)

    local obj = {}

    function obj:Set(c, silent)
        AxiUI.Flags[key] = c
        if opts.OnStateChange then pcall(opts.OnStateChange, guiElement, c) end
        if not silent and opts.Callback then pcall(opts.Callback, c) end
    end

    function obj:Get()
        return AxiUI.Flags[key]
    end

    AxiUI.Flags[key]           = def
    AxiUI.Flags[key .. "_obj"] = obj
    obj:Set(def, true)
    return obj
end

-- ═══════════════════════════════════════════════════════════════
--  ATTACH
-- ═══════════════════════════════════════════════════════════════
AxiUI.Binder = Binder
return Binder
