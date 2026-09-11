--[[
    Sticky Fingers — ignore-zone manager
    ------------------------------------------------------------------
    Zones are axis-aligned world-tile rectangles { x1, y1, x2, y2 } stored
    with normalised corners (x1<=x2, y1<=y2). While the player stands inside
    any zone, auto-looting is suppressed entirely (see Looter).

    Z-level is intentionally ignored so a multi-storey base is covered by a
    single footprint.
]]

SF = SF or {}
SF.Zones = {}

-- Store a rectangle from two arbitrary corner tiles.
function SF.Zones.add(ax, ay, bx, by)
    local zone = {
        x1 = math.min(ax, bx),
        y1 = math.min(ay, by),
        x2 = math.max(ax, bx),
        y2 = math.max(ay, by),
    }
    table.insert(SF.getData().zones, zone)
    SF.save()
    SF.log(string.format("Added zone (%d,%d)-(%d,%d)", zone.x1, zone.y1, zone.x2, zone.y2))
    return zone
end

-- Remove by 1-based index into the zones array.
function SF.Zones.removeAt(index)
    local zones = SF.getData().zones
    if zones[index] then
        table.remove(zones, index)
        SF.save()
    end
end

function SF.Zones.getAll()
    return SF.getData().zones
end

function SF.Zones.count()
    return #SF.getData().zones
end

-- True if the world tile (x, y) falls inside any ignore zone.
function SF.Zones.contains(x, y)
    for _, z in ipairs(SF.getData().zones) do
        if x >= z.x1 and x <= z.x2 and y >= z.y1 and y <= z.y2 then
            return true
        end
    end
    return false
end

-- Convenience: is this character currently standing in an ignore zone?
function SF.Zones.containsCharacter(character)
    if not character then return false end
    local sq = character:getCurrentSquare()
    if not sq then return false end
    return SF.Zones.contains(sq:getX(), sq:getY())
end

-- Width/height/area helpers for the UI list.
function SF.Zones.describe(zone)
    local w = (zone.x2 - zone.x1) + 1
    local h = (zone.y2 - zone.y1) + 1
    return string.format("(%d, %d) - %dx%d tiles", zone.x1, zone.y1, w, h)
end
