AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Network strings
util.AddNetworkString("rText_Update")
util.AddNetworkString("rText_RequestUpdate")

local function SanitizeText(text)
    -- Remove control characters
    text = string.gsub(text, "%c", "")
    
    -- Remove potential exploits
    text = string.gsub(text, "%%", "%%")
    text = string.gsub(text, "\n", "")
    text = string.gsub(text, "\r", "")
    
    -- Remove non-printable characters
    text = string.gsub(text, "[^%g%s]", "")
    
    return text
end

function ENT:Initialize()
    self:SetModel("models/hunter/plates/plate1x1.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetMaterial("models/effects/vol_light001")
    self:DrawShadow(false)
    
    -- Prevent damage
    self:SetCollisionGroup(COLLISION_GROUP_WORLD)
    
    -- Initialize default values
    self.TextData = {}
    self:SetLines({
        {
            text = "Sample Text",
            color = Color(255, 255, 255, 255),
            size = 30,
            font = "Roboto",
            rainbow = 0
        }
    })

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)
        -- Set mass to very light to prevent damage
        phys:SetMass(1)
    end
end

function ENT:SetLines(data)
    self.TextData = data
    
    -- Network the changes to clients
    net.Start("rText_Update")
        net.WriteEntity(self)
        net.WriteTable(self.TextData)
    net.Broadcast()
end

function ENT:UpdateText(ply, data, skipRateLimit)
    if not IsValid(ply) or not self:CanModify(ply) then return end
    
    -- Skip rate limit check for initial settings
    if not skipRateLimit then
        local canUpdate, message = rText.CanPlayerUpdate(ply)
        if not canUpdate then
            ply:ChatPrint(message)
            return
        end
    end

    local newData = {}
    local maxLines = rText.Config.Cache.maxLines or 8
    local lineCount = 0
    
    -- Convert the flat data structure to line-based structure
    for i = 1, 8 do
        if lineCount >= maxLines then break end
        
        if data.lines[i] and data.lines[i].text ~= "" then
            lineCount = lineCount + 1
            table.insert(newData, {
                text = string.sub(data.lines[i].text, 1, rText.Config.Cache.maxTextLength),
                size = data.lines[i].size or 30,
                color = data.color,
                font = data.font,
                rainbow = data.rainbow and 1 or 0,
                effect = data.effect,
                effect_speed = data.effect_speed,
                glow = data.glow,
                outline = data.outline,
                three_d = data.three_d,
                align = data.align,
                spacing = data.spacing
            })
        end
    end
    
    -- Respect feature toggles
    if not rText.Config.Cache.effectsEnabled then
        data.effect = "none"
    end

    if not rText.Config.Cache.rainbowEnabled then
        data.rainbow = false
    end

    -- Handle permanent flag
    local isPermanent = false
    if rText.Config.Cache.permanentEnabled then
        isPermanent = data.permanent or false
    end
    
    -- Set networked variables
    self:SetPermanent(isPermanent)
    
    -- Sanitize and limit text
    for i, line in pairs(data.lines) do
        if line.text then
            line.text = SanitizeText(line.text)
            line.text = string.sub(line.text, 1, rText.Config.Cache.maxTextLength)
        end
    end
    
    self:SetLines(newData)
end

-- Add this function to check if screen is permanent
function ENT:GetPermanent()
    return self:GetNWBool("Permanent", false)
end

-- Add this function to set permanent status
function ENT:SetPermanent(isPermanent)
    self:SetNWBool("Permanent", isPermanent)
end

-- Update cleanup hooks to respect permanent flag
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

-- Update Save/Load to include permanent status
function ENT:Save()
    local data = {
        TextData = self.TextData,
        Pos = self:GetPos(),
        Ang = self:GetAngles(),
        Creator = IsValid(self:GetCreator()) and self:GetCreator():SteamID64() or nil,
        Permanent = self:GetPermanent()
    }
    return data
end

function ENT:Load(data)
    self:SetPos(data.Pos)
    self:SetAngles(data.Ang)
    self.TextData = data.TextData
    self:SetPermanent(data.Permanent or false)
    
    -- Network the loaded data to clients
    net.Start("rText_Update")
        net.WriteEntity(self)
        net.WriteTable(self.TextData)
    net.Broadcast()
end

-- Cross-gamemode ownership check
function ENT:CanModify(ply)
    if not IsValid(ply) then return false end
    local owner = self:GetCreator()
    return not IsValid(owner) or owner == ply or ply:IsAdmin()
end

-- Set the creator of the entity
function ENT:SetCreator(ply)
    self:SetNWEntity("Creator", ply)
end

-- Get the creator of the entity
function ENT:GetCreator()
    return self:GetNWEntity("Creator")
end

function ENT:Think()
    -- Remove if too many entities nearby
    local nearby = ents.FindInSphere(self:GetPos(), 100)
    local screenCount = 0
    
    for _, ent in ipairs(nearby) do
        if ent:GetClass() == "rtext_screen" then
            screenCount = screenCount + 1
            if screenCount > 5 then -- Max 5 screens in close proximity
                self:Remove()
                return
            end
        end
    end
    
    self:NextThink(CurTime() + 1)
    return true
end
