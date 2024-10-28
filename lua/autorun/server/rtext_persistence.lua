rText = rText or {}
rText.PermanentScreens = rText.PermanentScreens or {}

-- Initialize database
local function InitDatabase()
    if not sql.TableExists("rtext_screens") then
        local query = [[
            CREATE TABLE rtext_screens (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                map TEXT NOT NULL,
                pos TEXT NOT NULL,
                ang TEXT NOT NULL,
                text_data TEXT NOT NULL,
                creator_steamid TEXT,
                created_at INTEGER,
                updated_at INTEGER
            )
        ]]
        sql.Query(query)
        print("[rText] Database initialized")
    end
end

InitDatabase()

-- Save permanent screens to database
function rText.SavePermanentScreens()
    -- Begin transaction for better performance
    sql.Begin()
    
    -- Clear existing screens for this map
    sql.Query(string.format("DELETE FROM rtext_screens WHERE map = %s", sql.SQLStr(game.GetMap())))
    
    local count = 0
    for _, ent in ipairs(ents.FindByClass("rtext_screen")) do
        if IsValid(ent) and ent:GetPermanent() then
            local data = {
                map = game.GetMap(),
                pos = util.TableToJSON({ent:GetPos():Unpack()}),
                ang = util.TableToJSON({ent:GetAngles():Unpack()}),
                text_data = util.TableToJSON(ent.TextData),
                creator_steamid = IsValid(ent:GetCreator()) and ent:GetCreator():SteamID64() or nil,
                created_at = os.time(),
                updated_at = os.time()
            }
            
            local query = string.format([[
                INSERT INTO rtext_screens 
                (map, pos, ang, text_data, creator_steamid, created_at, updated_at)
                VALUES (%s, %s, %s, %s, %s, %d, %d)
            ]], 
                sql.SQLStr(data.map),
                sql.SQLStr(data.pos),
                sql.SQLStr(data.ang),
                sql.SQLStr(data.text_data),
                data.creator_steamid and sql.SQLStr(data.creator_steamid) or "NULL",
                data.created_at,
                data.updated_at
            )
            
            sql.Query(query)
            count = count + 1
        end
    end
    
    -- Commit transaction
    sql.Commit()
    
    print(string.format("[rText] Saved %d permanent text screens for map: %s", count, game.GetMap()))
end

-- Load and spawn permanent screens
function rText.LoadPermanentScreens()
    local query = string.format("SELECT * FROM rtext_screens WHERE map = %s", sql.SQLStr(game.GetMap()))
    local results = sql.Query(query)
    
    if not results then return end
    
    local spawned = 0
    for _, data in ipairs(results) do
        local screen = ents.Create("rtext_screen")
        if IsValid(screen) then
            -- Parse position
            local posData = util.JSONToTable(data.pos)
            screen:SetPos(Vector(posData[1], posData[2], posData[3]))
            
            -- Parse angles
            local angData = util.JSONToTable(data.ang)
            screen:SetAngles(Angle(angData[1], angData[2], angData[3]))
            
            screen:Spawn()
            screen:SetPermanent(true)
            screen.TextData = util.JSONToTable(data.text_data)
            
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

-- Add command to list all maps with screens
concommand.Add("rtext_list_maps", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    
    local query = [[
        SELECT map, COUNT(*) as count 
        FROM rtext_screens 
        GROUP BY map
    ]]
    
    local results = sql.Query(query)
    if not results then return end
    
    local function SendMessage(msg)
        if IsValid(ply) then
            ply:ChatPrint(msg)
        else
            print(msg)
        end
    end
    
    SendMessage("Maps with permanent text screens:")
    for _, row in ipairs(results) do
        SendMessage(string.format("  %s: %s screens", row.map, row.count))
    end
end)

-- Add command to clear all permanent screens
concommand.Add("rtext_clear_all_maps", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    
    sql.Query("DELETE FROM rtext_screens")
    
    if IsValid(ply) then
        ply:ChatPrint("Cleared permanent text screens for all maps!")
    else
        print("[rText] Cleared permanent text screens for all maps")
    end
end)

-- Add command to clear current map's screens
concommand.Add("rtext_clear_map", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    
    sql.Query(string.format("DELETE FROM rtext_screens WHERE map = %s", sql.SQLStr(game.GetMap())))
    
    if IsValid(ply) then
        ply:ChatPrint(string.format("Cleared permanent text screens for map: %s!", game.GetMap()))
    else
        print(string.format("[rText] Cleared permanent text screens for map: %s", game.GetMap()))
    end
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

-- Update config references
local function SavePermanentScreens()
    local data = {}
    
    for _, ent in ipairs(ents.FindByClass("rtext_screen")) do
        if IsValid(ent) and ent:GetPermanent() then
            table.insert(data, {
                TextData = ent.TextData,
                Pos = ent:GetPos(),
                Ang = ent:GetAngles(),
                Creator = IsValid(ent:GetCreator()) and ent:GetCreator():SteamID64() or nil,
                Permanent = true
            })
        end
    end
    
    if #data > 0 then
        file.Write("rtext/permanent_screens.json", util.TableToJSON(data, true))
        rText.Debug.Log("Saved", #data, "permanent text screens")
    end
end
