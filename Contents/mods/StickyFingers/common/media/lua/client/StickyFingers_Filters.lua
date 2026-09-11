--[[
    Sticky Fingers — item quality filters
    ------------------------------------------------------------------
    Optional global filters applied on top of tagging: even if an item's type
    is tagged, these can veto the grab based on the specific item's condition.

      - ignoreNonFreshFood : skip stale / rotten / burnt food. PZ has no
        isStale(); staleness is simply "not fresh and not rotten", so
        `not isFresh()` already covers both stale and rotten. Burnt is separate
        (a freshly-burnt item can still be "fresh" age-wise). Freshness methods
        are Food-only, so they're guarded by instanceof(item, "Food") exactly as
        vanilla does (CFarming_Interact.lua).
      - ignoreBroken : skip broken items. isBroken() is a base InventoryItem
        method. Note broken items keep the same display name as working ones, so
        without this filter a tagged type would also collect its broken copies.
]]

SF = SF or {}
SF.Filters = {}

function SF.Filters.isNonFreshFood(item)
    if not instanceof(item, "Food") then return false end
    if item.isBurnt and item:isBurnt() then return true end
    return not item:isFresh()   -- stale or rotten
end

function SF.Filters.isBroken(item)
    return item.isBroken and item:isBroken() == true
end

-- True if this specific item should be skipped despite being tagged.
function SF.Filters.blocked(item)
    local data = SF.getData()
    if data.ignoreBroken and SF.Filters.isBroken(item) then return true end
    if data.ignoreNonFreshFood and SF.Filters.isNonFreshFood(item) then return true end
    return false
end
