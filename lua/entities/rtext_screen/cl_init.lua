include("shared.lua")

-- Cached ConVars for performance
local render_range = CreateClientConVar("rtext_render_range", 2000, true, false, "Maximum render distance for text screens")
local render_range_sqr = render_range:GetInt() ^ 2

cvars.AddChangeCallback("rtext_render_range", function(_, _, new)
    render_range_sqr = tonumber(new) ^ 2
end)

-- Cache LocalPlayer for performance
local LocalPlayer = LocalPlayer

-- Cache frequently used functions
local surface_SetFont = surface.SetFont
local surface_SetTextColor = surface.SetTextColor
local draw_SimpleText = draw.SimpleText
local math_sin = math.sin
local math_cos = math.cos
local math_abs = math.abs
local CurTime = CurTime
local HSVToColor = HSVToColor

-- Font cache with size limits to prevent memory bloat
local fontCache = setmetatable({}, {
    __mode = "v" -- Weak values for automatic cleanup
})
local MAX_CACHED_FONTS = 50
local fontCount = 0

-- Create a custom font based on size with caching limits
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

-- Optimized effect calculations
local effectFuncs = {
    pulse = function(time)
        return 0, math_sin(time * 2) * 2
    end,
    wave = function(time, i)
        return math_sin(time + i) * 10, math_cos(time + i) * 5
    end,
    bounce = function(time)
        return 0, math_abs(math_sin(time)) * 10
    end,
    typewriter = function(time, _, text)
        local visible = math.floor((time % (#text + 2)) * 2)
        return 0, 0, visible
    end
}

local function GetEffectOffset(effect, i, line)
    if not effectFuncs[effect] then return 0, 0 end
    return effectFuncs[effect](CurTime() * (line.effect_speed or 1), i, line.text)
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
    self.LastUpdate = 0
    
    net.Start("rText_RequestUpdate")
        net.WriteEntity(self)
    net.SendToServer()
end

-- Optimized draw function with distance checks
function ENT:Draw()
    if not self.TextData or #self.TextData == 0 then return end
    
    local pos = self:GetPos()
    local dist = LocalPlayer():GetPos():DistToSqr(pos)
    
    if dist > render_range_sqr then return end
    
    local ang = self:GetAngles()
    cam.Start3D2D(pos + ang:Forward() * 0.1, ang, 0.25)
        self:DrawText()
    cam.End3D2D()
end

-- Optimized text drawing with error prevention
function ENT:DrawText()
    if not self.TextData or #self.TextData == 0 then return end
    
    local totalHeight = 0
    local spacing = self.TextData.spacing or 1
    
    -- Pre-calculate heights
    for _, line in ipairs(self.TextData) do
        if not line or not line.text then continue end
        surface_SetFont(CreateFont(line.font or "Roboto", line.size or 30))
        local _, h = surface.GetTextSize(line.text)
        totalHeight = totalHeight + h * spacing
    end
    
    local y = -totalHeight / 2
    
    -- Draw each line with optimized rendering
    for i, line in ipairs(self.TextData) do
        if not line or not line.text then continue end
        
        local font = CreateFont(line.font or "Roboto", line.size or 30)
        surface_SetFont(font)
        local w, h = surface.GetTextSize(line.text)
        
        local color = line.rainbow == 1 and GetRainbowColor(i) or line.color
        local xOffset, yOffset, visibleChars = GetEffectOffset(line.effect, i, line)
        
        -- Optimized alignment calculation
        local textAlign = TEXT_ALIGN_CENTER
        if line.align == "left" then
            textAlign = TEXT_ALIGN_LEFT
            xOffset = xOffset - w/2
        elseif line.align == "right" then
            textAlign = TEXT_ALIGN_RIGHT
            xOffset = xOffset + w/2
        end
        
        -- Draw text with effects
        if line.outline then
            local outlineColor = Color(0, 0, 0, color.a)
            for ox = -1, 1 do
                for oy = -1, 1 do
                    if ox == 0 and oy == 0 then continue end
                    draw_SimpleText(line.text, font, xOffset + ox, y + yOffset + oy, outlineColor, textAlign, TEXT_ALIGN_TOP)
                end
            end
        end
        
        -- Draw main text
        local displayText = visibleChars and string.sub(line.text, 1, visibleChars) or line.text
        draw_SimpleText(displayText, font, xOffset, y + yOffset, color, textAlign, TEXT_ALIGN_TOP)
        
        y = y + h * spacing
    end
end

-- Optimized network handling
net.Receive("rText_Update", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end
    
    ent.TextData = net.ReadTable()
    ent.LastUpdate = CurTime()
end)
