local engine_GetAddons = engine.GetAddons
local addons = engine_GetAddons()

local function wshl_wsid(wsid, dep)
    if not dep then
        return WSHL.Workshop:Hotload(wsid)
    end

    local wsids = {wsid}

    WSHL.Workshop:GetRequiredAddons(wsid, function(requiredAddonIDs)
        for i = 1, #requiredAddonIDs do
            wsids[#wsids + 1] = requiredAddonIDs[i]
        end

        WSHL.Workshop:Hotload(unpack(wsids))
    end)
end

if SERVER then
    function wshl(wsid, dep, load = true)
        WSHL.Net:Start('wshl_send_wsid')
        net.WriteString(wsid)
        net.WriteBool(dep)
        net.Broadcast()
        if load then wshl_wsid(wsid, dep) end
    end
else

    WSHL.Net:Receive('wshl_send_wsid', function()
        local wsid = net.ReadString()

        local dep = net.ReadBool()

        wshl_wsid(wsid, dep)
    end)

    local allowHints = CreateClientConVar('wshl_receive_hints', 1)

    if not allowHints:GetBool() then return end

    local hints = {
        ['Welcome to Midgame Workshop Hotloader 3.0.0!'] = 8,
        ['You can disable these hints by changing wshl_receive_hints to 0.'] = 16,
        ['You can hotload by subscribing to an addon, or enabling an addon you have installed.'] = 24,
        ['You can disable automatic hotloading for addon requirements by changing wshl_hotload_requirements to 0.'] = 30,
        ['You can review all of these hints again by entering wshl_give_all_hints in console.'] = 36
    }

    local function SendHint(msg)
        surface.PlaySound('ambient/water/drip' .. math.random(1, 4) .. '.wav')
        notification.AddLegacy('[WSHL] ' .. msg, 3, 8)
    end

    for hint, delay in pairs(hints) do
        timer.Simple(delay, function()
            if allowHints:GetBool() then
                SendHint(hint)
            end
        end)
    end

    concommand.Add('wshl_give_all_hints', function()
        for hint in pairs(hints) do
            SendHint(hint)
        end
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
    else
        WSHL.Addons.Unmounted[wsid] = true
    end

    WSHL.Addons.All[wsid] = true
end
