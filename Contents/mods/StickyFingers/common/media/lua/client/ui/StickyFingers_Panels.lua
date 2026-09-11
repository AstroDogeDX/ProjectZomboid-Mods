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
require "ISUI/ISLabel"
require "ISUI/ISTickBox"

local PAD = 8
local BTN_H = 24

------------------------------------------------------------------
-- Tagged items panel
------------------------------------------------------------------

SFTaggedPanel = ISPanel:derive("SFTaggedPanel")

-- Inline "[max N, auto-remove]" suffix shown after each entry name.
local function limitText(max, autoRemove)
    if max then
        return "   [max " .. max .. (autoRemove and ", auto-remove]" or "]")
    end
    return "   [no limit]"
end

function SFTaggedPanel:new(x, y, w, h)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    o.lastSelected = -1
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

    -- Per-entry editor (acts on the selected row).
    self.maxLabel = ISLabel:new(PAD, 0, 18, "Max carried:", 1, 1, 1, 1, UIFont.Small, true)
    self.maxLabel:initialise()
    self:addChild(self.maxLabel)

    self.maxEntry = ISTextEntryBox:new("", 0, 0, 60, BTN_H)
    self.maxEntry:initialise()
    self.maxEntry:instantiate()
    self.maxEntry:setOnlyNumbers(true)
    self.maxEntry.onTextChangeFunction = function() self:onMaxChanged() end
    self:addChild(self.maxEntry)

    self.autoTick = ISTickBox:new(PAD, 0, 240, 18, "", self, SFTaggedPanel.onAutoChanged)
    self.autoTick:initialise()
    self.autoTick:instantiate()
    self.autoTick:addOption("Remove from list once max is reached")
    self:addChild(self.autoTick)

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

    local btnY  = h - PAD - BTN_H            -- remove / clear
    local autoY = btnY - PAD - 20            -- auto-remove tick
    local maxY  = autoY - PAD - BTN_H        -- max label + entry

    self.list:setX(PAD); self.list:setY(PAD)
    self.list:setWidth(w - PAD * 2)
    self.list:setHeight(maxY - PAD * 2)

    self.maxLabel:setX(PAD); self.maxLabel:setY(maxY + 4)
    self.maxEntry:setX(PAD + 90); self.maxEntry:setY(maxY); self.maxEntry:setWidth(60)

    self.autoTick:setX(PAD); self.autoTick:setY(autoY)

    local btnW = (w - PAD * 3) / 2
    self.removeBtn:setX(PAD);           self.removeBtn:setY(btnY); self.removeBtn:setWidth(btnW)
    self.clearBtn:setX(PAD * 2 + btnW); self.clearBtn:setY(btnY); self.clearBtn:setWidth(btnW)
end

function SFTaggedPanel:prerender()
    ISPanel.prerender(self)
    self:syncEditor()
    self:layout()
end

-- When the selected row changes, load its settings into the editor widgets.
function SFTaggedPanel:syncEditor()
    if self.list.selected == self.lastSelected then return end
    self.lastSelected = self.list.selected
    local item = self.list.items[self.list.selected]
    if item and item.item then
        self.editKey = item.item.key
        self.maxEntry:setText(item.item.max and tostring(item.item.max) or "")
        self.autoTick:setSelected(1, item.item.autoRemove == true)
    else
        self.editKey = nil
        self.maxEntry:setText("")
        self.autoTick:setSelected(1, false)
    end
end

-- Update the selected row's inline text after an edit (no list rebuild, so the
-- selection and typing focus are preserved).
function SFTaggedPanel:updateSelectedRowText()
    local item = self.list.items[self.list.selected]
    if not (item and item.item) then return end
    local e = SF.Tags.getEntry(item.item.key)
    item.item.max = e and e.max or nil
    item.item.autoRemove = e and e.autoRemove == true
    item.text = item.item.name .. limitText(item.item.max, item.item.autoRemove)
end

function SFTaggedPanel:onMaxChanged()
    if not self.editKey then return end
    SF.Tags.setMax(self.editKey, tonumber(self.maxEntry:getText()))
    self:updateSelectedRowText()
end

function SFTaggedPanel:onAutoChanged()
    if not self.editKey then return end
    SF.Tags.setAutoRemove(self.editKey, self.autoTick:isSelected(1))
    self:updateSelectedRowText()
end

function SFTaggedPanel:refresh()
    if not self.list then return end
    self.list:clear()
    self.lastSelected = -1   -- force editor re-sync after rebuild
    for _, entry in ipairs(SF.Tags.getSortedList()) do
        self.list:addItem(entry.name .. limitText(entry.max, entry.autoRemove), entry)
    end
end

function SFTaggedPanel:onRemove()
    local item = self.list.items[self.list.selected]
    if item and item.item then
        SF.Tags.remove(item.item.key)   -- triggers SF.UI.refreshIfOpen()
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

    -- Group results by display name (matching how items are tagged/grouped),
    -- counting how many item types collapse into each name.
    local all = getScriptManager():getAllItems()
    local groups, order = {}, {}
    for i = 0, all:size() - 1 do
        local script = all:get(i)
        local name = script:getDisplayName()
        local fullType = script:getFullName()  -- "Module.Type"
        if name and fullType then
            local hay = (name .. " " .. fullType):lower()
            if hay:find(query, 1, true) then
                if groups[name] then
                    groups[name] = groups[name] + 1
                else
                    groups[name] = 1
                    order[#order + 1] = name
                end
            end
        end
    end

    table.sort(order, function(a, b) return a:lower() < b:lower() end)

    for i = 1, math.min(#order, MAX_RESULTS) do
        local name = order[i]
        local variants = groups[name]
        local tagged = SF.Tags.isTagged(name)
        local suffix = variants > 1 and ("  (" .. variants .. " variants)") or ""
        local label = (tagged and "* " or "") .. name .. suffix
        self.list:addItem(label, { key = name })
    end
end

function SFSearchPanel:onAdd()
    local item = self.list.items[self.list.selected]
    if item and item.item then
        SF.Tags.add(item.item.key)   -- triggers SF.UI.refreshIfOpen() (updates both lists)
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

------------------------------------------------------------------
-- Exclusions panel (containers + vehicles)
------------------------------------------------------------------

SFExcludePanel = ISPanel:derive("SFExcludePanel")

function SFExcludePanel:new(x, y, w, h)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    return o
end

function SFExcludePanel:createChildren()
    ISPanel.createChildren(self)

    self.hint = ISLabel:new(PAD, PAD, 18,
        "Right-click a container or vehicle in the world to exclude it.",
        0.6, 0.6, 0.6, 1, UIFont.NewSmall, true)
    self.hint:initialise()
    self:addChild(self.hint)

    self.list = ISScrollingListBox:new(PAD, PAD, 100, 100)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = 22
    self.list.font = UIFont.NewSmall
    self:addChild(self.list)

    self.removeBtn = ISButton:new(0, 0, 100, BTN_H, "Remove selected", self, SFExcludePanel.onRemove)
    self.removeBtn:initialise()
    self:addChild(self.removeBtn)

    self:layout()
    self:refresh()
end

function SFExcludePanel:layout()
    local w, h = self:getWidth(), self:getHeight()
    local top = PAD + 16
    self.hint:setX(PAD); self.hint:setY(PAD)
    self.list:setX(PAD); self.list:setY(top)
    self.list:setWidth(w - PAD * 2)
    self.list:setHeight(h - top - PAD * 2 - BTN_H)
    self.removeBtn:setX(PAD); self.removeBtn:setY(h - PAD - BTN_H); self.removeBtn:setWidth(w - PAD * 2)
end

function SFExcludePanel:prerender()
    ISPanel.prerender(self)
    self:layout()
end

function SFExcludePanel:refresh()
    if not self.list then return end
    self.list:clear()
    for _, c in ipairs(SF.Excludes.listContainers()) do
        self.list:addItem("[Container] " .. c.label, { kind = "container", key = c.key })
    end
    for _, v in ipairs(SF.Excludes.listVehicles()) do
        self.list:addItem("[Vehicle] " .. v.label, { kind = "vehicle", id = v.id })
    end
end

function SFExcludePanel:onRemove()
    local item = self.list.items[self.list.selected]
    if item and item.item then
        if item.item.kind == "container" then
            SF.Excludes.removeContainer(item.item.key)
        else
            SF.Excludes.removeVehicle(item.item.id)
        end
        self:refresh()
    end
end

------------------------------------------------------------------
-- Settings panel (all toggles / sliders live here)
------------------------------------------------------------------

SFSettingsPanel = ISPanel:derive("SFSettingsPanel")

local S_CHECK = 18
local S_ROW   = 22

function SFSettingsPanel:new(x, y, w, h)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.background = false
    return o
end

function SFSettingsPanel:createChildren()
    ISPanel.createChildren(self)

    self.reachTick = ISTickBox:new(PAD, 0, 200, S_CHECK, "", self, SFSettingsPanel.onToggleReach)
    self.reachTick:initialise(); self.reachTick:instantiate()
    self.reachTick:addOption("Respect walls (don't loot through them)")
    self.reachTick:setSelected(1, SF.isRespectReach())
    self:addChild(self.reachTick)

    self.srcLabel = ISLabel:new(PAD, 0, 18, "Loot from these sources:", 1, 1, 1, 1, UIFont.Small, true)
    self.srcLabel:initialise(); self:addChild(self.srcLabel)

    self.srcTick = ISTickBox:new(PAD, 0, 200, S_CHECK, "", self, SFSettingsPanel.onToggleSource)
    self.srcTick:initialise(); self.srcTick:instantiate()
    for idx, key in ipairs(SF.SOURCE_KEYS) do
        self.srcTick:addOption(key)
        self.srcTick:setSelected(idx, SF.isSourceEnabled(key))
    end
    self:addChild(self.srcTick)

    self.rangeLabel = ISLabel:new(PAD, 0, 18, "", 1, 1, 1, 1, UIFont.Small, true)
    self.rangeLabel:initialise(); self:addChild(self.rangeLabel)
    self.rangeMinus = ISButton:new(0, 0, 20, 20, "-", self, SFSettingsPanel.onRangeMinus)
    self.rangeMinus:initialise(); self:addChild(self.rangeMinus)
    self.rangePlus = ISButton:new(0, 0, 20, 20, "+", self, SFSettingsPanel.onRangePlus)
    self.rangePlus:initialise(); self:addChild(self.rangePlus)
    self:updateRangeLabel()

    self.weightTick = ISTickBox:new(PAD, 0, 280, S_CHECK, "", self, SFSettingsPanel.onToggleWeight)
    self.weightTick:initialise(); self.weightTick:instantiate()
    self.weightTick:addOption("Stop looting when over the carry limit")
    self.weightTick:setSelected(1, SF.isRespectWeight())
    self:addChild(self.weightTick)

    self.weightLabel = ISLabel:new(PAD, 0, 18, "", 1, 1, 1, 1, UIFont.Small, true)
    self.weightLabel:initialise(); self:addChild(self.weightLabel)
    self.weightMinus = ISButton:new(0, 0, 20, 20, "-", self, SFSettingsPanel.onWeightMinus)
    self.weightMinus:initialise(); self:addChild(self.weightMinus)
    self.weightPlus = ISButton:new(0, 0, 20, 20, "+", self, SFSettingsPanel.onWeightPlus)
    self.weightPlus:initialise(); self:addChild(self.weightPlus)
    self:updateWeightLabel()

    self.filterLabel = ISLabel:new(PAD, 0, 18, "Skip these even if tagged:", 1, 1, 1, 1, UIFont.Small, true)
    self.filterLabel:initialise(); self:addChild(self.filterLabel)
    self.filterTick = ISTickBox:new(PAD, 0, 280, S_CHECK, "", self, SFSettingsPanel.onToggleFilters)
    self.filterTick:initialise(); self.filterTick:instantiate()
    self.filterTick:addOption("Non-fresh food (stale / rotten / burnt)")
    self.filterTick:addOption("Broken items")
    self.filterTick:setSelected(1, SF.getData().ignoreNonFreshFood == true)
    self.filterTick:setSelected(2, SF.getData().ignoreBroken == true)
    self:addChild(self.filterTick)

    self.booksTick = ISTickBox:new(PAD, 0, 300, S_CHECK, "", self, SFSettingsPanel.onToggleBooks)
    self.booksTick:initialise(); self.booksTick:instantiate()
    self.booksTick:addOption("Auto-loot unread skill books & recipe magazines")
    self.booksTick:setSelected(1, SF.getData().autoLootBooks == true)
    self:addChild(self.booksTick)

    self:layout()
end

function SFSettingsPanel:layout()
    local w = self:getWidth()
    local y = PAD

    self.reachTick:setX(PAD); self.reachTick:setY(y)
    y = y + self.reachTick:getHeight() + 8

    self.srcLabel:setX(PAD); self.srcLabel:setY(y); y = y + 20
    self.srcTick:setX(PAD); self.srcTick:setY(y); y = y + self.srcTick:getHeight() + 10

    self.rangeLabel:setX(PAD); self.rangeLabel:setY(y + 2)
    self.rangePlus:setX(w - PAD - 20);  self.rangePlus:setY(y)
    self.rangeMinus:setX(w - PAD - 44); self.rangeMinus:setY(y)
    y = y + S_ROW + 10

    self.weightTick:setX(PAD); self.weightTick:setY(y)
    y = y + self.weightTick:getHeight() + 6
    self.weightLabel:setX(PAD); self.weightLabel:setY(y + 2)
    self.weightPlus:setX(w - PAD - 20);  self.weightPlus:setY(y)
    self.weightMinus:setX(w - PAD - 44); self.weightMinus:setY(y)
    y = y + S_ROW + 10

    self.filterLabel:setX(PAD); self.filterLabel:setY(y); y = y + 20
    self.filterTick:setX(PAD); self.filterTick:setY(y)
    y = y + self.filterTick:getHeight() + 10

    self.booksTick:setX(PAD); self.booksTick:setY(y)
end

function SFSettingsPanel:prerender()
    ISPanel.prerender(self)
    self:layout()
end

function SFSettingsPanel:onToggleReach()
    SF.setRespectReach(self.reachTick:isSelected(1))
end

function SFSettingsPanel:onToggleSource()
    for idx, key in ipairs(SF.SOURCE_KEYS) do
        SF.setSourceEnabled(key, self.srcTick:isSelected(idx))
    end
end

function SFSettingsPanel:updateRangeLabel()
    local r = SF.getData().range or 2
    self.rangeLabel:setName("Scan range: " .. r .. " tile" .. (r == 1 and "" or "s"))
end

function SFSettingsPanel:onRangeMinus()
    local data = SF.getData()
    data.range = math.max(1, (data.range or 2) - 1)
    SF.save(); self:updateRangeLabel()
end

function SFSettingsPanel:onRangePlus()
    local data = SF.getData()
    data.range = math.min(6, (data.range or 2) + 1)
    SF.save(); self:updateRangeLabel()
end

function SFSettingsPanel:onToggleWeight()
    SF.setRespectWeight(self.weightTick:isSelected(1))
end

function SFSettingsPanel:updateWeightLabel()
    self.weightLabel:setName("Carry limit: " .. SF.getWeightPercent() .. "% of max")
end

function SFSettingsPanel:onWeightMinus()
    SF.setWeightPercent(SF.getWeightPercent() - 10)
    self:updateWeightLabel()
end

function SFSettingsPanel:onWeightPlus()
    SF.setWeightPercent(SF.getWeightPercent() + 10)
    self:updateWeightLabel()
end

function SFSettingsPanel:onToggleFilters()
    local data = SF.getData()
    data.ignoreNonFreshFood = self.filterTick:isSelected(1)
    data.ignoreBroken = self.filterTick:isSelected(2)
    SF.save()
end

function SFSettingsPanel:onToggleBooks()
    SF.getData().autoLootBooks = self.booksTick:isSelected(1)
    SF.save()
end
