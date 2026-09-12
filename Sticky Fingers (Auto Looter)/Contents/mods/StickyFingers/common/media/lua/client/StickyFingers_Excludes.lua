--[[
    Sticky Fingers — per-object exclusions
    ------------------------------------------------------------------
    Lets the player mark a specific placed container (e.g. a base loot-dump
    crate) or a whole vehicle (a personal hauler) as off-limits, so the looter
    never grabs back items dumped into them.

    Identity / persistence:
      - Containers: keyed by their owning object's world position + sprite name
        ("x,y,z|sprite") in config.excludes.containers. Position is stable for
        furniture, and config lives in the save, so this survives chunk reloads
        and is fully enumerable in the UI (even for far / unloaded crates).
      - Vehicles: the flag is stored in the vehicle's OWN modData, because a
        vehicle's runtime getId() is not stable across chunk unload/reload (the
        original bug — an id-keyed config entry was "forgotten" when you drove
        away and returned). modData is saved/restored with the vehicle, so the
        exclusion sticks. Trade-off: the UI list only shows excluded vehicles
        near the player (we sweep nearby squares to find loaded vehicles).
]]

SF = SF or {}
SF.Excludes = {}

local function data()
    return SF.getData().excludes
end

local function notifyUI()
    if SF.UI and SF.UI.refreshIfOpen then SF.UI.refreshIfOpen() end
end

------------------------------------------------------------------
-- Keys
------------------------------------------------------------------

-- Stable key for a placed container's owning IsoObject.
function SF.Excludes.objectKey(obj)
    if not obj or not obj.getSquare then return nil end
    local sq = obj:getSquare()
    if not sq then return nil end
    local sprite = obj.getSprite and obj:getSprite()
    local spriteName = (sprite and sprite:getName()) or "?"
    return sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ() .. "|" .. spriteName
end

-- Key for the object that owns a container (nil for vehicle-part / corpse
-- containers, which are handled by the vehicle path or not excluded at all).
function SF.Excludes.containerKey(container)
    if not container then return nil end
    local parent = container:getParent()
    if not parent or instanceof(parent, "BaseVehicle") then return nil end
    return SF.Excludes.objectKey(parent)
end

------------------------------------------------------------------
-- Containers
------------------------------------------------------------------

function SF.Excludes.isObjectExcluded(obj)
    local key = SF.Excludes.objectKey(obj)
    return key ~= nil and data().containers[key] ~= nil
end

function SF.Excludes.isContainerExcluded(container)
    local key = SF.Excludes.containerKey(container)
    return key ~= nil and data().containers[key] ~= nil
end

-- Toggle exclusion for an object (built from a world right-click). Returns the
-- new state (true = now excluded).
function SF.Excludes.toggleObject(obj)
    local key = SF.Excludes.objectKey(obj)
    if not key then return false end
    local containers = data().containers
    if containers[key] then
        containers[key] = nil
        SF.save(); notifyUI()
        return false
    end
    -- Friendly label: container type + coords.
    local sq = obj:getSquare()
    local ctype = (obj:getContainerCount() > 0 and obj:getContainerByIndex(0):getType()) or "container"
    containers[key] = ctype .. " (" .. sq:getX() .. ", " .. sq:getY() .. ")"
    SF.save(); notifyUI()
    return true
end

function SF.Excludes.removeContainer(key)
    data().containers[key] = nil
    SF.save(); notifyUI()
end

------------------------------------------------------------------
-- Vehicles
--   The exclusion flag lives in the vehicle's own modData, not our central
--   config. Vehicle instances get a fresh runtime getId() each time their chunk
--   reloads, so an id->config mapping is forgotten when you drive away and come
--   back. modData is saved and restored WITH the vehicle (the same mechanism
--   that persists e.g. heater state), so it survives chunk unload/reload.
------------------------------------------------------------------

local VEHICLE_FLAG = "StickyFingersExcluded"

function SF.Excludes.isVehicleExcluded(vehicle)
    if not vehicle or not vehicle.getModData then return false end
    local md = vehicle:getModData()
    return md ~= nil and md[VEHICLE_FLAG] == true
end

function SF.Excludes.setVehicleExcluded(vehicle, excluded)
    if not vehicle or not vehicle.getModData then return end
    vehicle:getModData()[VEHICLE_FLAG] = excluded and true or nil
    if vehicle.transmitModData then vehicle:transmitModData() end  -- MP-safe
    notifyUI()
end

function SF.Excludes.toggleVehicle(vehicle)
    local now = not SF.Excludes.isVehicleExcluded(vehicle)
    SF.Excludes.setVehicleExcluded(vehicle, now)
    return now
end

function SF.Excludes.removeVehicle(vehicle)
    SF.Excludes.setVehicleExcluded(vehicle, false)
end

------------------------------------------------------------------
-- Listings for the management UI
------------------------------------------------------------------

function SF.Excludes.listContainers()
    local out = {}
    for key, label in pairs(data().containers) do
        out[#out + 1] = { key = key, label = label }
    end
    table.sort(out, function(a, b) return a.label:lower() < b.label:lower() end)
    return out
end

-- Excluded vehicles NEAR the player. We can only read modData on loaded
-- vehicles, and getCell():getVehicles() isn't a reliable list here, so we sweep
-- the squares around the player with getVehicleContainer() (the same call the
-- looter uses) and collect the excluded ones. A far-away excluded vehicle stays
-- excluded (its modData persists); it just won't show here until you're near it.
local LIST_RADIUS = 12

function SF.Excludes.listVehicles()
    local out = {}
    local player = getPlayer()
    local center = player and player:getCurrentSquare()
    if not center then return out end

    local cell = getCell()
    local cx, cy, cz = center:getX(), center:getY(), center:getZ()
    local seen = {}
    for dx = -LIST_RADIUS, LIST_RADIUS do
        for dy = -LIST_RADIUS, LIST_RADIUS do
            local sq = cell:getGridSquare(cx + dx, cy + dy, cz)
            local veh = sq and sq:getVehicleContainer()
            if veh and not seen[veh] and SF.Excludes.isVehicleExcluded(veh) then
                seen[veh] = true
                local name = (veh.getScriptName and veh:getScriptName()) or "Vehicle"
                out[#out + 1] = { vehicle = veh, label = name }
            end
        end
    end
    table.sort(out, function(a, b) return a.label:lower() < b.label:lower() end)
    return out
end
