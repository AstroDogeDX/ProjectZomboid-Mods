--[[
    TuneUp_Mechanics — mechanics-menu integration (client).
    ------------------------------------------------------------------
    Post-hooks ISVehicleMechanics:doPartContextMenu so a "Tune Up" option is
    appended to the same per-part menu that hosts Repair / Install / Uninstall.
    The option is greyed with an explanatory tooltip when it can't be used
    (no skill, no tool, already at/above the skill cap, etc.).
]]

require "Vehicles/ISUI/ISVehicleMechanics"

------------------------------------------------------------------
-- Click handler
------------------------------------------------------------------

function TU.onTuneUp(playerObj, part)
    local vehicle = part:getVehicle()
    if not vehicle then return end

    -- Leave the seat if we're operating from inside (mirrors vanilla repairs).
    if playerObj:getVehicle() then
        ISVehicleMenu.onExit(playerObj)
    end

    -- Walk to the part's area first, then start tuning.
    local area = part:getArea()
    if area then
        ISTimedActionQueue.add(ISPathFindAction:pathToVehicleArea(playerObj, vehicle, area))
    end

    local cap = TU.getConditionCap(playerObj:getPerkLevel(Perks.Mechanics))
    local wrench = playerObj:getInventory():getFirstTagEvalRecurse(ItemTag.WRENCH, function(i) return not i:isBroken() end)
    ISTimedActionQueue.add(ISTuneUpPart:new(playerObj, part, wrench, cap))
end

------------------------------------------------------------------
-- Menu option + tooltip
------------------------------------------------------------------

-- Appends the Tune Up option to self.context. Returns true if an option was added.
function TU.addTuneUpOption(mechanicsUI, part, playerObj)
    if not part or not playerObj then return false end
    if not TU.isTuneable(part) then return false end

    local skill = playerObj:getPerkLevel(Perks.Mechanics)
    local cond  = part:getCondition()
    local cap   = TU.getConditionCap(skill)

    local option = mechanicsUI.context:addOption(getText("ContextMenu_TuneUp"), playerObj, TU.onTuneUp, part)

    -- Work out availability + the reason to show.
    local reason = nil
    if skill < TU.getMinSkillToRepair() then
        reason = getText("IGUI_TuneUp_NeedSkill", TU.getMinSkillToRepair())
    elseif cond >= 100 then
        reason = getText("IGUI_TuneUp_Full")
    elseif cap <= cond then
        reason = getText("IGUI_TuneUp_CapReached", cap, cond)
    elseif not TU.hasRequiredTool(playerObj) then
        reason = getText("IGUI_TuneUp_NeedTool")
    else
        local blockerId = TU.getRespectReach() and TU.getBlockingPartId(part) or nil
        if blockerId then
            reason = getText("IGUI_TuneUp_Blocked", getText("IGUI_VehiclePart" .. blockerId))
        end
    end

    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip:setVisible(false)
    local desc = getText("IGUI_TuneUp_Info")
    if reason then
        option.notAvailable = true
        desc = desc .. " <LINE> <RGB:1,0.3,0.3> " .. reason
    else
        local minutes = TU.getMinutesPerPercent(skill)
        desc = desc .. " <LINE> " .. getText("IGUI_TuneUp_TargetCap", cap)
                    .. " <LINE> " .. getText("IGUI_TuneUp_Rate", string.format("%.1f", minutes))
    end
    tooltip.description = desc
    option.toolTip = tooltip

    return true
end

------------------------------------------------------------------
-- Hook
------------------------------------------------------------------

local orig_doPartContextMenu = ISVehicleMechanics.doPartContextMenu
function ISVehicleMechanics:doPartContextMenu(part, x, y)
    orig_doPartContextMenu(self, part, x, y)

    -- Re-check the same guards the original bails on, so we never append to a
    -- stale/foreign context that the original returned early without building.
    if UIManager.getSpeedControls():getCurrentGameSpeed() == 0 then return end
    local playerObj = getSpecificPlayer(self.playerNum)
    if playerObj:getVehicle() ~= nil and not (isDebugEnabled() or (isClient() and (isAdmin() or getAccessLevel() == "moderator"))) then
        return
    end
    if not self.context then return end

    if TU.addTuneUpOption(self, part, playerObj) then
        -- The original hides the menu when it built only one option; now that
        -- we've added ours, make sure a real menu is shown.
        if self.context.numOptions > 1 then
            self.context:setVisible(true)
            self.context:bringToTop()
        end
    end
end
