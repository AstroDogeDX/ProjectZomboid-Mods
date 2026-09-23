--[[
    Butter Fingers — inventory right-click integration
    ------------------------------------------------------------------
    Adds a "Butter Fingers" submenu to the inventory context menu with a
    per-selected-type toggle ("Auto-drop X" / "Keep X") plus a shortcut to open
    the management window.
]]

BF = BF or {}
BF.ContextMenu = {}

function BF.ContextMenu.onToggle(_player, key, displayName)
    local nowTagged = BF.DropList.toggle(key)
    BF.halo(_player, nowTagged and ("Auto-dropping: " .. displayName) or ("Keeping: " .. displayName),
        not nowTagged)
end

function BF.ContextMenu.onOpenWindow(_player)
    if BF.UI and BF.UI.toggleMainWindow then BF.UI.toggleMainWindow() end
end

local function collectSelectedGroups(items)
    local seen, ordered = {}, {}
    for i = 1, #items do
        local entry = items[i]
        local item = entry
        if not instanceof(entry, "InventoryItem") then
            item = entry.items and entry.items[1] or nil
        end
        if item then
            local key = BF.DropList.keyOf(item)
            if key and not seen[key] then
                seen[key] = true
                ordered[#ordered + 1] = { key = key, name = key }
            end
        end
    end
    return ordered
end

function BF.ContextMenu.onFill(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    local groups = collectSelectedGroups(items)

    local parent = context:addOption("Butter Fingers", nil, nil)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(parent, sub)

    for _, g in ipairs(groups) do
        local tagged = BF.DropList.isTagged(g.key)
        local label = (tagged and "Keep " or "Auto-drop ") .. g.name
        local opt = sub:addOption(label, player, BF.ContextMenu.onToggle, g.key, g.name)
        if sub.setOptionChecked then sub:setOptionChecked(opt, tagged) end
    end

    sub:addOption("Open Butter Fingers panel", player, BF.ContextMenu.onOpenWindow)
end

Events.OnFillInventoryObjectContextMenu.Add(BF.ContextMenu.onFill)
