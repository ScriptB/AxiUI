--[[
    AxiUI — Example Script
    Demonstrates the full API: Core, Modern renderer, ConfigManager, ThemeManager.

    Load order matters:
        1. Core
        2. Renderer  (visual layer)
        3. Addons    (ThemeManager, ConfigManager — optional)
        4. Build your UI
        5. LoadDefault config (at the very end)
]]

-- ═══════════════════════════════════════════════════════════════
--  LOAD
-- ═══════════════════════════════════════════════════════════════
local AxiUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/ScriptB/AxiUI/main/AxiUI.lua"
))()

local Modern = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/ScriptB/AxiUI/main/Renderers/Modern.lua"
))()

local Basic = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/ScriptB/AxiUI/main/Renderers/Basic.lua"
))()

local Terminal = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/ScriptB/AxiUI/main/Renderers/Terminal.lua"
))()

local ThemeManager = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/ScriptB/AxiUI/main/Addons/ThemeManager.lua"
))()

local CM = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/ScriptB/AxiUI/main/Addons/ConfigManager.lua"
))()

-- ── Set up renderer ──────────────────────────────────────────
AxiUI:SetRenderer(Modern)

-- ── Register all renderers with ThemeManager ─────────────────
ThemeManager:Register("Modern",   Modern)
ThemeManager:Register("Basic",    Basic)
ThemeManager:Register("Terminal", Terminal)

-- ── Config manager (namespaced per script) ───────────────────
CM:Init(AxiUI, "AxiUI_Example")

-- ═══════════════════════════════════════════════════════════════
--  WINDOW
-- ═══════════════════════════════════════════════════════════════
local Window = AxiUI:CreateWindow({
    Title      = "AxiUI  v" .. AxiUI.Version,
    ToggleKey  = Enum.KeyCode.RightShift,
    Width      = 440,
    Height     = 500,
})

-- ═══════════════════════════════════════════════════════════════
--  TABS
-- ═══════════════════════════════════════════════════════════════
local Tabs = {
    Main     = Window:AddTab("Main"),
    Combat   = Window:AddTab("Combat"),
    Visual   = Window:AddTab("Visual"),
    Settings = Window:AddTab("Settings"),
}

-- ═══════════════════════════════════════════════════════════════
--  MAIN TAB
-- ═══════════════════════════════════════════════════════════════
local MainGroup = Tabs.Main:AddGroupbox("General")

MainGroup:AddLabel("Welcome to AxiUI — a universal, renderer-agnostic UI framework.")
MainGroup:AddDivider()

-- Button with a simple callback
MainGroup:AddButton({
    Text = "Send Notification",
    Callback = function()
        AxiUI:Notify("AxiUI", "Button was clicked!", 4)
    end,
})

-- Toggle — value is readable from AxiUI.Flags["GodMode"]
local GodMode = MainGroup:AddToggle("GodMode", {
    Text     = "God Mode",
    Tooltip  = "Prevents damage",
    Default  = false,
    Callback = function(enabled)
        print("God Mode:", enabled)
    end,
})

-- Programmatic update
-- GodMode:Set(true)

-- Slider
local Speed = MainGroup:AddSlider("Speed", {
    Text     = "Walk Speed",
    Min      = 16,
    Max      = 250,
    Default  = 16,
    Rounding = true,
    Suffix   = " st",
    Callback = function(val)
        local char = game.Players.LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = val end
        end
    end,
})

-- SubBox — visually inset inside a groupbox
local sub = MainGroup:AddSubBox("Quick Actions")
sub:AddButton({ Text = "Reset Speed",  Callback = function() Speed:Set(16) end })
sub:AddButton({ Text = "Max Speed",    Callback = function() Speed:Set(250) end })

-- ═══════════════════════════════════════════════════════════════
--  COMBAT TAB
-- ═══════════════════════════════════════════════════════════════
local AimGroup = Tabs.Combat:AddGroupbox("Aimbot")

local SilentAim = AimGroup:AddToggle("SilentAim", {
    Text    = "Silent Aim",
    Default = false,
    Callback = function(v) print("SilentAim:", v) end,
})

local FOV = AimGroup:AddSlider("AimFOV", {
    Text    = "FOV",
    Min     = 1,
    Max     = 360,
    Default = 90,
    Suffix  = "°",
})

local AimPart = AimGroup:AddDropdown("AimPart", {
    Text    = "Aim Part",
    Items   = { "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso" },
    Default = "Head",
    Callback = function(v) print("Aim part:", v) end,
})

-- Dynamically update dropdown items
-- AimPart:SetItems({ "Head", "UpperTorso" })

local AimKey = AimGroup:AddKeybind("AimKey", {
    Text    = "Aim Key",
    Default = Enum.KeyCode.Q,
    Callback = function(key) print("Aim key set to:", key.Name) end,
})

-- ═══════════════════════════════════════════════════════════════
--  VISUAL TAB
-- ═══════════════════════════════════════════════════════════════
local EspGroup = Tabs.Visual:AddGroupbox("ESP")

local EspEnabled = EspGroup:AddToggle("EspEnabled", {
    Text    = "Enable ESP",
    Default = false,
})

local EspColor = EspGroup:AddColorPicker("EspColor", {
    Text    = "ESP Colour",
    Default = Color3.fromRGB(255, 80, 80),
    Callback = function(c) print("ESP colour:", c) end,
})

local EspDistance = EspGroup:AddSlider("EspDistance", {
    Text    = "Max Distance",
    Min     = 50,
    Max     = 2000,
    Default = 500,
    Suffix  = " m",
})

local ChamsGroup = Tabs.Visual:AddGroupbox("Chams")

ChamsGroup:AddToggle("ChamsEnabled", {
    Text    = "Enable Chams",
    Default = false,
})

ChamsGroup:AddDropdown("ChamsStyle", {
    Text    = "Style",
    Items   = { "Flat", "Neon", "Glass" },
    Default = "Flat",
})

-- ═══════════════════════════════════════════════════════════════
--  SETTINGS TAB  (renderer picker + config manager)
-- ═══════════════════════════════════════════════════════════════

-- Renderer picker (drop the full swap UI into a groupbox)
local RenderGroup = Tabs.Settings:AddGroupbox("Renderer")

ThemeManager:BuildUI(RenderGroup)

-- Within Modern renderer — colour palette only (no remount)
RenderGroup:AddDropdown("__tm_colorTheme", {
    Text    = "Colour Theme",
    Items   = Modern:GetColorThemeNames(),
    Default = "Default",
    Callback = function(name) Modern:ApplyColorTheme(name) end,
})

-- Config manager UI
CM:ApplyToTab(Tabs.Settings)

-- ── Extra: persist window position across sessions ────────────
CM:RegisterExtra("windowPos",
    function()
        if Window.Frame then
            return {
                x = Window.Frame.Position.X.Offset,
                y = Window.Frame.Position.Y.Offset,
            }
        end
    end,
    function(d)
        if Window.Frame and d then
            Window.Frame.Position = UDim2.fromOffset(d.x or 0, d.y or 0)
        end
    end
)

-- ── Auto-save on any flag change (2s debounce) ───────────────
CM:SetAutoSave(true, 2)

-- ── Notify when profiles are saved/loaded ────────────────────
CM:OnSaved(function(name)
    AxiUI:Notify("Config", 'Saved "' .. name .. '"', 3)
end)

CM:OnLoaded(function(name)
    AxiUI:Notify("Config", 'Loaded "' .. name .. '"', 3)
end)

-- ═══════════════════════════════════════════════════════════════
--  START
-- ═══════════════════════════════════════════════════════════════
Window:SelectTab and Window:SelectTab(1) -- show first tab

AxiUI:Notify("AxiUI", "Framework loaded — " .. AxiUI.Version, 5)

-- Load the default config last so it overrides all defaults above
CM:LoadDefault()
