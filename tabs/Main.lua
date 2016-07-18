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
    background(20)
    
    world:draw()
end

function touched(touch)
    world:touched(touch)
end
