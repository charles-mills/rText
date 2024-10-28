-- Shared functions for rText
rText = rText or {}
rText.Core = rText.Core or {}

function rText.Core.CreateTextScreen(ply, tr, ang)
    if not IsValid(ply) or not tr.Hit then return end
    
    if SERVER then
        -- Check if player can spawn (includes wait time check)
        local canSpawn, message = rText.Core.CanPlayerSpawn(ply)
        if not canSpawn then
            ply:ChatPrint(message)
            return
        end

        -- Create the entity
        local textScreen = ents.Create("rtext_screen")
        if not IsValid(textScreen) then return end

        textScreen:SetPos(tr.HitPos)
        textScreen:SetAngles(ang)
        textScreen:Spawn()
        textScreen:SetCreator(ply)
        
        -- Get settings and ensure they're properly formatted
        local settings = rText.GetPlayerSettings(ply)
        
        -- Ensure we have at least one line
        if not settings.lines[1] then
            settings.lines[1] = {
                text = "Sample Text",
                size = 30,
                color = Color(255, 255, 255, 255),
                font = "Roboto",
                rainbow = 0
            }
        end
        
        -- Apply initial settings, bypassing rate limit
        textScreen:UpdateText(ply, settings, true)

        -- Undo registration
        undo.Create("rText Screen")
            undo.AddEntity(textScreen)
            undo.SetPlayer(ply)
        undo.Finish()

        return textScreen
    end
end

function rText.GetPlayerSettings(ply)
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
        effect = ply:GetInfo("rtext_effect"),
        effect_speed = ply:GetInfoNum("rtext_effect_speed", 1),
        glow = ply:GetInfoNum("rtext_glow", 0) == 1,
        outline = ply:GetInfoNum("rtext_outline", 0) == 1,
        three_d = ply:GetInfoNum("rtext_3d", 0) == 1,
        align = ply:GetInfo("rtext_align"),
        spacing = ply:GetInfoNum("rtext_spacing", 1),
        permanent = ply:GetInfoNum("rtext_permanent", 0) == 1
    }
    
    -- Get text and size for each line
    local maxLines = rText.Config.Cache.maxLines or 8
    for i = 1, maxLines do
        local text = ply:GetInfo("rtext_line" .. i)
        if text and text ~= "" then
            settings.lines[i] = {
                text = text,
                size = ply:GetInfoNum("rtext_line" .. i .. "_size", 30),
                effect = settings.effect,
                effect_speed = settings.effect_speed
            }
        end
    end
    
    return settings
end

function rText.Core.CanPlayerSpawn(ply)
    if not IsValid(ply) then return false end
    
    -- Superadmin check
    if rText.Config.Get("superadmin_only") and not ply:IsSuperAdmin() then
        return false, "Only superadmins can spawn text screens"
    end
    
    -- Player limit check
    local count = 0
    for _, ent in ipairs(ents.FindByClass("rtext_screen")) do
        if IsValid(ent:GetCreator()) and ent:GetCreator() == ply then
            count = count + 1
        end
    end
    
    if count >= rText.Config.Get("max_per_player") then
        return false, string.format("You've reached the maximum of %d text screens", rText.Config.Get("max_per_player"))
    end
    
    -- Global limit check
    local totalCount = #ents.FindByClass("rtext_screen")
    if totalCount >= rText.Config.Get("max_global") then
        return false, "The server has reached the maximum number of text screens"
    end
    
    return true
end
