--[[
    Butter Fingers (Auto Declutter) — shared core
    ------------------------------------------------------------------
    The anti-hoarding counterpart to Sticky Fingers. Establishes the global `BF`
    namespace, default configuration, and the ModData persistence layer. Loaded
    first (shared/ before client/), so every other file can rely on BF existing.

    SINGLE-PLAYER SCOPE (v1):
      Config lives in ModData keyed by BF.MOD_ID (persisted inside the save). The
      client/server split is kept clean so a future MP version can move authority
      + syncing without a rewrite. All world mutation is confined to the Dumper.
]]

BF = BF or {}

BF.MOD_ID  = "ButterFingers"
BF.VERSION = 1            -- config schema version, bump when Defaults change shape
BF.DEBUG   = false

-- Default configuration. getData() deep-fills any missing keys against this, so
-- adding a field here is automatically migration-safe.
BF.Defaults = {
    version = BF.VERSION,
    master  = true,                    -- master on/off switch

    -- When to act
    onlyWhenEncumbered = false,        -- only declutter while over carry capacity

    -- Where junk goes: "container" tries a dump container in reach; "floor"
    -- always drops on the floor.
    dropTarget    = "container",
    containerOnly = false,             -- in container mode, DON'T fall back to the floor
                                       -- (keep the item if no dump container is in reach)
    autoTrashCans = true,              -- trash cans/bins auto-count as dump containers

    -- Predefined drop categories (each optional)
    dropEmpty          = true,         -- empty fluid containers / used-up drainables
    dropBroken         = true,         -- broken items
    dropReadLiterature = true,         -- skill books already read / recipe mags already known

    -- Signals & protections
    useUnwantedFlag  = true,           -- treat B42's native "unwanted" mark as a drop signal
    smartProtect     = true,           -- manually picking up a droppable auto-favourites it
    respectSFLootList = true,          -- never drop something Sticky Fingers is set to loot

    tags = {},                         -- user drop list: set of display-name keys [key]=true
    dumpContainers = {},               -- tagged dump targets: [objectKey] = friendly label
}

------------------------------------------------------------------
-- Logging / feedback
------------------------------------------------------------------

function BF.log(...)
    if BF.DEBUG then print("[ButterFingers]", ...) end
end

function BF.warn(...)
    print("[ButterFingers][WARN]", ...)
end

function BF.halo(character, text, good)
    if not character or not HaloTextHelper then return end
    local color = good and HaloTextHelper.getColorGreen() or HaloTextHelper.getColorRed()
    HaloTextHelper.addTextWithArrow(character, text, good and true or false, color)
end

------------------------------------------------------------------
-- Persistence (ModData)
------------------------------------------------------------------

local function deepFill(t, defaults)
    local changed = false
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(t[k]) ~= "table" then t[k] = {}; changed = true end
            if deepFill(t[k], v) then changed = true end
        elseif t[k] == nil then
            t[k] = v; changed = true
        end
    end
    return changed
end

-- Live, persisted config table. Safe to mutate in place; call BF.save() after.
function BF.getData()
    local data = ModData.getOrCreate(BF.MOD_ID)
    deepFill(data, BF.Defaults)
    if (data.version or 0) < BF.VERSION then
        BF.migrate(data, data.version or 0)
        data.version = BF.VERSION
    end
    return data
end

-- Placeholder migration hook. Add version-keyed transforms as the schema evolves.
function BF.migrate(data, fromVersion)
    BF.log("Migrating config from", fromVersion, "to", BF.VERSION)
end

function BF.save()
    ModData.add(BF.MOD_ID, BF.getData())
    -- MP TODO: ModData.transmit(BF.MOD_ID)
end

------------------------------------------------------------------
-- Convenience accessors
------------------------------------------------------------------

function BF.isMasterEnabled() return BF.getData().master == true end

function BF.setMasterEnabled(enabled)
    BF.getData().master = (enabled == true)
    BF.save()
end

-- Generic boolean option get/set (used by the settings UI).
function BF.getOption(name) return BF.getData()[name] end

function BF.setOption(name, value)
    BF.getData()[name] = value
    BF.save()
end
