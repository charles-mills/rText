rText = rText or {}
rText.Render = {}

-- Cache frequently used functions
local surface_SetFont = surface.SetFont
local surface_SetTextColor = surface.SetTextColor
local surface_SetTextPos = surface.SetTextPos
local surface_DrawText = surface.DrawText
local draw_SimpleText = draw.SimpleText
local math_Clamp = math.Clamp
local CurTime = CurTime
local HSVToColor = HSVToColor

-- Render settings
local RENDER_SETTINGS = {
    MAX_DISTANCE = 2000,
    MAX_DISTANCE_SQR = 2000 * 2000,
    FADE_START = 1500,
    MIN_ALPHA = 0.1,
    BATCH_SIZE = 10 -- Number of text screens to render per frame
}

-- Font management
local fontCache = setmetatable({}, {__mode = "v"}) -- Weak values for auto-cleanup
local fontCount = 0
local MAX_FONTS = 50

local function CreateFont(name, size)
    local fontName = string.format("rText_%s_%d", name, size)
    
    if not fontCache[fontName] then
        if fontCount >= MAX_FONTS then
            fontCache = setmetatable({}, {__mode = "v"})
            fontCount = 0
            collectgarbage("step", 100)
        end
        
        surface.CreateFont(fontName, {
            font = name,
            size = math_Clamp(size, 10, 100) * 3,
            weight = 500,
            antialias = true,
            extended = true
        })
        
        fontCache[fontName] = true
        fontCount = fontCount + 1
    end
    
    return fontName
end

-- Rainbow color cache
local rainbowCache = {}
local RAINBOW_UPDATE_INTERVAL = 0.1
local lastRainbowUpdate = 0

local function GetRainbowColor(i)
    local curTime = CurTime()
    if curTime - lastRainbowUpdate > RAINBOW_UPDATE_INTERVAL then
        for j = 1, 8 do
            rainbowCache[j] = HSVToColor((curTime * 60 + (j * 5)) % 360, 1, 1)
        end
        lastRainbowUpdate = curTime
    end
    return rainbowCache[i] or rainbowCache[1]
end

-- Batch rendering system
local renderQueue = {}
local lastQueueProcess = 0
local QUEUE_PROCESS_INTERVAL = 0.016 -- ~60fps

local function ProcessRenderQueue()
    local curTime = CurTime()
    if curTime - lastQueueProcess < QUEUE_PROCESS_INTERVAL then return end
    lastQueueProcess = curTime
    
    local processed = 0
    for ent, _ in pairs(renderQueue) do
        if not IsValid(ent) then
            renderQueue[ent] = nil
            continue
        end
        
        -- Process render
        rText.Render.ProcessEntity(ent)
        renderQueue[ent] = nil
        
        processed = processed + 1
        if processed >= RENDER_SETTINGS.BATCH_SIZE then break end
    end
end

-- Main render function
function rText.Render.ProcessEntity(ent)
    if not ent.TextData or #ent.TextData == 0 then return end
    
    local pos = ent:GetPos()
    local distSqr = LocalPlayer():GetPos():DistToSqr(pos)
    
    if distSqr > RENDER_SETTINGS.MAX_DISTANCE_SQR then return end
    
    -- Calculate fade
    local alpha = 1
    if distSqr > (RENDER_SETTINGS.FADE_START * RENDER_SETTINGS.FADE_START) then
        alpha = math_Clamp(1 - ((math.sqrt(distSqr) - RENDER_SETTINGS.FADE_START) / 
                               (RENDER_SETTINGS.MAX_DISTANCE - RENDER_SETTINGS.FADE_START)), 
                          RENDER_SETTINGS.MIN_ALPHA, 1)
    end
    
    local ang = ent:GetAngles()
    
    cam.Start3D2D(pos + ang:Forward() * 0.1, ang, 0.25)
        rText.Render.DrawText(ent.TextData, alpha)
    cam.End3D2D()
end

-- Text drawing function
function rText.Render.DrawText(data, alpha)
    local totalHeight = 0
    local spacing = data.spacing or 1
    local maxWidth = 0
    
    -- Pre-calculate dimensions
    for _, line in ipairs(data) do
        if not line or not line.text then continue end
        surface_SetFont(CreateFont(line.font or "Roboto", line.size or 30))
        local w, h = surface.GetTextSize(line.text)
        totalHeight = totalHeight + h * spacing
        maxWidth = math.max(maxWidth, w)
    end
    
    local y = -totalHeight / 2
    
    -- Draw lines
    for i, line in ipairs(data) do
        if not line or not line.text then continue end
        
        local font = CreateFont(line.font or "Roboto", line.size or 30)
        surface_SetFont(font)
        local w, h = surface.GetTextSize(line.text)
        
        -- Calculate position
        local x = 0
        local align = line.align or "center"
        if align == "left" then
            x = -maxWidth/2
        elseif align == "right" then
            x = maxWidth/2
        end
        
        -- Get color
        local color = line.rainbow == 1 and GetRainbowColor(i) or line.color
        color = Color(color.r, color.g, color.b, color.a * alpha)
        
        -- Draw text
        draw_SimpleText(
            line.text,
            font,
            x,
            y,
            color,
            align == "right" and TEXT_ALIGN_RIGHT or 
            align == "left" and TEXT_ALIGN_LEFT or 
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_TOP
        )
        
        y = y + h * spacing
    end
end

-- Hook into rendering system
hook.Add("PostDrawTranslucentRenderables", "rText_Render", function()
    ProcessRenderQueue()
end)

-- Add entity to render queue
function rText.Render.QueueEntity(ent)
    if not IsValid(ent) then return end
    renderQueue[ent] = true
end
