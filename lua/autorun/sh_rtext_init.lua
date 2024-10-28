-- Initialize rText
rText = rText or {}

-- Core systems
rText.Core = rText.Core or {}
rText.Config = rText.Config or {}
rText.Cache = rText.Cache or {}

-- Debug system (define this first as it's used everywhere)
rText.Debug = {
    Log = function(...)
        if not rText.Config.Cache or not rText.Config.Cache.debugMode then return end
        print("[rText]", ...)
    end
}

if SERVER then
    -- Core files
    AddCSLuaFile("rtext/config/sh_config.lua")
    AddCSLuaFile("rtext/core/sh_util.lua")
    AddCSLuaFile("rtext/core/sh_fonts.lua")
    AddCSLuaFile("rtext/core/cl_render.lua")
    AddCSLuaFile("autorun/shared/rtext_functions.lua")
end

-- Load order is important
include("rtext/config/sh_config.lua")     -- Load config first
include("rtext/core/sh_util.lua")         -- Load utilities
include("rtext/core/sh_fonts.lua")        -- Load font system
include("autorun/shared/rtext_functions.lua") -- Load core functions

-- Initialize config immediately
rText.Config.Initialize()

-- Client-specific files
if CLIENT then
    include("rtext/core/cl_render.lua")
end

-- Server-specific files
if SERVER then
    include("rtext/core/sv_network.lua")
    include("autorun/server/rtext_persistence.lua")
end

-- Initialize core systems
if rText.Core.Initialize then
    rText.Core.Initialize()
    rText.Debug.Log("Initialized rText")
end
