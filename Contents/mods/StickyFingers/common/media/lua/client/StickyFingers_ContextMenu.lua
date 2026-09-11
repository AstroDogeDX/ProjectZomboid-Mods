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
function SF.ContextMenu.onToggle(_player, key, displayName)
    local nowTagged = SF.Tags.toggle(key)
    local msg = nowTagged
        and ("Auto-looting: " .. displayName)
        or  ("Stopped: " .. displayName)
    SF.halo(_player, msg, nowTagged)
end

function SF.ContextMenu.onOpenWindow(_player)
    if SF.UI and SF.UI.toggleMainWindow then
        SF.UI.toggleMainWindow()
    end
end

-- Reduce a context-menu selection (which may contain stacks/tables) to a
-- de-duplicated, ordered list of { key, name } grouped by inventory name — the
-- same grouping the inventory uses, so selecting two variants shows one entry
-- (and an "Empty X" is its own entry, distinct from the full "X").
local function collectSelectedGroups(items)
    local seen, ordered = {}, {}
    for i = 1, #items do
        local entry = items[i]
        local item = entry
        if not instanceof(entry, "InventoryItem") then
            item = entry.items and entry.items[1] or nil
        end
        if item then
            local key = SF.Tags.keyOf(item)
            if key and not seen[key] then
                seen[key] = true
                ordered[#ordered + 1] = { key = key, name = key }
            end
        end
    end
    return ordered
end

function SF.ContextMenu.onFill(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    local groups = collectSelectedGroups(items)

    local parent = context:addOption("Sticky Fingers", nil, nil)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(parent, sub)

    for _, g in ipairs(groups) do
        local tagged = SF.Tags.isTagged(g.key)
        local label = (tagged and "Stop auto-looting " or "Auto-loot ") .. g.name
        local opt = sub:addOption(label, player, SF.ContextMenu.onToggle, g.key, g.name)
        -- Reflect current state with a checkmark where the engine supports it.
        if sub.setOptionChecked then
            sub:setOptionChecked(opt, tagged)
        end
    end

    sub:addOption("Open Sticky Fingers panel", player, SF.ContextMenu.onOpenWindow)
end

Events.OnFillInventoryObjectContextMenu.Add(SF.ContextMenu.onFill)
