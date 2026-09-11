--[[
    Sticky Fingers — world right-click integration
    ------------------------------------------------------------------
    Adds "Exclude / Include" toggles to the world context menu for the placed
    container(s) and/or the vehicle under the cursor, so the player can protect
    a loot-dump crate or a personal vehicle from being auto-looted.
]]

SF = SF or {}
SF.WorldMenu = {}

function SF.WorldMenu.onToggleObject(player, obj)
    local nowExcluded = SF.Excludes.toggleObject(obj)
    SF.halo(player, nowExcluded and "Container excluded from auto-loot" or "Container re-included",
        not nowExcluded)
end

function SF.WorldMenu.onToggleVehicle(player, vehicle)
    local nowExcluded = SF.Excludes.toggleVehicle(vehicle)
    SF.halo(player, nowExcluded and "Vehicle excluded from auto-loot" or "Vehicle re-included",
        not nowExcluded)
end

function SF.WorldMenu.onFill(playerNum, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)

    -- Collect unique placed-container objects and (at most) one vehicle from
    -- the clicked tile.
    local seen, objs, vehicle = {}, {}, nil
    for _, o in ipairs(worldobjects) do
        if o then
            if o.getContainerCount and o:getContainerCount() > 0 then
                local key = SF.Excludes.objectKey(o)
                if key and not seen[key] then
                    seen[key] = true
                    objs[#objs + 1] = o
                end
            end
            if not vehicle and o.getSquare and o:getSquare() then
                local v = o:getSquare():getVehicleContainer()
                if v then vehicle = v end
            end
        end
    end

    if #objs == 0 and not vehicle then return end

    local parent = context:addOption("Sticky Fingers", nil, nil)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(parent, sub)

    for _, o in ipairs(objs) do
        local excluded = SF.Excludes.isObjectExcluded(o)
        local ctype = (o:getContainerCount() > 0 and o:getContainerByIndex(0):getType()) or "container"
        local label = (excluded and "Re-include container: " or "Exclude container: ") .. ctype
        local opt = sub:addOption(label, player, SF.WorldMenu.onToggleObject, o)
        if sub.setOptionChecked then sub:setOptionChecked(opt, excluded) end
    end

    if vehicle then
        local excluded = SF.Excludes.isVehicleExcluded(vehicle)
        local label = excluded and "Re-include this vehicle" or "Exclude this vehicle"
        local opt = sub:addOption(label, player, SF.WorldMenu.onToggleVehicle, vehicle)
        if sub.setOptionChecked then sub:setOptionChecked(opt, excluded) end
    end
end

Events.OnFillWorldObjectContextMenu.Add(SF.WorldMenu.onFill)
