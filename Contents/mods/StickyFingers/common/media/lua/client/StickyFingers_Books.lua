--[[
    Sticky Fingers — auto-loot unread literature
    ------------------------------------------------------------------
    Optional smart source: grab skill books, recipe magazines, leaflets and
    other literature the player hasn't consumed yet — while avoiding duplicates
    so you don't overload on five copies of the same book.

    We only want SKILL BOOKS and RECIPE PROVIDERS (magazines / leaflets that
    teach crafting), not plain fiction. So there are two tests:
      1. Type gate (teachesSkillOrRecipe): the item trains a skill (SkillBook[])
         or teaches at least one recipe (getLearnedRecipes / modData.learnedRecipe).
      2. Not-yet-consumed: delegated to vanilla ISInventoryPane:isLiteratureRead(),
         the same test the inventory uses to grey out finished books — it handles
         out-levelled skill books, already-known recipes, and fully-read pages.
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

-- Type gate: does this literature train a skill or teach a recipe? (Excludes
-- plain fiction / newspapers / comics with no skill or recipe payload.)
function SF.Books.teachesSkillOrRecipe(item)
    local trained = item.getSkillTrained and item:getSkillTrained()
    if trained and SkillBook and SkillBook[trained] then return true end

    local learned = item.getLearnedRecipes and item:getLearnedRecipes()
    if learned and learned:size() > 0 then return true end

    if item.hasModData and item:hasModData() then
        local md = item:getModData()
        if md and md.learnedRecipe then return true end
    end
    return false
end

function SF.Books.isDesiredLiterature(player, item)
    if not item or not item.IsLiterature or not item:IsLiterature() then return false end
    if not SF.Books.teachesSkillOrRecipe(item) then return false end        -- skill/recipe only
    if ISInventoryPane and ISInventoryPane.isLiteratureRead then
        -- isLiteratureRead(self, playerObj, item) -> true if already read/known.
        return not ISInventoryPane.isLiteratureRead(ISInventoryPane, player, item)
    end
    return false
end

-- Should the auto-book feature grab this item right now?
function SF.Books.shouldGrab(player, item)
    if not SF.getData().autoLootBooks then return false end
    if not SF.Books.isDesiredLiterature(player, item) then return false end

    local fullType = item:getFullType()
    if seenThisScan[fullType] then return false end
    if player:getInventory():getItemCountRecurse(fullType) > 0 then return false end

    seenThisScan[fullType] = true
    return true
end
