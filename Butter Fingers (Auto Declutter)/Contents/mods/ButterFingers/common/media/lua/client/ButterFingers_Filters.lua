--[[
    Butter Fingers — predefined drop categories
    ------------------------------------------------------------------
    Functional tests for the built-in "junk" categories, mirroring (and in the
    literature case, inverting) Sticky Fingers' detection so behaviour is
    consistent between the two mods.

      - isEmpty          : a fluid container run dry, or a drainable with no uses
                           left (soda cans, cleaning-liquid bottles, etc.).
      - isBroken         : the item is literally broken. NOTE: "broken" here means
                           the game's unusable state, not merely "dull" or "worn"
                           — a dull/worn item is still useful and is NOT dropped by
                           this category.
      - isReadLiterature : a skill book the player has already read out, or a
                           recipe magazine/leaflet whose recipes are all known.
]]

BF = BF or {}
BF.Filters = {}

function BF.Filters.isEmpty(item)
    if not item then return false end
    if item.getFluidContainer then
        local fc = item:getFluidContainer()
        if fc and (fc:isEmpty() or (fc.getAmount and fc:getAmount() <= 0)) then
            return true
        end
    end
    if instanceof(item, "DrainableComboItem")
        and item.getCurrentUsesFloat and item:getCurrentUsesFloat() <= 0 then
        return true
    end
    return false
end

function BF.Filters.isBroken(item)
    return item and item.isBroken and item:isBroken() == true
end

-- Already read/known? Uses the same vanilla test Sticky Fingers relies on
-- (ISInventoryPane.isLiteratureRead ignores `self`): handles out-levelled skill
-- books, fully-read pages, and already-known recipes.
local function isRead(player, item)
    if ISInventoryPane and ISInventoryPane.isLiteratureRead then
        return ISInventoryPane.isLiteratureRead(ISInventoryPane, player, item)
    end
    return false
end

local function teachesRecipe(item)
    local learned = item.getLearnedRecipes and item:getLearnedRecipes()
    if learned and learned:size() > 0 then return true end
    if item.hasModData and item:hasModData() then
        local md = item:getModData()
        if md and md.learnedRecipe then return true end
    end
    return false
end

local function isSkillBook(item)
    local trained = item.getSkillTrained and item:getSkillTrained()
    return trained ~= nil and SkillBook and SkillBook[trained] ~= nil
end

-- True if this is literature whose value the player has already extracted, so
-- keeping it is just hoarding.
function BF.Filters.isReadLiterature(player, item)
    if not item or not item.IsLiterature or not item:IsLiterature() then return false end
    if not (isSkillBook(item) or teachesRecipe(item)) then return false end  -- plain fiction: keep
    return isRead(player, item)
end

------------------------------------------------------------------
-- Inherent-capability checks (state-independent)
--   Used by smart-protect: they answer "could this item EVER be an auto-drop
--   target by category?", regardless of its current state — so picking up a
--   FULL bottle protects it before it's ever emptied.
------------------------------------------------------------------

-- Can hold/lose a fluid or uses: a fluid container (bottle, canteen, can) or a
-- drainable (cleaning liquid, etc.), full or empty.
function BF.Filters.isEmptyable(item)
    if not item then return false end
    if item.getFluidContainer and item:getFluidContainer() ~= nil then return true end
    if instanceof(item, "DrainableComboItem") then return true end
    return false
end

-- Has a condition track, so it can degrade to "broken" (weapons, tools,
-- clothing). Non-conditioned items (food, materials, ammo) report 0.
function BF.Filters.isBreakable(item)
    return item and item.getConditionMax and (item:getConditionMax() or 0) > 0
end

-- Literature that carries a read/known status (skill book or recipe provider),
-- whether or not it's currently read.
function BF.Filters.isReadableLiterature(item)
    if not item or not item.IsLiterature or not item:IsLiterature() then return false end
    return isSkillBook(item) or teachesRecipe(item)
end

-- Should a MANUAL pickup of this item auto-favourite it? Only for the types the
-- mod might one day auto-drop — not everything the player touches.
function BF.Filters.isProtectableOnPickup(item)
    return BF.Filters.isEmptyable(item)
        or BF.Filters.isBreakable(item)
        or BF.Filters.isReadableLiterature(item)
end
