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
    -- Effect convars
    CreateClientConVar("rtext_glow", "0", true, true)
    CreateClientConVar("rtext_outline", "0", true, true)
    CreateClientConVar("rtext_3d", "0", true, true)
    CreateClientConVar("rtext_align", "center", true, true)
    CreateClientConVar("rtext_spacing", "1", true, true)

    -- Add size convar for each line
    for i = 1, 8 do
        CreateClientConVar("rtext_line" .. i .. "_size", "30", true, true)
    end

    -- Font cache for preview
    local fontCache = {}
    local function CreatePreviewFont(name, size)
        local fontName = string.format("rText_preview_%s_%d", name, size)
        
        if not fontCache[fontName] then
            surface.CreateFont(fontName, {
                font = name,
                size = size * 3,
                weight = 500,
                antialias = true,
                extended = true
            })
            fontCache[fontName] = true
        end
        
        return fontName
    end

    -- Preview system
    local function DrawPreview()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "gmod_tool" or wep:GetMode() ~= "rtext" then 
            return 
        end

        local tr = ply:GetEyeTrace()
        if not tr.Hit then return end
        
        -- Calculate angle
        local ang = tr.HitNormal:Angle()
        if math.abs(tr.HitNormal.z) < 0.1 then
            ang = tr.HitNormal:Angle()
            ang:RotateAroundAxis(ang:Right(), -90)
            local plyYaw = ply:GetAngles().y
            local normalizedYaw = math.Round(plyYaw / 90) * 90
            ang:RotateAroundAxis(tr.HitNormal, -normalizedYaw + 90)
        else
            ang:RotateAroundAxis(ang:Right(), 90)
            local plyYaw = ply:GetAngles().y
            local normalizedYaw = math.Round(plyYaw / 90) * 90
            ang:RotateAroundAxis(ang:Up(), normalizedYaw - 90)
        end

        local pos = tr.HitPos + tr.HitNormal * 0.1

        -- Draw preview text
        cam.Start3D2D(pos, ang, 0.25)
            local totalHeight = 0
            local lines = {}
            local spacing = GetConVar("rtext_spacing"):GetFloat()
            local font = GetConVar("rtext_font"):GetString()
            local previewOpacity = rText.Config.Get("preview_opacity") or 50
            
            -- Calculate total height first
            for i = 1, 8 do
                local text = GetConVar("rtext_line" .. i):GetString()
                if text and text ~= "" then
                    local size = GetConVar("rtext_line" .. i .. "_size"):GetInt()
                    local fontName = CreatePreviewFont(font, size)
                    surface.SetFont(fontName)
                    local w, h = surface.GetTextSize(text)
                    totalHeight = totalHeight + (h * spacing)
                    
                    table.insert(lines, {
                        text = text,
                        font = fontName,
                        height = h,
                        width = w,
                        size = size
                    })
                end
            end
            
            -- Draw from center
            local y = -totalHeight / 2
            
            for i, line in ipairs(lines) do
                local color = Color(
                    GetConVar("rtext_color_r"):GetInt(),
                    GetConVar("rtext_color_g"):GetInt(),
                    GetConVar("rtext_color_b"):GetInt(),
                    previewOpacity
                )
                
                if GetConVar("rtext_rainbow"):GetBool() then
                    local rainbow = HSVToColor((CurTime() * 50 + (i * 25)) % 360, 1, 1)
                    color = Color(rainbow.r, rainbow.g, rainbow.b, previewOpacity)
                end
                
                -- Draw outline if enabled
                if GetConVar("rtext_outline"):GetBool() then
                    local outlineColor = Color(0, 0, 0, previewOpacity)
                    for ox = -1, 1 do
                        for oy = -1, 1 do
                            if ox == 0 and oy == 0 then continue end
                            draw.SimpleText(
                                line.text,
                                line.font,
                                ox,
                                y + oy,
                                outlineColor,
                                TEXT_ALIGN_CENTER,
                                TEXT_ALIGN_TOP
                            )
                        end
                    end
                end
                
                -- Draw glow if enabled
                if GetConVar("rtext_glow"):GetBool() then
                    local glowColor = Color(color.r, color.g, color.b, previewOpacity * 0.5)
                    for r = 1, 3 do
                        draw.SimpleText(
                            line.text,
                            line.font,
                            r,
                            y,
                            glowColor,
                            TEXT_ALIGN_CENTER,
                            TEXT_ALIGN_TOP
                        )
                        draw.SimpleText(
                            line.text,
                            line.font,
                            -r,
                            y,
                            glowColor,
                            TEXT_ALIGN_CENTER,
                            TEXT_ALIGN_TOP
                        )
                    end
                end
                
                -- Draw main text
                draw.SimpleText(
                    line.text,
                    line.font,
                    0,
                    y,
                    color,
                    TEXT_ALIGN_CENTER,
                    TEXT_ALIGN_TOP
                )
                
                y = y + (line.height * spacing)
            end
        cam.End3D2D()
    end

    -- Initialize preview system
    hook.Add("Initialize", "rText_InitPreview", function()
        hook.Add("PostDrawTranslucentRenderables", "rText_Preview", function(depth, skybox)
            if skybox then return end
            DrawPreview()
        end)
    end)

    -- No need for Deploy/Holster/ToolSwitched hooks anymore
    -- The preview will automatically show/hide based on weapon checks in DrawPreview
end

function TOOL:LeftClick(tr)
    if CLIENT then return true end
    
    if not rText or not rText.Core then
        ErrorNoHalt("[rText] Core systems not initialized!")
        return false
    end
    
    local ang = tr.HitNormal:Angle()
    
    -- If it's a wall (roughly vertical surface)
    if math.abs(tr.HitNormal.z) < 0.1 then
        ang = tr.HitNormal:Angle()
        ang:RotateAroundAxis(ang:Right(), -90)
        local plyYaw = self:GetOwner():GetAngles().y
        local normalizedYaw = math.Round(plyYaw / 90) * 90
        ang:RotateAroundAxis(tr.HitNormal, -normalizedYaw + 90)
    else
        -- If it's a floor/ceiling
        ang:RotateAroundAxis(ang:Right(), 90)
        local plyYaw = self:GetOwner():GetAngles().y
        local normalizedYaw = math.Round(plyYaw / 90) * 90
        ang:RotateAroundAxis(ang:Up(), normalizedYaw - 90)
    end

    local textScreen = rText.Core.CreateTextScreen(self:GetOwner(), tr, ang)
    if not IsValid(textScreen) then return false end

    return true
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
        color = Color(
            ply:GetInfoNum("rtext_color_r", 255),
            ply:GetInfoNum("rtext_color_g", 255),
            ply:GetInfoNum("rtext_color_b", 255),
            255
        ),
        font = ply:GetInfo("rtext_font"),
        rainbow = ply:GetInfoNum("rtext_rainbow", 0) == 1,
        spacing = ply:GetInfoNum("rtext_spacing", 1),
        permanent = ply:GetInfoNum("rtext_permanent", 0) == 1,
        glow = ply:GetInfoNum("rtext_glow", 0) == 1,
        outline = ply:GetInfoNum("rtext_outline", 0) == 1,
        three_d = ply:GetInfoNum("rtext_3d", 0) == 1,
        align = ply:GetInfo("rtext_align")
    }
    
    -- Get text and size for each line
    local maxLines = rText.Config.Cache.maxLines or 8
    for i = 1, maxLines do
        local text = ply:GetInfo("rtext_line" .. i)
        if text and text ~= "" then
            settings.lines[i] = {
                text = text,
                size = ply:GetInfoNum("rtext_line" .. i .. "_size", 30)
            }
        end
    end
    
    return settings
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
    
    if not data then return false end
    
    -- Clear existing lines first
    for i = 1, 8 do
        ply:ConCommand("rtext_line" .. i .. " ")
        ply:ConCommand("rtext_line" .. i .. "_size 30")
    end
    
    -- Copy each line's text and size
    for i, line in ipairs(data) do
        if line and line.text then
            ply:ConCommand(string.format("rtext_line%d %s", i, line.text))
            ply:ConCommand(string.format("rtext_line%d_size %d", i, line.size or 30))
        end
    end
    
    -- Copy other settings
    if data[1] then -- Use first line's settings as default
        ply:ConCommand("rtext_font " .. (data[1].font or "Roboto"))
        ply:ConCommand("rtext_color_r " .. (data[1].color and data[1].color.r or 255))
        ply:ConCommand("rtext_color_g " .. (data[1].color and data[1].color.g or 255))
        ply:ConCommand("rtext_color_b " .. (data[1].color and data[1].color.b or 255))
        ply:ConCommand("rtext_color_a " .. (data[1].color and data[1].color.a or 255))
        ply:ConCommand("rtext_rainbow " .. (data[1].rainbow and "1" or "0"))
        ply:ConCommand("rtext_glow " .. (data[1].glow and "1" or "0"))
        ply:ConCommand("rtext_outline " .. (data[1].outline and "1" or "0"))
        ply:ConCommand("rtext_3d " .. (data[1].three_d and "1" or "0"))
        ply:ConCommand("rtext_align " .. (data[1].align or "center"))
        ply:ConCommand("rtext_spacing " .. (data[1].spacing or "1"))
    end
    
    return true
end

local function BuildPanel(panel)
    if not IsValid(panel) then return end
    panel:ClearControls()

    -- Add header
    panel:AddControl("Header", {
        Description = "Create and customize 3D text screens in the world"
    })

    -- Color mixer at the top
    panel:AddControl("Color", {
        Label = "Text Color",
        Red = "rtext_color_r",
        Green = "rtext_color_g",
        Blue = "rtext_color_b",
        Alpha = "rtext_color_a"
    })

    -- Font selector
    local fontCombo = panel:ComboBox("Font", "rtext_font")
    for font in pairs(Config.allowed_fonts) do
        fontCombo:AddChoice(font)
    end

    -- Main lines (always visible)
    for i = 1, 3 do
        local lineContainer = vgui.Create("DPanel")
        lineContainer:SetTall(45)
        lineContainer:SetPaintBackground(false)
        
        -- Text input
        local textBox = lineContainer:Add("DTextEntry")
        textBox:SetConVar("rtext_line" .. i)
        textBox:Dock(TOP)
        textBox:SetTall(20)
        
        -- Size slider
        local sizeSlider = lineContainer:Add("DNumSlider")
        sizeSlider:SetConVar("rtext_line" .. i .. "_size")
        sizeSlider:SetText("Size")
        sizeSlider:SetMin(10)
        sizeSlider:SetMax(100)
        sizeSlider:SetDecimals(0)
        sizeSlider:Dock(TOP)
        sizeSlider:DockMargin(0, 2, 0, 0)
        sizeSlider:SetTall(20)
        
        panel:AddItem(lineContainer)
    end

    -- Additional Lines Form
    local extraLines = vgui.Create("DForm", panel)
    extraLines:SetName("Additional Lines")
    extraLines:SetExpanded(false)
    
    for i = 4, Config.max_lines do
        local lineContainer = vgui.Create("DPanel")
        lineContainer:SetTall(45)
        lineContainer:SetPaintBackground(false)
        
        local textBox = lineContainer:Add("DTextEntry")
        textBox:SetConVar("rtext_line" .. i)
        textBox:Dock(TOP)
        textBox:SetTall(20)
        
        local sizeSlider = lineContainer:Add("DNumSlider")
        sizeSlider:SetConVar("rtext_line" .. i .. "_size")
        sizeSlider:SetText("Size")
        sizeSlider:SetMin(10)
        sizeSlider:SetMax(100)
        sizeSlider:SetDecimals(0)
        sizeSlider:Dock(TOP)
        sizeSlider:DockMargin(0, 2, 0, 0)
        sizeSlider:SetTall(20)
        
        extraLines:AddItem(lineContainer)
    end
    
    panel:AddItem(extraLines)

    -- Style Form
    local stylePanel = vgui.Create("DForm", panel)
    stylePanel:SetName("Text Style")
    stylePanel:SetExpanded(false)
    
    -- Alignment
    local alignCombo = vgui.Create("DComboBox")
    alignCombo:SetConVar("rtext_align")
    alignCombo:AddChoice("Left")
    alignCombo:AddChoice("Center")
    alignCombo:AddChoice("Right")
    stylePanel:AddItem(alignCombo)
    
    -- Line spacing
    local spacingSlider = vgui.Create("DNumSlider")
    spacingSlider:SetConVar("rtext_spacing")
    spacingSlider:SetText("Line Spacing")
    spacingSlider:SetMin(0.5)
    spacingSlider:SetMax(2)
    spacingSlider:SetDecimals(2)
    stylePanel:AddItem(spacingSlider)
    
    -- Visual effects checkboxes
    local effects = {
        { label = "3D Effect", cmd = "rtext_3d" },
        { label = "Glow Effect", cmd = "rtext_glow" },
        { label = "Text Outline", cmd = "rtext_outline" },
        { label = "Rainbow Effect", cmd = "rtext_rainbow" }
    }
    
    for _, effect in ipairs(effects) do
        local checkbox = vgui.Create("DCheckBoxLabel")
        checkbox:SetText(effect.label)
        checkbox:SetConVar(effect.cmd)
        stylePanel:AddItem(checkbox)
    end
    
    panel:AddItem(stylePanel)

    -- Misc Form
    local miscPanel = vgui.Create("DForm", panel)
    miscPanel:SetName("Misc Settings")
    miscPanel:SetExpanded(false)
    
    local permanentCheck = vgui.Create("DCheckBoxLabel")
    permanentCheck:SetText("Permanent Screen")
    permanentCheck:SetConVar("rtext_permanent")
    miscPanel:AddItem(permanentCheck)
    
    panel:AddItem(miscPanel)
end

function TOOL.BuildCPanel(panel)
    BuildPanel(panel)
end

