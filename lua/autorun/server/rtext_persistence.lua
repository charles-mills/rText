rText = rText or {}
rText.PermanentScreens = rText.PermanentScreens or {}

-- Create data directory if it doesn't exist
if not file.Exists("rtext", "DATA") then
    file.CreateDir("rtext")
end

-- Create maps directory if it doesn't exist
if not file.Exists("rtext/maps", "DATA") then
    file.CreateDir("rtext/maps")
end

-- Get the current map's file path
local function GetMapFile()
    return string.format("rtext/maps/%s.json", game.GetMap())
end

-- Save permanent screens to file
function rText.SavePermanentScreens()
    local data = {}
    
    for _, ent in ipairs(ents.FindByClass("rtext_screen")) do
        if IsValid(ent) and ent:GetPermanent() then
            table.insert(data, {
                TextData = ent.TextData,
                Pos = ent:GetPos(),
                Ang = ent:GetAngles(),
                Creator = IsValid(ent:GetCreator()) and ent:GetCreator():SteamID64() or nil,
                Permanent = true -- Ensure permanent flag is saved
            })
        end
    end
    
    -- Save to map-specific JSON file
    if #data > 0 then
        file.Write(GetMapFile(), util.TableToJSON(data, true))
        print(string.format("[rText] Saved %d permanent text screens for map: %s", #data, game.GetMap()))
    end
end

-- Load and spawn permanent screens
function rText.LoadPermanentScreens()
    local mapFile = GetMapFile()
    if not file.Exists(mapFile, "DATA") then return end
    
    local content = file.Read(mapFile, "DATA")
    if not content or content == "" then return end
    
    local data = util.JSONToTable(content)
    if not data then 
        print(string.format("[rText] Failed to load permanent screens for map: %s (Invalid JSON)", game.GetMap()))
        return 
    end
    
    local spawned = 0
    for _, screenData in ipairs(data) do
        local screen = ents.Create("rtext_screen")
        if IsValid(screen) then
            screen:SetPos(screenData.Pos)
            screen:SetAngles(screenData.Ang)
            screen:Spawn()
            screen:SetPermanent(true)
            screen.TextData = screenData.TextData
            
            -- Network the data to clients
            net.Start("rText_Update")
                net.WriteEntity(screen)
                net.WriteTable(screen.TextData)
            net.Broadcast()
            
            spawned = spawned + 1
        end
    end
    
    if spawned > 0 then
        print(string.format("[rText] Loaded %d permanent text screens for map: %s", spawned, game.GetMap()))
    end
end

-- Save permanent screens before map cleanup
hook.Add("PreCleanupMap", "rText_SavePermanent", function()
    rText.SavePermanentScreens()
end)

-- Load permanent screens after map is fully loaded
hook.Add("PostCleanupMap", "rText_LoadPermanent", function()
    timer.Simple(1, function()
        rText.LoadPermanentScreens()
    end)
end)

hook.Add("InitPostEntity", "rText_LoadPermanent", function()
    timer.Simple(1, function()
        rText.LoadPermanentScreens()
    end)
end)

-- Save permanent screens periodically
timer.Create("rText_AutoSave", 300, 0, function() -- Every 5 minutes
    rText.SavePermanentScreens()
end)

-- Save on server shutdown
hook.Add("ShutDown", "rText_SaveOnShutdown", function()
    rText.SavePermanentScreens()
end)

-- Add console commands for manual control
concommand.Add("rtext_save_permanent", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    rText.SavePermanentScreens()
    if IsValid(ply) then
        ply:ChatPrint(string.format("Permanent text screens saved for map: %s!", game.GetMap()))
    else
        print(string.format("[rText] Permanent text screens saved for map: %s", game.GetMap()))
    end
end)

concommand.Add("rtext_load_permanent", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    rText.LoadPermanentScreens()
    if IsValid(ply) then
        ply:ChatPrint(string.format("Permanent text screens loaded for map: %s!", game.GetMap()))
    else
        print(string.format("[rText] Permanent text screens loaded for map: %s", game.GetMap()))
    end
end)

concommand.Add("rtext_clear_permanent", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    file.Write(GetMapFile(), "[]")
    if IsValid(ply) then
        ply:ChatPrint(string.format("Permanent text screens cleared for map: %s!", game.GetMap()))
    else
        print(string.format("[rText] Permanent text screens cleared for map: %s", game.GetMap()))
    end
end)

-- Debug command to list permanent screens
concommand.Add("rtext_list_permanent", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    
    local count = 0
    for _, ent in ipairs(ents.FindByClass("rtext_screen")) do
        if IsValid(ent) and ent:GetPermanent() then
            count = count + 1
            local pos = ent:GetPos()
            local msg = string.format("Screen %d: Pos(%d, %d, %d)", count, pos.x, pos.y, pos.z)
            if IsValid(ply) then
                ply:ChatPrint(msg)
            else
                print(msg)
            end
        end
    end
    
    local msg = string.format("Found %d permanent text screens", count)
    if IsValid(ply) then
        ply:ChatPrint(msg)
    else
        print(msg)
    end
end)

-- Add command to list all maps with permanent screens
concommand.Add("rtext_list_maps", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    
    local maps = {}
    local files = file.Find("rtext/maps/*.json", "DATA")
    
    for _, f in ipairs(files) do
        local mapName = string.sub(f, 1, -6) -- Remove .json
        local content = file.Read("rtext/maps/" .. f, "DATA")
        local data = util.JSONToTable(content)
        if data then
            maps[mapName] = #data
        end
    end
    
    local function SendMessage(msg)
        if IsValid(ply) then
            ply:ChatPrint(msg)
        else
            print(msg)
        end
    end
    
    SendMessage("Maps with permanent text screens:")
    for mapName, count in pairs(maps) do
        SendMessage(string.format("  %s: %d screens", mapName, count))
    end
end)

-- Add command to clear all permanent screens across all maps
concommand.Add("rtext_clear_all_maps", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    
    local files = file.Find("rtext/maps/*.json", "DATA")
    for _, f in ipairs(files) do
        file.Delete("rtext/maps/" .. f)
    end
    
    if IsValid(ply) then
        ply:ChatPrint("Cleared permanent text screens for all maps!")
    else
        print("[rText] Cleared permanent text screens for all maps")
    end
end)
