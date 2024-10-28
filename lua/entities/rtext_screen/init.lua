AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Network strings
util.AddNetworkString("rText_Update")
util.AddNetworkString("rText_RequestUpdate")

function ENT:Initialize()
    self:SetModel("models/hunter/plates/plate1x1.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetMaterial("models/effects/vol_light001")
    self:DrawShadow(false)
    
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

function ENT:UpdateText(ply, data)
    if not IsValid(ply) or not self:CanModify(ply) then return end
    
    local canUpdate, message = rText.CanPlayerUpdate(ply)
    if not canUpdate then
        ply:ChatPrint(message)
        return
    end

    -- Validate text length
    for i, line in pairs(data.lines) do
        if line.text then
            data.lines[i].text = string.sub(line.text, 1, rText.Config.Cache.maxTextLength)
        end
    end

    -- Respect feature toggles
    if not rText.Config.Cache.effectsEnabled then
        data.effect = "none"
    end

    if not rText.Config.Cache.rainbowEnabled then
        data.rainbow = false
    end

    if not rText.Config.Cache.permanentEnabled then
        data.permanent = false
    end
    
    local newData = {}
    -- Convert the flat data structure to line-based structure
    for i = 1, 8 do
        if data.lines[i] and data.lines[i].text ~= "" then
            table.insert(newData, {
                text = string.sub(data.lines[i].text, 1, 128),
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
    
    self:SetLines(newData)
end

-- Handle incoming update requests
net.Receive("rText_RequestUpdate", function(_, ply)
    local ent = net.ReadEntity()
    if not IsValid(ent) or ent:GetClass() ~= "rtext_screen" then return end
    
    net.Start("rText_Update")
        net.WriteEntity(ent)
        net.WriteTable(ent.TextData or {})
    net.Send(ply)
end)

-- Persistence
function ENT:Save()
    local data = {
        TextData = self.TextData,
        Pos = self:GetPos(),
        Ang = self:GetAngles(),
        Creator = IsValid(self:GetCreator()) and self:GetCreator():SteamID64() or nil
    }
    return data
end

function ENT:Load(data)
    self:SetPos(data.Pos)
    self:SetAngles(data.Ang)
    self.TextData = data.TextData
    
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
