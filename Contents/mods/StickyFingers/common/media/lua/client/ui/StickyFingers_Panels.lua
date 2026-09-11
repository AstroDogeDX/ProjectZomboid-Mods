--[[
    Sticky Fingers — management tab panels
    ------------------------------------------------------------------
    Three ISPanel subclasses used as tabs inside the main window:
      SFTaggedPanel  — list of currently tagged items, remove / clear
      SFSearchPanel  — search all game items and tag them
      SFZonePanel    — list ignore zones, start corner-picking, remove

    Each panel positions its children in :layout(), called every frame from
    :prerender(), so lists/buttons resize with the window. ISTabPanel does not
    resize its child views, so this is what makes them responsive.
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

    self.list = ISScrollingListBox:new(PAD, PAD, 100, 100)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = 22
    self.list.font = UIFont.NewSmall
    self:addChild(self.list)

    self.removeBtn = ISButton:new(0, 0, 100, BTN_H, "Remove selected", self, SFTaggedPanel.onRemove)
    self.removeBtn:initialise()
    self:addChild(self.removeBtn)

    self.clearBtn = ISButton:new(0, 0, 100, BTN_H, "Clear all", self, SFTaggedPanel.onClear)
    self.clearBtn:initialise()
    self:addChild(self.clearBtn)

    self:layout()
    self:refresh()
end

function SFTaggedPanel:layout()
    local w, h = self:getWidth(), self:getHeight()
    self.list:setX(PAD); self.list:setY(PAD)
    self.list:setWidth(w - PAD * 2)
    self.list:setHeight(h - PAD * 3 - BTN_H)

    local btnW = (w - PAD * 3) / 2
    local by = h - PAD - BTN_H
    self.removeBtn:setX(PAD);              self.removeBtn:setY(by); self.removeBtn:setWidth(btnW)
    self.clearBtn:setX(PAD * 2 + btnW);    self.clearBtn:setY(by); self.clearBtn:setWidth(btnW)
end

function SFTaggedPanel:prerender()
    ISPanel.prerender(self)
    self:layout()
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
        SF.Tags.remove(item.item.type)   -- triggers SF.UI.refreshIfOpen()
    end
end

function SFTaggedPanel:onClear()
    SF.Tags.clear()
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

    self.entry = ISTextEntryBox:new("", PAD, PAD, 100, BTN_H)
    self.entry:initialise()
    self.entry:instantiate()
    self.entry.onTextChangeFunction = function() self:refresh() end
    self:addChild(self.entry)

    self.list = ISScrollingListBox:new(PAD, PAD, 100, 100)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = 22
    self.list.font = UIFont.NewSmall
    self:addChild(self.list)

    self.addBtn = ISButton:new(PAD, 0, 100, BTN_H, "Tag selected item", self, SFSearchPanel.onAdd)
    self.addBtn:initialise()
    self:addChild(self.addBtn)

    self:layout()
end

function SFSearchPanel:layout()
    local w, h = self:getWidth(), self:getHeight()
    self.entry:setX(PAD); self.entry:setY(PAD); self.entry:setWidth(w - PAD * 2)

    self.list:setX(PAD); self.list:setY(PAD * 2 + BTN_H)
    self.list:setWidth(w - PAD * 2)
    self.list:setHeight(h - PAD * 4 - BTN_H * 2)

    self.addBtn:setX(PAD); self.addBtn:setY(h - PAD - BTN_H); self.addBtn:setWidth(w - PAD * 2)
end

function SFSearchPanel:prerender()
    ISPanel.prerender(self)
    self:layout()
end

function SFSearchPanel:refresh()
    if not self.list then return end
    self.list:clear()

    local query = self.entry:getText()
    query = query and query:lower():gsub("^%s*(.-)%s*$", "%1") or ""
    if #query < MIN_QUERY then return end

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
                local label = (tagged and "* " or "") .. name .. "  (" .. fullType .. ")"
                self.list:addItem(label, { type = fullType, name = name })
                count = count + 1
            end
        end
    end
end

function SFSearchPanel:onAdd()
    local item = self.list.items[self.list.selected]
    if item and item.item then
        SF.Tags.add(item.item.type)   -- triggers SF.UI.refreshIfOpen() (updates both lists)
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

    self.list = ISScrollingListBox:new(PAD, PAD, 100, 100)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = 22
    self.list.font = UIFont.NewSmall
    self:addChild(self.list)

    self.addBtn = ISButton:new(0, 0, 100, BTN_H, "Add zone (pick corners)", self, SFZonePanel.onAdd)
    self.addBtn:initialise()
    self:addChild(self.addBtn)

    self.removeBtn = ISButton:new(0, 0, 100, BTN_H, "Remove selected", self, SFZonePanel.onRemove)
    self.removeBtn:initialise()
    self:addChild(self.removeBtn)

    self:layout()
    self:refresh()
end

function SFZonePanel:layout()
    local w, h = self:getWidth(), self:getHeight()
    self.list:setX(PAD); self.list:setY(PAD)
    self.list:setWidth(w - PAD * 2)
    self.list:setHeight(h - PAD * 3 - BTN_H)

    local btnW = (w - PAD * 3) / 2
    local by = h - PAD - BTN_H
    self.addBtn:setX(PAD);            self.addBtn:setY(by);    self.addBtn:setWidth(btnW)
    self.removeBtn:setX(PAD * 2 + btnW); self.removeBtn:setY(by); self.removeBtn:setWidth(btnW)
end

function SFZonePanel:prerender()
    ISPanel.prerender(self)
    self:layout()
end

function SFZonePanel:refresh()
    if not self.list then return end
    self.list:clear()
    for i, zone in ipairs(SF.Zones.getAll()) do
        self.list:addItem(SF.Zones.describe(zone), { index = i })
    end
end

function SFZonePanel:onAdd()
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
