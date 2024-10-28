rText.Core = rText.Core or {}

-- Error handling
function rText.Core.SafeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        rText.Debug.Log("Error:", result)
        return nil
    end
    return result
end

-- Rate limiting
rText.Core.RateLimiter = {
    limits = {},
    
    Clear = function(self)
        if self and self.limits then  -- Add safety check
            table.Empty(self.limits)
        end
    end,
    
    Check = function(self, key, rate)
        if not self.limits then self.limits = {} end  -- Ensure table exists
        local last = self.limits[key]
        if last and (CurTime() - last) < rate then
            return false
        end
        self.limits[key] = CurTime()
        return true
    end
}

-- Entity validation
function rText.Core.IsValidTextScreen(ent)
    return ent:GetClass() == "rtext_screen"
end

-- Permission checking
function rText.Core.CanPlayerModify(ply, ent)
    if not IsValid(ply) or not rText.Core.IsValidTextScreen(ent) then 
        return false 
    end
    
    -- Check ownership
    if ent:GetCreator() ~= ply then
        return ply:IsAdmin()
    end
    
    return true
end

-- Initialize core systems
function rText.Core.Initialize()
    -- Set up network strings
    if SERVER then
        util.AddNetworkString("rText_Update")
        util.AddNetworkString("rText_RequestUpdate")
    end
    
    -- Initialize caches
    rText.Cache = rText.Cache or {}
    rText.Cache.Fonts = {}
    rText.Cache.RenderTargets = {}
    
    -- Set up cleanup hooks
    hook.Add("ShutDown", "rText_Cleanup", function()
        rText.Core.Cleanup()
    end)
end

-- Cleanup function
function rText.Core.Cleanup()
    if rText.Core.RateLimiter then
        rText.Core.RateLimiter:Clear()
    end
    
    -- Clear caches
    if rText.Cache then
        table.Empty(rText.Cache.Fonts or {})
        table.Empty(rText.Cache.RenderTargets or {})
    end
    
    -- Remove hooks
    hook.Remove("ShutDown", "rText_Cleanup")
end
