--[[
    Sticky Fingers (Auto Looter) — shared core
    ------------------------------------------------------------------
    Establishes the global `SF` namespace, default configuration, and the
    persistence layer (ModData). Loaded first (shared/ loads before client/
    and server/), so every other file can rely on SF existing.

    SINGLE-PLAYER SCOPE (v1):
      Config lives in ModData keyed by SF.MOD_ID, which the engine persists
      inside the save. The client/server split is kept clean so a future
      MP version can move authority + syncing to server/ without a rewrite.
]]

SF = SF or {}

SF.MOD_ID   = "StickyFingers"
SF.VERSION  = 2            -- config schema version, bump when Defaults change shape
SF.DEBUG    = false        -- flip on for verbose console logging

-- Canonical source-type keys. Order matters for UI display.
SF.SOURCE_KEYS = { "Ground", "Containers", "Vehicles", "Corpses", "Animals" }

-- Default configuration. getData() deep-fills any missing keys against this,
-- so adding a new field here is automatically migration-safe.
SF.Defaults = {
    version = SF.VERSION,
    master  = true,                    -- master on/off switch
    range   = 2,                       -- scan radius in tiles around the player
    respectReach = true,               -- only loot squares the player can walk to (no through-walls)
    respectWeight = false,             -- stop looting once at/over the carry limit
    weightPercent = 100,               -- carry limit as % of current max weight (100 = capacity, >100 = overcarry)
    ignoreNonFreshFood = false,        -- skip stale / rotten / burnt food
    ignoreBroken = false,              -- skip broken items
    sources = {
        Ground     = true,
        Containers = true,
        Vehicles   = false,
        Corpses    = false,
        Animals    = false,
    },
    tags  = {},                        -- set of tagged item display-names: [name] = true
    zones = {},                        -- array of { x1, y1, x2, y2 } world-tile rectangles
    excludes = {                       -- objects/vehicles to never loot from
        containers = {},               -- [objectKey] = friendly label
        vehicles   = {},               -- [vehicleId (string)] = friendly label
    },
}

------------------------------------------------------------------
-- Logging
------------------------------------------------------------------

function SF.log(...)
    if SF.DEBUG then
        print("[StickyFingers]", ...)
    end
end

function SF.warn(...)
    print("[StickyFingers][WARN]", ...)
end

-- Floating feedback text above a character. Uses the addTextWithArrow overload
-- (IsoPlayer, String, boolean arrowUp, ColorRGB) — the plain addText() requires
-- a separator arg and has no (player, text, color) overload.
function SF.halo(character, text, good)
    if not character or not HaloTextHelper then return end
    local color = good and HaloTextHelper.getColorGreen() or HaloTextHelper.getColorRed()
    HaloTextHelper.addTextWithArrow(character, text, good and true or false, color)
end

------------------------------------------------------------------
-- Small table helpers
------------------------------------------------------------------

-- Recursively fill missing keys of `t` from `defaults` (does not overwrite
-- values the player has already set). Returns whether anything changed.
local function deepFill(t, defaults)
    local changed = false
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(t[k]) ~= "table" then
                t[k] = {}
                changed = true
            end
            if deepFill(t[k], v) then changed = true end
        elseif t[k] == nil then
            t[k] = v
            changed = true
        end
    end
    return changed
end

------------------------------------------------------------------
-- Persistence (ModData)
------------------------------------------------------------------

-- Returns the live, persisted config table. Safe to mutate in place; call
-- SF.save() afterwards (in SP a mutation persists on save anyway, but calling
-- save() keeps the contract identical for a future MP transmit()).
function SF.getData()
    local data = ModData.getOrCreate(SF.MOD_ID)
    -- Fill defaults on first use / after a schema addition.
    deepFill(data, SF.Defaults)
    -- Run migrations if the stored schema is older than current.
    if (data.version or 0) < SF.VERSION then
        SF.migrate(data, data.version or 0)
        data.version = SF.VERSION
    end
    return data
end

-- Placeholder migration hook. Add version-keyed transforms here as the schema
-- evolves. Called only when stored version < SF.VERSION.
function SF.migrate(data, fromVersion)
    SF.log("Migrating config from version", fromVersion, "to", SF.VERSION)

    -- v1 -> v2: tags were keyed by fullType (e.g. "Base.556Box"); they are now
    -- keyed by display name so variants group like the inventory does. Convert
    -- each stored fullType to its item's display name.
    if fromVersion < 2 then
        local converted = {}
        for key, on in pairs(data.tags or {}) do
            if on then
                local newKey = key
                if type(key) == "string" and key:find("%.") then
                    local script = getScriptManager():getItem(key)
                    if script then newKey = script:getDisplayName() end
                end
                converted[newKey] = true
            end
        end
        data.tags = converted
    end
end

-- Persist current config. In SP this is mostly a no-op marker (ModData is
-- written with the save), but we route through it everywhere so the MP port
-- only has to change this one function to ModData.transmit().
function SF.save()
    ModData.add(SF.MOD_ID, SF.getData())
    -- MP TODO: ModData.transmit(SF.MOD_ID)
end

------------------------------------------------------------------
-- Convenience accessors used across client files
------------------------------------------------------------------

function SF.isMasterEnabled()
    return SF.getData().master == true
end

function SF.setMasterEnabled(enabled)
    SF.getData().master = (enabled == true)
    SF.save()
end

function SF.isRespectReach()
    return SF.getData().respectReach ~= false
end

function SF.setRespectReach(enabled)
    SF.getData().respectReach = (enabled == true)
    SF.save()
end

function SF.isRespectWeight()
    return SF.getData().respectWeight == true
end

function SF.setRespectWeight(enabled)
    SF.getData().respectWeight = (enabled == true)
    SF.save()
end

function SF.getWeightPercent()
    return SF.getData().weightPercent or 100
end

-- Clamped to a sane band: never below 50% (still useful), capped at 300%.
function SF.setWeightPercent(percent)
    percent = math.max(50, math.min(300, math.floor(percent + 0.5)))
    SF.getData().weightPercent = percent
    SF.save()
    return percent
end

function SF.isSourceEnabled(sourceKey)
    return SF.getData().sources[sourceKey] == true
end

function SF.setSourceEnabled(sourceKey, enabled)
    SF.getData().sources[sourceKey] = (enabled == true)
    SF.save()
end
