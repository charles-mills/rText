rText = rText or {}
rText.Config = {
    Cache = {},
    Convars = {},
    Defaults = {
        -- Access Control
        superadmin_only = false,
        
        -- Spawn Limits
        max_per_player = 10,
        max_global = 100,
        wait_time = 3,
        
        -- Content Settings
        max_text_length = 128,
        max_lines = 8,
        allowed_fonts = {
            ["Roboto"] = true,
            ["Arial"] = true,
            ["Helvetica"] = true,
            ["DermaLarge"] = true,
            ["DermaDefault"] = true,
            ["Trebuchet18"] = true,
            ["Trebuchet24"] = true,
            ["HudHintTextLarge"] = true,
            ["HudHintTextSmall"] = true,
            ["CenterPrintText"] = true,
            ["ChatFont"] = true,
            ["TargetID"] = true,
            ["TargetIDSmall"] = true,
            ["CloseCaption_Normal"] = true,
            ["CloseCaption_Bold"] = true,
            ["CloseCaption_BoldItalic"] = true,
            ["BudgetLabel"] = true,
            ["DefaultBold"] = true,
            ["DefaultUnderline"] = true,
            ["DefaultSmall"] = true,
            ["DefaultVerySmall"] = true,
            ["MenuLarge"] = true,
            ["ConsoleText"] = true,
            ["DebugFixed"] = true,
            ["DebugFixedSmall"] = true
        },
        
        -- Visual Settings
        render_distance = 2000,
        rainbow_enabled = true,
        permanent_enabled = true,
        min_text_size = 10,
        max_text_size = 100,
        min_line_spacing = 0.5,
        max_line_spacing = 2,
        preview_opacity = 50,
        
        -- Performance
        network_rate = 0.1,
        font_cache_size = 50,
        max_updates_per_second = 10,
        max_packet_size = 4096,
        batch_render_size = 10,
        fade_start_distance = 1500,
        min_render_alpha = 0.1,
        
        -- Memory Management
        max_cache_size = 50 * 1024 * 1024, -- 50MB
        cache_cleanup_interval = 30,
        emergency_threshold = 75 * 1024 * 1024, -- 75MB
        cache_lifetime = 300,
        
        -- Cleanup Settings
        cleanup_disconnected = true,
        cleanup_rounds = true,
        
        -- Debug
        debug_mode = false
    }
}

-- ConVar creation with validation
function rText.Config.CreateConVar(name, default, flags, help, min, max)
    local convar = CreateConVar(
        "rtext_" .. name,
        tostring(default),
        flags or (FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED),
        help or "",
        min,
        max
    )
    
    rText.Config.Convars[name] = convar
    return convar
end

-- Initialize configuration system
function rText.Config.Initialize()
    -- Create ConVars
    if SERVER then
        -- Access Control
        rText.Config.CreateConVar("superadmin_only", "0", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED),
            "Only superadmins can spawn text screens", 0, 1)
        
        -- Spawn Limits
        rText.Config.CreateConVar("max_per_player", "10", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY),
            "Maximum text screens per player", 0, 100)
        rText.Config.CreateConVar("max_global", "100", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY),
            "Maximum text screens in the world", 0, 1000)
        rText.Config.CreateConVar("wait_time", "3", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY),
            "Time between text screen spawns", 0, 30)
        
        -- Content Settings
        rText.Config.CreateConVar("max_text_length", "128", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED),
            "Maximum characters per line", 1, 512)
        rText.Config.CreateConVar("max_lines", "8", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED),
            "Maximum number of lines", 1, 16)
        
        -- Visual Settings
        rText.Config.CreateConVar("render_distance", "2000", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED),
            "Maximum render distance", 500, 5000)
        rText.Config.CreateConVar("rainbow_enabled", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED),
            "Enable rainbow effect", 0, 1)
        rText.Config.CreateConVar("permanent_enabled", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED),
            "Allow permanent text screens", 0, 1)
        rText.Config.CreateConVar("preview_opacity", "50", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED),
            "Preview text opacity", 10, 255)
        
        -- Performance Settings
        rText.Config.CreateConVar("network_rate", "0.1", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY),
            "Minimum time between updates (seconds)", 0.1, 5)
        rText.Config.CreateConVar("font_cache_size", "50", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY),
            "Maximum number of cached fonts", 10, 200)
        rText.Config.CreateConVar("max_updates_per_second", "10", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY),
            "Maximum updates per second globally", 1, 100)
        rText.Config.CreateConVar("max_packet_size", "4096", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY),
            "Maximum network packet size in bytes", 1024, 8192)
        rText.Config.CreateConVar("batch_render_size", "10", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED),
            "Number of text screens to render per frame", 1, 50)
        
        -- Memory Settings
        rText.Config.CreateConVar("cache_cleanup_interval", "30", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY),
            "Cache cleanup interval in seconds", 10, 300)
        
        -- Cleanup Settings
        rText.Config.CreateConVar("cleanup_disconnected", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY),
            "Remove text screens when owner disconnects", 0, 1)
        rText.Config.CreateConVar("cleanup_rounds", "1", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY),
            "Remove non-permanent text screens on round restart", 0, 1)
        
        -- Debug Settings
        rText.Config.CreateConVar("debug_mode", "0", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY),
            "Enable debug logging", 0, 1)
        
        -- Add missing convars from old config
        rText.Config.CreateConVar("max_packet_size", "4096", bit.bor(FCVAR_ARCHIVE, FCVAR_NOTIFY),
            "Maximum network packet size in bytes", 1024, 8192)
            
        -- Add any other missing convars here
    end
    
    -- Update cache
    rText.Config.UpdateCache()
    
    -- Add callbacks for all convars
    for name, convar in pairs(rText.Config.Convars) do
        cvars.AddChangeCallback(convar:GetName(), function(_, _, new)
            rText.Config.UpdateCache()
            rText.Debug.Log("Config updated:", name, "=", new)
        end, "rText_" .. name)
    end
end

-- Update configuration cache
function rText.Config.UpdateCache()
    for name, default in pairs(rText.Config.Defaults) do
        local convar = rText.Config.Convars[name]
        if not convar then
            rText.Config.Cache[name] = default
            continue
        end
        
        -- Convert value based on default type
        local value = convar:GetString()
        if type(default) == "boolean" then
            value = convar:GetBool()
        elseif type(default) == "number" then
            value = convar:GetFloat()
        end
        
        rText.Config.Cache[name] = value
    end
end

-- Get configuration value
function rText.Config.Get(name)
    return rText.Config.Cache[name] or rText.Config.Defaults[name]
end

-- Console commands for configuration management
if SERVER then
    concommand.Add("rtext_config_list", function(ply)
        if IsValid(ply) and not ply:IsSuperAdmin() then return end
        
        local function SendMessage(msg)
            if IsValid(ply) then
                ply:ChatPrint(msg)
            else
                print(msg)
            end
        end
        
        SendMessage("rText Configuration:")
        for name, value in pairs(rText.Config.Cache) do
            local convar = rText.Config.Convars[name]
            local default = rText.Config.Defaults[name]
            SendMessage(string.format("  %s: %s (default: %s)", 
                name, tostring(value), tostring(default)))
        end
    end)
    
    concommand.Add("rtext_config_reset", function(ply)
        if IsValid(ply) and not ply:IsSuperAdmin() then return end
        
        for name, default in pairs(rText.Config.Defaults) do
            local convar = rText.Config.Convars[name]
            if convar then
                convar:SetString(tostring(default))
            end
        end
        
        if IsValid(ply) then
            ply:ChatPrint("rText configuration reset to defaults")
        else
            print("rText configuration reset to defaults")
        end
    end)
end

-- Add dynamic configuration validation
function rText.Config.Validate(key, value)
    local validators = {
        max_text_length = function(v) return tonumber(v) and v >= 1 and v <= 512 end,
        render_distance = function(v) return tonumber(v) and v >= 500 and v <= 5000 end,
        max_lines = function(v) return tonumber(v) and v >= 1 and v <= 16 end
    }
    
    if validators[key] then
        return validators[key](value)
    end
    return true
end
