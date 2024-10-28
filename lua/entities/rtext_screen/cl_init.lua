include("shared.lua")

-- Cache for custom fonts
local fontCache = {}

-- Create a custom font based on size
local function CreateFont(name, size)
    local fontName = string.format("rText_%s_%d", name, size)
    if not fontCache[fontName] then
        surface.CreateFont(fontName, {
            font = name,
            size = size * 10,
            weight = 500,
            antialias = true,
            extended = true
        })
        fontCache[fontName] = true
    end
    return fontName
end

function ENT:Initialize()
    self.TextData = {
        lines = {},
        font = "Roboto",
        size = 30,
        color = Color(255, 255, 255, 255),
        rainbow = false,
        permanent = false
    }

    -- Request initial data from server
    net.Start("rText_RequestUpdate")
        net.WriteEntity(self)
    net.SendToServer()
end

-- Rainbow color calculation
local function GetRainbowColor(frequency)
    local time = CurTime() * frequency
    return Color(
        math.sin(time) * 127 + 128,
        math.sin(time + 2) * 127 + 128,
        math.sin(time + 4) * 127 + 128,
        255
    )
end

function ENT:Draw()
    -- Don't render the base model
    local pos = self:GetPos()
    local ang = self:GetAngles()
    local dist = LocalPlayer():GetPos():Distance(pos)
    
    -- Don't render if too far away
    if dist > 2000 then return end

    -- Calculate alpha based on distance
    local alpha = math.Clamp(1 - (dist / 2000), 0.1, 1)
    
    -- Start 3D2D rendering
    cam.Start3D2D(pos + ang:Up() * 0.1, ang, 0.25)
        -- Calculate the current color
        local color = self.TextData.rainbow and GetRainbowColor(1) or self.TextData.color
        color.a = color.a * alpha
        
        -- Create or get cached font
        local fontName = CreateFont(self.TextData.font, self.TextData.size)
        
        -- Draw each line
        for i, line in ipairs(self.TextData.lines) do
            if line and line ~= "" then
                draw.SimpleText(
                    line,
                    fontName,
                    0,
                    (i - 1) * (self.TextData.size + 5),
                    color,
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_TOP
                )
            end
        end
    cam.End3D2D()
end

-- Handle incoming updates from server
net.Receive("rText_Update", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end
    
    ent.TextData = net.ReadTable()
end)
