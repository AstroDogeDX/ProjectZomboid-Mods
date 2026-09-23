--[[
    Butter Fingers — drop-list (tag) manager
    ------------------------------------------------------------------
    A "drop tag" marks an item type for auto-dropping, keyed the same way Sticky
    Fingers tags for looting: by the item's display-name group. The keyOf() rule
    strips a trailing cosmetic-condition decoration ("<base> (Bloody)"/"(Dull)"/
    "(Worn)"/etc.) so every condition of an item groups under one tag, while an
    "Empty ..." rename or a custom name stays a distinct entry.

    Kept independent of Sticky Fingers (BF must work with SF absent), so the
    keying logic is duplicated here rather than shared.
]]

BF = BF or {}
BF.DropList = {}

local function notifyUI()
    if BF.UI and BF.UI.refreshIfOpen then BF.UI.refreshIfOpen() end
end

-- InventoryItem, Item script, or raw string -> group key. See header for the
-- condition-decoration handling.
function BF.DropList.keyOf(itemOrType)
    if itemOrType == nil then return nil end
    if type(itemOrType) == "string" then return itemOrType end
    if instanceof(itemOrType, "InventoryItem") then
        local base = itemOrType:getDisplayName()
        local full = itemOrType:getName()
        if base and full and full ~= base and full:sub(1, #base + 2) == base .. " (" then
            return base
        end
        return full
    end
    if itemOrType.getDisplayName then return itemOrType:getDisplayName() end
    return nil
end

function BF.DropList.isTagged(itemOrType)
    local key = BF.DropList.keyOf(itemOrType)
    return key ~= nil and BF.getData().tags[key] == true
end

function BF.DropList.add(itemOrType)
    local key = BF.DropList.keyOf(itemOrType)
    if not key then return end
    BF.getData().tags[key] = true
    BF.save(); BF.log("Drop-tagged", key); notifyUI()
end

function BF.DropList.remove(itemOrType)
    local key = BF.DropList.keyOf(itemOrType)
    if not key then return end
    BF.getData().tags[key] = nil
    BF.save(); BF.log("Un-drop-tagged", key); notifyUI()
end

-- Returns the new state (true = now tagged for dropping).
function BF.DropList.toggle(itemOrType)
    if BF.DropList.isTagged(itemOrType) then
        BF.DropList.remove(itemOrType)
        return false
    end
    BF.DropList.add(itemOrType)
    return true
end

function BF.DropList.clear()
    BF.getData().tags = {}
    BF.save(); notifyUI()
end

-- Sorted array of { key, name } for the UI list.
function BF.DropList.getSortedList()
    local list = {}
    for key, on in pairs(BF.getData().tags) do
        if on then list[#list + 1] = { key = key, name = key } end
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end

function BF.DropList.count()
    local n = 0
    for _, on in pairs(BF.getData().tags) do if on then n = n + 1 end end
    return n
end
