-- Cavemen
-- Version 0.3
-- (c) kennstewayne.de

supportedOrientations(CurrentOrientation) -- @Codea temporary bug fix!

function setup()
    world = World()
    
    parameter.boolean("WorldDebug", true, function(flag)
        world.debug = flag
        world.map:adjustPivot()
    end)
end

function orientationChanged()
    if world then world:orientationChanged() end
end

function draw()
    noSmooth()
    background(20)
    
    world:draw()
    
    --[[
    fill(0, 255, 0, 127)
    ellipse(CurrentTouch.x, CurrentTouch.y, 25)
    --]]
end

function touched(touch)
    world:touched(touch)
end
