--[[
    Sticky Fingers — tag manager
    ------------------------------------------------------------------
    A "tag" marks an item for auto-looting by its DISPLAY NAME, which is the
    exact key the vanilla inventory uses to group stacks
    (ISInventoryPane keys itemsByName on item:getDisplayName()). Tagging one
    variant therefore auto-collects every variant that groups with it in the
    inventory — e.g. tagging a black "Digital Watch" also grabs the red one,
    and tagging one "Energy Drink" grabs every branded variant.

    Stored as a set: config.tags[displayName] = true, for O(1) lookup.
]]

SF = SF or {}
SF.Tags = {}

-- Notify an open management window that the tag set changed, so its lists
-- refresh live (context menu, search add, and remove all funnel through here).
local function notifyUI()
    if SF.UI and SF.UI.refreshIfOpen then
        SF.UI.refreshIfOpen()
    end
end

-- Normalise anything we might be handed (InventoryItem, Item script, or a raw
-- display-name string) down to the group key (a display name).
function SF.Tags.keyOf(itemOrType)
    if itemOrType == nil then return nil end
    if type(itemOrType) == "string" then return itemOrType end
    if itemOrType.getDisplayName then return itemOrType:getDisplayName() end
    return nil
end

function SF.Tags.isTagged(itemOrType)
    local key = SF.Tags.keyOf(itemOrType)
    return key ~= nil and SF.getData().tags[key] == true
end

function SF.Tags.add(itemOrType)
    local key = SF.Tags.keyOf(itemOrType)
    if not key then return end
    SF.getData().tags[key] = true
    SF.save()
    SF.log("Tagged", key)
    notifyUI()
end

function SF.Tags.remove(itemOrType)
    local key = SF.Tags.keyOf(itemOrType)
    if not key then return end
    SF.getData().tags[key] = nil
    SF.save()
    SF.log("Untagged", key)
    notifyUI()
end

-- Returns the new tagged state (true = now tagged).
function SF.Tags.toggle(itemOrType)
    if SF.Tags.isTagged(itemOrType) then
        SF.Tags.remove(itemOrType)
        return false
    else
        SF.Tags.add(itemOrType)
        return true
    end
end

function SF.Tags.clear()
    SF.getData().tags = {}
    SF.save()
    notifyUI()
end

-- Sorted array of { key = displayName, name = displayName } for UI lists.
function SF.Tags.getSortedList()
    local list = {}
    for key, on in pairs(SF.getData().tags) do
        if on then
            list[#list + 1] = { key = key, name = key }
        end
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end

function SF.Tags.count()
    local n = 0
    for _, on in pairs(SF.getData().tags) do
        if on then n = n + 1 end
    end
    return n
end
