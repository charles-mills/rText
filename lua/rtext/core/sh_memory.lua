rText = rText or {}
rText.Memory = {
    Caches = {},
    Stats = {
        totalMemory = 0,
        cacheSize = 0,
        lastCleanup = 0
    }
}

-- Memory limits and thresholds
local MEMORY_SETTINGS = {
    MAX_CACHE_SIZE = 50 * 1024 * 1024, -- 50MB
    CLEANUP_INTERVAL = 30, -- 30 seconds
    EMERGENCY_THRESHOLD = 75 * 1024 * 1024, -- 75MB
    CACHE_LIFETIME = 300 -- 5 minutes
}

-- Create a new managed cache
function rText.Memory.CreateCache(name, options)
    if rText.Memory.Caches[name] then
        return rText.Memory.Caches[name]
    end
    
    options = options or {}
    local cache = {
        data = setmetatable({}, {__mode = options.weakKeys and "k" or nil}),
        size = 0,
        lastAccess = {},
        maxSize = options.maxSize or MEMORY_SETTINGS.MAX_CACHE_SIZE,
        cleanupInterval = options.cleanupInterval or MEMORY_SETTINGS.CLEANUP_INTERVAL,
        lastCleanup = 0
    }
    
    rText.Memory.Caches[name] = cache
    return cache
end

-- Add item to cache
function rText.Memory.CacheItem(cacheName, key, value, size)
    local cache = rText.Memory.Caches[cacheName]
    if not cache then return end
    
    -- Check if we need cleanup
    rText.Memory.CheckCleanup(cacheName)
    
    -- Update cache
    cache.data[key] = value
    cache.lastAccess[key] = CurTime()
    cache.size = cache.size + (size or 0)
    
    -- Update stats
    rText.Memory.Stats.cacheSize = rText.Memory.Stats.cacheSize + (size or 0)
end

-- Get item from cache
function rText.Memory.GetCached(cacheName, key)
    local cache = rText.Memory.Caches[cacheName]
    if not cache or not cache.data[key] then return nil end
    
    cache.lastAccess[key] = CurTime()
    return cache.data[key]
end

-- Clean specific cache
function rText.Memory.CleanCache(cacheName)
    local cache = rText.Memory.Caches[cacheName]
    if not cache then return end
    
    local now = CurTime()
    local removed = 0
    
    -- Remove old items
    for key, lastAccess in pairs(cache.lastAccess) do
        if now - lastAccess > MEMORY_SETTINGS.CACHE_LIFETIME then
            cache.data[key] = nil
            cache.lastAccess[key] = nil
            removed = removed + 1
        end
    end
    
    -- Force garbage collection if needed
    if removed > 10 then
        collectgarbage("step", 100)
    end
    
    cache.lastCleanup = now
    rText.Debug.Log("Cleaned cache:", cacheName, "Removed items:", removed)
end

-- Check if cleanup is needed
function rText.Memory.CheckCleanup(cacheName)
    local cache = rText.Memory.Caches[cacheName]
    if not cache then return end
    
    local now = CurTime()
    
    -- Regular cleanup
    if now - cache.lastCleanup > cache.cleanupInterval then
        rText.Memory.CleanCache(cacheName)
    end
    
    -- Emergency cleanup
    if collectgarbage("count") * 1024 > MEMORY_SETTINGS.EMERGENCY_THRESHOLD then
        rText.Memory.EmergencyCleanup()
    end
end

-- Emergency cleanup
function rText.Memory.EmergencyCleanup()
    rText.Debug.Log("Emergency cleanup triggered!")
    
    -- Clear all caches
    for name, _ in pairs(rText.Memory.Caches) do
        rText.Memory.CleanCache(name)
    end
    
    -- Force full garbage collection
    collectgarbage("collect")
    
    rText.Debug.Log("Emergency cleanup complete")
end

-- Initialize memory management
function rText.Memory.Initialize()
    -- Create standard caches
    rText.Memory.CreateCache("fonts", {weakKeys = true})
    rText.Memory.CreateCache("renderTargets", {weakKeys = true})
    rText.Memory.CreateCache("textData", {weakKeys = true})
    
    -- Start monitoring
    timer.Create("rText_MemoryMonitor", 1, 0, function()
        rText.Memory.Stats.totalMemory = collectgarbage("count") * 1024
        
        -- Log memory usage in debug mode
        if rText.Config.Cache.debugMode then
            rText.Debug.Log("Memory usage:", string.NiceSize(rText.Memory.Stats.totalMemory))
        end
    end)
end

-- Cleanup on shutdown
hook.Add("ShutDown", "rText_MemoryCleanup", function()
    for name, _ in pairs(rText.Memory.Caches) do
        rText.Memory.CleanCache(name)
    end
end)
