TOOL = TOOL or {}
TOOL.Category = "rlib"
TOOL.Name = "rText"
TOOL.Command = nil
TOOL.ConfigName = ""

-- Create ConVars
if CLIENT then
    TOOL.Information = {
        { name = "left" },
        { name = "right" },
        { name = "reload" }
    }

    language.Add("tool.rtext.name", "rText")
    language.Add("tool.rtext.desc", "Create customizable 3D2D text screens")
    language.Add("tool.rtext.0", "Left click: Place text screen | Right click: Update existing | Reload: Copy settings")

    for i = 1, 8 do
        CreateClientConVar("rtext_line" .. i, "", true, true)
    end

    CreateClientConVar("rtext_font", "Roboto", true, true)
    CreateClientConVar("rtext_size", "30", true, true)
    CreateClientConVar("rtext_color_r", "255", true, true)
    CreateClientConVar("rtext_color_g", "255", true, true)
    CreateClientConVar("rtext_color_b", "255", true, true)
    CreateClientConVar("rtext_color_a", "255", true, true)
    CreateClientConVar("rtext_rainbow", "0", true, true)
    CreateClientConVar("rtext_permanent", "0", true, true)
end

-- Default configuration
local Config = {
    max_distance = 2000,
    max_lines = 8,
    max_chars = 128,
    allowed_fonts = {
        ["Roboto"] = true,
        ["Montserrat"] = true,
        ["Arial"] = true,
        ["Helvetica"] = true,
        ["DermaLarge"] = true
    }
}

TOOL.Config = Config

local function GetPlayerSettings(ply)
    local settings = {
        lines = {},
        font = ply:GetInfo("rtext_font"),
        size = math.Clamp(ply:GetInfoNum("rtext_size", 30), 10, 100),
        color = Color(
            ply:GetInfoNum("rtext_color_r", 255),
            ply:GetInfoNum("rtext_color_g", 255),
            ply:GetInfoNum("rtext_color_b", 255),
            ply:GetInfoNum("rtext_color_a", 255)
        ),
        rainbow = ply:GetInfoNum("rtext_rainbow", 0) == 1,
        permanent = ply:GetInfoNum("rtext_permanent", 0) == 1
    }

    for i = 1, 8 do
        settings.lines[i] = ply:GetInfo("rtext_line" .. i)
    end

    return settings
end

local function CreateTextScreen(ply, tr, ang)
    if not IsValid(ply) or not tr.Hit then return end
    
    if SERVER then
        -- Spawn limit check
        local count = 0
        for _, ent in ipairs(ents.FindByClass("rtext_screen")) do
            if IsValid(ent:GetCreator()) and ent:GetCreator() == ply then
                count = count + 1
            end
        end
        
        local max = ply:GetInfoNum("sbox_maxrtextscreens", 10)
        if count >= max then
            ply:ChatPrint("You've reached the maximum number of text screens!")
            return
        end

        -- Create the entity
        local textScreen = ents.Create("rtext_screen")
        if not IsValid(textScreen) then return end

        textScreen:SetPos(tr.HitPos)
        textScreen:SetAngles(ang)
        textScreen:Spawn()
        textScreen:SetCreator(ply)
        
        -- Apply initial settings
        textScreen:UpdateText(ply, GetPlayerSettings(ply))

        -- Undo registration
        undo.Create("rText Screen")
            undo.AddEntity(textScreen)
            undo.SetPlayer(ply)
        undo.Finish()

        return textScreen
    end
end

function TOOL:LeftClick(tr)
    if CLIENT then return true end
    
    local ang = tr.HitNormal:Angle()
    local ply = self:GetOwner()
    
    -- If it's a wall (roughly vertical surface)
    if math.abs(tr.HitNormal.z) < 0.1 then
        -- Start with surface normal angle
        ang = tr.HitNormal:Angle()
        
        -- Rotate to face outward from wall
        ang:RotateAroundAxis(ang:Right(), -90)
        
        -- Get player's yaw and normalize it to 90-degree increments
        local plyYaw = ply:GetAngles().y
        local normalizedYaw = math.Round(plyYaw / 90) * 90
        
        -- Apply the normalized rotation
        ang:RotateAroundAxis(tr.HitNormal, -normalizedYaw + 90)
    else
        -- If it's a floor/ceiling
        ang:RotateAroundAxis(ang:Right(), 90)
        
        -- Normalize player's yaw to 90-degree increments
        local plyYaw = ply:GetAngles().y
        local normalizedYaw = math.Round(plyYaw / 90) * 90
        
        ang:RotateAroundAxis(ang:Up(), normalizedYaw - 90)
    end

    local textScreen = CreateTextScreen(self:GetOwner(), tr, ang)
    if not IsValid(textScreen) then return false end

    return true
end

function TOOL:RightClick(tr)
    if CLIENT then return true end
    
    local ent = tr.Entity
    if not IsValid(ent) or ent:GetClass() ~= "rtext_screen" then return false end
    
    -- Update existing text screen with current tool settings
    ent:UpdateText(self:GetOwner(), GetPlayerSettings(self:GetOwner()))
    
    return true
end

function TOOL:Reload(tr)
    if CLIENT then return true end
    
    local ent = tr.Entity
    if not IsValid(ent) or ent:GetClass() ~= "rtext_screen" then return false end
    
    -- Copy settings from text screen to tool
    local ply = self:GetOwner()
    local data = ent.TextData
    
    for i = 1, 8 do
        ply:ConCommand("rtext_line" .. i .. " " .. (data.lines[i] or ""))
    end
    
    ply:ConCommand("rtext_font " .. data.font)
    ply:ConCommand("rtext_size " .. data.size)
    ply:ConCommand("rtext_color_r " .. data.color.r)
    ply:ConCommand("rtext_color_g " .. data.color.g)
    ply:ConCommand("rtext_color_b " .. data.color.b)
    ply:ConCommand("rtext_color_a " .. data.color.a)
    ply:ConCommand("rtext_rainbow " .. (data.rainbow and "1" or "0"))
    ply:ConCommand("rtext_permanent " .. (data.permanent and "1" or "0"))
    
    return true
end

local function BuildPanel(panel)
    if not IsValid(panel) then return end
    panel:ClearControls()

    -- Add header
    panel:AddControl("Header", {
        Description = "Create and customize 3D text screens in the world"
    })

    -- Text input for each line
    for i = 1, Config.max_lines do
        panel:AddControl("TextBox", {
            Label = "Line " .. i,
            Command = "rtext_line" .. i,
            MaxLength = Config.max_chars
        })
    end

    -- Font selector
    local fontCombo = panel:ComboBox("Font", "rtext_font")
    for font in pairs(Config.allowed_fonts) do
        fontCombo:AddChoice(font)
    end

    -- Size slider
    panel:NumSlider("Size", "rtext_size", 10, 100, 0)

    -- Color mixer
    panel:AddControl("Color", {
        Label = "Text Color",
        Red = "rtext_color_r",
        Green = "rtext_color_g",
        Blue = "rtext_color_b",
        Alpha = "rtext_color_a"
    })

    -- Advanced options
    panel:AddControl("CheckBox", {
        Label = "Rainbow Effect",
        Command = "rtext_rainbow"
    })

    panel:AddControl("CheckBox", {
        Label = "Permanent Screen",
        Command = "rtext_permanent"
    })
end

function TOOL.BuildCPanel(panel)
    BuildPanel(panel)
end
