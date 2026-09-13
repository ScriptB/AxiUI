-- AxiUI RendererAPI v2.0.0 — interface contract for custom renderers
-- See README for the full contract. Implement every method; stub with no-ops for ones you skip.
-- Key rule: connect visuals via element.OnStateChanged inside MountXxx, never read state directly.

local RendererAPI = {}

RendererAPI.Audio  = { Hover = nil, Click = nil, Tick = nil, Error = nil }
RendererAPI.Tweens = {
    Fast   = TweenInfo.new(0.08, Enum.EasingStyle.Quart),
    Normal = TweenInfo.new(0.15, Enum.EasingStyle.Quart),
    Slow   = TweenInfo.new(0.30, Enum.EasingStyle.Quart),
}

-- ── Lifecycle ────────────────────────────────────────────────
function RendererAPI:Init(core)   error("[AxiUI RendererAPI] Init not implemented")   end
function RendererAPI:Unload()     error("[AxiUI RendererAPI] Unload not implemented") end

-- ── Window ───────────────────────────────────────────────────
-- MountWindow: create ScreenGui, build window.Gui / window.Frame / window.ContentArea, make draggable
function RendererAPI:MountWindow(window)      error("[AxiUI RendererAPI] MountWindow not implemented")     end
-- OnWindowToggled: window.Visible already flipped — show/hide window.Gui
function RendererAPI:OnWindowToggled(window)  error("[AxiUI RendererAPI] OnWindowToggled not implemented") end

-- ── Tab ───────────────────────────────────────────────────────
-- MountTab: build tab button + scroll frame; click → win:_SelectTab(tab)
function RendererAPI:MountTab(tab)        error("[AxiUI RendererAPI] MountTab not implemented")       end
-- OnTabSelected: highlight active button, show its scroll, hide others
function RendererAPI:OnTabSelected(tab)   error("[AxiUI RendererAPI] OnTabSelected not implemented")  end

-- ── Groupbox / SubBox ─────────────────────────────────────────
-- MountGroupbox: collapsible container in tab.Scroll; store gb.Container + gb.Body
function RendererAPI:MountGroupbox(gb)    error("[AxiUI RendererAPI] MountGroupbox not implemented")  end
-- MountSubBox: inset groupbox inside sb.ParentGroupbox.Body
function RendererAPI:MountSubBox(sb)      error("[AxiUI RendererAPI] MountSubBox not implemented")    end

-- ── Elements ─────────────────────────────────────────────────
-- Each Mount: build row in element.Groupbox.Body, hook input → element:Set(),
-- connect element.OnStateChanged → update visual (Core fires it after mounting).
function RendererAPI:MountToggle(el)       error("[AxiUI RendererAPI] MountToggle not implemented")      end
function RendererAPI:MountSlider(el)       error("[AxiUI RendererAPI] MountSlider not implemented")      end
function RendererAPI:MountButton(el)       error("[AxiUI RendererAPI] MountButton not implemented")      end
function RendererAPI:MountDropdown(el)     error("[AxiUI RendererAPI] MountDropdown not implemented")    end
function RendererAPI:MountInput(el)        error("[AxiUI RendererAPI] MountInput not implemented")       end
function RendererAPI:MountKeybind(el)      error("[AxiUI RendererAPI] MountKeybind not implemented")     end
function RendererAPI:MountColorPicker(el)  error("[AxiUI RendererAPI] MountColorPicker not implemented") end
function RendererAPI:MountLabel(el)        error("[AxiUI RendererAPI] MountLabel not implemented")       end
function RendererAPI:MountDivider(el)      error("[AxiUI RendererAPI] MountDivider not implemented")     end

-- Convenience dispatcher
function RendererAPI:MountElement(element)
    local fn = self["Mount" .. (element.Type or "")]
    if fn then fn(self, element) end
end

-- ── Notifications ─────────────────────────────────────────────
function RendererAPI:Notify(title, message, duration)
    error("[AxiUI RendererAPI] Notify not implemented")
end

return RendererAPI
