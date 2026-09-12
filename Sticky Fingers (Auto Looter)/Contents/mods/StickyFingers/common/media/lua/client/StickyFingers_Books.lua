--[[
    Sticky Fingers — auto-loot unread literature
    ------------------------------------------------------------------
    Optional smart source: grab skill books, recipe magazines, leaflets and
    other literature the player hasn't consumed yet — while avoiding duplicates
    so you don't overload on five copies of the same book.

    We only want SKILL BOOKS and RECIPE PROVIDERS (magazines / leaflets that
    teach crafting), not plain fiction — and the two are handled differently:

      Skill books: only grabbed if READABLE AT THE CURRENT LEVEL (mirrors the
        vanilla read-menu gates — not "too complicated" for a low skill, not
        "too simple" from being out-levelled) and not already read. This stops
        us hoarding Vol 3-5 while still at level 0.

      Recipe magazines / leaflets: grabbed while they still teach a recipe you
        don't know (vanilla ISInventoryPane:isLiteratureRead, which ignores
        `self`, is the "already known/read" test).

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

-- Skill-book descriptor for this item (or nil if it isn't one).
local function skillBookOf(item)
    local trained = item.getSkillTrained and item:getSkillTrained()
    if trained and SkillBook and SkillBook[trained] then
        return SkillBook[trained]
    end
    return nil
end

-- Does this literature teach a crafting recipe (magazine / leaflet / schematic)?
local function teachesRecipe(item)
    local learned = item.getLearnedRecipes and item:getLearnedRecipes()
    if learned and learned:size() > 0 then return true end
    if item.hasModData and item:hasModData() then
        local md = item:getModData()
        if md and md.learnedRecipe then return true end
    end
    return false
end

-- Already read / known? Delegated to vanilla (handles out-levelled skill books,
-- fully-read pages, and already-known recipes). isLiteratureRead ignores `self`.
local function isRead(player, item)
    if ISInventoryPane and ISInventoryPane.isLiteratureRead then
        return ISInventoryPane.isLiteratureRead(ISInventoryPane, player, item)
    end
    return false
end

-- Can this skill book actually be read at the player's CURRENT level? Mirrors
-- the vanilla read-menu gates (ISInventoryPaneContextMenu):
--   too complicated : getLvlSkillTrained() > perkLevel + 1
--   too simple      : getMaxLevelTrained() <= perkLevel
function SF.Books.isReadableSkillBookNow(player, sb, item)
    if not sb or not sb.perk then return false end
    local lvl = player:getPerkLevel(sb.perk)
    local minTrained = item:getLvlSkillTrained()
    local maxTrained = item:getMaxLevelTrained()
    if minTrained == -1 or maxTrained == -1 then return false end
    if minTrained > lvl + 1 then return false end   -- too advanced to read yet
    if maxTrained <= lvl then return false end       -- already out-levelled
    return true
end

function SF.Books.isDesiredLiterature(player, item)
    if not item or not item.IsLiterature or not item:IsLiterature() then return false end

    local sb = skillBookOf(item)
    if sb then
        -- Skill books: only ones we can read at our current level, and not
        -- already read.
        return SF.Books.isReadableSkillBookNow(player, sb, item) and not isRead(player, item)
    end

    -- Recipe magazines / leaflets: grab while they still teach something new.
    if teachesRecipe(item) then
        return not isRead(player, item)
    end

    return false   -- plain fiction / no skill or recipe payload
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
