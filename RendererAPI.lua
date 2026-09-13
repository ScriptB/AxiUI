--[[
    AxiUI — Renderer API v2.0.0
    Interface contract every custom renderer must implement.

    To write a custom renderer:
        1. Create a module table that implements every method below.
        2. Stub out methods you don't need with no-ops (not errors).
        3. Pass it to AxiUI:SetRenderer(yourRenderer).

    Visual state contract:
        - Core calls el:Set(default, true) immediately after MountXxx.
        - The renderer MUST update visuals from the OnStateChanged signal,
          not from its own Mount code. This ensures RemountAll works correctly.
]]

local RendererAPI = {}

-- ── Audio / Tween definitions (populate in your renderer) ───────
RendererAPI.Audio = {
    Hover = nil,  -- SoundId string; nil = silent
    Click = nil,
    Tick  = nil,
    Error = nil,
}

RendererAPI.Tweens = {
    Fast   = TweenInfo.new(0.08,  Enum.EasingStyle.Quart),
    Normal = TweenInfo.new(0.15,  Enum.EasingStyle.Quart),
    Slow   = TweenInfo.new(0.30,  Enum.EasingStyle.Quart),
}

-- ═══════════════════════════════════════════════════════════════
--  LIFECYCLE
-- ═══════════════════════════════════════════════════════════════

function RendererAPI:Init(core)
    --[[
        Called by AxiUI:SetRenderer() and AxiUI:RemountAll().
        Store reference to core. Create shared ScreenGuis (popup layer,
        notification holder, etc.) here.
        @param core  The AxiUI core table.
    ]]
    error("[AxiUI RendererAPI] Init not implemented")
end

function RendererAPI:Unload()
    --[[
        Destroy every ScreenGui and Instance created by this renderer.
        Disconnect every renderer-owned RBXScriptConnection.
        Called on AxiUI:Unload() and on ThemeManager renderer swap.
    ]]
    error("[AxiUI RendererAPI] Unload not implemented")
end

-- ═══════════════════════════════════════════════════════════════
--  WINDOW
-- ═══════════════════════════════════════════════════════════════

function RendererAPI:MountWindow(window)
    --[[
        Build the physical window.
        Expected to create and store on the window object:
            window.Gui          — ScreenGui
            window.Frame        — main background Frame
            window.ContentArea  — Frame that holds tab scroll frames
        Also make the window draggable via the TitleBar.
        Update window.Position when the user drags.
        @param window  Window data object from Core.
    ]]
    error("[AxiUI RendererAPI] MountWindow not implemented")
end

function RendererAPI:OnWindowToggled(window)
    --[[
        Called when the toggle key is pressed.
        window.Visible has already been flipped by Core.
        Default behaviour: set window.Gui.Enabled = window.Visible
        @param window  Window data object.
    ]]
    error("[AxiUI RendererAPI] OnWindowToggled not implemented")
end

-- ═══════════════════════════════════════════════════════════════
--  TAB
-- ═══════════════════════════════════════════════════════════════

function RendererAPI:MountTab(tab)
    --[[
        Build a tab button in window.TabRow and a ScrollingFrame
        in window.ContentArea. Hook the button click to call
        tab.Window:_SelectTab(tab).
        Expected to store:
            tab.Button  — TextButton in TabRow
            tab.Scroll  — ScrollingFrame in ContentArea
        @param tab  Tab data object from Core.
    ]]
    error("[AxiUI RendererAPI] MountTab not implemented")
end

function RendererAPI:OnTabSelected(tab)
    --[[
        Highlight the active tab button. Hide other tabs' ScrollFrames
        and show this one's.
        @param tab  The newly active Tab data object.
    ]]
    error("[AxiUI RendererAPI] OnTabSelected not implemented")
end

-- ═══════════════════════════════════════════════════════════════
--  GROUPBOX / SUBBOX
-- ═══════════════════════════════════════════════════════════════

function RendererAPI:MountGroupbox(groupbox)
    --[[
        Build a labelled container Frame inside groupbox.Tab.Scroll.
        Include a collapsible header with chevron.
        Expected to store:
            groupbox.Container  — outer Frame
            groupbox.Body       — inner Frame where elements are parented
        @param groupbox  Groupbox data object from Core.
    ]]
    error("[AxiUI RendererAPI] MountGroupbox not implemented")
end

function RendererAPI:MountSubBox(subbox)
    --[[
        Like MountGroupbox but visually inset; parented to
        subbox.ParentGroupbox.Body rather than a tab scroll.
        Expected to store:
            subbox.Container
            subbox.Body
        @param subbox  SubBox data object from Core (Type == "SubBox").
    ]]
    error("[AxiUI RendererAPI] MountSubBox not implemented")
end

-- ═══════════════════════════════════════════════════════════════
--  ELEMENTS
--  For every Mount method:
--    • Build the visual row parented to element.Groupbox.Body
--    • Hook user input → call element:Set(newValue)
--    • Connect element.OnStateChanged → update the visual
--    Core fires OnStateChanged immediately after mounting
--    with the default value (silent), so the visual handler
--    also sets the initial appearance.
-- ═══════════════════════════════════════════════════════════════

function RendererAPI:MountToggle(toggle)
    --[[
        Build a row with label + pill/thumb.
        Click → toggle:Set(not toggle.Value)
        OnStateChanged(val) → animate pill on/off
    ]]
    error("[AxiUI RendererAPI] MountToggle not implemented")
end

function RendererAPI:MountSlider(slider)
    --[[
        Build a row with label + track + fill + thumb + value label.
        Drag on track → slider:Set(computedValue)
        OnStateChanged(val) → update fill width, thumb position, value label
    ]]
    error("[AxiUI RendererAPI] MountSlider not implemented")
end

function RendererAPI:MountButton(button)
    --[[
        Build a styled button row.
        Click → button:Click()
    ]]
    error("[AxiUI RendererAPI] MountButton not implemented")
end

function RendererAPI:MountDropdown(dropdown)
    --[[
        Build a row with current-value label + chevron.
        Click → open a popup list of dropdown.Items.
        Item click → dropdown:Set(item); close popup.
        dropdown.OnStateChanged(val) → update current-value label.
        dropdown.OnItemsChanged(newItems) → rebuild popup list if open.
    ]]
    error("[AxiUI RendererAPI] MountDropdown not implemented")
end

function RendererAPI:MountInput(input)
    --[[
        Build a row with label + TextBox.
        TextBox change → input:Set(text)  (guard against re-entry)
        input.OnStateChanged(val) → update TextBox.Text if different
        Respect input.Numeric and input.Finished flags.
    ]]
    error("[AxiUI RendererAPI] MountInput not implemented")
end

function RendererAPI:MountKeybind(keybind)
    --[[
        Build a row with label + pill button showing current key name.
        Click pill → enter listening state → next KeyCode press calls keybind:Set(key)
        Escape cancels listening.
        keybind.OnStateChanged(key) → update pill text.
    ]]
    error("[AxiUI RendererAPI] MountKeybind not implemented")
end

function RendererAPI:MountColorPicker(colorPicker)
    --[[
        Build a row with label + colour swatch.
        Click swatch → open HSV popup.
        Popup change → colorPicker:Set(color)
        colorPicker.OnStateChanged(c) → update swatch BackgroundColor3.
    ]]
    error("[AxiUI RendererAPI] MountColorPicker not implemented")
end

function RendererAPI:MountLabel(label)
    --[[
        Build a non-interactive text row.
        Use label.Text, label.Size, label.Color, label.Align.
    ]]
    error("[AxiUI RendererAPI] MountLabel not implemented")
end

function RendererAPI:MountDivider(divider)
    --[[
        Build a 1px horizontal separator line.
    ]]
    error("[AxiUI RendererAPI] MountDivider not implemented")
end

-- ── Convenience dispatcher ──────────────────────────────────────

function RendererAPI:MountElement(element)
    local fn = self["Mount" .. (element.Type or "")]
    if fn then fn(self, element) end
end

-- ═══════════════════════════════════════════════════════════════
--  NOTIFICATIONS
-- ═══════════════════════════════════════════════════════════════

function RendererAPI:Notify(title, message, duration)
    --[[
        Display a floating notification (typically bottom-right).
        Auto-dismiss after duration seconds.
        @param title    string
        @param message  string
        @param duration number (seconds)
    ]]
    error("[AxiUI RendererAPI] Notify not implemented")
end

return RendererAPI
