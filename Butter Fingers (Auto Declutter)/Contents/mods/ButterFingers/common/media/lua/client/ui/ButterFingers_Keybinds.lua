--[[
    Butter Fingers — keybinds & hotkey entry points
    ------------------------------------------------------------------
    Registers three rebindable keys (Options > Key Bindings). Defaults are chosen
    to not clash with Sticky Fingers (L / K):
      • Open Butter Fingers panel  (default: J)
      • Toggle auto-declutter      (default: H)
      • Declutter now              (default: U)
]]

BF = BF or {}

local BIND_OPEN    = "Open Butter Fingers panel"
local BIND_MASTER  = "Toggle auto-declutter"
local BIND_NOW     = "Declutter now"

if keyBinding then
    table.insert(keyBinding, { value = "[Butter Fingers]" })
    table.insert(keyBinding, { value = BIND_OPEN,   key = Keyboard.KEY_J })
    table.insert(keyBinding, { value = BIND_MASTER, key = Keyboard.KEY_H })
    table.insert(keyBinding, { value = BIND_NOW,    key = Keyboard.KEY_U })
end

local function onKeyPressed(key)
    local core = getCore()
    if key == core:getKey(BIND_OPEN) then
        if BF.UI and BF.UI.toggleMainWindow then BF.UI.toggleMainWindow() end
    elseif key == core:getKey(BIND_MASTER) then
        local now = not BF.isMasterEnabled()
        BF.setMasterEnabled(now)
        BF.halo(getPlayer(), now and "Auto-declutter ON" or "Auto-declutter OFF", now)
        if BF.UI and BF.UI.refreshIfOpen then BF.UI.refreshIfOpen() end
    elseif key == core:getKey(BIND_NOW) then
        BF.Dumper.declutterNow(getPlayer())
    end
end

Events.OnKeyPressed.Add(onKeyPressed)
