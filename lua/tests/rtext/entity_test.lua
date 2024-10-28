return {
    groupName = "rText Screen Entity",
    
    beforeEach = function(state)
        -- Create a test entity
        state.screen = ents.Create("rtext_screen")
        state.screen:Spawn()
        
        -- Create test player
        state.ply = player.GetByID(1)
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
                local data = state.screen.TextData
                
                expect(data).to.exist()
                expect(data.font).to.equal("Roboto")
                expect(data.size).to.equal(30)
                expect(data.color).to.exist()
                expect(data.rainbow).to.equal(false)
                expect(data.permanent).to.equal(false)
            end
        },
        {
            name = "Should handle text updates",
            func = function(state)
                local testData = {
                    lines = {"Test Line 1", "Test Line 2"},
                    font = "Arial",
                    size = 40,
                    color = Color(255, 0, 0),
                    rainbow = true,
                    permanent = true
                }
                
                state.screen:UpdateText(state.ply, testData)
                
                local data = state.screen.TextData
                expect(data.lines[1]).to.equal("Test Line 1")
                expect(data.lines[2]).to.equal("Test Line 2")
                expect(data.font).to.equal("Arial")
                expect(data.size).to.equal(40)
                expect(data.color.r).to.equal(255)
                expect(data.color.g).to.equal(0)
                expect(data.color.b).to.equal(0)
                expect(data.rainbow).to.equal(true)
                expect(data.permanent).to.equal(true)
            end
        },
        {
            name = "Should handle ownership checks",
            func = function(state)
                state.screen:SetCreator(state.ply)
                
                expect(state.screen:CanModify(state.ply)).to.beTrue()
                
                -- Test invalid player
                local invalidPly = NULL
                expect(state.screen:CanModify(invalidPly)).to.beFalse()
            end
        }
    }
}
