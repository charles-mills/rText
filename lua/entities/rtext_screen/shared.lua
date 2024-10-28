ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "rText Screen"
ENT.Author = "Your Name"
ENT.Category = "rlib"
ENT.Spawnable = false
ENT.AdminOnly = false

function ENT:SetupDataTables()
    -- We'll primarily use networked tables for the text data
    -- but these are useful for quick checks and persistence
    self:NetworkVar("Bool", 0, "Rainbow")
    self:NetworkVar("Bool", 1, "Permanent")
    self:NetworkVar("Int", 0, "TextSize")
    self:NetworkVar("String", 0, "FontName")
end
