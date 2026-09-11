--[[
    Sticky Fingers — main management window
    ------------------------------------------------------------------
    ISCollapsableWindow holding the master switch, the five source toggles,
    a scan-range control, and a tab panel (Tagged / Search / Zones).

    Layout is done in :layout(), called from :prerender() every frame, so the
    window and its children reflow correctly when resized. ISTickBox auto-sizes
    its own height as options are added (boxSize == constructor height), so we
    read its real height back rather than guessing — that was the source-list /
    tab overlap.

    Opened via keybind or the inventory context menu (SF.UI.toggleMainWindow).
]]

require "ISUI/ISCollapsableWindow"
require "ISUI/ISTabPanel"
require "ISUI/ISTickBox"
require "ISUI/ISLabel"
require "ISUI/ISButton"

SF = SF or {}
SF.UI = SF.UI or {}

local PAD = 10
local ROW = 22
local CHECK = 18   -- tick-square size (also the tickbox constructor height)

SFMainWindow = ISCollapsableWindow:derive("SFMainWindow")

function SFMainWindow:new(x, y, w, h)
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.title = "Sticky Fingers"
    o.resizable = true
    o.minimumWidth = 320
    o.minimumHeight = 400
    return o
end

function SFMainWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    -- Master switch
    self.masterTick = ISTickBox:new(PAD, 0, 200, CHECK, "", self, SFMainWindow.onToggleMaster)
    self.masterTick:initialise()
    self.masterTick:instantiate()
    self.masterTick:addOption("Auto-looting enabled (master switch)")
    self.masterTick:setSelected(1, SF.isMasterEnabled())
    self:addChild(self.masterTick)

    -- Respect walls
    self.reachTick = ISTickBox:new(PAD, 0, 200, CHECK, "", self, SFMainWindow.onToggleReach)
    self.reachTick:initialise()
    self.reachTick:instantiate()
    self.reachTick:addOption("Respect walls (don't loot through them)")
    self.reachTick:setSelected(1, SF.isRespectReach())
    self:addChild(self.reachTick)

    -- Sources
    self.srcLabel = ISLabel:new(PAD, 0, 18, "Loot from these sources:", 1, 1, 1, 1, UIFont.Small, true)
    self.srcLabel:initialise()
    self:addChild(self.srcLabel)

    self.srcTick = ISTickBox:new(PAD, 0, 200, CHECK, "", self, SFMainWindow.onToggleSource)
    self.srcTick:initialise()
    self.srcTick:instantiate()
    for idx, key in ipairs(SF.SOURCE_KEYS) do
        self.srcTick:addOption(key)
        self.srcTick:setSelected(idx, SF.isSourceEnabled(key))
    end
    self:addChild(self.srcTick)

    -- Scan range
    self.rangeLabel = ISLabel:new(PAD, 0, 18, "", 1, 1, 1, 1, UIFont.Small, true)
    self.rangeLabel:initialise()
    self:addChild(self.rangeLabel)

    self.rangeMinus = ISButton:new(0, 0, 20, 20, "-", self, SFMainWindow.onRangeMinus)
    self.rangeMinus:initialise()
    self:addChild(self.rangeMinus)

    self.rangePlus = ISButton:new(0, 0, 20, 20, "+", self, SFMainWindow.onRangePlus)
    self.rangePlus:initialise()
    self:addChild(self.rangePlus)
    self:updateRangeLabel()

    -- Carry-weight limit
    self.weightTick = ISTickBox:new(PAD, 0, 260, CHECK, "", self, SFMainWindow.onToggleWeight)
    self.weightTick:initialise()
    self.weightTick:instantiate()
    self.weightTick:addOption("Stop looting when over the carry limit")
    self.weightTick:setSelected(1, SF.isRespectWeight())
    self:addChild(self.weightTick)

    self.weightLabel = ISLabel:new(PAD, 0, 18, "", 1, 1, 1, 1, UIFont.Small, true)
    self.weightLabel:initialise()
    self:addChild(self.weightLabel)

    self.weightMinus = ISButton:new(0, 0, 20, 20, "-", self, SFMainWindow.onWeightMinus)
    self.weightMinus:initialise()
    self:addChild(self.weightMinus)

    self.weightPlus = ISButton:new(0, 0, 20, 20, "+", self, SFMainWindow.onWeightPlus)
    self.weightPlus:initialise()
    self:addChild(self.weightPlus)
    self:updateWeightLabel()

    -- Quality filters
    self.filterLabel = ISLabel:new(PAD, 0, 18, "Skip these even if tagged:", 1, 1, 1, 1, UIFont.Small, true)
    self.filterLabel:initialise()
    self:addChild(self.filterLabel)

    self.filterTick = ISTickBox:new(PAD, 0, 280, CHECK, "", self, SFMainWindow.onToggleFilters)
    self.filterTick:initialise()
    self.filterTick:instantiate()
    self.filterTick:addOption("Non-fresh food (stale / rotten / burnt)")
    self.filterTick:addOption("Broken items")
    self.filterTick:setSelected(1, SF.getData().ignoreNonFreshFood == true)
    self.filterTick:setSelected(2, SF.getData().ignoreBroken == true)
    self:addChild(self.filterTick)

    -- Tabs + panels
    self.tabs = ISTabPanel:new(PAD, 0, 200, 200)
    self.tabs:initialise()
    self:addChild(self.tabs)

    self.taggedPanel = SFTaggedPanel:new(0, 0, 200, 200)
    self.taggedPanel.mainWindow = self
    self.taggedPanel:initialise()

    self.searchPanel = SFSearchPanel:new(0, 0, 200, 200)
    self.searchPanel.mainWindow = self
    self.searchPanel:initialise()

    self.zonePanel = SFZonePanel:new(0, 0, 200, 200)
    self.zonePanel.mainWindow = self
    self.zonePanel:initialise()

    self.excludePanel = SFExcludePanel:new(0, 0, 200, 200)
    self.excludePanel.mainWindow = self
    self.excludePanel:initialise()

    self.tabs:addView("Tagged", self.taggedPanel)
    self.tabs:addView("Search", self.searchPanel)
    self.tabs:addView("Zones", self.zonePanel)
    self.tabs:addView("Excludes", self.excludePanel)

    self:layout()
end

-- Reposition/resize every child from the current window size. Cheap; runs each
-- frame from prerender so resizing is fully responsive.
function SFMainWindow:layout()
    local w = self:getWidth()
    local y = self:titleBarHeight() + PAD

    self.masterTick:setX(PAD); self.masterTick:setY(y)
    y = y + self.masterTick:getHeight() + 6

    self.reachTick:setX(PAD); self.reachTick:setY(y)
    y = y + self.reachTick:getHeight() + 8

    self.srcLabel:setX(PAD); self.srcLabel:setY(y)
    y = y + 20

    self.srcTick:setX(PAD); self.srcTick:setY(y)
    y = y + self.srcTick:getHeight() + 10   -- real auto-computed height

    self.rangeLabel:setX(PAD); self.rangeLabel:setY(y + 2)
    self.rangePlus:setX(w - PAD - 20);     self.rangePlus:setY(y)
    self.rangeMinus:setX(w - PAD - 44);    self.rangeMinus:setY(y)
    y = y + ROW + 10

    self.weightTick:setX(PAD); self.weightTick:setY(y)
    y = y + self.weightTick:getHeight() + 6

    self.weightLabel:setX(PAD); self.weightLabel:setY(y + 2)
    self.weightPlus:setX(w - PAD - 20);    self.weightPlus:setY(y)
    self.weightMinus:setX(w - PAD - 44);   self.weightMinus:setY(y)
    y = y + ROW + 10

    self.filterLabel:setX(PAD); self.filterLabel:setY(y)
    y = y + 20
    self.filterTick:setX(PAD); self.filterTick:setY(y)
    y = y + self.filterTick:getHeight() + 10

    self.tabs:setX(PAD); self.tabs:setY(y)
    self.tabs:setWidth(w - PAD * 2)
    self.tabs:setHeight(self:getHeight() - y - PAD)

    local cw = self.tabs:getWidth()
    local ch = self.tabs:getHeight() - (self.tabs.tabHeight or 24)
    for _, p in ipairs({ self.taggedPanel, self.searchPanel, self.zonePanel, self.excludePanel }) do
        p:setWidth(cw)
        p:setHeight(ch)
    end
end

function SFMainWindow:prerender()
    ISCollapsableWindow.prerender(self)
    self:layout()
end

------------------------------------------------------------------
-- Control callbacks (read state back off the widget for robustness)
------------------------------------------------------------------

function SFMainWindow:onToggleMaster()
    SF.setMasterEnabled(self.masterTick:isSelected(1))
end

function SFMainWindow:onToggleReach()
    SF.setRespectReach(self.reachTick:isSelected(1))
end

function SFMainWindow:onToggleSource()
    -- Re-sync every source straight from the widget so we don't depend on the
    -- exact argument order ISTickBox passes to the change callback.
    for idx, key in ipairs(SF.SOURCE_KEYS) do
        SF.setSourceEnabled(key, self.srcTick:isSelected(idx))
    end
end

function SFMainWindow:updateRangeLabel()
    local r = SF.getData().range or 2
    self.rangeLabel:setName("Scan range: " .. r .. " tile" .. (r == 1 and "" or "s"))
end

function SFMainWindow:onRangeMinus()
    local data = SF.getData()
    data.range = math.max(1, (data.range or 2) - 1)
    SF.save()
    self:updateRangeLabel()
end

function SFMainWindow:onRangePlus()
    local data = SF.getData()
    data.range = math.min(6, (data.range or 2) + 1)
    SF.save()
    self:updateRangeLabel()
end

function SFMainWindow:onToggleWeight()
    SF.setRespectWeight(self.weightTick:isSelected(1))
end

function SFMainWindow:onToggleFilters()
    local data = SF.getData()
    data.ignoreNonFreshFood = self.filterTick:isSelected(1)
    data.ignoreBroken = self.filterTick:isSelected(2)
    SF.save()
end

function SFMainWindow:updateWeightLabel()
    self.weightLabel:setName("Carry limit: " .. SF.getWeightPercent() .. "% of max")
end

function SFMainWindow:onWeightMinus()
    SF.setWeightPercent(SF.getWeightPercent() - 10)
    self:updateWeightLabel()
end

function SFMainWindow:onWeightPlus()
    SF.setWeightPercent(SF.getWeightPercent() + 10)
    self:updateWeightLabel()
end

function SFMainWindow:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if SF.UI.instance == self then SF.UI.instance = nil end
end

------------------------------------------------------------------
-- Open / toggle + external refresh
------------------------------------------------------------------

function SF.UI.toggleMainWindow()
    if SF.UI.instance then
        SF.UI.instance:close()
        return
    end
    local w, h = 380, 600
    local x = getCore():getScreenWidth() / 2 - w / 2
    local y = getCore():getScreenHeight() / 2 - h / 2
    local win = SFMainWindow:new(x, y, w, h)
    win:initialise()
    win:addToUIManager()
    SF.UI.instance = win
end

-- Called after any tag change so an open window updates live (context menu,
-- search add, tagged remove all funnel through SF.Tags -> here).
function SF.UI.refreshIfOpen()
    local win = SF.UI.instance
    if not win then return end
    if win.taggedPanel then win.taggedPanel:refresh() end
    if win.searchPanel then win.searchPanel:refresh() end
    if win.zonePanel then win.zonePanel:refresh() end
    if win.excludePanel then win.excludePanel:refresh() end
end
