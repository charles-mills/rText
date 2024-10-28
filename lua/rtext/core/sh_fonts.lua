rText = rText or {}
rText.Fonts = rText.Fonts or {}

-- Font cache with size limits
local fontCache = {}
local fontCount = 0
local MAX_FONTS = rText.Config.Get("font_cache_size") or 50

function rText.Fonts.Create(name, size)
    local fontName = string.format("rText_%s_%d", name, size)
    
    if not fontCache[fontName] then
        if fontCount >= MAX_FONTS then
            -- Clear cache if full
            fontCache = {}
            fontCount = 0
        end
        
        surface.CreateFont(fontName, {
            font = name,
            size = size * 3,
            weight = 500,
            antialias = true,
            extended = true
        })
        
        fontCache[fontName] = true
        fontCount = fontCount + 1
    end
    
    return fontName
end

function rText.Fonts.Initialize()
    -- Pre-create common sizes for default font
    for size = 10, 100, 10 do
        rText.Fonts.Create("Roboto", size)
    end
end
