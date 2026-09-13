--[[
    AxiUI — ConfigManager v2.1.0 (Standalone)
    Full profile-based config save/load system.
    Works with any script, any renderer, or no renderer at all.

    ── LOAD ORDER ──────────────────────────────────────────────────
        local AxiUI    = loadstring(game:HttpGet("...AxiUI_Core.lua"))()
        local Renderer = loadstring(game:HttpGet("...Renderers/AxiUI_Renderer_Modern.lua"))()
        AxiUI:SetRenderer(Renderer)

        local CM = loadstring(game:HttpGet("...AxiUI_ConfigManager.lua"))()
        CM:Init(AxiUI, "MyScript")

    ── QUICK API ───────────────────────────────────────────────────
        CM:Save("Combat")            -- save current flags to "Combat" profile
        CM:Load("Combat")            -- restore flags and fire all element callbacks
        CM:Delete("Combat")          -- remove the profile
        CM:List()                    -- { "Combat", "Default", ... }
        CM:SetDefault("Combat")      -- auto-loaded by LoadDefault() on next run
        CM:LoadDefault()             -- load the marked default (call at script start)
        CM:SetAutoSave(true)         -- auto-save to current profile after every change
        CM:SetAutoSave(true, 3)      -- same, 3-second debounce (default: 2s)

    ── CUSTOM TYPES ─────────────────────────────────────────────────
        Script devs can teach the serializer about any value type:

        CM:RegisterType("cframe",
            function(v) return typeof(v) == "CFrame" end,
            function(v) return { px=v.X, py=v.Y, pz=v.Z,
                                  rx=v:ToEulerAnglesXYZ() } end,  -- serialize → table
            function(d) return CFrame.new(d.px, d.py, d.pz)
                             * CFrame.Angles(d.rx or 0, 0, 0) end -- deserialize ← table
        )

        Built-in types are also registered this way:
            "boolean", "number", "string", "enum", "color3", "vector2", "vector3"

    ── EXTRA DATA SLOTS ────────────────────────────────────────────
        Save/load arbitrary non-flag data alongside the profile:

        CM:RegisterExtra("windowPos",
            function() return { x = win.Frame.Position.X.Offset,
                                y = win.Frame.Position.Y.Offset } end,
            function(d) win.Frame.Position = UDim2.fromOffset(d.x, d.y) end
        )

    ── OPTIONAL UI ──────────────────────────────────────────────────
        CM:BuildUI(myGroupbox)   -- injects full manager UI into any groupbox
        CM:ApplyToTab(myTab)     -- convenience: creates a "Config" groupbox on tab

    ── EVENTS ───────────────────────────────────────────────────────
        CM:OnSaved(function(name) end)
        CM:OnLoaded(function(name) end)
        CM:OnDeleted(function(name) end)

    ── FILE STORAGE ─────────────────────────────────────────────────
        Folder layout (makefolder available):
            axiui/<ScriptName>/<ProfileName>.json
            axiui/<ScriptName>/_manifest.json

        Flat fallback:
            axiui_<ScriptName>_<ProfileName>.json
            axiui_<ScriptName>__manifest.json
]]

local _env    = (typeof(getgenv) == "function" and getgenv()) or _G
local HttpSvc = game:GetService("HttpService")

-- ═══════════════════════════════════════════════════════════════
--  MODULE
-- ═══════════════════════════════════════════════════════════════
local CM = {}

CM._axiui       = nil
CM._ns          = "default"
CM._current     = nil
CM._autoSave    = false
CM._autoDelay   = 2
CM._debounceJob = nil
CM._autoConns   = {}
CM._savedCbs    = {}
CM._loadedCbs   = {}
CM._deletedCbs  = {}
CM._hasFolder   = false

-- ── Custom type handlers ──────────────────────────────────────
-- Each entry: { tag = string, check = fn(v)->bool,
--               serialize = fn(v)->table, deserialize = fn(table)->value }
-- "tag" is stored as __type in the JSON so the right deserializer is found.
CM._typeHandlers  = {}
CM._typeByTag     = {}   -- tag → handler (fast lookup on deserialize)

-- ── Extra data slots ──────────────────────────────────────────
-- Each entry: { key = string, get = fn()->any, set = fn(data) }
-- Serialized under "__extras" in the profile JSON.
CM._extras = {}

-- ═══════════════════════════════════════════════════════════════
--  INIT
-- ═══════════════════════════════════════════════════════════════
function CM:Init(axiui, scriptName)
    assert(axiui,      "[AxiUI CM] Init: AxiUI core table required")
    assert(scriptName, "[AxiUI CM] Init: scriptName required (file namespace)")

    self._axiui = axiui
    self._ns    = tostring(scriptName):gsub("[^%w%-_]", "_")

    if typeof(makefolder) == "function" then
        pcall(makefolder, "axiui")
        local ok = pcall(makefolder, "axiui/" .. self._ns)
        self._hasFolder = ok
            or (typeof(isfolder) == "function" and isfolder("axiui/" .. self._ns))
    end

    _env.AxiUICM = self
    if _env.AxiUI then _env.AxiUI.ConfigManager = self end
    return self
end

-- ═══════════════════════════════════════════════════════════════
--  CUSTOM TYPE REGISTRATION
-- ═══════════════════════════════════════════════════════════════
--[[
    RegisterType(tag, checker, serializer, deserializer)

    @param tag           string  — unique id stored as __type in JSON
    @param checker       fn(v)   — returns true if this handler owns value v
    @param serializer    fn(v)   — converts v to a plain JSON-safe table
    @param deserializer  fn(t)   — converts the plain table back to the original type

    Later registrations take priority over earlier ones.
    Built-in types (color3, enum, …) are pre-registered below; you can
    override them by registering the same tag again.

    Example — save/load CFrame:
        CM:RegisterType("cframe",
            function(v) return typeof(v) == "CFrame" end,
            function(v)
                local x, y, z = v:ToEulerAnglesXYZ()
                return { px=v.X, py=v.Y, pz=v.Z, rx=x, ry=y, rz=z }
            end,
            function(d)
                return CFrame.new(d.px, d.py, d.pz)
                     * CFrame.Angles(d.rx or 0, d.ry or 0, d.rz or 0)
            end
        )

    Example — save/load a plain Lua table of data:
        CM:RegisterType("mySettings",
            function(v) return type(v) == "table" and v._isMySettings end,
            function(v) return { speed = v.speed, mode = v.mode } end,
            function(d) return { _isMySettings = true, speed = d.speed, mode = d.mode } end
        )
]]
function CM:RegisterType(tag, checker, serializer, deserializer)
    assert(type(tag)          == "string",   "[AxiUI CM] RegisterType: tag must be a string")
    assert(type(checker)      == "function", "[AxiUI CM] RegisterType: checker must be a function")
    assert(type(serializer)   == "function", "[AxiUI CM] RegisterType: serializer must be a function")
    assert(type(deserializer) == "function", "[AxiUI CM] RegisterType: deserializer must be a function")

    -- Replace existing handler with this tag, or append
    for i, h in ipairs(self._typeHandlers) do
        if h.tag == tag then
            self._typeHandlers[i] = { tag=tag, check=checker, serialize=serializer, deserialize=deserializer }
            self._typeByTag[tag]  = self._typeHandlers[i]
            return
        end
    end
    local entry = { tag=tag, check=checker, serialize=serializer, deserialize=deserializer }
    table.insert(self._typeHandlers, 1, entry) -- prepend so newer registrations win
    self._typeByTag[tag] = entry
end

-- ═══════════════════════════════════════════════════════════════
--  EXTRA DATA SLOTS
-- ═══════════════════════════════════════════════════════════════
--[[
    RegisterExtra(key, getter, setter)

    Saves/loads arbitrary non-flag data alongside the profile.
    The getter must return JSON-serializable data (table/string/number/bool).

    @param key     string  — unique key in the "__extras" block of the JSON
    @param getter  fn()    — called on Save; returns the data to persist
    @param setter  fn(data)— called on Load; receives the stored data

    Example — persist window position:
        CM:RegisterExtra("windowPos",
            function()
                return { x = win.Frame.Position.X.Offset,
                         y = win.Frame.Position.Y.Offset }
            end,
            function(d)
                win.Frame.Position = UDim2.fromOffset(d.x or 0, d.y or 0)
            end
        )

    Example — persist a table of custom runtime state:
        CM:RegisterExtra("killList",
            function() return killTargets end,
            function(d) for _, v in ipairs(d) do table.insert(killTargets, v) end end
        )
]]
function CM:RegisterExtra(key, getter, setter)
    assert(type(key)    == "string",   "[AxiUI CM] RegisterExtra: key must be a string")
    assert(type(getter) == "function", "[AxiUI CM] RegisterExtra: getter must be a function")
    assert(type(setter) == "function", "[AxiUI CM] RegisterExtra: setter must be a function")

    for i, e in ipairs(self._extras) do
        if e.key == key then
            self._extras[i] = { key=key, get=getter, set=setter }
            return
        end
    end
    table.insert(self._extras, { key=key, get=getter, set=setter })
end

-- ═══════════════════════════════════════════════════════════════
--  FILE PATH HELPERS
-- ═══════════════════════════════════════════════════════════════
function CM:_ProfilePath(name)
    local safe = tostring(name):gsub("[^%w%-_]", "_")
    if self._hasFolder then
        return "axiui/" .. self._ns .. "/" .. safe .. ".json"
    end
    return "axiui_" .. self._ns .. "_" .. safe .. ".json"
end

function CM:_ManifestPath()
    if self._hasFolder then
        return "axiui/" .. self._ns .. "/_manifest.json"
    end
    return "axiui_" .. self._ns .. "__manifest.json"
end

-- ═══════════════════════════════════════════════════════════════
--  MANIFEST
-- ═══════════════════════════════════════════════════════════════
function CM:_ReadManifest()
    local path = self:_ManifestPath()
    if not (typeof(isfile) == "function" and isfile(path)) then
        return { profiles = {}, default = nil }
    end
    local ok, raw = pcall(readfile, path)
    if not ok then return { profiles = {}, default = nil } end
    local ok2, data = pcall(function() return HttpSvc:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" then return { profiles = {}, default = nil } end
    if type(data.profiles) ~= "table" then data.profiles = {} end
    return data
end

function CM:_WriteManifest(manifest)
    local ok, err = pcall(writefile, self:_ManifestPath(), HttpSvc:JSONEncode(manifest))
    if not ok then warn("[AxiUI CM] Manifest write failed:", err) end
end

function CM:_ManifestAddProfile(name)
    local m = self:_ReadManifest()
    for _, v in ipairs(m.profiles) do if v == name then return end end
    table.insert(m.profiles, name)
    table.sort(m.profiles)
    self:_WriteManifest(m)
end

function CM:_ManifestRemoveProfile(name)
    local m = self:_ReadManifest()
    for i, v in ipairs(m.profiles) do
        if v == name then table.remove(m.profiles, i); break end
    end
    if m.default == name then m.default = nil end
    self:_WriteManifest(m)
end

-- ═══════════════════════════════════════════════════════════════
--  SERIALIZATION
-- ═══════════════════════════════════════════════════════════════
local SKIP_PATTERN = "^__cm_"

function CM:_SerializeValue(v)
    -- Check custom type handlers first (newest first, so overrides work)
    for _, h in ipairs(self._typeHandlers) do
        local ok, matches = pcall(h.check, v)
        if ok and matches then
            local ok2, result = pcall(h.serialize, v)
            if ok2 and type(result) == "table" then
                result.__type = h.tag
                return result
            end
        end
    end
    return nil -- unrecognised — skip
end

function CM:_DeserializeValue(v)
    if type(v) == "table" and type(v.__type) == "string" then
        local h = self._typeByTag[v.__type]
        if h then
            local ok, result = pcall(h.deserialize, v)
            if ok then return result end
        end
        return nil -- known __type but no handler (handler removed?) — skip
    end
    -- Primitives pass through as-is (boolean/number/string handled by Set directly)
    return v
end

function CM:_Serialize()
    local data    = {}
    local extras  = {}
    local flags   = self._axiui.Flags

    -- ── Flags ─────────────────────────────────────────────────
    for k, v in pairs(flags) do
        if k:find("_obj$") or k:find(SKIP_PATTERN) then continue end

        local t = type(v)
        if t == "boolean" or t == "number" or t == "string" then
            data[k] = v
        else
            local serialized = self:_SerializeValue(v)
            if serialized then data[k] = serialized end
            -- silently skip if no handler — never error on unknown types
        end
    end

    -- ── Extras ────────────────────────────────────────────────
    for _, extra in ipairs(self._extras) do
        local ok, val = pcall(extra.get)
        if ok and val ~= nil then extras[extra.key] = val end
    end
    if next(extras) then data["__extras"] = extras end

    return data
end

function CM:_Deserialize(data)
    if type(data) ~= "table" then return end
    local flags = self._axiui.Flags

    -- ── Flags ─────────────────────────────────────────────────
    for k, v in pairs(data) do
        if k == "__extras" or k:find(SKIP_PATTERN) then continue end
        local obj = flags[k .. "_obj"]
        if obj and obj.Set then
            local value = self:_DeserializeValue(v)
            if value ~= nil then
                pcall(obj.Set, obj, value)
            end
        end
    end

    -- ── Extras ────────────────────────────────────────────────
    local extras = data["__extras"]
    if type(extras) == "table" then
        for _, extra in ipairs(self._extras) do
            if extras[extra.key] ~= nil then
                pcall(extra.set, extras[extra.key])
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
--  BUILT-IN TYPE HANDLERS
--  Registered here so they can be overridden by scripts if needed.
-- ═══════════════════════════════════════════════════════════════
do
    local cm = CM

    -- EnumItem (Keybinds, etc.)
    cm:RegisterType("enum",
        function(v) return typeof(v) == "EnumItem" end,
        function(v) return { value = tostring(v) } end,
        function(d)
            local parts = tostring(d.value):split(".")
            if #parts == 3 then
                return (Enum :: any)[parts[2]][parts[3]]
            end
        end
    )

    -- Color3
    cm:RegisterType("color3",
        function(v) return typeof(v) == "Color3" end,
        function(v) return { r = v.R, g = v.G, b = v.B } end,
        function(d) return Color3.new(d.r or 0, d.g or 0, d.b or 0) end
    )

    -- Vector2
    cm:RegisterType("vector2",
        function(v) return typeof(v) == "Vector2" end,
        function(v) return { x = v.X, y = v.Y } end,
        function(d) return Vector2.new(d.x or 0, d.y or 0) end
    )

    -- Vector3
    cm:RegisterType("vector3",
        function(v) return typeof(v) == "Vector3" end,
        function(v) return { x = v.X, y = v.Y, z = v.Z } end,
        function(d) return Vector3.new(d.x or 0, d.y or 0, d.z or 0) end
    )

    -- UDim2
    cm:RegisterType("udim2",
        function(v) return typeof(v) == "UDim2" end,
        function(v)
            return {
                sx = v.X.Scale, ox = v.X.Offset,
                sy = v.Y.Scale, oy = v.Y.Offset,
            }
        end,
        function(d)
            return UDim2.new(d.sx or 0, d.ox or 0, d.sy or 0, d.oy or 0)
        end
    )

    -- UDim
    cm:RegisterType("udim",
        function(v) return typeof(v) == "UDim" end,
        function(v) return { scale = v.Scale, offset = v.Offset } end,
        function(d) return UDim.new(d.scale or 0, d.offset or 0) end
    )

    -- NumberRange
    cm:RegisterType("numberrange",
        function(v) return typeof(v) == "NumberRange" end,
        function(v) return { min = v.Min, max = v.Max } end,
        function(d) return NumberRange.new(d.min or 0, d.max or 0) end
    )
end

-- ═══════════════════════════════════════════════════════════════
--  CORE API
-- ═══════════════════════════════════════════════════════════════
function CM:Save(name)
    name = name or self._current
    assert(name and name ~= "", "[AxiUI CM] Save: profile name required")
    name = tostring(name):gsub("[^%w%-_ ]", "_")

    local data = self:_Serialize()
    local ok, err = pcall(writefile, self:_ProfilePath(name), HttpSvc:JSONEncode(data))
    if not ok then warn("[AxiUI CM] Save failed for '" .. name .. "':", err); return false end

    self._current = name
    self:_ManifestAddProfile(name)
    self:_UpdateDropdown()
    for _, fn in ipairs(self._savedCbs) do pcall(fn, name) end
    return true
end

function CM:Load(name)
    assert(name and name ~= "", "[AxiUI CM] Load: profile name required")
    local path = self:_ProfilePath(name)
    if not (typeof(isfile) == "function" and isfile(path)) then
        warn("[AxiUI CM] Profile '" .. name .. "' not found"); return false
    end
    local ok, raw = pcall(readfile, path)
    if not ok then return false end
    local ok2, data = pcall(function() return HttpSvc:JSONDecode(raw) end)
    if not ok2 then warn("[AxiUI CM] Profile '" .. name .. "' is corrupt"); return false end

    self:_Deserialize(data)
    self._current = name
    self:_SyncDropdown(name)
    for _, fn in ipairs(self._loadedCbs) do pcall(fn, name) end
    return true
end

function CM:Delete(name)
    assert(name and name ~= "", "[AxiUI CM] Delete: profile name required")
    local path = self:_ProfilePath(name)
    if typeof(isfile) == "function" and isfile(path) then
        pcall(delfile, path)
    end
    self:_ManifestRemoveProfile(name)
    if self._current == name then self._current = nil end
    self:_UpdateDropdown()
    for _, fn in ipairs(self._deletedCbs) do pcall(fn, name) end
end

function CM:List()
    return self:_ReadManifest().profiles
end

function CM:SetDefault(name)
    assert(name and name ~= "", "[AxiUI CM] SetDefault: profile name required")
    local m = self:_ReadManifest()
    m.default = name
    self:_WriteManifest(m)
end

function CM:LoadDefault()
    local m = self:_ReadManifest()
    if m.default and m.default ~= "" then return self:Load(m.default) end
    return false
end

function CM:GetCurrent() return self._current end

function CM:SetCurrent(name)
    self._current = name
    self:_SyncDropdown(name)
end

-- ═══════════════════════════════════════════════════════════════
--  AUTO-SAVE
-- ═══════════════════════════════════════════════════════════════
function CM:SetAutoSave(enabled, delay)
    self._autoSave  = enabled == true
    self._autoDelay = delay or self._autoDelay or 2
    self:_StopAutoSave()
    if self._autoSave then self:_StartAutoSave() end
end

function CM:_ScheduleSave()
    if not self._autoSave or not self._current then return end
    if self._debounceJob then task.cancel(self._debounceJob) end
    self._debounceJob = task.delay(self._autoDelay, function()
        self._debounceJob = nil
        self:Save(self._current)
    end)
end

function CM:_StartAutoSave()
    self:_StopAutoSave()
    local flags = self._axiui and self._axiui.Flags
    if not flags then return end
    for k, obj in pairs(flags) do
        if k:find("_obj$") and type(obj) == "table" and obj.OnStateChanged then
            local conn = obj.OnStateChanged:Connect(function()
                self:_ScheduleSave()
            end)
            table.insert(self._autoConns, conn)
        end
    end
end

function CM:_StopAutoSave()
    for _, c in ipairs(self._autoConns) do pcall(function() c:Disconnect() end) end
    self._autoConns = {}
    if self._debounceJob then pcall(task.cancel, self._debounceJob); self._debounceJob = nil end
end

-- ═══════════════════════════════════════════════════════════════
--  EVENTS
-- ═══════════════════════════════════════════════════════════════
function CM:OnSaved(fn)   table.insert(self._savedCbs,   fn) end
function CM:OnLoaded(fn)  table.insert(self._loadedCbs,  fn) end
function CM:OnDeleted(fn) table.insert(self._deletedCbs, fn) end

-- ═══════════════════════════════════════════════════════════════
--  BUILT-IN UI  (renderer-agnostic — uses Core element API)
-- ═══════════════════════════════════════════════════════════════
CM._dd     = nil
CM._nameEl = nil

function CM:_UpdateDropdown()
    if not self._dd then return end
    local list = self:List()
    self._dd:SetItems(#list > 0 and list or { "" })
end

function CM:_SyncDropdown(name)
    if not self._dd or not name then return end
    for _, v in ipairs(self:List()) do
        if v == name then self._dd:Set(name, true); break end
    end
end

function CM:BuildUI(gb)
    assert(gb, "[AxiUI CM] BuildUI: groupbox required")
    local profiles = self:List()

    -- Profile selector
    self._dd = gb:AddDropdown("__cm_profile", {
        Text    = "Active Profile",
        Items   = #profiles > 0 and profiles or { "" },
        Default = self._current or (profiles[1] or ""),
    })

    gb:AddButton({
        Text = "Load Selected",
        Callback = function()
            local sel = self._axiui.Flags["__cm_profile"]
            if sel and sel ~= "" then self:Load(sel) end
        end,
    })

    gb:AddDivider()

    -- New / overwrite
    self._nameEl = gb:AddInput("__cm_newname", {
        Text        = "Profile Name",
        Placeholder = "e.g. Combat",
        Default     = "",
        Finished    = false,
    })

    gb:AddButton({
        Text = "Save as New Profile",
        Callback = function()
            local name = self._axiui.Flags["__cm_newname"]
            if not name or name == "" then
                warn("[AxiUI CM] Enter a profile name first"); return
            end
            self:Save(name)
        end,
    })

    gb:AddButton({
        Text = "Overwrite Selected",
        Callback = function()
            local sel = self._axiui.Flags["__cm_profile"]
            if sel and sel ~= "" then self:Save(sel) end
        end,
    })

    gb:AddButton({
        Text = "Delete Selected",
        Callback = function()
            local sel = self._axiui.Flags["__cm_profile"]
            if sel and sel ~= "" then self:Delete(sel) end
        end,
    })

    gb:AddDivider()

    gb:AddButton({
        Text = "Set as Default Profile",
        Callback = function()
            local sel = self._axiui.Flags["__cm_profile"]
            if sel and sel ~= "" then self:SetDefault(sel) end
        end,
    })

    gb:AddToggle("__cm_autosave", {
        Text     = "Auto-Save on Change",
        Default  = self._autoSave,
        Callback = function(val) self:SetAutoSave(val) end,
    })

    -- Mirror dropdown selection into the name input
    self._dd.OnStateChanged:Connect(function(name)
        if self._nameEl then self._nameEl:Set(name, true) end
    end)
end

function CM:ApplyToTab(tab)
    assert(tab, "[AxiUI CM] ApplyToTab: tab required")
    local gb = tab:AddGroupbox("Config Manager")
    self:BuildUI(gb)
    return gb
end

-- ═══════════════════════════════════════════════════════════════
--  UTILITIES
-- ═══════════════════════════════════════════════════════════════
function CM:PrintProfiles()
    local list = self:List()
    if #list == 0 then print("[AxiUI CM] No profiles for '" .. self._ns .. "'"); return end
    local m = self:_ReadManifest()
    print("[AxiUI CM] Profiles for '" .. self._ns .. "':")
    for _, name in ipairs(list) do
        print("  " .. name
            .. (name == m.default   and " [default]" or "")
            .. (name == self._current and " *" or ""))
    end
end

function CM:WipeAll()
    for _, name in ipairs(self:List()) do self:Delete(name) end
end

return CM
