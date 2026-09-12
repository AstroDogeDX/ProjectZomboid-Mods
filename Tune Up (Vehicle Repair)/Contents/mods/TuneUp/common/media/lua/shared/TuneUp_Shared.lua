--[[
    Tune Up (Vehicle Repair) — shared core
    ------------------------------------------------------------------
    Establishes the global `TU` namespace: config accessors (backed by
    sandbox options), the skill->cap and skill->time math, the reach/tool
    gates, and the two "apply" functions (condition write + effort cost).

    Loaded in the shared/ phase, so both the client menu hook and the
    ISTuneUpPart timed action can rely on TU existing at runtime.

    SINGLE-PLAYER SCOPE (v1):
      Balance lives in sandbox options (SandboxVars.TuneUp.*). The one place
      that mutates world state, TU.applyRepair(), is isolated so a future MP
      version can route it through a server command (mirroring the vanilla
      Commands.fixPart) without touching the rest of the mod.
]]

TU = TU or {}

TU.MOD_ID = "TuneUp"
TU.DEBUG  = false

------------------------------------------------------------------
-- Logging
------------------------------------------------------------------

function TU.log(...)
    if TU.DEBUG then print("[TuneUp]", ...) end
end

function TU.warn(...)
    print("[TuneUp][WARN]", ...)
end

-- Floating feedback above the character (green = good, red = bad).
function TU.halo(character, text, good)
    if not character or not HaloTextHelper then return end
    local color = good and HaloTextHelper.getColorGreen() or HaloTextHelper.getColorRed()
    HaloTextHelper.addTextWithArrow(character, text, good and true or false, color)
end

------------------------------------------------------------------
-- Config (sandbox options with safe fallbacks)
------------------------------------------------------------------

-- Read SandboxVars.TuneUp[name], falling back to `default` if the option or
-- the whole table isn't present (e.g. loading a save from before the mod).
local function opt(name, default)
    local sv = SandboxVars and SandboxVars.TuneUp
    if sv ~= nil and sv[name] ~= nil then return sv[name] end
    return default
end

function TU.getMaxConditionPerLevel()  return opt("MaxConditionPerLevel", 10) end
function TU.getMinSkillToRepair()      return opt("MinSkillToRepair", 1) end
function TU.getBaseMinutesPerPercent() return opt("BaseMinutesPerPercent", 10.0) end
function TU.getMinutesReductionPerLevel() return opt("MinutesReductionPerLevel", 0.9) end
function TU.getMinMinutesPerPercent()  return opt("MinMinutesPerPercent", 1.0) end
function TU.getRequireTools()          return opt("RequireTools", true) end
function TU.getRespectReach()          return opt("RespectReach", true) end
function TU.getGrantXP()               return opt("GrantXP", true) end
function TU.getXPPerPercent()          return opt("XPPerPercent", 0.2) end
function TU.getFatiguePerPercent()     return opt("FatiguePerPercent", 0.006) end
function TU.getBoredomPerPercent()     return opt("BoredomPerPercent", 0.004) end
function TU.getExpertLevel()           return opt("ExpertLevel", 7) end
function TU.getExpertEaseFactor()      return opt("ExpertEaseFactor", 0.5) end

------------------------------------------------------------------
-- Core math
------------------------------------------------------------------

-- Highest condition (0-100) a character can tune a part up to.
function TU.getConditionCap(skill)
    local cap = skill * TU.getMaxConditionPerLevel()
    if cap > 100 then cap = 100 end
    if cap < 0 then cap = 0 end
    return cap
end

-- In-game minutes to restore 1% of condition at the given Mechanics level.
function TU.getMinutesPerPercent(skill)
    local minutes = TU.getBaseMinutesPerPercent() - (skill * TU.getMinutesReductionPerLevel())
    local floor = TU.getMinMinutesPerPercent()
    if minutes < floor then minutes = floor end
    return minutes
end

------------------------------------------------------------------
-- Eligibility, reach and tools
------------------------------------------------------------------

-- Is this a part we can meaningfully tune (has a condition track and something
-- physically present to work on)? Deliberately permissive per design — engines,
-- windows and any installed part with an inventory item all qualify.
function TU.isTuneable(part)
    if not part then return false end
    if part:getCondition() >= 100 then return false end
    if part:getInventoryItem() then return true end
    if part:getId() == "Engine" then return true end
    local window = part:getWindow()
    if window and not window:isDestroyed() then return true end
    return false
end

-- If this part is covered by another that must be removed first (e.g. a brake
-- behind its wheel), return that covering part's id; otherwise nil. Reads the
-- same `requireUninstalled` keyvalue the vanilla uninstall gate uses.
function TU.getBlockingPartId(part)
    if not part then return nil end
    local kv = part:getTable("uninstall")
    if not kv or not kv.requireUninstalled then return nil end
    local vehicle = part:getVehicle()
    local blocker = vehicle and vehicle:getPartById(kv.requireUninstalled)
    if blocker and blocker:getInventoryItem() then
        return kv.requireUninstalled
    end
    return nil
end

-- Reach: the character must be standing in the part's area (same rule the game
-- uses for installs/uninstalls), and any covering part must be removed first —
-- so you still have to take the wheel off to tune the brake behind it.
function TU.canReach(vehicle, part, chr)
    if not TU.getRespectReach() then return true end
    if not vehicle or not part then return false end
    if TU.getBlockingPartId(part) then return false end
    local area = part:getArea()
    if not area then return true end -- part with no area gate (nothing to block)
    return vehicle:isInArea(area, chr)
end

-- Does the character hold a usable wrench? Reuses the game's own helper so the
-- definition of "wrench" (tag + not broken) stays consistent with vanilla.
function TU.hasRequiredTool(chr)
    if not TU.getRequireTools() then return true end
    if not chr then return false end
    return chr:getInventory():getFirstTagEvalRecurse(ItemTag.WRENCH, function(i) return not i:isBroken() end) ~= nil
end

------------------------------------------------------------------
-- World mutation (isolated for a clean MP port)
------------------------------------------------------------------

-- Write a new absolute condition (0-100) onto the part and keep the vehicle's
-- derived stats/network state consistent. Mirrors the important half of the
-- vanilla Commands.fixPart. We intentionally do NOT flag the part as
-- "have been repaired" — a tune-up's cost is time, not a permanent max-condition
-- penalty.
--
-- MP TODO: in a multiplayer build, replace the body with
--   sendClientCommand(chr, "vehicle", "fixPart", {...}) style call so the
--   server owns the change; the call site would not need to change.
function TU.applyRepair(part, condition)
    if not part then return end
    condition = math.floor(condition + 0.5)
    if condition < 0 then condition = 0 elseif condition > 100 then condition = 100 end

    local vehicle = part:getVehicle()
    part:setCondition(condition)

    local item = part:getInventoryItem()
    if item then
        item:setCondition(condition)
        part:doInventoryItemStats(item, part:getMechanicSkillInstaller())
    end

    -- Condition can change a container part's capacity; clamp its contents.
    if part:isContainer() and not part:getItemContainer() then
        part:setContainerContentAmount(part:getContainerContentAmount())
    end

    if vehicle then
        vehicle:updatePartStats()
        vehicle:transmitPartCondition(part)
        if item then vehicle:transmitPartItem(part) end
    end
end

-- Apply the per-percent cost/reward: fatigue, boredom, and a little XP. Experts
-- tire less and find the work relaxing (boredom goes down instead of up).
function TU.applyEffort(chr, percentDone)
    if not chr or percentDone <= 0 then return end
    local stats = chr:getStats()
    local skill = chr:getPerkLevel(Perks.Mechanics)
    local expert = skill >= TU.getExpertLevel()

    -- Fatigue: the "need to sleep" cost, eased for experts.
    local ease = expert and TU.getExpertEaseFactor() or 1.0
    local fatigue = stats:get(CharacterStat.FATIGUE) + (TU.getFatiguePerPercent() * percentDone * ease)
    stats:set(CharacterStat.FATIGUE, math.max(0.0, math.min(1.0, fatigue)))

    -- Boredom: novices grow bored; a skilled mechanic finds it satisfying.
    local boreDelta = TU.getBoredomPerPercent() * percentDone
    if expert then boreDelta = -boreDelta end
    local boredom = stats:get(CharacterStat.BOREDOM) + boreDelta
    stats:set(CharacterStat.BOREDOM, math.max(0.0, math.min(1.0, boredom)))

    -- XP: intentionally paltry.
    if TU.getGrantXP() then
        local xp = TU.getXPPerPercent() * percentDone
        if xp > 0 then addXp(chr, Perks.Mechanics, xp) end
    end
end
