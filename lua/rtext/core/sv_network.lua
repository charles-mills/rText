rText = rText or {}
rText.Network = {}

-- Network strings
util.AddNetworkString("rText_Update")
util.AddNetworkString("rText_RequestUpdate")

-- Network rate limiting
local rateLimits = {
    update = 0.1, -- 100ms between updates
    request = 1.0, -- 1s between requests
    maxPacketSize = 8192 -- 8KB max packet size
}

-- Track last network action per player
local lastAction = setmetatable({}, {__mode = "k"}) -- Weak keys for auto-cleanup

-- Network security wrapper
function rText.Network.CanSendUpdate(ply)
    if not IsValid(ply) then return false end
    
    local now = CurTime()
    local last = lastAction[ply] and lastAction[ply].update or 0
    
    if now - last < rateLimits.update then
        return false, "Please wait before updating"
    end
    
    lastAction[ply] = lastAction[ply] or {}
    lastAction[ply].update = now
    return true
end

function rText.Network.CanRequestUpdate(ply)
    if not IsValid(ply) then return false end
    
    local now = CurTime()
    local last = lastAction[ply] and lastAction[ply].request or 0
    
    if now - last < rateLimits.request then
        return false, "Please wait before requesting updates"
    end
    
    lastAction[ply] = lastAction[ply] or {}
    lastAction[ply].request = now
    return true
end

-- Secure data transmission
function rText.Network.SendUpdate(ent, data, target)
    if not IsValid(ent) then return end
    
    -- Validate and sanitize data
    local sanitizedData = rText.Network.SanitizeData(data)
    local encodedData = util.Compress(util.TableToJSON(sanitizedData))
    
    if #encodedData > rateLimits.maxPacketSize then
        return false, "Data exceeds size limit"
    end
    
    net.Start("rText_Update")
        net.WriteEntity(ent)
        net.WriteUInt(#encodedData, 16)
        net.WriteData(encodedData, #encodedData)
    if target then
        net.Send(target)
    else
        net.Broadcast()
    end
    
    return true
end

-- Data sanitization
function rText.Network.SanitizeData(data)
    if not data then return {} end
    
    local sanitized = {
        lines = {},
        spacing = math.Clamp(data.spacing or 1, 0.5, 2),
        align = data.align == "left" or data.align == "right" and data.align or "center"
    }
    
    -- Sanitize each line
    for i, line in ipairs(data.lines or {}) do
        if type(line) ~= "table" then continue end
        
        sanitized.lines[i] = {
            text = string.sub(tostring(line.text or ""), 1, rText.Config.Cache.maxTextLength),
            size = math.Clamp(tonumber(line.size) or 30, 10, 100),
            color = IsColor(line.color) and line.color or Color(255, 255, 255),
            font = rText.Config.Cache.allowedFonts[line.font] and line.font or "Roboto",
            rainbow = tobool(line.rainbow) and 1 or 0
        }
    end
    
    return sanitized
end

-- Network receivers
net.Receive("rText_RequestUpdate", function(len, ply)
    local canRequest, err = rText.Network.CanRequestUpdate(ply)
    if not canRequest then
        rText.Debug.Log("Update request denied for", ply, ":", err)
        return
    end
    
    local ent = net.ReadEntity()
    if not IsValid(ent) or ent:GetClass() ~= "rtext_screen" then return end
    
    -- Send current data to requesting player
    rText.Network.SendUpdate(ent, ent.TextData, ply)
end)

-- Client-side network handler
if CLIENT then
    net.Receive("rText_Update", function()
        local ent = net.ReadEntity()
        if not IsValid(ent) then return end
        
        local length = net.ReadUInt(16)
        local data = net.ReadData(length)
        
        -- Decompress and decode data
        local success, decodedData = pcall(function()
            return util.JSONToTable(util.Decompress(data))
        end)
        
        if not success or not decodedData then
            rText.Debug.Log("Failed to decode update data")
            return
        end
        
        ent.TextData = decodedData
    end)
end
