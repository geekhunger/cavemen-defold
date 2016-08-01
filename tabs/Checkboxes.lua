Checkbox = class(Object)

-- Generate n checkboxes in a row
-- Each checkbox can be toggled on and of (set bytes to true or false)
-- these bytes have also numerical values by power of 2^n (1, 2, 4, 8, 16, ...)
-- By combining bytes of multiple checkboxes one can get every numerical value within a range
-- the meanings of this flags are up to the user (eg. layers, flags, ...)
function Checkbox:init(number, value, radius)
    Object.init(self)
    
    self.byte = {} -- boolean toggles for each object
    self.value = {} -- numerical meanings of those boolean toggles
    self.color = {} -- might be a table OR a single color() value
    self.radius = radius or 24 -- use width and height properties to adjust at runtime
    self.whitespace = 2
    
    for i = 1, number do self:addByte() end
    if value and value > 0 then self:setValue(value) end
    
    self.width = #self.value * self.radius + #self.value * self.whitespace - self.whitespace
    self.height = self.radius
end

-- Create additional checkboxes (bytes) at runtime
function Checkbox:addByte(pos)
    local id = pos or (#self.byte + 1)
    
    table.insert(self.byte, id, false)
    
    if id < #self.byte - 1 then
        self.value = sequencePower2(#self.byte)
    else
        table.insert(self.value, id, 2^(id - 1))
    end
    
    if type(self.color) == "table" then 
        math.randomseed(id)
        local r, g, b
        repeat r, g, b = math.random(255), math.random(255), math.random(255) until (r+g+b)/3 > 90
        table.insert(self.color, id, color(r, g, b))
    end
    
    self.width = self.width + self.radius + self.whitespace
end

function Checkbox:removeByte(id)
    table.remove(self.byte, id)
    
    if id < #self.byte then
        self.value = sequencePower2(#self.byte)
    else
        table.remove(self.value, id)
    end
    
    if type(self.color) == "table" then table.remove(self.color, id) end
    
    self.width = self.width - self.radius - self.whitespace
end

-- Invert certain byte's state
function Checkbox:toggleByte(id)
    self.byte[id] = not self.byte[id]
end

-- Set checkboxes value by given booleans
-- To assign only certain bytes use direct access through Checkbox.bytes[id] (boolean)
function Checkbox:setBytes(...)
    local bytes = {unpack({...}, 1, #self.value)} -- unpack only n values from m parameters
    assert(#bytes == #self.value, "attempt to set 8x bytes with only "..#bytes.."x values") -- validate amounts and types
    for i = 1, #bytes do assert(type(bytes[i]) == "boolean", "byte setters must be booleans") end
    self.byte = bytes -- assign given bytes
end

-- Set checkboxes value by the sum of bytes
function Checkbox:setValue(n)
    assert(n >= self:getMinValue() and n <= self:getMaxValue(), "attempt to set checkbox value out of range")
    
    local sum = n
    local ptr = #self.value
    local bytes = {}
    
    if sum == 0 then
        for i = 1, ptr do table.insert(bytes, false) end -- default filler
    else
        while sum ~= 0 do
            for i = ptr, 1, -1 do
                if self.value[i] <= sum then
                    bytes[i] = true -- set byte
                    sum = sum - self.value[i]
                    ptr = i - 1
                    if sum > 0 then break end -- continue to next byte
                else
                    bytes[i] = false -- default value
                end
            end
        end
    end
    
    self.byte = bytes
end

-- Return/Encode checkboxes value through booleans
-- If value is passed as parameter then only responsible bytes are returned
function Checkbox:getBytes(value)
    local bytes = value and {} or self.byte
    
    if value then
        local sum = value
        local ptr = #self.value
        
        while sum ~= 0 do
            for i = ptr, 1, -1 do
                if self.value[i] <= sum then
                    bytes[i] = self.byte[i] -- save
                    sum = sum - self.value[i]
                    ptr = i - 1
                    if sum > 0 then break end -- continue search
                end
            end
        end
    end
    
    return bytes
end

-- Return checkboxes value through the sum of bytes
-- If byte id's are passed as parameters then the value from them is returned,
-- useful to calculate a value sum for when certain bytes were active
function Checkbox:getValue(...)
    local ids = {...}
    local sum = 0
    
    if #ids > 0 then
        for _, id in ipairs(ids) do
            sum = sum + self.value[id]
        end
    else
        for id, byte in ipairs(self.byte) do
            if byte then sum = sum + self.value[id] end
        end
    end
    
    return sum
end

-- Value when no bytes selected
function Checkbox:getMinValue()
    return 0
end

-- Value when all available bytes selected
function Checkbox:getMaxValue()
    return #self.value == 0 and 0 or (self.value[#self.value] * 2 - 1)
end

function Checkbox:draw()
    if not self.hidden then
        pushStyle()
        pushMatrix()
        translate(self.x, self.y)
        rotate(self.angle)
        pushMatrix()
        
        if #self.byte > 0 then
            scale(self.scaleX, self.scaleY)
            translate(-self.pivotX * self.width, -self.pivotY * self.height)
            
            local border = 2
            local width = (self.width - self.whitespace * (#self.byte - 1)) / #self.byte
            
            for id, byte in ipairs(self.byte) do
                local x = id * width - width + id * self.whitespace - self.whitespace
                stroke(0)
                strokeWidth(border)
                if byte then
                    if self.color then
                        if type(self.color) == "table" and self.color[id] then
                            fill(self.color[id])
                        elseif type(self.color) ~= "table" then
                            fill(self.color)
                        end
                    else
                        fill(255)
                    end
                else
                    fill(28, 43, 83, 255)
                end
                ellipseMode(CORNER)
                ellipse(x, 0, width,self. height)
                strokeWidth(border/2)
                stroke(255)
                ellipse(x + border, border, width - 2*border, self.height - 2*border)
            end
        end
        
        popMatrix()
        self:debugDraw()
        popMatrix()
        popStyle()
    end
end

function Checkbox:touched(touch, callback)
    if #self.byte > 0
    and touch.state ~= MOVING
    and self:testHitPoint(touch.x, touch.y)
    then
        local width = (self.width - self.whitespace * (#self.byte - 1)) / #self.byte
        local pivot = vec2(self.pivotX * self.scaleX * self.width, self.pivotY * self.scaleY * self.height)
        local tch = pivot + vec2(rotatePoint(touch.x, touch.y, -self.angle, self.x, self.y))
        
        for id, byte in ipairs(self.byte) do
            local obj = Object()
            obj.width = self.scaleX * width
            obj.height = self.scaleY * self.height
            obj.x = self.x + id * obj.width - obj.width + id * self.whitespace
            obj.y = self.y
            
            if obj:testHitPoint(tch.x, tch.y) then
                if touch.state == BEGAN then self._toggleByte = id end
                if touch.state == ENDED and self._toggleByte and self._toggleByte == id then
                    if callback then
                        callback(id) -- pass byte id as parameter
                    else
                        self:toggleByte(id)
                    end
                end
                break
            end
        end
    end
    
    if touch.state == ENDED then
        self._toggleByte = nil
    end
end
