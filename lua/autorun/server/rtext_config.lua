-- Server-side configuration for rText
rText = rText or {}
rText.Config = rText.Config or {}

-- Core configuration convars
local config = {
    -- Access Control
    superadmin_only = CreateConVar("rtext_superadmin_only", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED, "Only superadmins can spawn text screens", 0, 1),
    
    -- Spawn Limits
    max_per_player = CreateConVar("rtext_max_per_player", "10", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Maximum text screens per player", 0, 100),
    max_global = CreateConVar("rtext_max_global", "100", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Maximum text screens in the world", 0, 1000),
    
    -- Feature Control
    effects_enabled = CreateConVar("rtext_effects_enabled", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED, "Enable text effects", 0, 1),
    rainbow_enabled = CreateConVar("rtext_rainbow_enabled", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED, "Enable rainbow effect", 0, 1),
    permanent_enabled = CreateConVar("rtext_permanent_enabled", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED, "Allow permanent text screens", 0, 1),
    
    -- Content Restrictions
    max_text_length = CreateConVar("rtext_max_text_length", "128", FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED, "Maximum characters per line", 1, 512),
    max_lines = CreateConVar("rtext_max_lines", "8", FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED, "Maximum number of lines", 1, 16),
    
    -- Performance Settings
    render_distance = CreateConVar("rtext_render_distance", "2000", FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED, "Maximum render distance", 500, 5000),
    network_rate = CreateConVar("rtext_network_rate", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Minimum time between updates (seconds)", 0.1, 5),
    
    -- Cleanup Settings
    cleanup_disconnected = CreateConVar("rtext_cleanup_disconnected", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Remove text screens when owner disconnects", 0, 1),
    cleanup_rounds = CreateConVar("rtext_cleanup_rounds", "1", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Remove non-permanent text screens on round restart", 0, 1),
    
    -- Spawn Timing
    wait_time = CreateConVar("rtext_wait_time", "3", FCVAR_ARCHIVE + FCVAR_NOTIFY, "Time in seconds players must wait between placing text screens", 0, 30),
}

-- Cache configuration values
rText.Config.Cache = {}

-- Update cache when convars change
local function UpdateCache()
    rText.Config.Cache = {
        superadminOnly = config.superadmin_only:GetBool(),
        maxPerPlayer = config.max_per_player:GetInt(),
        maxGlobal = config.max_global:GetInt(),
        effectsEnabled = config.effects_enabled:GetBool(),
        rainbowEnabled = config.rainbow_enabled:GetBool(),
        permanentEnabled = config.permanent_enabled:GetBool(),
        maxTextLength = config.max_text_length:GetInt(),
        maxLines = config.max_lines:GetInt(),
        renderDistance = config.render_distance:GetInt(),
        networkRate = config.network_rate:GetFloat(),
        cleanupDisconnected = config.cleanup_disconnected:GetBool(),
        cleanupRounds = config.cleanup_rounds:GetBool(),
        waitTime = config.wait_time:GetFloat(),
    }
end

-- Add callbacks for all convars
for name, convar in pairs(config) do
    cvars.AddChangeCallback(convar:GetName(), function(_, _, _)
        UpdateCache()
    end, "rText_" .. name)
end

-- Initial cache update
UpdateCache()

-- Permission checking function
function rText.CanPlayerSpawn(ply)
    if not IsValid(ply) then return false end
    
    -- Check spawn timing first
    local canSpawnNow, waitMessage = rText.CanPlayerSpawnNow(ply)
    if not canSpawnNow then
        return false, waitMessage
    end
    
    -- Superadmin check
    if rText.Config.Cache.superadminOnly and not ply:IsSuperAdmin() then
        return false, "Only superadmins can spawn text screens"
    end
    
    -- Player limit check
    local count = 0
    for _, ent in ipairs(ents.FindByClass("rtext_screen")) do
        if IsValid(ent:GetCreator()) and ent:GetCreator() == ply then
            count = count + 1
        end
    end
    
    if count >= rText.Config.Cache.maxPerPlayer then
        return false, string.format("You've reached the maximum of %d text screens", rText.Config.Cache.maxPerPlayer)
    end
    
    -- Global limit check
    local totalCount = #ents.FindByClass("rtext_screen")
    if totalCount >= rText.Config.Cache.maxGlobal then
        return false, "The server has reached the maximum number of text screens"
    end
    
    -- If all checks pass, update the last spawn time
    rText.LastSpawns[ply] = CurTime()
    
    return true
end

-- Cleanup hooks
hook.Add("PlayerDisconnected", "rText_CleanupDisconnected", function(ply)
    if not rText.Config.Cache.cleanupDisconnected then return end
    
    for _, ent in ipairs(ents.FindByClass("rtext_screen")) do
        if IsValid(ent) and ent:GetCreator() == ply and not ent:GetPermanent() then
            ent:Remove()
        end
    end
end)

hook.Add("PostCleanupMap", "rText_CleanupRounds", function()
    if not rText.Config.Cache.cleanupRounds then return end
    
    for _, ent in ipairs(ents.FindByClass("rtext_screen")) do
        if IsValid(ent) and not ent:GetPermanent() then
            ent:Remove()
        end
    end
end)

-- Network rate limiting
rText.LastUpdates = setmetatable({}, {__mode = "k"})

function rText.CanPlayerUpdate(ply)
    if not IsValid(ply) then return false end
    
    local lastUpdate = rText.LastUpdates[ply] or 0
    if CurTime() - lastUpdate < rText.Config.Cache.networkRate then
        return false, "Please wait before updating text screens"
    end
    
    rText.LastUpdates[ply] = CurTime()
    return true
end

-- Help command
if SERVER then
    concommand.Add("rtext_help", function(ply)
        -- Only allow console or admins to see configuration
        if IsValid(ply) and not ply:IsAdmin() then
            ply:ChatPrint("You need to be an admin to view rText configuration!")
            return
        end
        
        local target = IsValid(ply) and ply or print -- Print to console or player
        
        local function SendMessage(msg)
            if IsValid(ply) then
                ply:ChatPrint(msg)
            else
                print(msg)
            end
        end
        
        SendMessage("\n=== rText Configuration ===\n")
        
        -- Group convars by category
        local categories = {
            ["Access Control"] = {
                rtext_superadmin_only = config.superadmin_only,
            },
            ["Spawn Limits"] = {
                rtext_max_per_player = config.max_per_player,
                rtext_max_global = config.max_global
            },
            ["Feature Control"] = {
                rtext_effects_enabled = config.effects_enabled,
                rtext_rainbow_enabled = config.rainbow_enabled,
                rtext_permanent_enabled = config.permanent_enabled
            },
            ["Content Restrictions"] = {
                rtext_max_text_length = config.max_text_length,
                rtext_max_lines = config.max_lines
            },
            ["Performance Settings"] = {
                rtext_render_distance = config.render_distance,
                rtext_network_rate = config.network_rate
            },
            ["Cleanup Settings"] = {
                rtext_cleanup_disconnected = config.cleanup_disconnected,
                rtext_cleanup_rounds = config.cleanup_rounds
            },
            ["Spawn Timing"] = {
                rtext_wait_time = config.wait_time
            },
        }
        
        -- Display each category
        for category, convars in pairs(categories) do
            SendMessage("\n" .. category .. ":")
            for name, convar in pairs(convars) do
                local current = convar:GetString()
                local default = convar:GetDefault()
                local desc = convar:GetHelpText()
                
                SendMessage(string.format("  %s:", name))
                SendMessage(string.format("    Current: %s", current))
                SendMessage(string.format("    Default: %s", default))
                SendMessage(string.format("    Description: %s", desc))
            end
        end
        
        -- Add usage information
        SendMessage("\nUsage:")
        SendMessage("  To change a setting: <convar> <value>")
        SendMessage("  Example: rtext_max_per_player 20")
        SendMessage("\nNote: Some changes require map restart to take effect.")
    end)
end

-- Add chat command
if SERVER then
    hook.Add("PlayerSay", "rText_HelpCommand", function(ply, text)
        if text:lower() == "!rtexthelp" or text:lower() == "/rtexthelp" then
            -- Run help command
            ply:ConCommand("rtext_help")
            return ""
        end
    end)
end
