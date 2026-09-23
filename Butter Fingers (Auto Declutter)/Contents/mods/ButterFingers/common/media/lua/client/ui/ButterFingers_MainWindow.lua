--[[
    Butter Fingers — management window (first pass)
    ------------------------------------------------------------------
    A compact settings window: the master switch, all behaviour toggles, the
    predefined drop categories, and quick actions (declutter now / clear drop
    list). Day-to-day tagging is done via right-click (inventory items -> drop
    list, world containers -> dump targets), so this window focuses on settings.

    TODO (next pass): richer tabs mirroring Sticky Fingers — a live drop-list
    editor with per-row remove, a searchable "pre-tag" item browser, and a
    dump-container list.
]]

require "ISUI/ISCollapsableWindow"
require "ISUI/ISTickBox"
require "ISUI/ISButton"

BF = BF or {}
BF.UI = BF.UI or {}

ButterFingersWindow = ISCollapsableWindow:derive("ButterFingersWindow")

-- Each row: { key, label }. `master`/`dropTarget` are handled specially; the
-- rest are plain boolean options in config.
local ROWS = {
    { key = "master",             label = "Butter Fingers enabled" },
    { key = "onlyWhenEncumbered", label = "Only declutter when over-encumbered" },
    { key = "dropTarget",         label = "Dump into bins/containers when in reach" },
    { key = "containerOnly",      label = "  ...and never drop on the floor (keep if no bin in reach)" },
    { key = "autoTrashCans",      label = "Trash cans count as dump containers" },
    { key = "dropEmpty",          label = "Drop empty containers" },
    { key = "dropBroken",         label = "Drop broken items" },
    { key = "dropReadLiterature", label = "Drop read books & known recipes" },
    { key = "useUnwantedFlag",    label = "Drop items marked 'unwanted'" },
    { key = "smartProtect",       label = "Protect items I manually pick up" },
    { key = "respectSFLootList",  label = "Never drop Sticky Fingers loot" },
}

local function rowValue(key)
    if key == "master" then return BF.isMasterEnabled() end
    if key == "dropTarget" then return BF.getData().dropTarget == "container" end
    return BF.getData()[key] == true
end

function ButterFingersWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local pad = 12
    local y = self:titleBarHeight() + pad

    self.tickBox = ISTickBox:new(pad, y, self.width - pad * 2, 18, "", self, self.onTick)
    self.tickBox:initialise()
    self.tickBox.autoWidth = true
    for _, row in ipairs(ROWS) do
        self.tickBox:addOption(row.label)
    end
    self:addChild(self.tickBox)
    -- Advance past the box using its rendered per-row stride (itemHgt + spacing),
    -- so the buttons below never overlap the last option.
    local stride = self.tickBox.itemHgt + 6
    y = y + (#ROWS * stride) + pad

    self.statusLabel = ISButton:new(pad, y, self.width - pad * 2, 20, "", self, nil)
    self.statusLabel:initialise()
    self.statusLabel.enable = false
    self:addChild(self.statusLabel)
    y = y + 28

    local bw = (self.width - pad * 3) / 2
    self.declutterBtn = ISButton:new(pad, y, bw, 24, "Declutter now", self, ButterFingersWindow.onDeclutterNow)
    self.declutterBtn:initialise()
    self:addChild(self.declutterBtn)

    self.clearBtn = ISButton:new(pad * 2 + bw, y, bw, 24, "Clear drop list", self, ButterFingersWindow.onClearList)
    self.clearBtn:initialise()
    self:addChild(self.clearBtn)

    self:syncFromConfig()
end

function ButterFingersWindow:syncFromConfig()
    if not self.tickBox then return end
    for i, row in ipairs(ROWS) do
        self.tickBox:setSelected(i, rowValue(row.key))
    end
    if self.statusLabel then
        self.statusLabel:setTitle("Drop list: " .. BF.DropList.count()
            .. "   Dump containers: " .. #BF.DumpContainers.listTagged())
    end
end

-- ISTickBox change callback: (self, index, selected)
function ButterFingersWindow:onTick(index, selected)
    local row = ROWS[index]
    if not row then return end
    if row.key == "master" then
        BF.setMasterEnabled(selected)
    elseif row.key == "dropTarget" then
        BF.setOption("dropTarget", selected and "container" or "floor")
    else
        BF.setOption(row.key, selected == true)
    end
end

function ButterFingersWindow:onDeclutterNow()
    BF.Dumper.declutterNow(getPlayer())
    self:syncFromConfig()
end

function ButterFingersWindow:onClearList()
    BF.DropList.clear()
    self:syncFromConfig()
end

function ButterFingersWindow:new()
    local w, h = 380, 440
    local x = getCore():getScreenWidth() / 2 - w / 2
    local y = getCore():getScreenHeight() / 2 - h / 2
    local o = ISCollapsableWindow.new(self, x, y, w, h)
    o.title = "Butter Fingers"
    o.resizable = false
    return o
end

------------------------------------------------------------------
-- Public API
------------------------------------------------------------------

function BF.UI.toggleMainWindow()
    if BF.UI.instance and BF.UI.instance:isVisible() then
        BF.UI.instance:setVisible(false)
        BF.UI.instance:removeFromUIManager()
        BF.UI.instance = nil
        return
    end
    local win = ButterFingersWindow:new()
    win:initialise()
    win:addToUIManager()
    BF.UI.instance = win
end

function BF.UI.refreshIfOpen()
    if BF.UI.instance and BF.UI.instance.syncFromConfig then
        BF.UI.instance:syncFromConfig()
    end
end
