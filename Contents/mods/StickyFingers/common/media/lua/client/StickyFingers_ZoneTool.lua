--[[
    Sticky Fingers — ignore-zone corner picker
    ------------------------------------------------------------------
    A transparent fullscreen overlay. Left-click sets corner A, left-click
    again sets corner B and commits the rectangle. Right-click cancels.
    On finish it reopens the management window on the Zones tab.

    ENGINE-API CAUTION (verify in-game):
      - ISCoordConversion.ToWorld(screenX, screenY, z) -> world tile floats
      - ISCoordConversion.ToScreen(worldX, worldY, z) -> screen px (for markers)
      Signatures/return order should be confirmed once running.
]]

require "ISUI/ISPanel"

SF = SF or {}
SF.ZoneTool = {}

SFZoneSelector = ISPanel:derive("SFZoneSelector")

function SFZoneSelector:new()
    local o = ISPanel:new(0, 0, getCore():getScreenWidth(), getCore():getScreenHeight())
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.moveWithMouse = false
    o.cornerA = nil          -- { x, y }
    return o
end

-- Convert current mouse position to an integer world tile at the player's z.
function SFZoneSelector:mouseWorldTile()
    local player = getPlayer()
    local z = player and player:getZ() or 0
    local wx, wy = ISCoordConversion.ToWorld(self:getMouseX(), self:getMouseY(), z)
    return math.floor(wx), math.floor(wy)
end

function SFZoneSelector:onMouseDown(x, y)
    local tx, ty = self:mouseWorldTile()
    if not self.cornerA then
        self.cornerA = { x = tx, y = ty }
        local p = getPlayer()
        if HaloTextHelper and p then
            HaloTextHelper.addText(p, "Corner set — click the opposite corner", HaloTextHelper.getColorGreen())
        end
    else
        SF.Zones.add(self.cornerA.x, self.cornerA.y, tx, ty)
        self:finish()
    end
    return true
end

function SFZoneSelector:onRightMouseDown(x, y)
    self:finish()
    return true
end

function SFZoneSelector:prerender()
    ISPanel.prerender(self)

    -- Instruction banner.
    local msg = self.cornerA
        and "Click the OPPOSITE corner to finish  •  right-click to cancel"
        or  "Click the FIRST corner of the safe zone  •  right-click to cancel"
    local tw = getTextManager():MeasureStringX(UIFont.Medium, msg)
    local bx = self.width / 2 - tw / 2 - 10
    self:drawRect(bx, 20, tw + 20, 30, 0.7, 0, 0, 0)
    self:drawText(msg, bx + 10, 27, 1, 1, 1, 1, UIFont.Medium)

    -- Marker for corner A and current cursor tile.
    if self.cornerA then
        local player = getPlayer()
        local z = player and player:getZ() or 0
        local sx, sy = ISCoordConversion.ToScreen(self.cornerA.x, self.cornerA.y, z)
        self:drawRect(sx - 3, sy - 3, 6, 6, 1, 0.2, 1, 0.2)
    end
end

function SFZoneSelector:finish()
    self:setVisible(false)
    self:removeFromUIManager()
    SF.ZoneTool.selector = nil
    -- Reopen the window on the Zones tab.
    if SF.UI and SF.UI.toggleMainWindow then
        if not SF.UI.instance then SF.UI.toggleMainWindow() end
        local win = SF.UI.instance
        if win then
            if win.tabs and win.tabs.activateView then win.tabs:activateView("Zones") end
            if win.zonePanel then win.zonePanel:refresh() end
        end
    end
end

function SF.ZoneTool.start()
    if SF.ZoneTool.selector then return end
    local sel = SFZoneSelector:new()
    sel:initialise()
    sel:instantiate()
    sel:addToUIManager()
    sel:setAlwaysOnTop(true)
    SF.ZoneTool.selector = sel
end
