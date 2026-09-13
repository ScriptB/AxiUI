# AxiUI

A universal, renderer-agnostic UI framework for Roblox executor scripts.  
Build once — swap the entire visual layer at runtime without touching your logic.

<br/>

## ⚡ Features

- **Renderer system** — swap the entire visual layer live with no code changes
- **Three built-in renderers** — Modern (glass), Basic (flat), Terminal (green-on-black CLI)
- **Write your own renderer** — implement one interface, drop it in, done
- **Zero visual code in core** — all logic lives separately from all visuals
- **Universal flag system** — every element writes to `AxiUI.Flags`, readable from anywhere
- **Full config manager** — named profiles, auto-save, custom type serialisation, extras
- **Binder addon** — wire Core's flag system to any Studio-built GUI without a renderer
- **All standard elements** — Toggle, Slider, Button, Dropdown, Input, Keybind, ColorPicker, Label, Divider

<br/>

## 🔌 Installation

Load **Core** and a **Renderer** — everything else is optional.

```lua
-- Core (required)
local AxiUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/ScriptB/AxiUI/main/AxiUI.lua"))()

-- Pick a renderer
local Modern   = loadstring(game:HttpGet("https://raw.githubusercontent.com/ScriptB/AxiUI/main/Renderers/Modern.lua"))()
local Basic    = loadstring(game:HttpGet("https://raw.githubusercontent.com/ScriptB/AxiUI/main/Renderers/Basic.lua"))()
local Terminal = loadstring(game:HttpGet("https://raw.githubusercontent.com/ScriptB/AxiUI/main/Renderers/Terminal.lua"))()

AxiUI:SetRenderer(Modern)
```

**Optional addons:**
```lua
-- Renderer swapper (swap the whole visual layer at runtime)
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/ScriptB/AxiUI/main/Addons/ThemeManager.lua"))()

-- Config profiles (save / load / auto-save)
local CM = loadstring(game:HttpGet("https://raw.githubusercontent.com/ScriptB/AxiUI/main/Addons/ConfigManager.lua"))()
CM:Init(AxiUI, "MyScript")

-- Binder (wire Core flags to your own Studio GUI, no renderer needed)
local Binder = loadstring(game:HttpGet("https://raw.githubusercontent.com/ScriptB/AxiUI/main/Addons/Binder.lua"))()
```

<br/>

## 📜 Usage

[Full example script →](https://github.com/ScriptB/AxiUI/blob/main/Example.lua)

<br/>

## 🎨 Renderers

| Renderer | Style | Colour themes |
|---|---|---|
| `Modern` | Translucent glass, tweened | 8 built-in (`Ocean`, `Rose`, `Midnight`, `Emerald`, `Neon`, `Carbon`, `Sunset`, `Default`) |
| `Basic` | Flat, zero transparency | — |
| `Terminal` | Green-on-black, ASCII borders | — |

**Swap renderers at runtime:**
```lua
ThemeManager:Register("Modern",   Modern)
ThemeManager:Register("Basic",    Basic)
ThemeManager:Register("Terminal", Terminal)

ThemeManager:Apply("Basic")   -- tears down Modern, remounts everything under Basic
```

**Colour themes within Modern (no tree crawling):**
```lua
Modern:ApplyColorTheme("Ocean")
Modern:ApplyColorTheme("Rose")
```

<br/>

## 🛠 Writing a Custom Renderer

Implement the interface defined in [`RendererAPI.lua`](https://github.com/ScriptB/AxiUI/blob/main/RendererAPI.lua):

```lua
local MyRenderer = {}

function MyRenderer:Init(core)          end  -- store core ref, create ScreenGuis
function MyRenderer:Unload()            end  -- destroy all instances + disconnect

function MyRenderer:MountWindow(win)    end  -- build the physical window
function MyRenderer:OnWindowToggled(w)  end  -- win.Visible already flipped by Core
function MyRenderer:MountTab(tab)       end  -- tab button + scroll frame
function MyRenderer:OnTabSelected(tab)  end  -- highlight active tab

function MyRenderer:MountGroupbox(gb)   end  -- container + collapsible header
function MyRenderer:MountSubBox(sb)     end  -- inset groupbox

function MyRenderer:MountToggle(el)     end
function MyRenderer:MountSlider(el)     end
function MyRenderer:MountButton(el)     end
function MyRenderer:MountDropdown(el)   end
function MyRenderer:MountInput(el)      end
function MyRenderer:MountKeybind(el)    end
function MyRenderer:MountColorPicker(el)end
function MyRenderer:MountLabel(el)      end
function MyRenderer:MountDivider(el)    end

function MyRenderer:Notify(title, msg, duration) end

return MyRenderer
```

Core calls `MountXxx` at element creation and fires `element.OnStateChanged` immediately after — connect your visual update in `MountXxx`, use `element:Set()` for input.

<br/>

## 💾 Config Manager

```lua
CM:Save("Combat")           -- write current flags to "Combat" profile
CM:Load("Combat")           -- restore all flags, fires element callbacks
CM:Delete("Combat")         -- remove profile
CM:List()                   -- { "Combat", "Rage", ... }
CM:SetDefault("Combat")     -- auto-loaded next run
CM:LoadDefault()            -- call at startup
CM:SetAutoSave(true, 2)     -- debounced auto-save every 2s

-- Optional UI (adapts to active renderer automatically)
CM:BuildUI(myGroupbox)
CM:ApplyToTab(myTab)

-- Custom type serialisation
CM:RegisterType("cframe",
    function(v) return typeof(v) == "CFrame" end,
    function(v) return { px=v.X, py=v.Y, pz=v.Z } end,
    function(d) return CFrame.new(d.px, d.py, d.pz) end
)

-- Non-flag extras
CM:RegisterExtra("windowPos",
    function()  return { x = win.Frame.Position.X.Offset, y = win.Frame.Position.Y.Offset } end,
    function(d) win.Frame.Position = UDim2.fromOffset(d.x, d.y) end
)
```

<br/>

## 🔗 Binder

Use Core's flag system with a GUI you built yourself — no renderer required:

```lua
Binder:BindToggle(myFrame, "SilentAim", {
    Default = false,
    OnStateChange = function(gui, enabled)
        gui.BackgroundColor3 = enabled and Color3.fromRGB(0,200,80)
                                        or Color3.fromRGB(60,55,80)
    end,
    Callback = function(v) print("SilentAim:", v) end,
})
```

All bound elements write to `AxiUI.Flags` and are compatible with `CM:Save` / `CM:Load`.

<br/>

## 📄 License

MIT
