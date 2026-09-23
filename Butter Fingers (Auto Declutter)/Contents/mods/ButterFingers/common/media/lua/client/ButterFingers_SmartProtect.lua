--[[
    Butter Fingers — smart protect
    ------------------------------------------------------------------
    When you MANUALLY pick something up that Butter Fingers would otherwise drop,
    auto-favourite it so it's protected (from this mod, and natively from
    accidental transfer). This deliberately extends B42's favourite feature.

    "Manual" is detected by hooking ISInventoryTransferAction — the UI path a
    player uses to move items. Sticky Fingers' auto-grab bypasses this action
    (direct AddItem), so auto-looted items don't trip it: only your deliberate
    pickups do. Opt-out via the smartProtect setting.
]]

require "TimedActions/ISInventoryTransferAction"

BF = BF or {}
BF.SmartProtect = {}

function BF.SmartProtect.onTransfer(action)
    if not BF.getData().smartProtect then return end
    local player = action and action.character
    if not player or player:getPlayerNum() ~= 0 then return end

    local item = action.item
    local dest = action.destContainer
    if not item or not dest then return end

    -- Only when the item ends up in the player's own inventory (or a worn bag).
    if not (dest.isInCharacterInventory and dest:isInCharacterInventory(player)) then return end

    -- Only protect the KINDS of item the mod might one day auto-drop (emptyable,
    -- breakable, or readable literature) — not everything the player touches.
    -- Checked by inherent capability, not current state, so grabbing a full
    -- bottle/canteen keeps it safe once it's emptied later.
    if item:isFavorite() then return end
    local ok, protectable = pcall(function() return BF.Filters.isProtectableOnPickup(item) end)
    if ok and protectable then
        item:setFavorite(true)
        BF.halo(player, "Protected from declutter", true)
    end
end

local orig_perform = ISInventoryTransferAction.perform
function ISInventoryTransferAction:perform()
    orig_perform(self)
    -- Guarded so a hook error can never break item transfers.
    local ok, err = pcall(function() BF.SmartProtect.onTransfer(self) end)
    if not ok then BF.warn("SmartProtect hook failed:", err) end
end
