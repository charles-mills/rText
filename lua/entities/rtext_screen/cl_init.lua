include("shared.lua")

-- Client convars for configuration
local render_range = CreateClientConVar("rtext_render_range", 2000, true, false, "Maximum render distance for text screens")

-- Cache for custom fonts
local fontCache = {}

-- Create a custom font based on size
local function CreateFont(name, size)
    local fontName = string.format("rText_%s_%d", name, size)
    if not fontCache[fontName] then
        surface.CreateFont(fontName, {
            font = name,
            size = math.Clamp(size, 10, 100) * 20, -- Scale size more reasonably
            weight = 500,
            antialias = true,
            extended = true
        })
        fontCache[fontName] = true
    end
    return fontName
end

function ENT:Initialize()
    self:SetMaterial("models/effects/vol_light001")
    self:SetRenderMode(RENDERMODE_NONE)
    self.TextData = {}
    
    net.Start("rText_RequestUpdate")
        net.WriteEntity(self)
    net.SendToServer()
end

-- Rainbow color calculation
local function GetRainbowColor(i)
    return HSVToColor((CurTime() * 60 + (i * 5)) % 360, 1, 1)
end

function ENT:Draw()
    local pos = self:GetPos()
    local dist = LocalPlayer():GetPos():DistToSqr(pos)
    
    if dist > (render_range:GetInt() * render_range:GetInt()) then return end
    
    local ang = self:GetAngles()
    
    -- No need for additional rotations, the angle is already correct from the tool
    
    -- Draw front
    cam.Start3D2D(pos + ang:Forward() * 0.1, ang, 0.25)
        self:DrawText()
    cam.End3D2D()
    
    -- Draw back
    ang:RotateAroundAxis(ang:Forward(), 180)
    cam.Start3D2D(pos + ang:Forward() * 0.1, ang, 0.25)
        self:DrawText()
    cam.End3D2D()
end

function ENT:DrawText()
    if not self.TextData or #self.TextData == 0 then return end
    
    local totalHeight = 0
    
    -- Calculate total height based on actual font sizes
    for _, line in ipairs(self.TextData) do
        if not line or not line.text then continue end
        surface.SetFont(CreateFont(line.font, line.size))
        local _, h = surface.GetTextSize(line.text)
        totalHeight = totalHeight + h + 5 -- Add small padding
    end
    
    -- Start drawing from top
    local y = -totalHeight / 2
    
    -- Draw each line
    for i, line in ipairs(self.TextData) do
        if not line or not line.text then continue end
        
        local font = CreateFont(line.font, line.size)
        surface.SetFont(font)
        local _, h = surface.GetTextSize(line.text)
        
        local color = line.rainbow == 1 and GetRainbowColor(i) or line.color
        
        -- Draw text
        draw.SimpleText(
            line.text,
            font,
            0, -- Center X
            y, -- Current Y position
            color,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_TOP
        )
        
        y = y + h + 5 -- Add padding between lines
    end
end

-- Handle incoming updates from server
net.Receive("rText_Update", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end
    
    ent.TextData = net.ReadTable()
end)
