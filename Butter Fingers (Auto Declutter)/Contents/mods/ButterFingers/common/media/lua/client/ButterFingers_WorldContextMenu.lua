--[[
    Butter Fingers — world right-click integration
    ------------------------------------------------------------------
    Adds a "Set / unset as dump container" toggle to the world context menu for
    placed container(s) under the cursor, so the player can nominate where junk
    gets dumped. (Trash cans are auto-recognised without needing this.)
]]

BF = BF or {}
BF.WorldMenu = {}

function BF.WorldMenu.onToggleObject(player, obj)
    local nowDump = BF.DumpContainers.toggleObject(obj)
    BF.halo(player, nowDump and "Set as dump container" or "No longer a dump container", nowDump)
end

function BF.WorldMenu.onFill(playerNum, context, worldobjects, test)
    if test then return end
    local player = getSpecificPlayer(playerNum)

    local seen, objs = {}, {}
    for _, o in ipairs(worldobjects) do
        if o and o.getContainerCount and o:getContainerCount() > 0 then
            local key = BF.DumpContainers.objectKey(o)
            if key and not seen[key] then
                seen[key] = true
                objs[#objs + 1] = o
            end
        end
    end
    if #objs == 0 then return end

    local parent = context:addOption("Butter Fingers", nil, nil)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(parent, sub)

    for _, o in ipairs(objs) do
        local isDump = BF.DumpContainers.objectKey(o) and BF.getData().dumpContainers[BF.DumpContainers.objectKey(o)]
        local auto = BF.DumpContainers.isTrashCan(o)
        local ctype = (o:getContainerCount() > 0 and o:getContainerByIndex(0):getType()) or "container"
        local label
        if isDump then
            label = "Unset dump container: " .. ctype
        elseif auto then
            label = "Bin (auto dump target): " .. ctype
        else
            label = "Set as dump container: " .. ctype
        end
        local opt = sub:addOption(label, player, BF.WorldMenu.onToggleObject, o)
        if sub.setOptionChecked then sub:setOptionChecked(opt, isDump or auto) end
        if auto and not isDump then opt.notAvailable = false end -- informational; still toggleable
    end
end

Events.OnFillWorldObjectContextMenu.Add(BF.WorldMenu.onFill)
