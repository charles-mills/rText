beforeEach = function(state)
    -- Create test player
    state.ply = player.GetByID(1)
    
    -- Mock rText if not exists
    if not rText then
        rText = {
            Config = {
                Get = function(key)
                    local defaults = {
                        max_text_length = 128,
                        rainbow_enabled = true,
                        permanent_enabled = true
                    }
                    return defaults[key]
                end
            },
            CanPlayerUpdate = function() return true end
        }
    end
    
    -- Create a test entity
    state.screen = ents.Create("rtext_screen")
    state.screen:Spawn()
end
