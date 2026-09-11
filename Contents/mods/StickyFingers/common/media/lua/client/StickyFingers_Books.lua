--[[
    Sticky Fingers — auto-loot unread literature
    ------------------------------------------------------------------
    Optional smart source: grab skill books, recipe magazines, leaflets and
    other literature the player hasn't consumed yet — while avoiding duplicates
    so you don't overload on five copies of the same book.

    "Useful/unread" delegates to vanilla ISInventoryPane:isLiteratureRead(), the
    same test the inventory uses to grey out finished books. It already handles:
      - skill books you've already out-levelled,
      - recipe magazines whose recipes you already know,
      - page-tracked / titled literature you've finished reading.
    isLiteratureRead ignores `self`, so we can call it as a plain function.

    Duplicate guard:
      - not already carrying a copy (getItemCountRecurse over the whole
        inventory, bags included), and
      - only one copy of a given type queued per scan (seenThisScan), so two
        copies on the same shelf don't both get grabbed.
]]

SF = SF or {}
SF.Books = {}

local seenThisScan = {}

-- Reset the per-scan dedupe set. Called once at the top of each looter scan.
function SF.Books.beginScan()
    seenThisScan = {}
end

function SF.Books.isUsefulLiterature(player, item)
    if not item or not item.IsLiterature or not item:IsLiterature() then return false end
    if ISInventoryPane and ISInventoryPane.isLiteratureRead then
        -- isLiteratureRead(self, playerObj, item) -> true if already read/known.
        return not ISInventoryPane.isLiteratureRead(ISInventoryPane, player, item)
    end
    return false
end

-- Should the auto-book feature grab this item right now?
function SF.Books.shouldGrab(player, item)
    if not SF.getData().autoLootBooks then return false end
    if not SF.Books.isUsefulLiterature(player, item) then return false end

    local fullType = item:getFullType()
    if seenThisScan[fullType] then return false end
    if player:getInventory():getItemCountRecurse(fullType) > 0 then return false end

    seenThisScan[fullType] = true
    return true
end
