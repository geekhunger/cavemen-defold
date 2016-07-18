-- Decompose 4x4 matrix into separate transformation operations (translate, rotate, scale)
-- Intended to use with modelMatrix() and viewMatrix()
function matrixDecompose(m)
    local tx = m[13]
    local ty = m[14]
    local tz = m[15]
    local sx = math.sqrt(m[1]^2 + m[2]^2  + m[3]^2)
    local sy = math.sqrt(m[5]^2 + m[6]^2  + m[7]^2)
    local sz = math.sqrt(m[9]^2 + m[10]^2 + m[11]^2)
    -- TODO: extract also z angle in degrees or split further into rx, ry, rz
    return tx, ty, tz, sx, sy, sz
end

-- Return rotated point around custom origin by certain degree
function rotatePoint(x, y, angle, cx, cy)
    cx = cx or 0
    cy = cy or 0
    local deg = math.rad(angle)
    local sin = math.sin(deg)
    local cos = math.cos(deg)
    return
        cx + (cos*(x-cx) - sin*(y-cy)),
        cy + (sin*(x-cx) + cos*(y-cy))
end

-- Choose always bool(bool) over default(bool) while not nil
function booleanOrDefaultBoolean(bool, default)
    if type(bool) == "boolean" then return bool end
    return default
end

-- Format the console output of a table
function printf(t, indent)
    if not indent then indent = "" end
    local names = {}
    for n,g in pairs(t) do
        table.insert(names,n)
    end
    table.sort(names)
    for i,n in pairs(names) do
        local v = t[n]
        if type(v) == "table" then
            if v==t then -- prevent endless loop on self reference
                print(indent..tostring(n)..": <-")
            else
                print(indent..tostring(n)..":")
                printf(v,indent.."   ")
            end
        elseif type(v) == "function" then
            print(indent..tostring(n).."()")
        else
            print(indent..tostring(n)..": "..tostring(v))
        end
    end
end

-- Map value from one range to another
function remapRange(val, a1, a2, b1, b2)
    return b1 + (val-a1) * (b2-b1) / (a2-a1)
end

-- This method extends Codea's math class
-- Round number from float to integer based on adjacent delimiter
function roundNumer(float, limit)
    local i, f = math.modf(float)
    return f < limit and math.floor(float) or math.ceil(float)
end

-- Generate 2^n number sequence
-- [start]1, 2, 4, 8, 16, 32, 64, 128, ...[count]
function sequencePower2(count, start)
    local i = math.max(start or 0, 0)
    local j = i + count - 1
    local sequence = {}
    for n = i, j, 1 do
        table.insert(sequence, 2^n)
    end
    return sequence
end

-- Calculate closest 2^n number to value
function nearestPower2(value)
    return math.log(value) / math.log(2)
end

-- Determine pixel positions on straight line
-- Can be used for A* search algorithm or pixelated drawings
function bresenham(x1, y1, x2, y2)
    local p1 = vec2(math.min(x1, x2), math.min(y1, y2))
    local p2 = vec2(math.max(x1, x2), math.max(y1, y2))
    local delta = vec2(p2.x - p1.x, p1.y - p2.y)
    local err, e2 = delta.x + delta.y -- error value e_xy
    local buffer = {}
    
    while true do
        e2 = 2 * err
        if #buffer > 0 and buffer[#buffer].y == p1.y then -- increase previous line width
            buffer[#buffer].z = buffer[#buffer].z + 1
        elseif #buffer > 0 and buffer[#buffer].x == p1.x then -- increase previous line height
            buffer[#buffer].w = buffer[#buffer].w + 1
        else -- create new line
            table.insert(buffer, vec4(p1.x, p1.y, 1, 1)) -- image.set(x1, y1)
        end
        if p1.x == p2.x and p1.y == p2.y then break end
        if e2 > delta.y then err = err + delta.y; p1.x = p1.x + 1 end -- e_xy + e_x > 0
        if e2 < delta.x then err = err + delta.x; p1.y = p1.y + 1 end -- e_xy + e_y < 0
    end
    
    return buffer
end

-- Return perpendicular distance from point p0 to line defined by p1 and p2
function perpendicularDistance(p0, p1, p2)
    if p1.x == p2.x then
        return math.abs(p0.x - p1.x)
    end
    
    local m = (p2.y - p1.y) / (p2.x - p1.x) -- slope
    local b = p1.y - m * p1.x -- offset
    local dist = math.abs(p0.y - m * p0.x - b)
    
    return dist / math.sqrt(m*m + 1)
end

-- Curve fitting algorithm
function ramerDouglasPeucker(vertices, epsilon)
    epsilon = epsilon or .1
    local dmax = 0
    local index = 0
    local simplified = {}
    
    -- Find point at max distance
    for i = 3, #vertices do
        local d = perpendicularDistance(vertices[i], vertices[1], vertices[#vertices])
        if d > dmax then
            index = i
            dmax = d
        end
    end
    
    -- Recursively simplify
    if dmax >= epsilon then
        local list1 = {}
        local list2 = {}
        
        for i = 1, index - 1 do
            table.insert(list1, vertices[i])
        end
        
        for i = index, #vertices do
            table.insert(list2, vertices[i])
        end
        
        local result1 = ramerDouglasPeucker(list1, epsilon)
        local result2 = ramerDouglasPeucker(list2, epsilon)
        
        for i = 1, #result1 - 1 do
            table.insert(simplified, result1[i])
        end
        
        for i = 1, #result2 do
            table.insert(simplified, result2[i])
        end
    else
        for i = 1, #vertices do
            table.insert(simplified, vertices[i])
        end
    end
    
    return simplified
end

-- Return random point inside a circle
function randomPointInCircle(radius)
    local t = 2 * math.pi * math.random()
    local u = math.random() + math.random()
    local r = u > 1 and (2-u) or u
    return
        radius * r * math.cos(t),
        radius * r * math.sin(t)
end

-- Test point in polygon
function pointInPoly(x, y, poly)
    local oddNodes = false
    local j = #poly
    
    for i = 1, j do
        if (poly[i].y < y and poly[j].y >= y or poly[j].y < y and poly[i].y >= y) and (poly[i].x <= x or poly[j].x <= x) then
            if poly[i].x + (y - poly[i].y) / (poly[j].y - poly[i].y) * (poly[j].x - poly[i].x) < x then
                oddNodes = not oddNodes
            end
        end
        j = i
    end
    
    return oddNodes
end
