Camera = class(Object)

function Camera:init(x, y)
    Object.init(self)
    
    self.scene = {}
    self.x = x or 0
    self.y = y or 0
    self.pivotX = .5
    self.pivotY = .5
    self.parallax = false
    self.parallaxSpeed = 1.0
end

-- Add new member to camera scene
-- (Optional) "solid" children retain their drawing order
-- and react to parallax (but only when Camera.parallax is active)
function Camera:addChild(object, sorted, parallaxed)
    table.insert(self.scene, object)
    object.sorted = sorted
    object.parallaxed = parallaxed
    self:setParallaxProperties()
end

-- Remove member object from camera scene
function Camera:removeChild(object)
    table.remove(self.scene, self:getChildId(object))
    object.sorted = nil
    object.parallaxed = nil
    self:setParallaxProperties()
end

function Camera:clearChildren()
    self.scene = {}
end

function Camera:setParallaxProperties()
    -- Collect children effected by parallax
    local children = {}
    for i = 1, #self.scene do
        if self.scene[i].parallaxed then
            table.insert(children, self.scene[i])
        end
    end
    
    -- Calculate parallax speed for each child
    for id, child in ipairs(children) do
        child.parallaxSpeed = id * self.parallaxSpeed / #children
    end
end

function Camera:getChildId(object)
    local id
    for i = 1, #self.scene do
        if object == self.scene[i] then
            id = i
            break
        end
    end
    return id
end

-- Return screen coordinate of any world point
-- Pass Object class or x, y world point position
-- Objects care about parallax!
function Camera:getScreenPosition(x, y)
    local isObject = not y and type(x) == "table"
    local parallaxRatio = isObject and x.parallaxSpeed or 1
    local pnt = isObject and vec2(x.x, x.y) or vec2(x, y)
          pnt.x = pnt.x * self.scaleX - self.x * parallaxRatio + self.pivotX * WIDTH
          pnt.y = pnt.y * self.scaleY - self.y * parallaxRatio + self.pivotY * HEIGHT
    local screenPoint = vec2(rotatePoint(pnt.x, pnt.y, self.angle, WIDTH/2, HEIGHT/2))
    
    if not isObject then
        return
            screenPoint.x,
            screenPoint.y,
            screenPoint.x > 0 and screenPoint.x < WIDTH and screenPoint.y > 0 and screenPoint.y < HEIGHT
    end
    
    -- TODO:
    -- The fallowing algorithm has still some flaws:
    -- try rotate object 45° and move to any screen corner
    -- portion of object will be visible but object is considered off-screen because bounding box vertices are actually off-screen
    
    local bb   = select(3, x:getBoundingBox())
    local bb00 = select(3, self:getScreenPosition(bb[1]:unpack()))
    local bb10 = select(3, self:getScreenPosition(bb[2]:unpack()))
    local bb11 = select(3, self:getScreenPosition(bb[3]:unpack()))
    local bb01 = select(3, self:getScreenPosition(bb[4]:unpack()))
    
    return
        screenPoint.x,
        screenPoint.y,
        bb00 or bb10 or bb11 or bb01
end

-- Return world position of any screen coordinate
function Camera:getWorldPosition(x, y)
    local pnt = vec2(rotatePoint(x, y, -self.angle, WIDTH/2, HEIGHT/2))
    return
        (pnt.x + self.x - self.pivotX * WIDTH) / self.scaleX,
        (pnt.y + self.y - self.pivotY * HEIGHT) / self.scaleY
end

function Camera:shake(duration, strength, resolution)
    if self._shakingTween then
        tween.stop(self._shakingTween)
    end
    
    self._shakingOffset = {x = 0, y = 0}
    local shakings = {}
    resolution = resolution or 4 -- ADJUST!
    
    for i = 0, resolution do
        local direction = i%2==0 and -1 or 1
        local ratio = 1 - i / resolution
        --local time = duration / resolution * (1 - ratio)
        local y = strength * ratio * direction
        --local x = math.random() * y / 10
        table.insert(shakings, {x = 0, y = y})
    end
    
    self._shakingTween = tween.path(duration, self._shakingOffset, shakings, tween.easing.linear, function()
        self._shakingOffset = nil
        self._shakingTween = nil
    end)
end

function Camera:debugDraw()
    if self.debug then
        pushStyle()
        pushMatrix()
        
        resetMatrix()
        translate(self.pivotX * WIDTH, self.pivotY * HEIGHT)
        noFill()
        stroke(127)
        strokeWidth(1)
        line(-25, 0, 25, 0)
        line(0, -25, 0, 25)
        ellipseMode(CENTER)
        ellipse(0, 0, 25)
        
        resetMatrix()
        translate(WIDTH/2, HEIGHT/2)
        line(-WIDTH/2, 0, WIDTH/2, 0)
        line(0, -HEIGHT/2, 0, HEIGHT/2)
        
        fill(127)
        font("HelveticaNeue-Light")
        text(string.format("%.0f,%.0f", self.x, self.y), 0, -15)
        
        popMatrix()
        popStyle()
    end
end

function Camera:draw()
    if not self.hidden then
        pushMatrix()
        
        if self._shakingOffset then
            translate(self._shakingOffset.x, self._shakingOffset.y)
        end
        
        translate(self.pivotX * WIDTH, self.pivotY * HEIGHT)
        rotate(self.angle)
        
        table.sort(self.scene, function(obj, list)
            if list.sorted then
                if self.parallax and obj.parallaxed and list.parallaxed then
                    return obj.y + self.y * list.parallaxSpeed > list.y + self.y * obj.parallaxSpeed
                end
                return obj.y > list.y
            end
        end)
        
        for id, child in ipairs(self.scene) do
            if child.draw then
                pushMatrix()
                if self.parallax and child.parallaxed then
                    translate((child.parallaxSpeed * -vec2(self.x, self.y)):unpack())
                else
                    translate(-self.x, -self.y)
                end
                scale(self.scaleX, self.scaleY)
                child:draw()
                popMatrix()
            end
        end
        
        self:debugDraw()
        popMatrix()
    end
end
