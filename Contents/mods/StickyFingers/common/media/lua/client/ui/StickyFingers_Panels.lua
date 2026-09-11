--[[
    Sticky Fingers — management tab panels
    ------------------------------------------------------------------
    Three ISPanel subclasses used as tabs inside the main window:
      SFTaggedPanel  — list of currently tagged items, remove / clear
      SFSearchPanel  — search all game items and tag them
      SFZonePanel    — list ignore zones, start corner-picking, remove

    All three use plain ISScrollingListBox default row drawing (item.text),
    so there is no custom doDrawItem to maintain.
]]

require "ISUI/ISPanel"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"

local PAD = 8
local BTN_H = 24

------------------------------------------------------------------
-- Tagged items panel
------------------------------------------------------------------

SFTaggedPanel = ISPanel:derive("SFTaggedPanel")

function SFTaggedPanel:new(x, y, w, h)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    return o
end

function SFTaggedPanel:createChildren()
    ISPanel.createChildren(self)
    local w, h = self:getWidth(), self:getHeight()

    self.list = ISScrollingListBox:new(PAD, PAD, w - PAD * 2, h - PAD * 3 - BTN_H)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = 22
    self.list.font = UIFont.NewSmall
    self.list:setAnchorRight(true)
    self.list:setAnchorBottom(true)
    self:addChild(self.list)

    local btnW = (w - PAD * 3) / 2
    self.removeBtn = ISButton:new(PAD, h - PAD - BTN_H, btnW, BTN_H, "Remove selected", self, SFTaggedPanel.onRemove)
    self.removeBtn:initialise()
    self.removeBtn:setAnchorTop(false)
    self.removeBtn:setAnchorBottom(true)
    self:addChild(self.removeBtn)

    self.clearBtn = ISButton:new(PAD * 2 + btnW, h - PAD - BTN_H, btnW, BTN_H, "Clear all", self, SFTaggedPanel.onClear)
    self.clearBtn:initialise()
    self.clearBtn:setAnchorTop(false)
    self.clearBtn:setAnchorBottom(true)
    self.clearBtn:setAnchorLeft(false)
    self.clearBtn:setAnchorRight(true)
    self:addChild(self.clearBtn)

    self:refresh()
end

function SFTaggedPanel:refresh()
    if not self.list then return end
    self.list:clear()
    for _, entry in ipairs(SF.Tags.getSortedList()) do
        self.list:addItem(entry.name, entry)
    end
end

function SFTaggedPanel:onRemove()
    local item = self.list.items[self.list.selected]
    if item and item.item then
        SF.Tags.remove(item.item.type)
        self:refresh()
    end
end

function SFTaggedPanel:onClear()
    SF.Tags.clear()
    self:refresh()
end

------------------------------------------------------------------
-- Search / add panel
------------------------------------------------------------------

SFSearchPanel = ISPanel:derive("SFSearchPanel")

local MAX_RESULTS = 200
local MIN_QUERY   = 2

function SFSearchPanel:new(x, y, w, h)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    return o
end

function SFSearchPanel:createChildren()
    ISPanel.createChildren(self)
    local w, h = self:getWidth(), self:getHeight()

    self.entry = ISTextEntryBox:new("", PAD, PAD, w - PAD * 2, BTN_H)
    self.entry:initialise()
    self.entry:instantiate()
    self.entry:setAnchorRight(true)
    self.entry.onTextChange = function() self:refresh() end
    self:addChild(self.entry)

    self.list = ISScrollingListBox:new(PAD, PAD * 2 + BTN_H, w - PAD * 2, h - PAD * 4 - BTN_H * 2)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = 22
    self.list.font = UIFont.NewSmall
    self.list:setAnchorRight(true)
    self.list:setAnchorBottom(true)
    self:addChild(self.list)

    self.addBtn = ISButton:new(PAD, h - PAD - BTN_H, w - PAD * 2, BTN_H, "Tag selected item", self, SFSearchPanel.onAdd)
    self.addBtn:initialise()
    self.addBtn:setAnchorTop(false)
    self.addBtn:setAnchorBottom(true)
    self.addBtn:setAnchorRight(true)
    self:addChild(self.addBtn)

    self.hint = ISLabel:new(PAD, PAD * 2 + BTN_H, 18, "Type at least " .. MIN_QUERY .. " characters to search…", 0.6, 0.6, 0.6, 1, UIFont.NewSmall, true)
    self.hint:initialise()
    self:addChild(self.hint)
end

function SFSearchPanel:refresh()
    if not self.list then return end
    self.list:clear()

    local query = self.entry:getText()
    query = query and query:lower():gsub("^%s*(.-)%s*$", "%1") or ""
    if #query < MIN_QUERY then
        if self.hint then self.hint:setVisible(true) end
        return
    end
    if self.hint then self.hint:setVisible(false) end

    local all = getScriptManager():getAllItems()
    local count = 0
    for i = 0, all:size() - 1 do
        if count >= MAX_RESULTS then break end
        local script = all:get(i)
        local name = script:getDisplayName()
        local fullType = script:getFullName()  -- "Module.Type"
        if name and fullType then
            local hay = (name .. " " .. fullType):lower()
            if hay:find(query, 1, true) then
                local tagged = SF.Tags.isTagged(fullType)
                local label = (tagged and "[✓] " or "") .. name .. "  (" .. fullType .. ")"
                self.list:addItem(label, { type = fullType, name = name })
                count = count + 1
            end
        end
    end
end

function SFSearchPanel:onAdd()
    local item = self.list.items[self.list.selected]
    if item and item.item then
        SF.Tags.add(item.item.type)
        self:refresh()
        if self.mainWindow then self.mainWindow:refreshTagged() end
    end
end

------------------------------------------------------------------
-- Ignore-zone panel
------------------------------------------------------------------

SFZonePanel = ISPanel:derive("SFZonePanel")

function SFZonePanel:new(x, y, w, h)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    return o
end

function SFZonePanel:createChildren()
    ISPanel.createChildren(self)
    local w, h = self:getWidth(), self:getHeight()

    self.list = ISScrollingListBox:new(PAD, PAD, w - PAD * 2, h - PAD * 3 - BTN_H)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = 22
    self.list.font = UIFont.NewSmall
    self.list:setAnchorRight(true)
    self.list:setAnchorBottom(true)
    self:addChild(self.list)

    local btnW = (w - PAD * 3) / 2
    self.addBtn = ISButton:new(PAD, h - PAD - BTN_H, btnW, BTN_H, "Add zone (pick corners)", self, SFZonePanel.onAdd)
    self.addBtn:initialise()
    self.addBtn:setAnchorTop(false)
    self.addBtn:setAnchorBottom(true)
    self:addChild(self.addBtn)

    self.removeBtn = ISButton:new(PAD * 2 + btnW, h - PAD - BTN_H, btnW, BTN_H, "Remove selected", self, SFZonePanel.onRemove)
    self.removeBtn:initialise()
    self.removeBtn:setAnchorTop(false)
    self.removeBtn:setAnchorBottom(true)
    self.removeBtn:setAnchorLeft(false)
    self.removeBtn:setAnchorRight(true)
    self:addChild(self.removeBtn)

    self:refresh()
end

function SFZonePanel:refresh()
    if not self.list then return end
    self.list:clear()
    for i, zone in ipairs(SF.Zones.getAll()) do
        self.list:addItem(SF.Zones.describe(zone), { index = i })
    end
end

function SFZonePanel:onAdd()
    -- Hand off to the world-based corner picker; it re-opens the window after.
    if SF.ZoneTool and SF.ZoneTool.start then
        if self.mainWindow then self.mainWindow:close() end
        SF.ZoneTool.start()
    end
end

function SFZonePanel:onRemove()
    local item = self.list.items[self.list.selected]
    if item and item.item then
        SF.Zones.removeAt(item.item.index)
        self:refresh()
    end
end
