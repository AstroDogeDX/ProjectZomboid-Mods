--[[
    Sticky Fingers — main management window
    ------------------------------------------------------------------
    A compact ISCollapsableWindow: the master switch sits on top (always
    visible for a quick pause), and everything else lives in tabs —
    Tagged / Search / Zones / Excludes / Settings.

    Layout runs from :prerender() every frame so the window and its children
    reflow when resized. The tab panels each handle their own inner layout.

    Opened via keybind or the inventory context menu (SF.UI.toggleMainWindow).
]]

require "ISUI/ISCollapsableWindow"
require "ISUI/ISTabPanel"
require "ISUI/ISTickBox"

SF = SF or {}
SF.UI = SF.UI or {}

local PAD = 10
local CHECK = 18   -- tick-square size (also the tickbox constructor height)

SFMainWindow = ISCollapsableWindow:derive("SFMainWindow")

function SFMainWindow:new(x, y, w, h)
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.title = "Sticky Fingers"
    o.resizable = true
    o.minimumWidth = 360
    o.minimumHeight = 460
    return o
end

function SFMainWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    -- Master switch (stays on top)
    self.masterTick = ISTickBox:new(PAD, 0, 200, CHECK, "", self, SFMainWindow.onToggleMaster)
    self.masterTick:initialise()
    self.masterTick:instantiate()
    self.masterTick:addOption("Auto-looting enabled (master switch)")
    self.masterTick:setSelected(1, SF.isMasterEnabled())
    self:addChild(self.masterTick)

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

    self.settingsPanel = SFSettingsPanel:new(0, 0, 200, 200)
    self.settingsPanel.mainWindow = self
    self.settingsPanel:initialise()

    self.tabs:addView("Tagged", self.taggedPanel)
    self.tabs:addView("Search", self.searchPanel)
    self.tabs:addView("Zones", self.zonePanel)
    self.tabs:addView("Excludes", self.excludePanel)
    self.tabs:addView("Settings", self.settingsPanel)

    self:layout()
end

-- Reposition/resize from the current window size. Runs each frame from
-- prerender so resizing stays responsive.
function SFMainWindow:layout()
    local w = self:getWidth()
    local y = self:titleBarHeight() + PAD

    self.masterTick:setX(PAD); self.masterTick:setY(y)
    y = y + self.masterTick:getHeight() + 8

    self.tabs:setX(PAD); self.tabs:setY(y)
    self.tabs:setWidth(w - PAD * 2)
    self.tabs:setHeight(self:getHeight() - y - PAD)

    local cw = self.tabs:getWidth()
    local ch = self.tabs:getHeight() - (self.tabs.tabHeight or 24)
    for _, p in ipairs({ self.taggedPanel, self.searchPanel, self.zonePanel, self.excludePanel, self.settingsPanel }) do
        p:setWidth(cw)
        p:setHeight(ch)
    end
end

function SFMainWindow:prerender()
    ISCollapsableWindow.prerender(self)
    self:layout()
end

function SFMainWindow:onToggleMaster()
    SF.setMasterEnabled(self.masterTick:isSelected(1))
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
    local w, h = 420, 520
    local x = getCore():getScreenWidth() / 2 - w / 2
    local y = getCore():getScreenHeight() / 2 - h / 2
    local win = SFMainWindow:new(x, y, w, h)
    win:initialise()
    win:addToUIManager()
    SF.UI.instance = win
end

-- Called after any tag/exclude change so an open window updates live.
function SF.UI.refreshIfOpen()
    local win = SF.UI.instance
    if not win then return end
    if win.taggedPanel then win.taggedPanel:refresh() end
    if win.searchPanel then win.searchPanel:refresh() end
    if win.zonePanel then win.zonePanel:refresh() end
    if win.excludePanel then win.excludePanel:refresh() end
end
