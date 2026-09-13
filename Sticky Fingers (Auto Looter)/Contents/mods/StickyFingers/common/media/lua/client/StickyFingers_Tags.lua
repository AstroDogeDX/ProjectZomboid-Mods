--[[
    Sticky Fingers — tag manager
    ------------------------------------------------------------------
    A "tag" marks an item for auto-looting by its inventory NAME — the exact key
    the vanilla inventory stacks by (ISInventoryPane keys stacks on
    item:getName(player), not the base display name). So tagging one variant
    collects everything that stacks with it, and — crucially — a depleted item
    that the game renames (e.g. "Empty Cleaning Liquid Bottle" vs "Cleaning
    Liquid Bottle") is treated as a DIFFERENT entry, so it isn't looted just
    because the full version is tagged.

    For an Item *script* (search tab) only the base display name is available;
    that equals getName() for a normal/full item, so tagging still matches.

    CONDITION STATES: getName() appends a cosmetic state as "<base> (state)" via
    the "%1 (%2)" format — (Bloody)/(Dirty)/(Wet)/(Worn) on clothing, (Dull) on
    blades, and even (Bloody) on a plain tool like a screwdriver. Keying on that
    would treat a bloody/dull item as a different entry from the clean tag, so it
    would silently never be looted. keyOf() therefore falls back to the
    undecorated base name whenever getName() is only the base plus an appended
    "(...)", grouping every condition under one tag. These states aren't "broken"
    and aren't touched by the quality filters — broken (literally unusable),
    non-fresh food, and empty are separate opt-in toggles.

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

-- InventoryItem, Item script, or raw string -> group key.
--   InventoryItem : getName() (the runtime name the inventory stacks by — carries
--                   the "Empty" prefix, fluid contents, custom names), EXCEPT when
--                   the only decoration is an appended "(state)" condition, in
--                   which case the undecorated getDisplayName() is used so every
--                   condition groups under one tag (see the header note).
--   Item script   : getDisplayName() — base name (== getName() when full).
--   string        : already a key.
function SF.Tags.keyOf(itemOrType)
    if itemOrType == nil then return nil end
    if type(itemOrType) == "string" then return itemOrType end
    if instanceof(itemOrType, "InventoryItem") then
        local base = itemOrType:getDisplayName()
        local full = itemOrType:getName()
        -- Strip a trailing cosmetic-condition decoration: getName() appends state
        -- as "<base> (state)" via the "%1 (%2)" format. When that's the only
        -- difference from the base name, key on the base so (Bloody)/(Dull)/
        -- (Worn)/(Dirty)/(Wet) etc. all group under one tag. Any other rename
        -- ("Empty ..." prefix, fluid contents, a custom name) doesn't fit that
        -- shape and keeps getName(), staying a distinct entry.
        if base and full and full ~= base and full:sub(1, #base + 2) == base .. " (" then
            return base
        end
        return full
    end
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

-- Count how many of each TAGGED key the player currently carries (whole
-- inventory, bags included). Keyed by the same getName() the tags use, so an
-- "Empty X" is counted separately from "X". Restricted to tagged keys so it
-- stays small.
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
                local nm = SF.Tags.keyOf(it)
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
