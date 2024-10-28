return {
    groupName = "rText Tool",
    
    beforeEach = function(state)
        -- Create test player
        state.ply = player.GetByID(1)
        
        -- Mock the rText global table
        if not rText then
            rText = {
                Config = {
                    Cache = {
                        maxPerPlayer = 10,
                        maxGlobal = 100,
                        waitTime = 3,
                        maxTextLength = 128,
                        effectsEnabled = true,
                        rainbowEnabled = true,
                        permanentEnabled = true
                    }
                },
                LastSpawns = {},
                CanPlayerSpawn = function() return true end,
                CanPlayerUpdate = function() return true end
            }
        end
    end,
    
    cases = {
        {
            name = "Should create text screen entity",
            func = function(state)
                if not IsValid(state.ply) then return end
                
                local tr = {
                    Hit = true,
                    HitPos = Vector(0, 0, 0),
                    HitNormal = Vector(0, 0, 1)
                }
                
                local ang = tr.HitNormal:Angle()
                ang:RotateAroundAxis(ang:Right(), 90)
                ang:RotateAroundAxis(ang:Up(), 90)
                
                -- Get the CreateTextScreen function from the tool
                local TOOL = weapons.Get("gmod_tool_rtext")
                local textScreen = TOOL.CreateTextScreen(state.ply, tr, ang)
                
                expect(textScreen).to.exist()
                expect(textScreen:GetClass()).to.equal("rtext_screen")
                expect(textScreen:GetCreator()).to.equal(state.ply)
            end
        },
        {
            name = "Should respect spawn limits",
            func = function(state)
                if not IsValid(state.ply) then return end
                
                -- Mock trace
                local tr = {
                    Hit = true,
                    HitPos = Vector(0, 0, 0),
                    HitNormal = Vector(0, 0, 1)
                }
                
                local ang = tr.HitNormal:Angle()
                ang:RotateAroundAxis(ang:Right(), 90)
                ang:RotateAroundAxis(ang:Up(), 90)
                
                -- Get the CreateTextScreen function
                local TOOL = weapons.Get("gmod_tool_rtext")
                local CreateTextScreen = TOOL.CreateTextScreen
                
                -- Create max + 1 screens
                local max = rText.Config.Cache.maxPerPlayer
                local screens = {}
                
                for i = 1, max do
                    screens[i] = CreateTextScreen(state.ply, tr, ang)
                    expect(screens[i]).to.exist()
                end
                
                -- Try to create one more
                local extraScreen = CreateTextScreen(state.ply, tr, ang)
                expect(extraScreen).to.beNil()
                
                -- Cleanup
                for _, screen in ipairs(screens) do
                    if IsValid(screen) then
                        screen:Remove()
                    end
                end
            end
        },
        {
            name = "Should respect wait time between spawns",
            func = function(state)
                if not IsValid(state.ply) then return end
                
                local tr = {
                    Hit = true,
                    HitPos = Vector(0, 0, 0),
                    HitNormal = Vector(0, 0, 1)
                }
                
                local ang = tr.HitNormal:Angle()
                local TOOL = weapons.Get("gmod_tool_rtext")
                
                -- First spawn should work
                local screen1 = TOOL.CreateTextScreen(state.ply, tr, ang)
                expect(screen1).to.exist()
                
                -- Immediate second spawn should fail
                local screen2 = TOOL.CreateTextScreen(state.ply, tr, ang)
                expect(screen2).to.beNil()
                
                if IsValid(screen1) then screen1:Remove() end
            end
        },
        {
            name = "Should properly normalize wall angles",
            func = function(state)
                if not IsValid(state.ply) then return end
                
                local tr = {
                    Hit = true,
                    HitPos = Vector(0, 0, 0),
                    HitNormal = Vector(1, 0, 0) -- Wall normal
                }
                
                local TOOL = weapons.Get("gmod_tool_rtext")
                local screen = TOOL.CreateTextScreen(state.ply, tr, Angle())
                
                expect(screen).to.exist()
                local ang = screen:GetAngles()
                expect(ang.p % 90).to.equal(0)
                expect(ang.y % 90).to.equal(0)
                expect(ang.r % 90).to.equal(0)
                
                if IsValid(screen) then screen:Remove() end
            end
        }
    }
}
