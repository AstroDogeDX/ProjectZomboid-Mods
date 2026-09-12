--[[
    ISTuneUpPart — timed action for a single 1% tune-up tick.
    ------------------------------------------------------------------
    Each instance restores exactly 1% of a part's condition, then (if still
    below the skill cap and still valid) queues the next 1%. This keeps the
    whole repair interruptible: cancelling the queue, walking away, losing the
    tool, or reaching the cap all stop it cleanly at a whole percent.

    Timing is driven off the world clock rather than the opaque frame-based
    maxTime, so "10 in-game minutes per percent" means exactly that — and the
    game's fast-forward time controls speed it up naturally (the intended way
    to "trade time" for the repair).
]]

require "TimedActions/ISBaseTimedAction"

ISTuneUpPart = ISBaseTimedAction:derive("ISTuneUpPart")

function ISTuneUpPart:isValid()
    if not self.part or not self.vehicle then return false end
    if self.part:getCondition() >= self.targetCap then return false end
    if not TU.canReach(self.vehicle, self.part, self.character) then return false end
    if not TU.hasRequiredTool(self.character) then return false end
    return true
end

function ISTuneUpPart:waitToStart()
    self.character:faceThisObject(self.vehicle)
    return self.character:shouldBeTurning()
end

function ISTuneUpPart:start()
    self.startMinutes = getGameTime():getWorldAgeHours() * 60.0
    self:setActionAnim("VehicleWorkOnMid")
    if self.item then self.item:setJobType(getText("ContextMenu_TuneUp")) end
end

function ISTuneUpPart:update()
    self.character:faceThisObject(self.vehicle)

    -- Exertion: experts work light, everyone else works medium.
    local expert = self.character:getPerkLevel(Perks.Mechanics) >= TU.getExpertLevel()
    self.character:setMetabolicTarget(expert and Metabolics.LightWork or Metabolics.MediumWork)

    -- Clock-based progress for this 1%.
    local elapsed = (getGameTime():getWorldAgeHours() * 60.0) - self.startMinutes
    local frac = 0.0
    if self.targetMinutes > 0 then frac = elapsed / self.targetMinutes end
    if frac < 0.0 then frac = 0.0 elseif frac > 1.0 then frac = 1.0 end

    -- Drive both the on-screen radial and the action progress bar.
    self:setJobDelta(frac)
    if self.item then self.item:setJobDelta(frac) end
    self:setCurrentTime(frac * self.maxTime)

    if self.character:isTimedActionInstant() or frac >= 1.0 then
        self:forceComplete()
    end
end

function ISTuneUpPart:stop()
    if self.item then self.item:setJobDelta(0) end
    ISBaseTimedAction.stop(self)
end

function ISTuneUpPart:perform()
    if self.item then self.item:setJobDelta(0) end
    ISBaseTimedAction.perform(self)
end

function ISTuneUpPart:complete()
    local part = self.part
    if not part then return false end

    -- Restore one whole percent, clamped to the character's skill cap.
    local newCond = math.min(self.targetCap, part:getCondition() + 1)
    TU.applyRepair(part, newCond)
    TU.applyEffort(self.character, 1)

    -- Keep going, one percent at a time, until the cap is reached.
    if part:getCondition() < self.targetCap then
        ISTimedActionQueue.add(ISTuneUpPart:new(self.character, part, self.item, self.targetCap))
    else
        TU.halo(self.character, getText("IGUI_TuneUp_Done"), true)
    end
    return true
end

function ISTuneUpPart:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return self.maxTime
end

function ISTuneUpPart:new(character, part, item, targetCap)
    local o = ISBaseTimedAction.new(self, character)
    o.part = part
    o.vehicle = part and part:getVehicle() or nil
    o.item = item                                   -- wrench, used only for the job radial
    o.targetCap = targetCap
    o.targetMinutes = TU.getMinutesPerPercent(character:getPerkLevel(Perks.Mechanics))
    -- maxTime is only a scale for the progress bar; real completion is clock-driven
    -- via forceComplete() in update(). We keep currentTime pinned below maxTime so
    -- the engine never completes the action ahead of the world clock.
    o.maxTime = 1000
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end
