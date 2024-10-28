return {
    groupName = "rText Tool",
    
    cases = {
        {
            name = "Should create text screen entity",
            func = function()
                local ply = player.GetByID(1)
                if not IsValid(ply) then return end
                
                local tr = {
                    Hit = true,
                    HitPos = Vector(0, 0, 0),
                    HitNormal = Vector(0, 0, 1)
                }
                
                local ang = tr.HitNormal:Angle()
                ang:RotateAroundAxis(ang:Right(), 90)
                ang:RotateAroundAxis(ang:Up(), 90)
                
                local textScreen = CreateTextScreen(ply, tr, ang)
                
                expect(textScreen).to.exist()
                expect(textScreen:GetClass()).to.equal("rtext_screen")
                expect(textScreen:GetCreator()).to.equal(ply)
            end
        },
        {
            name = "Should respect spawn limits",
            func = function()
                local ply = player.GetByID(1)
                if not IsValid(ply) then return end
                
                -- Mock trace
                local tr = {
                    Hit = true,
                    HitPos = Vector(0, 0, 0),
                    HitNormal = Vector(0, 0, 1)
                }
                
                local ang = tr.HitNormal:Angle()
                ang:RotateAroundAxis(ang:Right(), 90)
                ang:RotateAroundAxis(ang:Up(), 90)
                
                -- Create max + 1 screens
                local max = ply:GetInfoNum("sbox_maxrtextscreens", 10)
                local screens = {}
                
                for i = 1, max do
                    screens[i] = CreateTextScreen(ply, tr, ang)
                    expect(screens[i]).to.exist()
                end
                
                -- Try to create one more
                local extraScreen = CreateTextScreen(ply, tr, ang)
                expect(extraScreen).to.beNil()
                
                -- Cleanup
                for _, screen in ipairs(screens) do
                    if IsValid(screen) then
                        screen:Remove()
                    end
                end
            end
        }
    }
}
