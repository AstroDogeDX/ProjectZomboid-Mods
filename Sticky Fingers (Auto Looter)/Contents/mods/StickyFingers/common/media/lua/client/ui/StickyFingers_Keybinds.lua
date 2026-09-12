--[[
    Sticky Fingers — keybinds & hotkey entry points
    ------------------------------------------------------------------
    Registers two rebindable keys (Options > Key Bindings):
      • Open Sticky Fingers panel   (default: L)
      • Toggle auto-looting         (default: K)
]]

SF = SF or {}

local BIND_OPEN   = "Open Sticky Fingers panel"
local BIND_MASTER = "Toggle auto-looting"

-- Register into the vanilla key-binding list (shown in the Options screen).
-- Guarded in case load order ever changes.
if keyBinding then
    table.insert(keyBinding, { value = "[Sticky Fingers]" })
    table.insert(keyBinding, { value = BIND_OPEN,   key = Keyboard.KEY_L })
    table.insert(keyBinding, { value = BIND_MASTER, key = Keyboard.KEY_K })
end

local function onKeyPressed(key)
    local core = getCore()
    if key == core:getKey(BIND_OPEN) then
        SF.UI.toggleMainWindow()
    elseif key == core:getKey(BIND_MASTER) then
        local now = not SF.isMasterEnabled()
        SF.setMasterEnabled(now)
        SF.halo(getPlayer(), now and "Auto-looting ON" or "Auto-looting OFF", now)
        -- Keep an open window's master tick in sync.
        if SF.UI.instance and SF.UI.instance.masterTick then
            SF.UI.instance.masterTick:setSelected(1, now)
        end
    end
end

Events.OnKeyPressed.Add(onKeyPressed)
