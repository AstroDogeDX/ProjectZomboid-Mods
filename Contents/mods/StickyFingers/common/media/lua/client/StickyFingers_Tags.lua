--[[
    Sticky Fingers — tag manager
    ------------------------------------------------------------------
    A "tag" marks an item for auto-looting by its DISPLAY NAME (the same key the
    vanilla inventory groups stacks by), so tagging one variant collects them
    all (see the variant-grouping notes elsewhere).

    Each tag carries per-item settings:
        config.tags[displayName] = { max = number|nil, autoRemove = bool }
      - max        : stop looting this once you carry this many (nil = forever).
      - autoRemove : drop the tag from the list once max is reached
                     (a "shopping list" entry).
    New tags default to { max = nil, autoRemove = false } — loot forever.
]]

SF = SF or {}
SF.Tags = {}

-- Notify an open management window that the tag SET changed (add/remove/clear).
-- Per-entry edits (setMax/setAutoRemove) deliberately don't fire this — the
-- panel updates the affected row in place so it doesn't fight live editing.
local function notifyUI()
    if SF.UI and SF.UI.refreshIfOpen then
        SF.UI.refreshIfOpen()
    end
end

-- InventoryItem, Item script, or raw string -> group key (display name).
function SF.Tags.keyOf(itemOrType)
    if itemOrType == nil then return nil end
    if type(itemOrType) == "string" then return itemOrType end
    if itemOrType.getDisplayName then return itemOrType:getDisplayName() end
    return nil
end

function SF.Tags.isTagged(itemOrType)
    local key = SF.Tags.keyOf(itemOrType)
    return key ~= nil and SF.getData().tags[key] ~= nil
end

-- Normalised settings record for a key (nil if not tagged). Legacy `true`
-- values (pre-migration safety) read as an unlimited record.
function SF.Tags.getEntry(key)
    local e = SF.getData().tags[key]
    if e == nil then return nil end
    if type(e) ~= "table" then return { max = nil, autoRemove = false } end
    return e
end

local function ensureRecord(key)
    local tags = SF.getData().tags
    if type(tags[key]) ~= "table" then
        tags[key] = { max = nil, autoRemove = false }
    end
    return tags[key]
end

function SF.Tags.add(itemOrType)
    local key = SF.Tags.keyOf(itemOrType)
    if not key then return end
    if SF.getData().tags[key] == nil then
        SF.getData().tags[key] = { max = nil, autoRemove = false }
    end
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

-- Per-entry edits (no notifyUI — see note above).
function SF.Tags.setMax(key, n)
    if not key then return end
    ensureRecord(key).max = (n and n > 0) and math.floor(n) or nil
    SF.save()
end

function SF.Tags.setAutoRemove(key, enabled)
    if not key then return end
    ensureRecord(key).autoRemove = (enabled == true)
    SF.save()
end

-- Sorted array of { key, name, max, autoRemove } for the UI list.
function SF.Tags.getSortedList()
    local list = {}
    for key, e in pairs(SF.getData().tags) do
        if e ~= nil then
            local rec = type(e) == "table" and e or {}
            list[#list + 1] = { key = key, name = key, max = rec.max, autoRemove = rec.autoRemove == true }
        end
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end

function SF.Tags.count()
    local n = 0
    for _ in pairs(SF.getData().tags) do n = n + 1 end
    return n
end

-- Any tag using a max / auto-remove? Lets the looter skip the inventory walk
-- entirely when nobody's using the shopping-list feature.
function SF.Tags.hasLimits()
    for _, e in pairs(SF.getData().tags) do
        if type(e) == "table" and (e.max or e.autoRemove) then return true end
    end
    return false
end

-- Count how many of each TAGGED display name the player currently carries
-- (whole inventory, bags included). Returns a { [displayName] = count } map
-- restricted to tagged names so it stays small.
function SF.Tags.buildInventoryCounts(player)
    local counts = {}
    local tags = SF.getData().tags
    local function walk(container)
        if not container then return end
        local items = container:getItems()
        if not items then return end
        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it then
                local nm = it:getDisplayName()
                if nm and tags[nm] ~= nil then
                    counts[nm] = (counts[nm] or 0) + 1
                end
                local sub = it.getInventory and it:getInventory()  -- bag contents
                if sub then walk(sub) end
            end
        end
    end
    walk(player:getInventory())
    return counts
end
