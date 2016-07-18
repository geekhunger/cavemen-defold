Sprite = class(Object)

-- General purpose class
function Sprite:init(img, x, y, w, h, width, height)
    Object.init(self)
    
    self.x = x or 0
    self.y = y or 0
    self.frameWidth = w or img.width
    self.frameHeight = h or img.height
    self.width = width or self.frameWidth
    self.height = height or self.frameHeight
    self.color = color(255)
    self.antialiased = false
    
    self.mesh = mesh()
    self.mesh.texture = img
    self.mesh.textureRegion = 1
    self.mesh:addRect(0, 0, 0, 0)
    
    self.animations = {}
    self.numAnimations = 0
    --self.animating (boolean)
    --self.name (string)
    --self.frame (number)
    --self.fps (number)
    --self.looping (boolean or number)
    --self.numLoopings (number)
    --self.callback (function)
    
    self:addAnimation("_default", {1})
    self:setAnimation("_default", 1, false)
end

-- Set parameters for animation playback
-- Each call to setAnimation overrides the previous so that [fps, looping, callback] are always reset
-- to their defaults, but [name, frame and numLoopings] are only reset once per unique animation call
-- This allows for frequent calls of this method, without messing up the current playback!
-- [looping] can be boolean or number
-- [callback] is called after every complete loop over the animation sequence
-- and gets passed [currentLoopNumber, animationName] parameters which are optional to use
function Sprite:setAnimation(name, fps, looping, callback)
    assert(self.animations[name], "could not find animation '"..name.."'")
    
    if name ~= self.name then
        -- Reset only when animation really changes!
        self.name = name
        self.frame = 1
        self.numLoopings = 0
        self.animating = nil
        self._animationTimer = nil
    end
    
    self.fps = fps or 12
    self.looping = type(looping) == "number" and looping or booleanOrDefaultBoolean(looping, true)
    self.callback = callback
end

-- Create a named animation on sprite from sequence of frames
function Sprite:addAnimation(name, frames)
    if not self.animations[name] then
        self.numAnimations = self.numAnimations + 1
    end
    self.animations[name] = frames
end

-- Remove animation from sprite by name
function Sprite:removeAnimation(name)
    if self.animations[name] then
        self.numAnimations = self.numAnimations - 1
    end
    self.animations[name] = nil
end

-- Gather information about any rectangular region on texture
-- Return a sequence of all regions from i to j where each region is a tile of width x height
-- Setting the 'explicit' flag returns only tiles enclosed by the overall region rect from i to j (skipping the inbetweens)
-- Regions are described by their index position on texture: reading from top left on texture, indices are: 1,2,3...x
function Sprite:getTextureRegion(width, height, i, j, explicit)
    i = i or 1
    j = j or i
    local cols = self.mesh.texture.width / width
    local rows = self.mesh.texture.height / height
    local tiles = {}
    local ids = {}
    
    local getColNRow = function(id)
        local rem = id % cols
        local col = (rem ~= 0 and rem or cols) - 1
        local row = rows - math.ceil(id / cols)
        return col, row
    end
    
    local minCol, minRow = getColNRow(i)
    local maxCol, maxRow = getColNRow(j)
    
    for k = i, j do
        local col, row = getColNRow(k)
        local w = 1 / cols
        local h = 1 / rows
        local u = w * col
        local v = h * row
        
        if not explicit
        or (col >= minCol and col <= maxCol)
        then
            table.insert(ids, k) -- save texture redion indeces in separate table
            table.insert(tiles, {
                col = col + 1, -- tile (1,1) is at the lower left corner!
                row = row + 1,
                id = k, -- region index on spritesheet
                x = col * width, -- (x,y) is lower left position of the tile at (col,row)
                y = row * height,
                width = width,
                height = height,
                uv = {
                    x = u,
                    y = v,
                    width = w,
                    height = h
                }
            })
        end
    end
    
    return tiles, ids
end

function Sprite:draw()
    if not self.hidden then
        if booleanOrDefaultBoolean(self.animating, true) then
            if not self._animationTimer or ElapsedTime > self._animationTimer + 1/self.fps then
                local ani = self.animations[self.name]
                local frm = self.frame
                
                -- Update texture uv
                local tex = self:getTextureRegion(self.frameWidth, self.frameHeight, ani[frm])
                self.mesh:setRectTex(1, tex[1].uv.x, tex[1].uv.y, tex[1].uv.width, tex[1].uv.height)
                
                -- Stop animating at last frame and last animation in sequence
                -- Invoke callback after each complete loop
                if frm == #ani then
                    self.numLoopings = self.numLoopings + 1
                    self._animationTimer = nil
                    self.animating = false
                    
                    if self.callback then
                        self.callback(self.numLoopings, self.name)
                    end
                end
                
                -- Continue animating when not finished looping
                if (type(self.looping) == "boolean" and self.looping or frm < #ani)
                or (type(self.looping) == "number" and self.numLoopings < self.looping) then
                    -- Advance to next frame in current animation sequence
                    frm = frm + 1
                    self.frame = ani[frm] and frm or 1
                    self.mesh.textureRegionId = ani[self.frame]
                    self._animationTimer = ElapsedTime
                    self.animating = true
                end
            end
        end
        
        pushStyle()
        if self.antialiased then smooth() else noSmooth() end
        pushMatrix()
        translate(self.x, self.y)
        rotate(self.angle)
        pushMatrix()
        scale(self.scaleX, self.scaleY)
        translate(-self.pivotX * self.width, -self.pivotY * self.height)
        self.mesh:setColors(self.color)
        self.mesh:setRect(1, self.width/2, self.height/2, self.width, self.height)
        self.mesh:draw()
        popMatrix()
        self:debugDraw()
        popMatrix()
        popStyle()
    end
end
