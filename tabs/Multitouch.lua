local touches = {}
local expiredTouches = 0
local gestureCountdown = .08 -- ADJUST!
local touchesAutoDispatcher
local dispatchTouches = touched

function touched(touch)
    -- Identify touch
    local gesture, uid = #touches > 0 and touches[1].initTime + gestureCountdown < ElapsedTime
    for r, t in ipairs(touches) do
        if touch.id == t.id then uid = r end
        touches[r].state = "RESTING"
    end
    
    -- Cache updates
    local rt = touches[uid] or {}
    local template = {
        id = rt.id or touch.id,
        state = touch.state,
        tapCount = CurrentTouch.tapCount,
        initTime = rt.initTime or ElapsedTime,
        duration = ElapsedTime - (rt.initTime or ElapsedTime),
        initX = rt.initX or touch.x,
        initY = rt.initY or touch.y,
        x = touch.x,
        y = touch.y,
        prevX = touch.prevX,
        prevY = touch.prevY,
        deltaX = touch.deltaX,
        deltaY = touch.deltaY,
        radius = touch.radius,
        radiusTolerance = touch.radiusTolerance,
        force = remapRange(touch.radius, 0, touch.radius + touch.radiusTolerance, 0, 1)
    }
    
    if uid then
        -- Update touches
        touches[uid] = template
        
        -- Dispatch touches
        if touch.state == ENDED then
            -- First touch expired while gesture still active (or waiting to get active)
            if expiredTouches == 0 then
                -- Gesture was waiting to get active
                if touchesAutoDispatcher then
                    -- Sync all touch states to BEGAN
                    -- Still dispatch the planed BEGAN state from Auto-Dispatch
                    for r, t in ipairs(touches) do
                        touches[r].state = BEGAN
                        touches[r].initX = t.x
                        touches[r].initY = t.y
                    end
                    dispatchTouches(table.unpack(touches))
                    
                    -- Cancel gesture!
                    tween.reset(touchesAutoDispatcher)
                    touchesAutoDispatcher = nil
                end
                
                -- Sync all touch states to ENDED
                for r, t in ipairs(touches) do
                    touches[r].state = ENDED
                end
                -- Dispatch ENDED
                dispatchTouches(table.unpack(touches))
            end
            
            -- Delete all touches when all expired
            expiredTouches = expiredTouches + 1
            if expiredTouches == #touches then
                touches = {}
                expiredTouches = 0
            end
        else
            -- Dispatch MOVING
            if not touchesAutoDispatcher and gesture and expiredTouches == 0 then
                dispatchTouches(table.unpack(touches))
            end
        end
    else
        -- Register touch
        -- Ignore new touches when gesture already active
        if not gesture and touch.state == BEGAN then
            table.insert(touches, template)
            uid = #touches
            
            -- Auto-Dispatch touches
            if uid == 1 then
                -- Dispatch BEGAN ... when gesture gets active
                touchesAutoDispatcher = tween.delay(gestureCountdown, function()
                    -- Sync all touch states to BEGAN
                    for r, t in ipairs(touches) do
                        touches[r].state = BEGAN
                        touches[r].initX = t.x
                        touches[r].initY = t.y
                    end
                    -- Dispatch BEGAN
                    dispatchTouches(table.unpack(touches))
                    touchesAutoDispatcher = nil
                end)
            end
        end
    end
end
