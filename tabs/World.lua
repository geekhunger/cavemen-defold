World = class()

function World:init()
    parameter.action("Delete All", function()
        print("removed project data but nothing more")
        clearProjectData()
    end)
    
    self.sfx = {}
    self.sfx.selection = {DATA, "ZgBAQABlQEBAP0BAAAAAAHuYhT4qLhk/fwBAf0BAQEBAQEA+"}
    self.sfx.action = {SOUND_RANDOM, 6653}
    
    self.gestureTimer = .33 -- time duration (in sec) after which to lock into a certain touch mode
    self.undoTimer = 3 -- time duration (in sec) after which drawings can not be un-done anymore
    
    -- NOTE:
    -- Each tile on spritesheet should be at size of power of 2 (8x8, 16x24, 32x32, ... px)
    -- First tile always considered to be empty (eraser)
    self.texture = readImage("Dropbox:cavemen_spritesheet")
    
    self.picker = Object()
    self.picker.width = 8 -- initial size
    self.picker.height = 8
    self.picker.minWidth = 8 -- picker min size AND grid step size!
    self.picker.minHeight = 8
    self.picker.maxWidth = self.picker.minWidth^2 -- max size
    self.picker.maxHeight = self.picker.minHeight^2
    self.picker.preview = Sprite(self.texture, 0, 0, self.picker.width, self.picker.height, 24, 24)
    self.picker.preview.pivotY = 1
    self.picker.preview.textureRegion = {1, 1}
    
    self.titleBarHeight = 32
    
    self.spritesheet = Sprite(self.texture)
    self.spritesheet.scaleX = 6 -- spritesheet and picker scale value
    self.spritesheet.scaleY = 6
    self.spritesheet.pivotY = 1
    self.spritesheet.windowHeight = math.min(self.spritesheet.scaleY * self.spritesheet.height + self.titleBarHeight, HEIGHT/3)
    self.spritesheet.y = self.spritesheet.windowHeight - self.titleBarHeight
    self.picker.y = self.spritesheet.y - self.spritesheet.scaleY * self.picker.height
    
    local numTiles = self.texture.width/8 * self.texture.height/8
    self.flag = Checkbox(math.ceil(nearestPower2(numTiles) + 1))
    self.flag:setValue(tonumber(readProjectData("flag", "0")))
    self.flag.pivotX = 1
    self.flag.pivotY = 1
    
    self.layer = {}
    for layer in string.gmatch(readProjectData("layer", ""), "%S+") do table.insert(self.layer, tonumber(layer)) end
    
    self.visible = Checkbox(#self.layer)
    self.visible:setValue(tonumber(readProjectData("visible", "0")))
    self.visible.color = color(255)
    self.visible.windowWidth = self.visible.height + textSize(self.flag.value[#self.flag.value]*2)
    self.visible.x = WIDTH - self.visible.windowWidth
    self.visible.y = HEIGHT - self.titleBarHeight
    self.visible.angle = -90
    
    self.map = Camera()
    self.map.scaleX = 8 -- map scale value (important for in-game view)
    self.map.scaleY = 8
    self.map.chunkWidth = 4 -- NOTE: Right now chunks only used as visual guides when scrolling tiles (no technical use yet)
    self.map.chunkHeight = 4 -- number of sprites (not pixels)
    self.map.saveBuffer = {} -- used to cache drawings and allow to undo them within timer range
    self.map.adjustPivot = function()
        if self.debug then
            self.map.pivotX = (WIDTH - self.visible.windowWidth) / WIDTH / 2
            self.map.pivotY = (HEIGHT - self.spritesheet.windowHeight - self.titleBarHeight) / HEIGHT / 2 + self.spritesheet.windowHeight / HEIGHT
        else
            self.map.pivotX = .5
            self.map.pivotY = .5
        end
    end
    
    self:orientationChanged()
    self:load()
end

function World:orientationChanged()
    -- NOTE: it's important to call this method without checking self.debug state!
    --if self.debug then
        local whitespace = (self.titleBarHeight - self.flag.height)/2
        
        self.visible.x = WIDTH - self.visible.windowWidth
        
        self.flag.x = WIDTH - whitespace
        self.flag.y = self.spritesheet.windowHeight - whitespace
        
        self.picker.x = self.picker.x - self.spritesheet.x -- move picker and spritesheet always to the left but keep their y
        self.picker.preview.x = whitespace
        self.picker.preview.y = self.flag.y
        
        self.spritesheet.x = 0
        
        self.map:adjustPivot()
    --end
end

-- This method is a coroutine and runs on a separate thread
function World:save()
    local maxTasks = 15 -- number of tasks to solve per single draw() call
    local maxTiles = 30 -- number of tiles to save per single draw() call
    
    -- Loop over save buffer until everything saved
    while #self.map.saveBuffer > 0 do
        for i, task in ipairs(self.map.saveBuffer) do
            if task.time + self.undoTimer < ElapsedTime then
                -- Save tiles that can not be undone anymore (deletes tiles whose texture region index is 1)
                for j, tile in ipairs(task.tiles) do
                    saveProjectData(tile.x.." "..tile.y.." "..task.layer, tile.id)
                    if j % maxTiles == 0 then coroutine.yield() end
                end
                
                -- Create layer at correct sorting position when its still missing
                local pos = 1
                for id, val in ipairs(self.layer) do
                    if val <  task.layer then pos = id + 1 end
                    if val == task.layer then pos = nil end
                    if val >= task.layer then break end
                end
                if pos then
                    table.insert(self.layer, pos, task.layer)
                    self.visible:addByte(pos)
                    self.visible:toggleByte(pos)
                end
                
                table.remove(self.map.saveBuffer, i)
                if i % maxTasks == 0 then coroutine.yield() end
            end
        end
        coroutine.yield()
    end
    
    -- Delete layers that have no content anymore
    local content = table.concat(listProjectData(), " ")
    for id, layer in ipairs(self.layer) do
        if not content:find("%S+%s%S+%s"..layer) then
            table.remove(self.layer, id)
            self.visible:removeByte(id)
        end
    end
    
    saveProjectData("layer", table.concat(self.layer, " "))
    saveProjectData("visible", self.visible:getValue())
    saveProjectData("flag", self.flag:getValue())
end

-- Call this method for dynamic loading (e.g. when camera position changes)
function World:load()
    -- Calculate which tiles are inside cameras sight
    local bottomLeftPos = vec2(self.map:getWorldPosition(0, 0)) -- sight borders!
    local topRightPos = vec2(self.map:getWorldPosition(WIDTH, HEIGHT))
    --local chunkWidth = self.picker.minWidth * self.map.chunkWidth
    --local chunkHeight = self.picker.minHeight * self.map.chunkHeight
    --local bottomLeftChunk = vec2(math.floor(bottomLeftPos.x / chunkWidth), math.floor(bottomLeftPos.y / chunkHeight))
    --local topRightChunk = vec2(math.floor(topRightPos.x / chunkWidth), math.floor(topRightPos.y / chunkHeight))
    local bottomLeftTile = vec2(math.floor(bottomLeftPos.x / self.picker.minWidth), math.floor(bottomLeftPos.y / self.picker.minHeight))
    local topRightTile = vec2(math.floor(topRightPos.x / self.picker.minWidth), math.floor(topRightPos.y / self.picker.minHeight))
    
    -- Load appropriate tiles and pass them to setup()
    if self.map.activeTile ~= bottomLeftTile then
        -- Load all visible tiles
        if not self.map.activeTile then
            local tiles = {}
            
            for layerId, layerValue in ipairs(self.layer) do
                for x = bottomLeftTile.x, topRightTile.x do
                    for y = bottomLeftTile.y, topRightTile.y do
                        local tileId = readProjectData(x.." "..y.." "..layerValue)
                        if tileId then
                            table.insert(tiles, {
                                x = x,
                                y = y,
                                id = tileId,
                                layer = layerValue
                            })
                        end
                    end
                end
            end
            
            self:setup(tiles)
        else
        -- Load only new visible tiles when map changed position
            print("load row/column of tiles")
        end
        
        self.map.activeTile = bottomLeftTile
    end
end

-- Override this method to perform custom world setup
-- This funtion gets called automatically each time when a new piece of the map was dynamically loaded
function World:setup(data)
    for i, tile in ipairs(data) do
        local obj = Sprite(
            self.texture,
            tile.x * self.picker.minWidth,
            tile.y * self.picker.minHeight,
            self.picker.minWidth,
            self.picker.minHeight
        )
        obj.animation._default[1] = tile.id
        obj.layer = tile.layer
        self.map:addChild(obj)
    end
end

-- Expand purpose of debugDraw for this class
-- Display GUI and development tools for the world editor
function World:debugDraw()
    if self.debug then
        pushMatrix()
        pushStyle()
        font("Futura-CondensedMedium")
        
        -- World map
        if self._useMapWindow
        and self._useMapWindow + self.gestureTimer < ElapsedTime
        and not self._drawPickerSprite
        then
            -- Scrolling world map camera
            -- Display grid
            -- TODO: fade out grid when ended scrolling
            local centerX = WIDTH * self.map.pivotX
            local centerY = HEIGHT * self.map.pivotY
            local tileWidth = self.map.scaleX * self.picker.minWidth
            local tileHeight = self.map.scaleY * self.picker.minHeight
            
            local gridScreenX2 = math.ceil(WIDTH / tileWidth / 2) * tileWidth
            local gridScreenY2 = math.ceil(HEIGHT / tileHeight / 2) * tileHeight
            local gridScrollX = self.map.x % tileWidth
            local gridScrollY = self.map.y % tileHeight
            
            local chunkWidth = tileWidth * self.map.chunkWidth
            local chunkHeight = tileHeight * self.map.chunkHeight
            local chunkScreenX2 = math.ceil(WIDTH / chunkWidth / 2) * chunkWidth
            local chunkScreenY2 = math.ceil(HEIGHT / chunkHeight / 2) * chunkHeight
            local chunkScrollX = self.map.x % chunkWidth
            local chunkScrollY = self.map.y % chunkHeight
            
            pushStyle()
            for x = centerX - gridScreenX2, centerX + gridScreenX2, tileWidth do
                noFill()
                strokeWidth(2)
                stroke(33)
                line(x - gridScrollX + 1, 0, x - gridScrollX + 1, HEIGHT)
                strokeWidth(1)
                stroke(96, 88, 79, 255)
                line(x - gridScrollX, 0, x - gridScrollX, HEIGHT)
            end
            for y = centerY - gridScreenY2, centerY + gridScreenY2, tileHeight do
                strokeWidth(2)
                stroke(33)
                line(0, y - gridScrollY - 1, WIDTH, y - gridScrollY - 1)
                strokeWidth(1)
                stroke(96, 88, 79, 255)
                line(0, y - gridScrollY, WIDTH, y - gridScrollY)
            end
            
            -- Display grid chunks
            for x = centerX - chunkScreenX2, centerX + chunkScreenX2, chunkWidth do
                for y = centerY - chunkScreenY2, centerY + chunkScreenY2, chunkHeight do
                    noStroke()
                    fill(33)
                    ellipse(x - chunkScrollX, y - chunkScrollY, 20)
                    noFill()
                    strokeWidth(2)
                    stroke(250, 162, 27, 255)
                    ellipse(x - chunkScrollX, y - chunkScrollY, 15)
                end
            end
            popStyle()
            
            -- Set title bar color to indicate touch mode
            self._moveMapCamera = true
            fill(250, 162, 27, 255)
        else
            fill(236, 26, 79, 255)
        end
        zLevel(1)
        rect(0, HEIGHT - self.titleBarHeight, WIDTH, self.titleBarHeight)
        
        -- Display additional info on title bar
        if self._moveMapCamera then
        -- Scrolling mode
            fill(20)
            text(string.format("x: %.0f  y: %.0f", self.map.x / self.map.scaleX, self.map.y / self.map.scaleY), WIDTH/2, HEIGHT - self.titleBarHeight/2)
        else
        -- Drawing mode
            if #self.map.saveBuffer > 0 then
                local time = self.map.saveBuffer[#self.map.saveBuffer].time + self.undoTimer - ElapsedTime
                fill(255)
                text(string.format("Undo %.0f", time), WIDTH/2, HEIGHT - self.titleBarHeight/2)
            end
        end
        
        -- Layers
        zLevel(-1)
        fill(33)
        rect(WIDTH - self.visible.windowWidth, 0, self.visible.windowWidth, HEIGHT)
        self.visible:draw()
        
        for id, value in ipairs(self.layer) do
            local valueHeight = select(2, textSize(value))
            fill(255)
            textMode(CORNER)
            textAlign(LEFT)
            text(string.format("%i", value), self.visible.x + self.visible.height + 8, self.visible.y - id * self.visible.height + self.visible.height - id * self.visible.whitespace + self.visible.whitespace - valueHeight)
        end
        
        -- Sprite picker
        clip(0, 0, WIDTH, self.spritesheet.windowHeight)
            fill(20)
            rect(0, 0, WIDTH, HEIGHT)
            self.spritesheet:draw()
            
            noFill()
            strokeWidth(4)
            stroke(0)
            rect(self.picker.x, self.picker.y, self.spritesheet.scaleX * self.picker.width, self.spritesheet.scaleY * self.picker.height)
            stroke(255)
            rect(self.picker.x + 4, self.picker.y + 4, self.spritesheet.scaleX * self.picker.width - 8, self.spritesheet.scaleY * self.picker.height - 8)
            
            if self._useSpritesheetWindow
            and self._useSpritesheetWindow + self.gestureTimer < ElapsedTime
            and not self._moveSpritesheet
            then
                self._resizePicker = true
                fill(250, 162, 27, 255)
            else
                fill(236, 26, 79, 255)
            end
            noStroke()
            rect(0, self.spritesheet.windowHeight - self.titleBarHeight, WIDTH, self.titleBarHeight)
            
            fill(0)
            rect(self.picker.preview.x, self.picker.preview.y - self.picker.preview.height, self.picker.preview.width, self.picker.preview.height)
            self.picker.preview:draw()
            
            fill(255)
            textMode(CENTER)
            text(string.format("%04i", self.picker.preview.textureRegion[1] - 1), self.picker.preview.x + self.picker.preview.width + 24, self.spritesheet.windowHeight - self.titleBarHeight/2)
            
            textAlign(RIGHT)
            text(string.format("%i", self.flag:getValue()), WIDTH - 24 - self.flag.width, self.spritesheet.windowHeight - self.titleBarHeight/2)
            self.flag:draw()
        clip()
        
        popStyle()
        popMatrix()
    end
end

-- Override this method to perform custom world drawing
function World:draw()
    if not self.hidden then
        -- Custom world camera
        -- NOTE: rotation, sorting and parallax completely deactivated for this game!
        pushMatrix()
        
        if self._shakingOffset then translate(self.map._shakingOffset.x, self.map._shakingOffset.y) end
        translate(self.map.pivotX * WIDTH, self.map.pivotY * HEIGHT)
        
        for id, child in ipairs(self.map.scene) do
            local layer
            for layerId, layerValue in ipairs(self.layer) do
                if child.layer == layerValue then
                    layer = layerId
                    break
                end
            end
            
            if child.draw
            and self.visible.byte[layer] then
                pushMatrix()
                translate(-self.map.x, -self.map.y)
                scale(self.map.scaleX, self.map.scaleY)
                child:draw()
                popMatrix()
            end
        end
        
        -- Editor
        popMatrix()
        self:debugDraw()
        
        -- Coroutine threads
        if self.map.saveRoutine then
            coroutine.resume(self.map.saveRoutine)
        end
    end
end

function World:debugTouched(touch)
    -- Actions on editor (debug mode only)
    if self.debug then
        -- Register where touches begin and save identifier flags
        if touch.state == BEGAN then
            -- Touch inside world maps title bar
            if touch.x > 0 and touch.x < WIDTH and touch.y > HEIGHT - self.titleBarHeight and touch.y < HEIGHT then
                self._undoDrawing = true
            end
            
            -- Touch inside spritesheets title bar
            if touch.y < self.spritesheet.windowHeight and touch.y > self.spritesheet.windowHeight - self.titleBarHeight then
                self._resizeSpritesheetWindow = true
            end
            
            -- Touch inside spritesheets window
            if touch.y < self.spritesheet.windowHeight - self.titleBarHeight and touch.y > 0 then
                self._useSpritesheetWindow = touch.initTime
                -- uses more sub-action flags
            end
            
            -- Touch inside layers window
            if touch.x < WIDTH and touch.x > WIDTH - self.visible.windowWidth + self.visible.height
            and touch.y < HEIGHT - self.titleBarHeight and touch.y > self.spritesheet.windowHeight
            then
                self._useLayerWindow = true
            end
            
            -- Touch inside world map window
            if touch.x > 0 and touch.x < WIDTH - self.visible.windowWidth
            and touch.y > self.spritesheet.windowHeight and touch.y < HEIGHT - self.titleBarHeight
            then
                self._useMapWindow = touch.initTime
                self._saveBuffer = { -- collector variable
                    --time (number) set in ENDED state
                    layer = self.flag:getValue(),
                    tiles = {}
                }
            end
        end
        
        -- Track registered touches
        if touch.state == MOVING then
            -- Resize spritesheet window
            if self._resizeSpritesheetWindow then
                if touch.deltaY < 0 or (touch.deltaY > 0 and self.spritesheet.windowHeight - self.titleBarHeight + touch.deltaY < self.spritesheet.scaleY * self.spritesheet.height) then
                    if self.spritesheet.windowHeight + touch.deltaY < HEIGHT - self.titleBarHeight
                    and self.spritesheet.windowHeight + touch.deltaY > self.titleBarHeight
                    then
                        self.spritesheet.windowHeight = self.spritesheet.windowHeight + touch.deltaY
                        self.picker.preview.y = self.picker.preview.y + touch.deltaY
                        self.flag.y = self.flag.y + touch.deltaY
                    end
                    
                    if (touch.deltaY < 0 and self.spritesheet.y > self.spritesheet.windowHeight - self.titleBarHeight)
                    or (touch.deltaY > 0 and self.spritesheet.y < self.spritesheet.windowHeight - self.titleBarHeight)
                    then
                        self.spritesheet.y = self.spritesheet.y + touch.deltaY
                        self.picker.y = self.picker.y + touch.deltaY
                    end
                end
                
                -- Adjust world map camera (same done on orientationChanged)
                self.map:adjustPivot()
            end
            
            -- Sub-actions on spritesheet window
            if self._useSpritesheetWindow then
                -- Resize width and height of sprite picker (at 8px steps)
                if self._resizePicker then
                    local delta = touch.x - touch.initX
                    local min = vec2(self.picker.minWidth, self.picker.minHeight)
                    local step = touch.deltaX > 0 and min or -min
                    local width = self.picker.width + step.x
                    local height = self.picker.height + step.y
                    
                    if delta % math.abs(step.x) == 0 and delta % math.abs(step.y) == 0
                    and width >= self.picker.minWidth and width <= self.picker.maxWidth
                    and height >= self.picker.minHeight and height <= self.picker.maxHeight
                    and width <= self.spritesheet.width
                    and height <= self.spritesheet.height
                    then
                        self.picker.y = self.picker.y - self.spritesheet.scaleY * step.y
                        self.picker.width = width
                        self.picker.height = height
                    end
                else
                -- Scroll spritesheet and sprite picker
                    local x = self.spritesheet.x + touch.deltaX
                    local y = self.spritesheet.y + touch.deltaY
                    local width = self.spritesheet.scaleX * self.spritesheet.width
                    local height = self.spritesheet.scaleY * self.spritesheet.height
                    self._moveSpritesheet = true
                    
                    if (width > WIDTH and x < 0 and x + width > WIDTH)
                    or (width < WIDTH and x > 0 and x + width < WIDTH)
                    then
                        self.spritesheet.x = x
                        self.picker.x = self.picker.x + touch.deltaX
                    end
                    
                    if (height > self.spritesheet.windowHeight - self.titleBarHeight and y > self.spritesheet.windowHeight - self.titleBarHeight and y - height < 0)
                    or (height < self.spritesheet.windowHeight - self.titleBarHeight and y < self.spritesheet.windowHeight - self.titleBarHeight and y - height > 0)
                    then
                        self.spritesheet.y = y
                        self.picker.y = self.picker.y + touch.deltaY
                    end
                end
            end
            
            -- Scroll layers window
            if self._useLayerWindow then
                local y = self.visible.y + touch.deltaY
                self._scrollLayerWindow = true
                
                if self.visible.width > HEIGHT - self.spritesheet.windowHeight - self.titleBarHeight
                and (y > HEIGHT - self.titleBarHeight and y - self.visible.width < self.spritesheet.windowHeight)
                or (touch.deltaY < 0 and y > HEIGHT - self.titleBarHeight and y - self.visible.width > self.spritesheet.windowHeight)
                then
                    self.visible.y = y
                end
            end
            
            -- Sub-actions on world map window
            if self._useMapWindow then
                -- Draw on map (with picker sprite) at (flag) layer
                if not self._moveMapCamera then
                    self._drawPickerSprite = true
                    
                    if touch.x > 0 and touch.x < WIDTH - self.visible.windowWidth
                    and touch.y > self.spritesheet.windowHeight and touch.y < HEIGHT - self.titleBarHeight
                    then
                        -- Calculate tile that we are currently touching
                        local pos = vec2(self.map:getWorldPosition(touch.x, touch.y))
                        local tile = vec2(math.floor(pos.x / self.picker.minWidth), math.floor(pos.y / self.picker.minHeight))
                        local i = 0
                        
                        -- Chache the touched tile and respond to drawing only when this tile changes
                        if self._activeTile ~= tile then
                            self._activeTile = tile
                            
                            -- Unpack picker indeces into tile positions
                            for y = self.picker.height / self.picker.minHeight, 1, -1 do
                                for x = 1, self.picker.width / self.picker.minWidth do
                                    i = i + 1
                                    local x = tile.x + x - 1
                                    local y = tile.y + y - 1
                                    local id = self.picker.preview.textureRegion[i] ~= 1 and self.picker.preview.textureRegion[i] or nil
                                    local skip = false
                                    
                                    for _, existingTile in ipairs(self._saveBuffer.tiles) do
                                        if existingTile.x == x and existingTile.y == y then
                                            existingTile.id = id
                                            skip = true
                                            break
                                        end
                                    end
                                    
                                    if not skip then table.insert(self._saveBuffer.tiles, {x = x, y = y, id = id}) end
                                end
                            end
                        end
                    end
                else
                -- Scroll world map camera
                    self.map.x = self.map.x - touch.deltaX
                    self.map.y = self.map.y - touch.deltaY
                    self:load()
                end
            end
        end
        
        if touch.state == ENDED then
            -- Select sprite for picker
            if self._useSpritesheetWindow
            and not self._moveSpritesheet
            then
                -- Return tile and its index position on spritesheet
                local getTile = function(x, y)
                    local tileX = (x - self.spritesheet.x) / (self.spritesheet.scaleX * self.picker.minWidth)
                    local tileY = (self.spritesheet.y - y) / (self.spritesheet.scaleY * self.picker.minHeight)
                    return
                        tileX,
                        tileY,
                        self.spritesheet.scaleX * self.spritesheet.width / (self.spritesheet.scaleX * self.picker.minWidth) * math.floor(tileY) + math.ceil(tileX)
                end
                
                -- Move picker to selected sprite
                if not self._resizePicker
                and touch.x > self.spritesheet.x and touch.x < self.spritesheet.x + self.spritesheet.scaleX * self.spritesheet.width
                then
                    local tileX, tileY = getTile(touch.x, touch.y)
                    self.picker.x = self.spritesheet.x + self.spritesheet.scaleX * self.picker.minWidth * math.floor(tileX)
                    self.picker.y = self.spritesheet.y - self.spritesheet.scaleY * self.picker.minHeight * math.floor(tileY) - self.spritesheet.scaleY * self.picker.height
                end
                
                -- Adjust picker position when its outside of spritesheet bounds
                local overlapX = self.picker.x + self.spritesheet.scaleX * self.picker.width - self.spritesheet.x - self.spritesheet.scaleX * self.spritesheet.width
                local overlapY = self.picker.y - self.spritesheet.y + self.spritesheet.scaleY * self.spritesheet.height
                if overlapX > 0 then self.picker.x = self.picker.x - overlapX end
                if overlapY < 0 then self.picker.y = self.picker.y - overlapY end
                
                -- Update picker sprite preview
                -- Hack to manually update picker sprite preview
                self.picker.preview.frameWidth = self.picker.minWidth
                self.picker.preview.frameHeight = self.picker.minHeight
                local tileX, tileY, tileID_i = getTile(self.picker.x + 1, self.picker.y + self.spritesheet.scaleY * self.picker.height - 1)
                local tileID_j = select(3, getTile(self.picker.x + self.spritesheet.scaleX * self.picker.width - 1, self.picker.y + 1))
                local tex, ids = self.picker.preview:getTextureRegion(self.picker.preview.frameWidth, self.picker.preview.frameHeight, tileID_i, tileID_j, true)
                local cols = tex[#tex].col - tex[1].col
                local rows = tex[1].row - tex[#tex].row
                local x = tex[1].uv.x
                local y = tex[#tex].uv.y
                local w = cols * tex[1].uv.width + tex[1].uv.width
                local h = rows * tex[1].uv.height + tex[1].uv.height
                
                self.picker.preview.mesh:setRectTex(1, x, y, w, h)
                self.picker.preview.textureRegion = ids -- all texture region indeces inside the picker preview
                
                sound(unpack(self.sfx.selection))
            end
            
            -- Select layer and set flag to its value
            if self._useLayerWindow
            and not self._scrollLayerWindow
            then
                local x = self.visible.x + self.visible.height + 8
                local w = self.visible.windowWidth + self.visible.x - x
                
                for id, value in ipairs(self.layer) do
                    local y = self.visible.y - id * self.visible.height - id * self.visible.whitespace + 4
                    local h = select(2, textSize(value))
                    
                    if touch.x > x and touch.x < x + w
                    and touch.y > y and touch.y < y + h
                    then
                        self.flag:setValue(value)
                        sound(unpack(self.sfx.selection))
                        break
                    end
                end
            end
            
            -- Callbacks for actions inside world map window
            if self._useMapWindow then
                -- Finished drawing onto world map
                if self._drawPickerSprite
                or touch.duration < self.gestureTimer
                then
                    -- Painted (long dragged) over map across multiple tile positions and now finished the action
                    if touch.duration > self.gestureTimer then
                        self._saveBuffer.time = ElapsedTime
                    else
                    -- Painted (just tapped) only over one tile position on the map and now finished the action
                        -- NOTE: The same routine (with minor modifications) is used above in the MOVING state of the picker!
                        local pos = vec2(self.map:getWorldPosition(touch.x, touch.y))
                        local tile = vec2(math.floor(pos.x / self.picker.minWidth), math.floor(pos.y / self.picker.minHeight))
                        local i = 1
                        self._saveBuffer.time = ElapsedTime
                        
                        for y = self.picker.height / self.picker.minHeight, 1, -1 do
                            for x = 1, self.picker.width / self.picker.minWidth do
                                table.insert(self._saveBuffer.tiles, {
                                    x = tile.x + x - 1,
                                    y = tile.y + y - 1,
                                    id = self.picker.preview.textureRegion[i] ~= 1 and self.picker.preview.textureRegion[i] or nil
                                })
                                i = i + 1
                            end
                        end
                    end
                    
                    -- Export collector to actual save buffer
                    table.insert(self.map.saveBuffer, self._saveBuffer)
                    
                    if not self.map.saveRoutine or coroutine.status(self.map.saveRoutine) == "dead" then
                        self.map.saveRoutine = coroutine.create(function() self:save() end)
                    end
                    
                    sound(unpack(self.sfx.action))
                else
                -- Finisched scrolling world map camera
                    --action to perform...
                end
            end
            
            -- Undo drawing action (before coroutine timer kicks in and actually saves it)
            if touch.x > 0 and touch.x < WIDTH and touch.y > HEIGHT - self.titleBarHeight and touch.y < HEIGHT
            and self._undoDrawing
            and #self.map.saveBuffer > 0
            then
                -- Remove one drawing action at a time (starting from latest)
                table.remove(self.map.saveBuffer)
            end
        end
        
        -- Redirect touches to also to objects
        self.flag:touched(touch, function(id)
            self.flag:toggleByte(id)
            saveProjectData("flag", self.flag:getValue())
            sound(unpack(self.sfx.selection))
        end)
        
        self.visible:touched(touch, function(id)
            if touch.y > self.spritesheet.windowHeight then -- trick to block touches for bytes that are hidden by spritesheet window
                self.visible:toggleByte(id)
                saveProjectData("visible", self.visible:getValue())
                sound(unpack(self.sfx.selection))
            end
        end)
    end
    
    -- Clear all identifier flags
    if touch.state == ENDED then
        -- BEGAN states
        self._resizeSpritesheetWindow = nil
        self._useSpritesheetWindow = nil
        self._useLayerWindow = nil
        self._useMapWindow = nil
        self._drawPickerSprite = nil
        self._undoDrawing = nil
        self._saveBuffer = nil
        -- MOVING states
        self._moveSpritesheet = nil
        self._scrollLayerWindow = nil
        self._activeTile = nil
        -- ENDED states
        --
        -- draw() flags
        self._moveMapCamera = nil
        self._resizePicker = nil
    end
end

function World:touched(touch)
    self:debugTouched(touch)
    
    -- Actions on map (only in gameplay mode)
    if not self.debug then
        -- redirect touches to world map objects here
    end
end
