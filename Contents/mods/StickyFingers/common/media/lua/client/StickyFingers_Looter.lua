--[[
    Sticky Fingers — core proximity looter
    ------------------------------------------------------------------
    Throttled scan around the local player. For each enabled source type we
    collect tagged items within range, then "instant grab" them into the
    player's inventory (per the chosen mechanic — no timed action, no weight
    gate).

    Source access mirrors vanilla ISInventoryPage.lua (verified against the
    game's own Lua):
        - Ground     : IsoGridSquare:getWorldObjects() -> :getItem()
        - Containers : IsoGridSquare:getObjects() -> getContainerCount()/
                       getContainerByIndex()
        - Corpses/   : IsoGridSquare:getStaticMovingObjects() -> :getContainer();
          Animals      instanceof(so,"IsoDeadBody") and so:isAnimal() splits them
        - Vehicles   : Cell:getVehicles(), BaseVehicle:getPartByIndex()
                       :getItemContainer()   (still to confirm in-game)
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
    -- Objects can expose several containers (matches vanilla ISInventoryPage,
    -- which iterates getContainerCount / getContainerByIndex).
    local objects = sq:getObjects()
    if not objects then return end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj then
            for c = 0, obj:getContainerCount() - 1 do
                collectFromContainer(obj:getContainerByIndex(c), player, out)
            end
        end
    end
end

-- Corpses AND animal carcasses are both IsoDeadBody entries in the square's
-- static-moving-object list (this is how vanilla builds the loot window).
-- so:isAnimal() splits the two so each source toggle is honoured independently.
local function collectStaticMovingObjects(sq, player, out, wantCorpses, wantAnimals)
    local sobs = sq:getStaticMovingObjects()
    if not sobs then return end
    for i = 0, sobs:size() - 1 do
        local so = sobs:get(i)
        local container = so and so:getContainer()
        if container then
            local isAnimal = instanceof(so, "IsoDeadBody") and so:isAnimal()
            if (isAnimal and wantAnimals) or ((not isAnimal) and wantCorpses) then
                collectFromContainer(container, player, out)
            end
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

    -- Per-square sources: ground, placed containers, and corpses/animals
    -- (both live in the square's static-moving-object list).
    local wantGround     = SF.isSourceEnabled("Ground")
    local wantContainers = SF.isSourceEnabled("Containers")
    local wantCorpses    = SF.isSourceEnabled("Corpses")
    local wantAnimals    = SF.isSourceEnabled("Animals")

    if wantGround or wantContainers or wantCorpses or wantAnimals then
        for dx = -range, range do
            for dy = -range, range do
                local sq = cell:getGridSquare(cx + dx, cy + dy, cz)
                if sq then
                    if wantGround then
                        safe("Ground", function() collectGround(sq, player, out) end)
                    end
                    if wantContainers then
                        safe("Containers", function() collectContainersOnSquare(sq, player, out) end)
                    end
                    if wantCorpses or wantAnimals then
                        safe("Corpses/Animals", function()
                            collectStaticMovingObjects(sq, player, out, wantCorpses, wantAnimals)
                        end)
                    end
                end
            end
        end
    end

    -- Cell-level sources (checked once per scan, distance-filtered).
    if SF.isSourceEnabled("Vehicles") then
        safe("Vehicles", function() collectVehicles(player, cx, cy, range, out) end)
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
