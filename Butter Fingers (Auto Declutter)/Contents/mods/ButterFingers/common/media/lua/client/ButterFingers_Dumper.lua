--[[
    Butter Fingers — core declutter engine
    ------------------------------------------------------------------
    Throttled scan of the player's OWN inventory. Any item that is a drop
    candidate (and not protected) is dumped into a nearby dump container or,
    failing that, dropped on the floor. Mirrors Sticky Fingers' scan cadence and
    per-scan work cap so it can't hitch.

    SAFETY: protections are checked FIRST and are absolute. We only ever drop
    items that match an explicit rule/list — never a blanket sweep.
]]

BF = BF or {}
BF.Dumper = {}

local SCAN_INTERVAL_MS  = 800   -- min ms between scans (gentler than the looter)
local MAX_DROPS_PER_SCAN = 10   -- cap work per scan
local lastScanMs = 0
local warned = {}

local function safe(key, fn)
    local ok, err = pcall(fn)
    if not ok and not warned[key] then
        warned[key] = true
        BF.warn("Step '" .. tostring(key) .. "' failed:", err)
    end
end

------------------------------------------------------------------
-- Protections & candidacy
------------------------------------------------------------------

-- Absolute never-drop rules. Checked before any candidacy test.
function BF.Dumper.isProtected(player, item)
    if item:isFavorite() then return true end                 -- explicit whitelist
    if player:isEquipped(item) then return true end            -- in hand
    if player.isEquippedClothing and player:isEquippedClothing(item) then return true end
    -- A container item that still holds things (don't throw away a full bag).
    local inv = item.getInventory and item:getInventory()
    if inv and inv:getItems() and inv:getItems():size() > 0 then return true end
    -- Play nice with Sticky Fingers: never drop something it's set to loot.
    if BF.getData().respectSFLootList and _G.SF and SF.Tags and SF.Tags.isTagged then
        local ok, tagged = pcall(function() return SF.Tags.isTagged(item) end)
        if ok and tagged then return true end
    end
    return false
end

-- Should this item be dropped? Protections win; then explicit list / unwanted /
-- predefined categories.
function BF.Dumper.isDropCandidate(player, item)
    if not item then return false end
    if BF.Dumper.isProtected(player, item) then return false end
    local data = BF.getData()

    if BF.DropList.isTagged(item) then return true end
    if data.useUnwantedFlag and item.isUnwanted and item:isUnwanted(player) then return true end
    -- Empty category drops any drained container. Water vessels you care about
    -- are kept safe by favouriting instead (auto on manual pickup, see SmartProtect).
    if data.dropEmpty and BF.Filters.isEmpty(item) then return true end
    if data.dropBroken and BF.Filters.isBroken(item) then return true end
    if data.dropReadLiterature and BF.Filters.isReadLiterature(player, item) then return true end
    return false
end

------------------------------------------------------------------
-- Collection & execution
------------------------------------------------------------------

-- Recurse the player's inventory (into non-protected bags) collecting drop
-- candidates. We collect first and act second so we never mutate a container
-- while iterating it.
local function collect(player, container, out)
    if not container then return end
    local items = container:getItems()
    if not items then return end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            if BF.Dumper.isDropCandidate(player, item) then
                out[#out + 1] = item
            else
                -- Descend into a (kept) bag to clear junk stashed inside it.
                local sub = item.getInventory and item:getInventory()
                if sub then collect(player, sub, out) end
            end
        end
    end
end

-- Move one item out. In "container" mode it goes to a dump container in reach;
-- if none is found, it falls back to the floor UNLESS containerOnly is set, in
-- which case the item is kept (nothing is dropped). Returns true if disposed.
local function dispose(player, item)
    local src = item:getContainer()
    local data = BF.getData()

    if data.dropTarget == "container" then
        local cont = BF.DumpContainers.findFor(player, item)
        if cont then
            if src then src:Remove(item) end
            cont:AddItem(item)
            return true
        end
        if data.containerOnly then
            return false   -- no container in reach; keep it rather than litter
        end
    end

    -- Floor drop ("floor" mode, or "container" mode without containerOnly).
    local sq = player:getCurrentSquare()
    if not sq then return false end
    if src then src:Remove(item) end
    sq:AddWorldInventoryItem(item, 0, 0, 0)
    return true
end

------------------------------------------------------------------
-- Scan
------------------------------------------------------------------

function BF.Dumper.scan(player)
    if not player or player:isDead() then return end
    if not BF.isMasterEnabled() then return end

    if BF.getData().onlyWhenEncumbered then
        local inv = player:getInventory()
        if inv:getCapacityWeight() <= player:getMaxWeight() then return end
    end

    local candidates = {}
    safe("collect", function() collect(player, player:getInventory(), candidates) end)

    local dropped = 0
    for _, item in ipairs(candidates) do
        if dropped >= MAX_DROPS_PER_SCAN then break end
        local ok = false
        safe("dispose", function() ok = dispose(player, item) end)
        if ok then dropped = dropped + 1 end
    end

    if dropped > 0 then
        BF.log("Decluttered", dropped, "item(s)")
        BF.halo(player, "-" .. dropped .. " decluttered", false)
    end
    return dropped
end

-- Manual "declutter now" entry point (hotkey). Runs regardless of the throttle,
-- but still honours master + the encumbrance gate.
function BF.Dumper.declutterNow(player)
    player = player or getPlayer()
    if not BF.isMasterEnabled() then
        BF.halo(player, "Butter Fingers is off", false)
        return
    end
    BF.Dumper.scan(player)
end

------------------------------------------------------------------
-- Tick binding (throttled). SP: local player only; MP handling comes later.
------------------------------------------------------------------

function BF.Dumper.onPlayerUpdate(player)
    if not player or player:getPlayerNum() ~= 0 then return end
    if not BF.isMasterEnabled() then return end
    local now = getTimestampMs()
    if now - lastScanMs < SCAN_INTERVAL_MS then return end
    lastScanMs = now
    BF.Dumper.scan(player)
end

Events.OnPlayerUpdate.Add(BF.Dumper.onPlayerUpdate)
