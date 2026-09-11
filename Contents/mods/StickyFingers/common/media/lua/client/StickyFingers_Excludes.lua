--[[
    Sticky Fingers — per-object exclusions
    ------------------------------------------------------------------
    Lets the player mark a specific placed container (e.g. a base loot-dump
    crate) or a whole vehicle (a personal hauler) as off-limits, so the looter
    never grabs back items dumped into them.

    Identity / persistence:
      - Containers are keyed by their owning object's world position + sprite
        name ("x,y,z|sprite"), which is stable for furniture across sessions.
      - Vehicles are keyed by vehicle:getId() (the persistent vehicle id),
        stored as a string.
    Both live in config.excludes with a friendly label for the management list.
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
------------------------------------------------------------------

function SF.Excludes.isVehicleExcluded(vehicle)
    if not vehicle or not vehicle.getId then return false end
    return data().vehicles[tostring(vehicle:getId())] ~= nil
end

function SF.Excludes.toggleVehicle(vehicle)
    if not vehicle or not vehicle.getId then return false end
    local id = tostring(vehicle:getId())
    local vehicles = data().vehicles
    if vehicles[id] then
        vehicles[id] = nil
        SF.save(); notifyUI()
        return false
    end
    local name = (vehicle.getScriptName and vehicle:getScriptName()) or "Vehicle"
    vehicles[id] = name .. " (#" .. id .. ")"
    SF.save(); notifyUI()
    return true
end

function SF.Excludes.removeVehicle(id)
    data().vehicles[id] = nil
    SF.save(); notifyUI()
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

function SF.Excludes.listVehicles()
    local out = {}
    for id, label in pairs(data().vehicles) do
        out[#out + 1] = { id = id, label = label }
    end
    table.sort(out, function(a, b) return a.label:lower() < b.label:lower() end)
    return out
end
