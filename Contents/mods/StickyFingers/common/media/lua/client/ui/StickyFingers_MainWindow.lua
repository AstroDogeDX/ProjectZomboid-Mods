--[[
    Sticky Fingers — main management window
    ------------------------------------------------------------------
    ISCollapsableWindow holding the master switch, the five source toggles,
    a scan-range control, and a tab panel (Tagged / Search / Zones).

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

SFMainWindow = ISCollapsableWindow:derive("SFMainWindow")

function SFMainWindow:new(x, y, w, h)
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.title = "Sticky Fingers"
    o.resizable = true
    o:setResizable(true)
    o.minimumWidth = 320
    o.minimumHeight = 380
    return o
end

function SFMainWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    local w = self:getWidth()
    local top = self:titleBarHeight()
    local y = top + PAD

    -- Master switch --------------------------------------------------
    self.masterTick = ISTickBox:new(PAD, y, w - PAD * 2, ROW, "", self, SFMainWindow.onToggleMaster)
    self.masterTick:initialise()
    self.masterTick:instantiate()
    self.masterTick:addOption("Auto-looting enabled (master switch)")
    self.masterTick:setSelected(1, SF.isMasterEnabled())
    self:addChild(self.masterTick)
    y = y + ROW + 6

    -- Sources --------------------------------------------------------
    self.srcLabel = ISLabel:new(PAD, y, 18, "Loot from these sources:", 1, 1, 1, 1, UIFont.Small, true)
    self.srcLabel:initialise()
    self:addChild(self.srcLabel)
    y = y + 20

    -- NOTE: ISTickBox sizes each tick square from the widget height, so this
    -- must be a single-row height. The box lays its options out downward on its
    -- own; we reserve #keys*ROW of vertical space below for the tabs.
    self.srcTick = ISTickBox:new(PAD, y, w - PAD * 2, ROW, "", self, SFMainWindow.onToggleSource)
    self.srcTick:initialise()
    self.srcTick:instantiate()
    for idx, key in ipairs(SF.SOURCE_KEYS) do
        self.srcTick:addOption(key)
        self.srcTick:setSelected(idx, SF.isSourceEnabled(key))
    end
    self:addChild(self.srcTick)
    y = y + (#SF.SOURCE_KEYS * ROW) + 8

    -- Scan range -----------------------------------------------------
    self.rangeLabel = ISLabel:new(PAD, y, 18, "", 1, 1, 1, 1, UIFont.Small, true)
    self.rangeLabel:initialise()
    self:addChild(self.rangeLabel)

    local btnSize = 20
    self.rangeMinus = ISButton:new(w - PAD - btnSize * 2 - 4, y, btnSize, btnSize, "-", self, SFMainWindow.onRangeMinus)
    self.rangeMinus:initialise()
    self.rangeMinus:setAnchorLeft(false)
    self.rangeMinus:setAnchorRight(true)
    self:addChild(self.rangeMinus)

    self.rangePlus = ISButton:new(w - PAD - btnSize, y, btnSize, btnSize, "+", self, SFMainWindow.onRangePlus)
    self.rangePlus:initialise()
    self.rangePlus:setAnchorLeft(false)
    self.rangePlus:setAnchorRight(true)
    self:addChild(self.rangePlus)
    self:updateRangeLabel()
    y = y + ROW + 8

    -- Tabs ----------------------------------------------------------
    local tabH = self:getHeight() - y - PAD
    self.tabs = ISTabPanel:new(PAD, y, w - PAD * 2, tabH)
    self.tabs:initialise()
    self.tabs:setAnchorRight(true)
    self.tabs:setAnchorBottom(true)
    self:addChild(self.tabs)

    local cw = w - PAD * 2
    local ch = tabH - (self.tabs.tabHeight or 24)

    self.taggedPanel = SFTaggedPanel:new(0, 0, cw, ch)
    self.taggedPanel.mainWindow = self
    self.taggedPanel:initialise()

    self.searchPanel = SFSearchPanel:new(0, 0, cw, ch)
    self.searchPanel.mainWindow = self
    self.searchPanel:initialise()

    self.zonePanel = SFZonePanel:new(0, 0, cw, ch)
    self.zonePanel.mainWindow = self
    self.zonePanel:initialise()

    self.tabs:addView("Tagged", self.taggedPanel)
    self.tabs:addView("Search", self.searchPanel)
    self.tabs:addView("Zones", self.zonePanel)
end

------------------------------------------------------------------
-- Control callbacks (read state back off the widget for robustness)
------------------------------------------------------------------

function SFMainWindow:onToggleMaster()
    SF.setMasterEnabled(self.masterTick:isSelected(1))
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

-- Called by the search panel after tagging so the Tagged tab stays in sync.
function SFMainWindow:refreshTagged()
    if self.taggedPanel then self.taggedPanel:refresh() end
end

function SFMainWindow:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if SF.UI.instance == self then SF.UI.instance = nil end
end

------------------------------------------------------------------
-- Open / toggle entry point
------------------------------------------------------------------

function SF.UI.toggleMainWindow()
    if SF.UI.instance then
        SF.UI.instance:close()
        return
    end
    local w, h = 360, 460
    local x = getCore():getScreenWidth() / 2 - w / 2
    local y = getCore():getScreenHeight() / 2 - h / 2
    local win = SFMainWindow:new(x, y, w, h)
    win:initialise()
    win:addToUIManager()
    SF.UI.instance = win
end
