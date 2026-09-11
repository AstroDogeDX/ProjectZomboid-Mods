--[[
    Sticky Fingers — core proximity looter
    ------------------------------------------------------------------
    Throttled scan around the local player. For each enabled source type we
    collect tagged items within range, then "instant grab" them into the
    player's inventory (per the chosen mechanic — no timed action, no weight
    gate).

    ENGINE-API CAUTION (verify in-game, see README "Verification checklist"):
      Several Java-bound methods below are called from memory of the B41/B42
      API and may need small tweaks once tested in the real game:
        - IsoGridSquare:getWorldObjects()          (ground items)
        - IsoGridSquare:getObjects() + :getContainer()
        - IsoGridSquare:getDeadBodys()             (note vanilla spelling)
        - IsoGridSquare:transmitRemoveItemFromSquare(obj)
        - Cell:getVehicles(), BaseVehicle:getPartByIndex():getItemContainer()
        - Animal API (B42) — currently a best-effort stub
      Each source is wrapped so a single bad call can't break the whole loop;
      it warns once to the console and is skipped.
]]

SF = SF or {}
SF.Looter = {}

local SCAN_INTERVAL_MS   = 400   -- min ms between scans (throttle)
local MAX_GRABS_PER_SCAN = 20    -- cap work per scan to avoid hitches

local lastScanMs = 0
local warned = {}                -- source -> true, so each warning prints once

-- Run `fn`; on error, warn once for `key` and swallow it so the loop survives.
local function safe(key, fn)
    local ok, err = pcall(fn)
    if not ok and not warned[key] then
        warned[key] = true
        SF.warn("Source/step '" .. tostring(key) .. "' failed (engine API mismatch?):", err)
    end
end

------------------------------------------------------------------
-- Candidate collection. Each collector appends zero-arg closures to `out`;
-- each closure performs one item move when executed. We collect first and
-- move second so we never mutate a container while iterating it.
------------------------------------------------------------------

local function collectFromContainer(container, player, out)
    if not container then return end
    local items = container:getItems()
    if not items then return end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and SF.Tags.isTagged(item) then
            out[#out + 1] = function()
                container:Remove(item)
                player:getInventory():AddItem(item)
            end
        end
    end
end

local function collectGround(sq, player, out)
    local worldObjs = sq:getWorldObjects()
    if not worldObjs then return end
    for i = 0, worldObjs:size() - 1 do
        local wobj = worldObjs:get(i)
        local item = wobj and wobj:getItem()
        if item and SF.Tags.isTagged(item) then
            out[#out + 1] = function()
                sq:transmitRemoveItemFromSquare(wobj)
                player:getInventory():AddItem(item)
            end
        end
    end
end

local function collectContainersOnSquare(sq, player, out)
    local objects = sq:getObjects()
    if not objects then return end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        local container = obj and obj:getContainer()
        if container then
            collectFromContainer(container, player, out)
        end
    end
end

local function collectCorpses(sq, player, out)
    local bodies = sq:getDeadBodys()
    if not bodies then return end
    for i = 0, bodies:size() - 1 do
        local body = bodies:get(i)
        local container = body and body:getContainer()
        if container then
            collectFromContainer(container, player, out)
        end
    end
end

local function collectVehicles(player, cx, cy, range, out)
    local cell = getCell()
    local vehicles = cell and cell:getVehicles()
    if not vehicles then return end
    for i = 0, vehicles:size() - 1 do
        local veh = vehicles:get(i)
        if veh and math.abs(veh:getX() - cx) <= range and math.abs(veh:getY() - cy) <= range then
            local partCount = veh:getPartCount()
            for p = 0, partCount - 1 do
                local part = veh:getPartByIndex(p)
                local container = part and part:getItemContainer()
                if container then
                    collectFromContainer(container, player, out)
                end
            end
        end
    end
end

local function collectAnimals(player, cx, cy, range, out)
    -- BEST-EFFORT STUB. The B42 live/dead animal API needs confirmation.
    -- We probe for a cell animal accessor and, if present, treat any animal
    -- carrying an inventory container (e.g. a butcherable carcass) as a source.
    local cell = getCell()
    if not cell or not cell.getAnimals then return end
    local animals = cell:getAnimals()
    if not animals then return end
    for i = 0, animals:size() - 1 do
        local animal = animals:get(i)
        if animal and math.abs(animal:getX() - cx) <= range and math.abs(animal:getY() - cy) <= range then
            -- Only pull from animals that expose a container (carcass/inventory).
            local container = animal.getContainer and animal:getContainer()
            if container then
                collectFromContainer(container, player, out)
            end
        end
    end
end

------------------------------------------------------------------
-- Scan orchestration
------------------------------------------------------------------

function SF.Looter.scan(player)
    if not player or player:isDead() then return end
    if not SF.isMasterEnabled() then return end
    if SF.Zones.containsCharacter(player) then return end

    local center = player:getCurrentSquare()
    if not center then return end

    local data  = SF.getData()
    local range = data.range or 2
    local cx, cy, cz = center:getX(), center:getY(), center:getZ()
    local cell = getCell()
    local out = {}

    -- Per-square sources (ground / placed containers / corpses).
    local squareSourcesActive =
        SF.isSourceEnabled("Ground") or
        SF.isSourceEnabled("Containers") or
        SF.isSourceEnabled("Corpses")

    if squareSourcesActive then
        for dx = -range, range do
            for dy = -range, range do
                local sq = cell:getGridSquare(cx + dx, cy + dy, cz)
                if sq then
                    if SF.isSourceEnabled("Ground") then
                        safe("Ground", function() collectGround(sq, player, out) end)
                    end
                    if SF.isSourceEnabled("Containers") then
                        safe("Containers", function() collectContainersOnSquare(sq, player, out) end)
                    end
                    if SF.isSourceEnabled("Corpses") then
                        safe("Corpses", function() collectCorpses(sq, player, out) end)
                    end
                end
            end
        end
    end

    -- Cell-level sources (checked once per scan, distance-filtered).
    if SF.isSourceEnabled("Vehicles") then
        safe("Vehicles", function() collectVehicles(player, cx, cy, range, out) end)
    end
    if SF.isSourceEnabled("Animals") then
        safe("Animals", function() collectAnimals(player, cx, cy, range, out) end)
    end

    -- Execute grabs (capped).
    local grabbed = 0
    for _, doGrab in ipairs(out) do
        if grabbed >= MAX_GRABS_PER_SCAN then break end
        local ok, err = pcall(doGrab)
        if ok then
            grabbed = grabbed + 1
        elseif not warned["grab"] then
            warned["grab"] = true
            SF.warn("Grab failed:", err)
        end
    end

    if grabbed > 0 then
        SF.log("Grabbed", grabbed, "item(s)")
        SF.Looter.onGrabbed(player, grabbed)
    end
end

-- Feedback hook when items are grabbed. Kept tiny/optional so it's easy to
-- swap for a sound or richer notification later.
function SF.Looter.onGrabbed(player, count)
    SF.halo(player, "+" .. count .. " looted", true)
end

------------------------------------------------------------------
-- Tick binding (throttled). SP: local player only; MP handling comes later.
------------------------------------------------------------------

function SF.Looter.onPlayerUpdate(player)
    if not player or player:getPlayerNum() ~= 0 then return end
    if not SF.isMasterEnabled() then return end
    local now = getTimestampMs()
    if now - lastScanMs < SCAN_INTERVAL_MS then return end
    lastScanMs = now
    SF.Looter.scan(player)
end

Events.OnPlayerUpdate.Add(SF.Looter.onPlayerUpdate)
