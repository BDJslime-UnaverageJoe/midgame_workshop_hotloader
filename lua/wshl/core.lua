local engine_GetAddons = engine.GetAddons
local addons = engine_GetAddons()

local function wshl_wsid(wsid, dep, simple)
    if not dep then
        return WSHL.Workshop:Hotload(simple, wsid)
    end

    local wsids = {wsid}

    WSHL.Workshop:GetRequiredAddons(wsid, function(requiredAddonIDs)
        for i = 1, #requiredAddonIDs do
            wsids[#wsids + 1] = requiredAddonIDs[i]
        end

        WSHL.Workshop:Hotload(simple, unpack(wsids))
    end)
end

if SERVER then
    local wshl_cmd = CreateConVar("wshl_cmd", 0, FCVAR_CHEAT)

    function wshl(wsid, dep, load, simple)
        WSHL.Net:Start('wshl_send_wsid')
        net.WriteString(wsid)
        net.WriteBool(dep)
        net.Broadcast()
        if load then wshl_wsid(wsid, dep, simple) end
    end

    concommand.Add('wshl_hotload', function(ply, cmd, args)
        if not wshl_cmd:GetBool() then return end
        if ply:IsSuperAdmin() then
            local wsid = args[1]

            if not wsid then
                ply:PrintMessage(HUD_PRINTCONSOLE, '[wshl_hotload] Error: Workshop ID not provided.\n')
            else
                steamworks.FileInfo(wsid, function(result)
                    if not result or result.title == 'Hidden addon' then
                        return ply:PrintMessage(HUD_PRINTCONSOLE, '[wshl_hotload] Error: Addon is non-existent, hidden, or Steam Servers are offline.\n')
                    end

                    wshl(wsid, false, true)

                    ply:PrintMessage(HUD_PRINTCONSOLE, '[WSHL] Addon "' .. (result.title or wsid) .. '" requested!\n')
                end)
            end
        else
            ply:PrintMessage(HUD_PRINTCONSOLE, '[wshl_hotload] Error: Command is only available to super admins.\n')
        end
    end)
else

    WSHL.Net:Receive('wshl_send_wsid', function()
        local wsid = net.ReadString()

        local dep = net.ReadBool()

        wshl_wsid(wsid, dep)
    end)
end

for i = 1, #addons do
    local addon = addons[i]
    local title = addon.title
    local wsid = addon.wsid

    if not WSHL.VersionDate and wsid == '2885846408' then
        WSHL.VersionDate = addon.updated
    end

    if WSHL.Workshop:IsMounted(title) then
        WSHL.Addons.Mounted[wsid] = true
        WSHL.Addons.Path[wsid] = addon.title
    else
        WSHL.Addons.Unmounted[wsid] = true
    end

    WSHL.Addons.All[wsid] = true
end
