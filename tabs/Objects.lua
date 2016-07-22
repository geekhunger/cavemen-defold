Object = class()

-- Base class for everything
function Object:init()
    self.x = 0
    self.y = 0
    self.width = 0
    self.height = 0
    self.angle = 0
    self.scaleX = 1
    self.scaleY = 1
    self.pivotX = 0
    self.pivotY = 0
    self.speed = 0.1
    self.moving = false
    self.hidden = false
    self.debug = false
end

-- Transition smoothly to new coordinates
-- Assign self.x and self.y directly when interpolation and timing not needed!
function Object:move(x, y, speed, easing)
    self:halt()
    
    local dist = vec2(self.x, self.y):dist(vec2(x, y))
    local time = dist / ((speed or self.speed) * 1000)
    self.moving = true
    
    self._positionTween = tween(time, self, {x = x, y = y}, easing or tween.easing.linear, function()
        self:halt()
    end)
end

-- Immediatelly stop moving transition
function Object:halt()
    if self._positionTween then
        tween.stop(self._positionTween)
        self._positionTween = nil
        self.moving = false
    end
end

-- Return true width and height counting scale
function Object:getSize()
    return
        self.scaleX * self.width,
        self.scaleY * self.width
end

-- Return proposed scaleX and scaleX at given width and height
-- Useful when resizing (scaling!) sprite to new concrete demensions
function Object:getScale(width, height)
    return
        width / self.width,
        height / self.height
end

-- Return width, height and vertices of object's surrounding box
-- Useful when correct size needed regardless of objects rotation
-- Vertices might be used in conjunction with pointInPoly()
function Object:getBoundingBox()
    -- Calculate overall width and height at current rotation
    local deg = math.rad(self.angle)
    local cos = math.abs(math.cos(deg))
    local sin = math.abs(math.sin(deg))
    local width = cos * self.width + sin * self.height
    local height = sin * self.width + cos * self.height
    
    -- Calculate edge vertices of the bounding box
    local w, h = self:getSize()
    local w2 = w * self.pivotX
    local h2 = h * self.pivotY
    
    return
        width,
        height,
        {
            vec2(rotatePoint(self.x - w2, self.y - h2, self.angle, self.x, self.y)), -- (0,0)
            vec2(rotatePoint(self.x + w - w2, self.y - h2, self.angle, self.x, self.y)), -- (1,0)
            vec2(rotatePoint(self.x + w - w2, self.y + h - h2, self.angle, self.x, self.y)), -- (1,1)
            vec2(rotatePoint(self.x - w2, self.y + h - h2, self.angle, self.x, self.y)), -- (0,1)
        }
end

-- Check if point is inside object
-- Useful in conjunction with touches
function Object:testHitPoint(x, y, vertices)
    return pointInPoly(x, y, vertices or select(3, self:getBoundingBox()))
end

-- Display debug widgets
function Object:debugDraw()
    if self.debug then
        -- TODO:
        -- when parenting objects to cameras, then we know nothing about their scale anymore
        -- if debug draw of an object get scaled by its camera parent, we can't reset them back to 1
        -- to avoid this behaviour, we have to use modelMatrix(), decompose its components and scale everything back
        -- Any better ideas?
        math.randomseed(self.x + self.y)
        local r, g, b = math.random(255), math.random(255), math.random(255)
        local sx, sy  = select(4, matrixDecompose(modelMatrix()))
        
        pushStyle()
        pushMatrix()
        
        pushMatrix()
        scale(self.scaleX, self.scaleY)
        translate(-self.pivotX * self.width, -self.pivotY * self.height)
        noFill()
        stroke(r, g, b)
        strokeWidth(1/((sx + sy)/2))
        rect(0, 0, self.width, self.height)
        popMatrix()
        
        scale(1/sx, 1/sy)
        strokeWidth(1)
        line(-25, 0, 25, 0)
        line(0, -25, 0, 25)
        ellipseMode(CENTER)
        ellipse(0, 0, 25)
        
        fill(r, g, b)
        font("HelveticaNeue-Light")
        text(string.format("%.0f,%.0f", self.x, self.y), 0, -15)
        
        popMatrix()
        popStyle()
    end
end
