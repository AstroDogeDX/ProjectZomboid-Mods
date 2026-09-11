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
        - Vehicles   : IsoGridSquare:getVehicleContainer() -> getPartByIndex()
                       :getItemContainer(), gated by canAccessContainer()
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

-- Vehicle containers are reached per-square via IsoGridSquare:getVehicleContainer()
-- (exactly how vanilla ISInventoryPage builds the loot window), respecting
-- canAccessContainer() so locked/unreachable parts are skipped. `seen` dedupes
-- a vehicle that spans several scanned squares.
local function collectVehicleOnSquare(sq, player, out, seen)
    local veh = sq:getVehicleContainer()
    if not veh or seen[veh] then return end
    seen[veh] = true
    for partIndex = 1, veh:getPartCount() do
        local part = veh:getPartByIndex(partIndex - 1)
        local container = part and part:getItemContainer()
        if container and veh:canAccessContainer(partIndex - 1, player) then
            collectFromContainer(container, player, out)
        end
    end
end

------------------------------------------------------------------
-- Which squares to scan
------------------------------------------------------------------

local NEIGHBOURS = { {1,0}, {-1,0}, {0,1}, {0,-1}, {1,1}, {1,-1}, {-1,1}, {-1,-1} }

-- Squares reachable from the player by walking, flood-filled outward up to
-- `range` steps with canReachTo() on each adjacent step. This is how we avoid
-- looting through walls: only squares connected by an unobstructed path are
-- scanned. canReachTo() is only meaningful between *adjacent* squares (see
-- luautils / ISEntityUI in the game source), so multi-tile reach must be built
-- one step at a time rather than tested player->far-square directly.
local function reachableSquares(center, range, cell)
    local result  = { center }
    local visited = { [center:getX() .. "," .. center:getY()] = true }
    local z = center:getZ()
    local queue = { { sq = center, d = 0 } }
    local head = 1
    while head <= #queue do
        local node = queue[head]; head = head + 1
        if node.d < range then
            local csq = node.sq
            for _, off in ipairs(NEIGHBOURS) do
                local nx, ny = csq:getX() + off[1], csq:getY() + off[2]
                local key = nx .. "," .. ny
                if not visited[key] then
                    local nsq = cell:getGridSquare(nx, ny, z)
                    if nsq and csq:canReachTo(nsq) then
                        visited[key] = true
                        result[#result + 1] = nsq
                        queue[#queue + 1] = { sq = nsq, d = node.d + 1 }
                    end
                end
            end
        end
    end
    return result
end

-- Plain bounding-box squares, ignoring walls (used only when the player turns
-- off "respect walls" for the old cheaty behaviour).
local function boxSquares(center, range, cell)
    local result = {}
    local cx, cy, cz = center:getX(), center:getY(), center:getZ()
    for dx = -range, range do
        for dy = -range, range do
            local sq = cell:getGridSquare(cx + dx, cy + dy, cz)
            if sq then result[#result + 1] = sq end
        end
    end
    return result
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
    local cell = getCell()
    local out = {}

    -- All sources are scanned per-square within range: ground, placed
    -- containers, corpses/animals (static-moving objects), and vehicle parts.
    local wantGround     = SF.isSourceEnabled("Ground")
    local wantContainers = SF.isSourceEnabled("Containers")
    local wantCorpses    = SF.isSourceEnabled("Corpses")
    local wantAnimals    = SF.isSourceEnabled("Animals")
    local wantVehicles   = SF.isSourceEnabled("Vehicles")
    local seenVehicles   = {}

    if wantGround or wantContainers or wantCorpses or wantAnimals or wantVehicles then
        -- Respect walls by default: only scan squares the player could actually
        -- walk to. Disable respectReach for the old scan-through-walls behaviour.
        local squares
        if data.respectReach == false then
            squares = boxSquares(center, range, cell)
        else
            squares = reachableSquares(center, range, cell)
        end

        for _, sq in ipairs(squares) do
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
            if wantVehicles then
                safe("Vehicles", function()
                    collectVehicleOnSquare(sq, player, out, seenVehicles)
                end)
            end
        end
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
