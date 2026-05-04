if SERVER then
    if game.IsDedicated() then
        require("workshop") -- Server needs gmsv_workshop module
    else
        util.AddNetworkString("wshl_initialize_bundle")
        WSHL.Net:Receive('wshl_initialize_bundle', function(len, ply)
        if ply:IsListenServerHost() then
            local len = net.ReadUInt(16)
            local data = net.ReadData(len)
            local files = util.JSONToTable(util.Decompress(data))
            local bundle = WSHL.Bundle:Create(files, net.ReadString())

            local binfo = bundle.Information
            
            bundle:Message('Starting initialization...')
            bundle:Message('Bundle Addons: ' .. bundle.Name)
            bundle:Message(string.format('Bundle Information: %s lua files, %s materials, %s models, and %s sounds.', binfo.lua, binfo.materials, binfo.models, binfo.sound))

            bundle:Initialize()
        end
    end)
    end
end
WSHL.ErrorColor = Color(255, 125, 125)

function WSHL.Workshop:Hotload(simple, ...)
    if SERVER and not game.IsDedicated() then return end
    local failed = false
    local wsids = {...}
    local num = #wsids
    local count = 0

    local bundlefiles = {}
    local bundlename = ''

    for i = 1, num do
        if failed then break end

        local wsid = wsids[i]

        steamworks.DownloadUGC(wsid, function(path, gma)
            if not path or not gma then
                failed = true
                return MsgC(WSHL.ErrorColor, '[WSHL] Whoops! Addon ' .. wsid .. ' could not download. Aborting... (Offline, not enough allocation, or addon is hidden?)')
            end

            local pass, files = game.MountGMA(path)

            if pass then
                if SERVER then resource.AddWorkshop(wsid) end
                table.Add(bundlefiles, files)
                local name = WSHL.Workshop:GetGMATitle(gma)
                bundlename = bundlename .. name
                WSHL.Addons.Path[wsid] = name
                hook.Run("WSHL.AddonMounted", wsid, name, files)
            end

            count = count + 1

            if count >= num then
                bundlename = string.sub(bundlename, 1, -3) .. ', '

                timer.Simple(0.5, function()
                    local bundle = WSHL.Bundle:Create(bundlefiles, bundlename)
                    if SERVER and not game.IsDedicated() then
                        print('Starting initialization...')
                        print('Bundle Addons: ' .. bundle.Name)
                        print(string.format('Bundle Information: %s lua files, %s materials, %s models, and %s sounds.', binfo.lua, binfo.materials, binfo.models, binfo.sound))
                    elseif CLIENT and LocalPlayer():IsListenServerHost() then
                        local json = util.Compress(util.TableToJSON(bundlefiles))
                        local len = #json
                        WSHL.Net:Start('wshl_initialize_bundle')
                            net.WriteUInt(len, 16)
                            net.WriteData(json, len)
                            net.WriteString(bundlename)
                            net.SendToServer()
                    end
                    bundle:Initialize(simple)

                    for k, wsid in ipairs(wsids) do
                        WSHL.Addons.Unmounted[wsid] = nil
                        WSHL.Addons.Mounted[wsid] = true
                        WSHL.Addons.All[wsid] = true
                    end
                end)
            end
        end)
    end
end

function WSHL.Workshop:GetRequiredAddons(wsid, callback, tab)
    local timerName = 'wshl_getrequireditems_' .. wsid
    local isFirst = not tab

    tab = tab or {}

    if not getmetatable(tab) then
        timer.Create(timerName, 2.5, 1, function()
            if callback then
                callback(table.GetKeys(tab))
            end
        end)

        local lastEntryTime = SysTime()

        setmetatable(tab, { 
            __index = rawget,

            -- Give the callback delay more time
            -- I'm making sure we get all of the required addons
            __newindex = function(self, ...)
                timer.Adjust(timerName, (SysTime() - lastEntryTime) + 0.45)
                lastEntryTime = SysTime()
    
                rawset(self, ...)
            end
        })
    end

    http.Fetch('https://steamcommunity.com/sharedfiles/filedetails/?id=' .. wsid, function(body)
        local hasRequiredItems = false

        for wsid in string.gmatch(body, '<a href="https://steamcommunity%.com/workshop/filedetails/%?id=(%d+)" target="_blank">') do
            tab[wsid] = true
            hasRequiredItems = true
            
            self:GetRequiredAddons(wsid, nil, tab)
        end

        if not hasRequiredItems and isFirst then
            timer.Adjust(timerName, 0)
        end
    end)
end

-- Code adapted from https://github.com/Facepunch/garrysmod-issues/issues/5143#issuecomment-1014786514
function WSHL.Workshop:GetGMATitle(gma)
    if gma:Read(4) ~= 'GMAD' then return end

    gma:Skip(1) -- Version
    gma:Skip(8) -- Steamid64
    gma:Skip(8) -- Timestamp
    
    -- Required content
    while not gma:EndOfFile() and gma:Read(1) ~= '\0' do end

    local title = {}

    while not gma:EndOfFile() do
        local char = gma:Read(1)

        if char == '\0' then 
            break 
        end

        title[#title + 1] = char
    end

    return table.concat(title)
end

function WSHL.Workshop:IsMounted(name)
    local files, dirs = file.Find('*', name)

    return dirs[1] ~= nil
end