rText = rText or {}
rText.Render = {
    -- Expose these functions to be used by the entity
    Render3DText = function(text, font, pos, ang, color, effects, lineIndex)
        if not text or not font then return end
        
        local up = ang:Up()
        local right = ang:Right()
        local forward = ang:Forward()

        -- 3D effect depth
        local depth = 2
        if effects.three_d then
            -- Draw shadow layers
            for i = 1, depth do
                local shadowColor = Color(0, 0, 0, (color.a or 255) * (1 - i/depth))
                local offset = forward * (i * -0.1)
                cam.Start3D2D(pos + offset, ang, 0.1)
                    rText.Render.RenderText(text, font, 0, 0, shadowColor, effects, lineIndex)
                cam.End3D2D()
            end
        end

        -- Draw main text
        cam.Start3D2D(pos, ang, 0.1)
            rText.Render.RenderText(text, font, 0, 0, color, effects, lineIndex)
        cam.End3D2D()
    end,

    RenderText = function(text, font, x, y, color, effects, lineIndex)
        -- Rainbow effect
        if effects.rainbow == 1 then
            local offset = lineIndex and (lineIndex * 0.5) or 0
            color = rText.Render.GetRainbowColorWithOffset(offset)
        end

        -- Glow effect (improved)
        if effects.glow then
            local glowSize = 4
            local glowSteps = 12
            local glowColor = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, color.a * 0.3)
            
            -- Create smooth glow effect
            for i = 1, glowSteps do
                local angle = (i / glowSteps) * math.pi * 2
                local intensity = 0.5 + math.sin(angle) * 0.5
                local glowX = x + math.cos(angle) * glowSize
                local glowY = y + math.sin(angle) * glowSize
                
                local thisGlowColor = Color(
                    glowColor.r,
                    glowColor.g,
                    glowColor.b,
                    glowColor.a * intensity
                )
                
                draw.SimpleText(text, font, glowX, glowY, thisGlowColor, TEXT_ALIGN_CENTER)
            end
        end

        -- Outline effect (improved)
        if effects.outline then
            local outlineColor = Color(0, 0, 0, color.a)
            local outlineSize = 1.5
            
            -- Outer outline (thicker)
            for x_offset = -outlineSize, outlineSize, 0.5 do
                for y_offset = -outlineSize, outlineSize, 0.5 do
                    if x_offset == 0 and y_offset == 0 then continue end
                    
                    local distance = math.sqrt(x_offset * x_offset + y_offset * y_offset)
                    local alpha = math.Clamp(1 - (distance / outlineSize), 0, 1)
                    outlineColor.a = color.a * alpha
                    
                    draw.SimpleText(text, font, x + x_offset, y + y_offset, outlineColor, TEXT_ALIGN_CENTER)
                end
            end
            
            -- Inner outline (sharper)
            outlineColor.a = color.a
            for i = 0, 7 do
                local angle = (i / 8) * math.pi * 2
                local ox = math.cos(angle)
                local oy = math.sin(angle)
                draw.SimpleText(text, font, x + ox, y + oy, outlineColor, TEXT_ALIGN_CENTER)
            end
        end

        -- 3D effect (improved)
        if effects.three_d then
            local depth = 4
            local shadowSteps = 8
            local baseAlpha = color.a * 0.7
            
            -- Create layered shadow effect
            for i = 1, shadowSteps do
                local shadowDepth = (i / shadowSteps) * depth
                local shadowColor = Color(0, 0, 0, baseAlpha * (1 - (i / shadowSteps)))
                
                draw.SimpleText(text, font, 
                    x - shadowDepth, 
                    y - shadowDepth, 
                    shadowColor, 
                    TEXT_ALIGN_CENTER
                )
            end
            
            -- Add subtle color gradient to main text
            local gradientColor = Color(
                math.min(color.r * 1.2, 255),
                math.min(color.g * 1.2, 255),
                math.min(color.b * 1.2, 255),
                color.a
            )
            
            draw.SimpleText(text, font, x + 0.5, y + 0.5, gradientColor, TEXT_ALIGN_CENTER)
        end

        -- Main text (always drawn last)
        draw.SimpleText(text, font, x, y, color, TEXT_ALIGN_CENTER)
    end,

    GetRainbowColorWithOffset = function(offset)
        if not offset then return rainbowColor end
        
        local frequency = 0.5
        local time = CurTime() * frequency + offset
        
        return Color(
            math.sin(time) * 127 + 128,
            math.sin(time + 2.094) * 127 + 128,
            math.sin(time + 4.189) * 127 + 128
        )
    end
}

-- Cache frequently used functions
local surface_SetFont = surface.SetFont
local surface_SetTextColor = surface.SetTextColor
local surface_SetTextPos = surface.SetTextPos
local surface_DrawText = surface.DrawText
local draw_SimpleText = draw.SimpleText
local math_Clamp = math.Clamp
local CurTime = CurTime
local HSVToColor = HSVToColor
local Lerp = Lerp

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
    return rText.Fonts.Create(name, size)
end

-- Global rainbow color calculation
local rainbowColor = Color(255, 0, 0)
local function UpdateGlobalRainbow()
    local frequency = 0.5 -- Lower = slower
    local time = CurTime() * frequency
    
    -- Use smoother sine waves with better phase offsets
    local r = math.sin(time) * 127 + 128
    local g = math.sin(time + 2.094) * 127 + 128  -- 2.094 radians = 120 degrees
    local b = math.sin(time + 4.189) * 127 + 128  -- 4.189 radians = 240 degrees
    
    -- Smooth color transitions
    rainbowColor.r = Lerp(0.1, rainbowColor.r, r)
    rainbowColor.g = Lerp(0.1, rainbowColor.g, g)
    rainbowColor.b = Lerp(0.1, rainbowColor.b, b)
end

-- Update more frequently for smoother animation
timer.Remove("rText_RainbowUpdate")
timer.Create("rText_RainbowUpdate", 0.01, 0, UpdateGlobalRainbow)

-- Add this helper function for getting rainbow colors with offset
local function GetRainbowColorWithOffset(offset)
    if not offset then return rainbowColor end
    
    local frequency = 0.5
    local time = CurTime() * frequency + offset
    
    return Color(
        math.sin(time) * 127 + 128,
        math.sin(time + 2.094) * 127 + 128,
        math.sin(time + 4.189) * 127 + 128
    )
end

-- Render effects
local function RenderText(text, font, x, y, color, effects, lineIndex)
    if effects.rainbow == 1 then
        -- Add slight offset based on line index for wave effect
        local offset = lineIndex and (lineIndex * 0.5) or 0
        color = GetRainbowColorWithOffset(offset)
    end

    if effects.glow then
        local glowColor = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, color.a * 0.4)
        for i = 1, 8 do
            local ang = math.rad(i * 45)
            local ox = math.cos(ang) * 2
            local oy = math.sin(ang) * 2
            draw.SimpleText(text, font, x + ox, y + oy, glowColor, TEXT_ALIGN_CENTER)
        end
    end

    if effects.outline then
        local outlineColor = Color(0, 0, 0, color.a)
        for i = -1, 1 do
            for j = -1, 1 do
                if i ~= 0 or j ~= 0 then
                    draw.SimpleText(text, font, x + i, y + j, outlineColor, TEXT_ALIGN_CENTER)
                end
            end
        end
    end

    -- Draw main text
    draw.SimpleText(text, font, x, y, color, TEXT_ALIGN_CENTER)
end

-- 3D effect rendering
local function Render3DText(text, font, pos, ang, color, effects, scale)
    local up = ang:Up()
    local right = ang:Right()
    local forward = ang:Forward()

    -- 3D effect depth
    local depth = 2
    if effects.three_d then
        -- Draw shadow layers
        for i = 1, depth do
            local shadowColor = Color(0, 0, 0, color.a * (1 - i/depth))
            local offset = forward * (i * -0.1)
            cam.Start3D2D(pos + offset, ang, scale)
                RenderText(text, font, 0, 0, shadowColor, effects)
            cam.End3D2D()
        end
    end

    -- Draw main text
    cam.Start3D2D(pos, ang, scale)
        RenderText(text, font, 0, 0, color, effects)
    cam.End3D2D()
end

-- Batch rendering system
local renderQueue = {}
local lastQueueProcess = 0
local QUEUE_PROCESS_INTERVAL = 0.016 -- ~60fps

function rText.Render.ProcessRenderQueue()
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
    rText.Render.ProcessRenderQueue()
end)

-- Add entity to render queue
function rText.Render.QueueEntity(ent)
    if not IsValid(ent) then return end
    renderQueue[ent] = true
end

-- At the top of the file, add font creation function
rText.Fonts = rText.Fonts or {}

function rText.Fonts.Create(name, size)
    local fontName = string.format("rText_%s_%d", name, size)
    
    -- Check if font exists by trying to use it
    local exists = pcall(function() 
        surface.SetFont(fontName)
    end)
    
    if not exists then
        surface.CreateFont(fontName, {
            font = name,
            size = math.Clamp(size, 10, 100) * 3,
            weight = 500,
            antialias = true,
            extended = true
        })
    end
    
    return fontName
end
