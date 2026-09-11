--[[
    Sticky Fingers — inventory right-click integration
    ------------------------------------------------------------------
    Adds a "Sticky Fingers" submenu to the inventory context menu with a
    per-selected-type toggle ("Auto-loot X" / "Stop auto-looting X") plus a
    shortcut to open the management window.
]]

SF = SF or {}
SF.ContextMenu = {}

-- Callback: target is passed first by ISContextMenu, then our params.
function SF.ContextMenu.onToggle(_player, fullType, displayName)
    local nowTagged = SF.Tags.toggle(fullType)
    if HaloTextHelper and _player then
        local msg = nowTagged
            and ("Auto-looting: " .. displayName)
            or  ("Stopped: " .. displayName)
        HaloTextHelper.addText(_player, msg,
            nowTagged and HaloTextHelper.getColorGreen() or HaloTextHelper.getColorRed())
    end
end

function SF.ContextMenu.onOpenWindow(_player)
    if SF.UI and SF.UI.toggleMainWindow then
        SF.UI.toggleMainWindow()
    end
end

-- Reduce a context-menu selection (which may contain stacks/tables) to a
-- de-duplicated, ordered list of { type, name }.
local function collectSelectedTypes(items)
    local seen, ordered = {}, {}
    for i = 1, #items do
        local entry = items[i]
        local item = entry
        if not instanceof(entry, "InventoryItem") then
            item = entry.items and entry.items[1] or nil
        end
        if item then
            local ft = item:getFullType()
            if ft and not seen[ft] then
                seen[ft] = true
                ordered[#ordered + 1] = { type = ft, name = item:getName() }
            end
        end
    end
    return ordered
end

function SF.ContextMenu.onFill(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    local types = collectSelectedTypes(items)

    local parent = context:addOption("Sticky Fingers", nil, nil)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(parent, sub)

    for _, t in ipairs(types) do
        local tagged = SF.Tags.isTagged(t.type)
        local label = (tagged and "Stop auto-looting " or "Auto-loot ") .. t.name
        local opt = sub:addOption(label, player, SF.ContextMenu.onToggle, t.type, t.name)
        -- Reflect current state with a checkmark where the engine supports it.
        if sub.setOptionChecked then
            sub:setOptionChecked(opt, tagged)
        end
    end

    if #types > 0 then
        sub:addOption("—", nil, nil)  -- lightweight visual separator
    end
    sub:addOption("Open Sticky Fingers…", player, SF.ContextMenu.onOpenWindow)
end

Events.OnFillInventoryObjectContextMenu.Add(SF.ContextMenu.onFill)
