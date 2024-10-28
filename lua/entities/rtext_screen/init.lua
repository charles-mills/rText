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
    
    -- Make it invisible but keep collisions
    self:SetRenderMode(RENDERMODE_NONE)
    self:SetColor(Color(0, 0, 0, 0))

    -- Initialize default values
    self.TextData = {
        lines = {},
        font = "Roboto",
        size = 30,
        color = Color(255, 255, 255, 255),
        rainbow = false,
        permanent = false
    }

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)
    end
end

function ENT:UpdateText(ply, data)
    if not IsValid(ply) or not self:CPPICanUse(ply) then return end
    
    -- Validate and sanitize input
    data.lines = data.lines or {}
    for i = 1, 8 do
        data.lines[i] = string.sub(data.lines[i] or "", 1, 128)
    end
    
    data.font = data.font or "Roboto"
    data.size = math.Clamp(data.size or 30, 10, 100)
    data.color = data.color or Color(255, 255, 255, 255)
    data.rainbow = data.rainbow or false
    data.permanent = data.permanent or false

    -- Update the entity's data
    self.TextData = data

    -- Network the changes to clients
    net.Start("rText_Update")
        net.WriteEntity(self)
        net.WriteTable(self.TextData)
    net.Broadcast()
end

-- Handle incoming update requests
net.Receive("rText_RequestUpdate", function(_, ply)
    local ent = net.ReadEntity()
    if not IsValid(ent) or ent:GetClass() ~= "rtext_screen" then return end
    
    -- Send the current text data to the requesting client
    net.Start("rText_Update")
        net.WriteEntity(ent)
        net.WriteTable(ent.TextData)
    net.Send(ply)
end)

-- Persistence
function ENT:Save()
    local data = {
        TextData = self.TextData,
        Pos = self:GetPos(),
        Ang = self:GetAngles(),
        Creator = self:CPPIGetOwner():SteamID64()
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
