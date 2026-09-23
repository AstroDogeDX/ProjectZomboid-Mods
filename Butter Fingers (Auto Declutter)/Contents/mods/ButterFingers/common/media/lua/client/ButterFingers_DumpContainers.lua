--[[
    Butter Fingers — dump containers
    ------------------------------------------------------------------
    When "dump to container" mode is on, junk is placed into a designated dump
    container in reach, falling back to the floor if none is found or none has
    room. Dump containers are either:
      - tagged by the player (world right-click), keyed by the owning object's
        world position + sprite ("x,y,z|sprite"), stored in config so it survives
        chunk reloads and is enumerable in the UI; or
      - a trash can / bin, auto-recognised by container type (opt-out).
]]

BF = BF or {}
BF.DumpContainers = {}

local function data() return BF.getData().dumpContainers end
local function notifyUI() if BF.UI and BF.UI.refreshIfOpen then BF.UI.refreshIfOpen() end end

-- Container TYPES (getType(), NOT the display name) that count as bins/trash.
-- The in-world "bin" reports type "bin" and shows the header "Garbage"; a
-- dumpster reports "dumpster". Matched EXACTLY (case-insensitively) — a substring
-- match would wrongly catch "cabinet" (contains "bin"). Extend as needed.
local TRASH_TYPES = {
    bin        = true,
    dumpster   = true,
    garbagebin = true,
    trashcan   = true,
}

------------------------------------------------------------------
-- Keys
------------------------------------------------------------------

function BF.DumpContainers.objectKey(obj)
    if not obj or not obj.getSquare then return nil end
    local sq = obj:getSquare()
    if not sq then return nil end
    local sprite = obj.getSprite and obj:getSprite()
    local spriteName = (sprite and sprite:getName()) or "?"
    return sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ() .. "|" .. spriteName
end

------------------------------------------------------------------
-- Classification
------------------------------------------------------------------

function BF.DumpContainers.isTrashCan(obj)
    if not obj or not obj.getContainerCount or obj:getContainerCount() == 0 then return false end
    for c = 0, obj:getContainerCount() - 1 do
        local cont = obj:getContainerByIndex(c)
        local t = cont and cont:getType()
        if t and TRASH_TYPES[string.lower(t)] then return true end
    end
    return false
end

-- Is this object a valid dump target right now (player-tagged, or an auto trash can)?
function BF.DumpContainers.isDumpTarget(obj)
    local key = BF.DumpContainers.objectKey(obj)
    if key and data()[key] then return true end
    if BF.getData().autoTrashCans and BF.DumpContainers.isTrashCan(obj) then return true end
    return false
end

------------------------------------------------------------------
-- Tagging (world right-click)
------------------------------------------------------------------

function BF.DumpContainers.toggleObject(obj)
    local key = BF.DumpContainers.objectKey(obj)
    if not key then return false end
    if data()[key] then
        data()[key] = nil
        BF.save(); notifyUI()
        return false
    end
    local sq = obj:getSquare()
    local ctype = (obj:getContainerCount() > 0 and obj:getContainerByIndex(0):getType()) or "container"
    data()[key] = ctype .. " (" .. sq:getX() .. ", " .. sq:getY() .. ")"
    BF.save(); notifyUI()
    return true
end

function BF.DumpContainers.removeTagged(key)
    data()[key] = nil
    BF.save(); notifyUI()
end

------------------------------------------------------------------
-- Finding a dump container in reach
------------------------------------------------------------------

local SEARCH_RADIUS = 2

-- First dump container with room for `item` within a small radius of the player,
-- or nil. (v1 uses a simple radius box; wall-aware reach can be added later.)
function BF.DumpContainers.findFor(player, item)
    local center = player:getCurrentSquare()
    if not center then return nil end
    local cell = getCell()
    local cx, cy, cz = center:getX(), center:getY(), center:getZ()
    for dx = -SEARCH_RADIUS, SEARCH_RADIUS do
        for dy = -SEARCH_RADIUS, SEARCH_RADIUS do
            local sq = cell:getGridSquare(cx + dx, cy + dy, cz)
            local objs = sq and sq:getObjects()
            if objs then
                for i = 0, objs:size() - 1 do
                    local obj = objs:get(i)
                    if obj and obj.getContainerCount and obj:getContainerCount() > 0
                        and BF.DumpContainers.isDumpTarget(obj) then
                        for c = 0, obj:getContainerCount() - 1 do
                            local cont = obj:getContainerByIndex(c)
                            if cont and cont:hasRoomFor(player, item) then
                                return cont
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

------------------------------------------------------------------
-- Listing for the UI
------------------------------------------------------------------

function BF.DumpContainers.listTagged()
    local out = {}
    for key, label in pairs(data()) do
        out[#out + 1] = { key = key, label = label }
    end
    table.sort(out, function(a, b) return a.label:lower() < b.label:lower() end)
    return out
end
