--[[
    Sticky Fingers — tag manager
    ------------------------------------------------------------------
    A "tag" marks an item *type* (fullType, e.g. "Base.556Box") for
    auto-looting. Tags are stored as a set in config.tags for O(1) lookup
    during the proximity scan.
]]

SF = SF or {}
SF.Tags = {}

-- Normalise anything we might be handed (InventoryItem, Item script, or a
-- raw string) down to a fullType string like "Base.Nails".
function SF.Tags.resolveType(itemOrType)
    if type(itemOrType) == "string" then
        return itemOrType
    end
    if itemOrType == nil then
        return nil
    end
    -- InventoryItem and Item script both expose getFullType() in B42.
    if itemOrType.getFullType then
        return itemOrType:getFullType()
    end
    return nil
end

function SF.Tags.isTagged(itemOrType)
    local fullType = SF.Tags.resolveType(itemOrType)
    if not fullType then return false end
    return SF.getData().tags[fullType] == true
end

function SF.Tags.add(itemOrType)
    local fullType = SF.Tags.resolveType(itemOrType)
    if not fullType then return end
    SF.getData().tags[fullType] = true
    SF.save()
    SF.log("Tagged", fullType)
end

function SF.Tags.remove(itemOrType)
    local fullType = SF.Tags.resolveType(itemOrType)
    if not fullType then return end
    SF.getData().tags[fullType] = nil
    SF.save()
    SF.log("Untagged", fullType)
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
end

-- Human-readable display name for a fullType, falling back to the raw type.
function SF.Tags.displayName(fullType)
    local script = getScriptManager():getItem(fullType)
    if script then
        return script:getDisplayName()
    end
    return fullType
end

-- Returns a sorted array of { type = fullType, name = displayName } for UI use.
function SF.Tags.getSortedList()
    local list = {}
    for fullType, on in pairs(SF.getData().tags) do
        if on then
            list[#list + 1] = { type = fullType, name = SF.Tags.displayName(fullType) }
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
