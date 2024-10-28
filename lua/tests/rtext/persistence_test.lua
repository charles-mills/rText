return {
    groupName = "rText Persistence",
    
    beforeEach = function(state)
        -- Clear any existing permanent screens data
        file.Write("rtext/permanent_screens.json", "[]")
        
        -- Create a test screen
        state.screen = ents.Create("rtext_screen")
        state.screen:SetPos(Vector(100, 100, 100))
        state.screen:SetAngles(Angle(0, 90, 0))
        state.screen:Spawn()
        state.screen:SetPermanent(true)
        
        -- Set some test data
        state.screen.TextData = {
            {
                text = "Test Permanent Text",
                size = 40,
                color = Color(255, 0, 0),
                font = "Arial"
            }
        }
    end,
    
    afterEach = function(state)
        if IsValid(state.screen) then
            state.screen:Remove()
        end
        file.Write("rtext/permanent_screens.json", "[]")
    end,
    
    cases = {
        {
            name = "Should save and load permanent screens",
            func = function(state)
                -- Save the current state
                rText.SavePermanentScreens()
                
                -- Remove the test screen
                state.screen:Remove()
                
                -- Load the saved state
                rText.LoadPermanentScreens()
                
                -- Find the newly spawned screen
                local screens = ents.FindByClass("rtext_screen")
                expect(#screens).to.equal(1)
                
                local newScreen = screens[1]
                expect(newScreen:GetPos()).to.equal(Vector(100, 100, 100))
                expect(newScreen:GetAngles()).to.equal(Angle(0, 90, 0))
                expect(newScreen:GetPermanent()).to.beTrue()
                expect(newScreen.TextData[1].text).to.equal("Test Permanent Text")
            end
        }
    }
}
