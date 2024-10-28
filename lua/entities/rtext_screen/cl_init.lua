include("shared.lua")

-- Remove effects references
rText = rText or {}

-- Cached ConVars for performance
local render_range = CreateClientConVar("rtext_render_range", 2000, true, false, "Maximum render distance for text screens")
local render_range_sqr = render_range:GetInt() ^ 2

cvars.AddChangeCallback("rtext_render_range", function(_, _, new)
    render_range_sqr = tonumber(new) ^ 2
end)

-- Cache frequently used functions
local surface_SetFont = surface.SetFont
local surface_SetTextColor = surface.SetTextColor
local draw_SimpleText = draw.SimpleText
local CurTime = CurTime
local HSVToColor = HSVToColor

-- Font cache with size limits to prevent memory bloat
local fontCache = setmetatable({}, {
    __mode = "v" -- Weak values for automatic cleanup
})
local MAX_CACHED_FONTS = 50
local fontCount = 0

-- Create a custom font based on size
local function CreateFont(name, size)
    local fontName = string.format("rText_%s_%d", name, size)
    
    if not fontCache[fontName] then
        -- Clear old fonts if we're at the limit
        if fontCount >= MAX_CACHED_FONTS then
            fontCache = setmetatable({}, {__mode = "v"})
            fontCount = 0
        end
        
        surface.CreateFont(fontName, {
            font = name,
            size = math.Clamp(size, 10, 100) * 3,
            weight = 500,
            antialias = true,
            extended = true
        })
        
        fontCache[fontName] = true
        fontCount = fontCount + 1
    end
    
    return fontName
end

-- Cached rainbow color calculation
local rainbowCache = {}
local RAINBOW_CACHE_TIME = 0.1
local lastRainbowUpdate = 0

local function GetRainbowColor(i)
    local curTime = CurTime()
    if curTime - lastRainbowUpdate > RAINBOW_CACHE_TIME then
        for j = 1, 8 do -- Cache colors for up to 8 lines
            rainbowCache[j] = HSVToColor((curTime * 60 + (j * 5)) % 360, 1, 1)
        end
        lastRainbowUpdate = curTime
    end
    return rainbowCache[i] or rainbowCache[1]
end

function ENT:Initialize()
    self:SetMaterial("models/effects/vol_light001")
    self:SetRenderMode(RENDERMODE_NONE)
    self.TextData = {}
    
    net.Start("rText_RequestUpdate")
        net.WriteEntity(self)
    net.SendToServer()
end

function ENT:Draw()
    if not self.TextData or #self.TextData == 0 then return end
    
    local pos = self:GetPos()
    local dist = LocalPlayer():GetPos():DistToSqr(pos)
    
    if dist > render_range_sqr then return end
    
    local ang = self:GetAngles()
    
    cam.Start3D2D(pos + ang:Forward() * 0.1, ang, 0.25)
    xpcall(function()
        self:DrawText()
    end, function(err)
        print("[rText] Render Error:", err)
    end)
    cam.End3D2D()
end

function ENT:DrawText()
    if not self.TextData or #self.TextData == 0 then return end
    
    local totalHeight = 0
    local spacing = self.TextData.spacing or 1 -- Get spacing from root level
    local maxWidth = 0
    
    -- Calculate total height and max width
    for _, line in ipairs(self.TextData) do
        if not line or not line.text then continue end
        
        local font = CreateFont(line.font or "Roboto", line.size or 30)
        surface.SetFont(font)
        local w, h = surface.GetTextSize(line.text)
        totalHeight = totalHeight + (h * spacing) -- Apply spacing to height calculation
        maxWidth = math.max(maxWidth, w)
    end
    
    local y = -totalHeight / 2
    
    -- Draw each line
    for i, line in ipairs(self.TextData) do
        if not line or not line.text then continue end
        
        local font = CreateFont(line.font or "Roboto", line.size or 30)
        surface.SetFont(font)
        local w, h = surface.GetTextSize(line.text)
        
        -- Calculate x position based on alignment
        local x = 0
        local align = line.align or "center"
        
        if align == "left" then
            x = -maxWidth/2
        elseif align == "right" then
            x = maxWidth/2
        end
        
        -- Draw text with current settings
        local color = line.rainbow == 1 and GetRainbowColor(i) or line.color
        
        draw_SimpleText(
            line.text,
            font,
            x,
            y,
            color,
            align == "right" and TEXT_ALIGN_RIGHT or align == "left" and TEXT_ALIGN_LEFT or TEXT_ALIGN_CENTER,
            TEXT_ALIGN_TOP
        )
        
        y = y + (h * spacing) -- Apply spacing to line positioning
    end
end

net.Receive("rText_Update", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end
    
    -- Use pcall to safely read the table
    local success, data = pcall(function()
        return net.ReadTable()
    end)
    
    if not success then
        -- Use print as fallback if Debug isn't available
        local errorMsg = "[rText] Failed to read network data: " .. tostring(data)
        if rText and rText.Debug then
            rText.Debug.Log(errorMsg)
        else
            print(errorMsg)
        end
        return
    end
    
    -- Validate data before applying
    if type(data) == "table" then
        ent.TextData = data
    end
end)

-- Memory cleanup
timer.Create("rText_MemoryCheck", 30, 0, function()
    local totalMem = collectgarbage("count")
    if totalMem > 50000 then -- 50MB limit
        fontCache = setmetatable({}, {__mode = "v"})
        fontCount = 0
        collectgarbage("collect")
    end
end)
