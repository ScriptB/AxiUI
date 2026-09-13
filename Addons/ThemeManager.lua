-- AxiUI ThemeManager v2.0.0 — renderer registry and live hot-swap

local _env  = (typeof(getgenv) == "function" and getgenv()) or _G
local AxiUI = _env.AxiUI
assert(AxiUI, "[AxiUI ThemeManager] AxiUI Core must be loaded first.")

-- ═══════════════════════════════════════════════════════════════
--  THEME MANAGER
-- ═══════════════════════════════════════════════════════════════
local ThemeManager            = {}
ThemeManager._renderers       = {}
ThemeManager._current         = nil
ThemeManager._listeners       = {}

-- Register a named renderer module.
function ThemeManager:Register(name, renderer)
    assert(type(name) == "string",    "[AxiUI ThemeManager] Register: name must be a string")
    assert(type(renderer) == "table", "[AxiUI ThemeManager] Register: renderer must be a table")
    self._renderers[name] = renderer
end

-- Swap the active renderer. Tears down the current visual layer and
-- remounts everything from the virtual DOM with the new renderer.
function ThemeManager:Apply(name)
    local newRenderer = self._renderers[name]
    if not newRenderer then
        warn("[AxiUI ThemeManager] Unknown renderer '" .. tostring(name) .. "'")
        return
    end

    -- Unload current visual layer (destroys ScreenGuis, disconnects renderer connections).
    if AxiUI.Renderer and AxiUI.Renderer.Unload then
        pcall(AxiUI.Renderer.Unload, AxiUI.Renderer)
    end

    -- Walk the virtual DOM with the new renderer.
    AxiUI:RemountAll(newRenderer)

    self._current = name
    for _, fn in ipairs(self._listeners) do pcall(fn, name) end
end

-- Returns the name of the currently active renderer.
function ThemeManager:GetCurrent()
    return self._current
end

-- Returns a sorted list of all registered renderer names.
function ThemeManager:GetNames()
    local n = {}
    for k in pairs(self._renderers) do n[#n+1] = k end
    table.sort(n)
    return n
end

-- Subscribe to renderer-swap events.
-- fn(rendererName) is called each time Apply() succeeds.
function ThemeManager:OnChanged(fn)
    table.insert(self._listeners, fn)
end

-- ── UI helpers ──────────────────────────────────────────────────

-- Adds a renderer-picker dropdown to a groupbox.
function ThemeManager:BuildUI(gb)
    gb:AddDropdown("TM_Renderer", {
        Text    = "UI Theme",
        Items   = self:GetNames(),
        Default = self._current or "",
        Callback = function(v) self:Apply(v) end,
    })
end

-- Convenience: add a renderer-picker into a new groupbox on a tab.
function ThemeManager:ApplyToTab(tab)
    self:BuildUI(tab:AddGroupbox("UI Theme"))
end

-- Convenience: add a renderer-picker into an existing groupbox.
function ThemeManager:ApplyToGroupbox(gb)
    self:BuildUI(gb)
end

-- ═══════════════════════════════════════════════════════════════
--  ATTACH
-- ═══════════════════════════════════════════════════════════════
AxiUI.ThemeManager = ThemeManager
return ThemeManager
