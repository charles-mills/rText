return {
    groupName = "rText Screen Entity",
    
    beforeEach = function(state)
        state.ply = player.GetByID(1)
        
        if not rText then
            rText = {
                Config = {
                    Cache = {
                        maxTextLength = 128,
                        effectsEnabled = true,
                        rainbowEnabled = true,
                        permanentEnabled = true
                    }
                },
                CanPlayerUpdate = function() return true end
            }
        end
        
        state.screen = ents.Create("rtext_screen")
        state.screen:Spawn()
    end,
    
    afterEach = function(state)
        if IsValid(state.screen) then
            state.screen:Remove()
        end
    end,
    
    cases = {
        {
            name = "Should initialize with default values",
            func = function(state)
                local data = state.screen.TextData[1]
                
                expect(data).to.exist()
                expect(data.text).to.equal("Sample Text")
                expect(data.font).to.equal("Roboto")
                expect(data.size).to.equal(30)
                expect(data.color).to.exist()
                expect(data.rainbow).to.equal(0)
            end
        },
        {
            name = "Should handle text updates",
            func = function(state)
                local testData = {
                    lines = {
                        { text = "Test Line 1", size = 40 },
                        { text = "Test Line 2", size = 40 }
                    },
                    font = "Arial",
                    color = Color(255, 0, 0),
                    rainbow = true,
                    permanent = true
                }
                
                state.screen:UpdateText(state.ply, testData)
                
                local data = state.screen.TextData
                expect(data[1].text).to.equal("Test Line 1")
                expect(data[2].text).to.equal("Test Line 2")
                expect(data[1].font).to.equal("Arial")
                expect(data[1].size).to.equal(40)
                expect(data[1].color.r).to.equal(255)
                expect(data[1].rainbow).to.equal(1)
            end
        },
        {
            name = "Should respect text length limits",
            func = function(state)
                local longText = string.rep("a", 256)
                local testData = {
                    lines = {{ text = longText, size = 30 }},
                    font = "Arial"
                }
                
                state.screen:UpdateText(state.ply, testData)
                
                local data = state.screen.TextData[1]
                expect(#data.text).to.equal(rText.Config.Cache.maxTextLength)
            end
        },
        {
            name = "Should handle ownership checks",
            func = function(state)
                state.screen:SetCreator(state.ply)
                expect(state.screen:CanModify(state.ply)).to.beTrue()
                expect(state.screen:CanModify(NULL)).to.beFalse()
            end
        },
        {
            name = "Should handle feature toggles",
            func = function(state)
                -- Disable effects
                rText.Config.Cache.effectsEnabled = false
                
                local testData = {
                    lines = {{ text = "Test", size = 30 }},
                    effect = "pulse"
                }
                
                state.screen:UpdateText(state.ply, testData)
                expect(state.screen.TextData[1].effect).to.equal("none")
                
                -- Re-enable for other tests
                rText.Config.Cache.effectsEnabled = true
            end
        },
        {
            name = "Should handle persistence",
            func = function(state)
                state.screen:SetCreator(state.ply)
                local pos = Vector(100, 100, 100)
                local ang = Angle(0, 90, 0)
                state.screen:SetPos(pos)
                state.screen:SetAngles(ang)
                
                local saved = state.screen:Save()
                expect(saved.Pos).to.equal(pos)
                expect(saved.Ang).to.equal(ang)
                expect(saved.Creator).to.equal(state.ply:SteamID64())
            end
        }
    }
}
