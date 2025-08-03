player = {
    x = 64,
    y = 64,
    dx = 0,
    dy = 0,
    width = 8,
    height = 8,
    sprite = 1,
    speed = 2,
    face = 0,
}

GLOBAL_ROTATION = 0

MAP_SIZE_IN_TILES = 16
MAP_SIZE = MAP_SIZE_IN_TILES * 8

S = {
    WALL = {
        TILE = 17,
        WALL = 33,
    },
    BOX = {
        TILE = 18,
        WALL = 34,
    },
    BUTTON = {
        TILE = 35
    }
}

wall_lookup = {}

boxes_to_draw = {}

particles={}

function _init()
    -- Populate wall lookup for predefined tiles
    for _, tile in pairs(S) do
        wall_lookup[tile.TILE] = tile.WALL
    end
    
    -- Auto-populate wall lookup for all tiles with collision flags
    -- This assumes wall sprites are 16 tiles higher than their base tile
    for tile_id = 0, 255 do
        if fget(tile_id, 0) and not wall_lookup[tile_id] then
            wall_lookup[tile_id] = tile_id + 16
        end
    end
    
    collect_static_boxes()
end

function _update()
    player_update()

    if not stat(57) then
        -- music(0)
    end
end

function is_solid_at(px, py)
    local tile_x = flr(px / 8) -- pga spritesen är 8x8
    local tile_y = flr(py / 8)
    return fget(mget(tile_x, tile_y), 0) or fget(mget(tile_x, tile_y + MAP_SIZE_IN_TILES), 0)
end

function in_rect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end


function player_update()
    -- inputs baby
    local x_dir = (btn(1) and 1 or 0) - (btn(0) and 1 or 0)
    local y_dir = (btn(3) and 1 or 0) - (btn(2) and 1 or 0)

    -- normalize diagonal movement
    if x_dir != 0 and y_dir != 0 then
        x_dir *= 0.7071
        y_dir *= 0.7071
    end

    -- move x axis as far as possible
    if x_dir != 0 then
        local step = x_dir > 0 and 1 or -1
        for i=1,player.speed do
            local next_x = player.x + step
            local test_x = next_x + (x_dir > 0 and player.width-1 or 0)
            if not is_solid_at(test_x, player.y) and not is_solid_at(test_x, player.y + player.height-1) then
                player.x = next_x
            else
                break
            end
        end
    end

    -- move y axis as far as possible
    if y_dir != 0 then
        local step = y_dir > 0 and 1 or -1
        for i=1,player.speed do
            local next_y = player.y + step
            local test_y = next_y + (y_dir > 0 and player.height-1 or 0)
            if not is_solid_at(player.x, test_y) and not is_solid_at(player.x + player.width-1, test_y) then
                player.y = next_y
            else
                break
            end
        end
    end

    -- Check room transition
    local offset = player.width
    local player_x_center = player.x + (player.width/2)
    local player_y_center = player.y + (player.height/2)
    local left_screen_position = player.face*MAP_SIZE
    if not in_rect(player_x_center, player_y_center, left_screen_position + offset, offset, MAP_SIZE - (offset*2), MAP_SIZE - (offset*2)) then
        direction = directions.WEST
        edge_offset = player.y
        if player_y_center - offset < 0 then
            direction = directions.NORTH
            edge_offset = player.x - left_screen_position
        elseif player_y_center + offset > MAP_SIZE then
            direction = directions.SOUTH
            edge_offset = player.x - left_screen_position
        elseif player_x_center + offset > (player.face+1)*MAP_SIZE then
            direction = directions.EAST
        end

        traverse(direction, edge_offset)
    end
end

-- Update map based on current cube rotation and player position.
function update_map(previous_face, current_face)
    local map_segment = {}
    local box_map_segment = {}
    local angle = cube_rotation_lookup[previous_face][current_face] or 0
    
    if angle == 0 then
        return -- No rotation needed, exit early.
    end
    GLOBAL_ROTATION += angle / 90
    GLOBAL_ROTATION = GLOBAL_ROTATION % 4
    for i = 0, 5 do
        for j = 0, MAP_SIZE_IN_TILES - 1 do
            for k = 0, MAP_SIZE_IN_TILES - 1 do
                -- Rotate all map segments based on the previous and current face.
                
                local new_tile = 
                    (angle == -90 and mget(i * MAP_SIZE_IN_TILES + 15 - k, j)) or 
                    (angle == 180 and mget(i * MAP_SIZE_IN_TILES + 15 - j, 15 - k)) or 
                    (angle == 90 and mget(i * MAP_SIZE_IN_TILES + k, 15 - j)) or {}

                -- Rotate all map segments based on the previous and current face.
                
                local new_box_tile = 
                    (angle == -90 and mget(i * MAP_SIZE_IN_TILES + 15 - k, MAP_SIZE_IN_TILES + j)) or 
                    (angle == 180 and mget(i * MAP_SIZE_IN_TILES + 15 - j, MAP_SIZE_IN_TILES + 15 - k)) or 
                    (angle == 90 and mget(i * MAP_SIZE_IN_TILES + k, MAP_SIZE_IN_TILES + 15 - j)) or {}
                    
                map_segment[(i * MAP_SIZE_IN_TILES * MAP_SIZE_IN_TILES) + (j * MAP_SIZE_IN_TILES) + k] = new_tile
                    
                box_map_segment[(i * MAP_SIZE_IN_TILES * MAP_SIZE_IN_TILES) + (j * MAP_SIZE_IN_TILES) + k] = new_box_tile
            end
        end
    end
    -- Loop through the copied map segment and set the new tiles to the map.
    for i = 0, 5 do
        for j = 0, MAP_SIZE_IN_TILES - 1 do
            for k = 0, MAP_SIZE_IN_TILES - 1 do
                mset(i * MAP_SIZE_IN_TILES + j, k, map_segment[(i * MAP_SIZE_IN_TILES * MAP_SIZE_IN_TILES) + (j * MAP_SIZE_IN_TILES) + k])
                mset(i * MAP_SIZE_IN_TILES + j, k + MAP_SIZE_IN_TILES, box_map_segment[(i * MAP_SIZE_IN_TILES * MAP_SIZE_IN_TILES) + (j * MAP_SIZE_IN_TILES) + k])
            end
        end
    end
end


function collect_static_boxes()
    for x = 0, MAP_SIZE_IN_TILES - 1 do
        for y = 0, MAP_SIZE_IN_TILES - 1 do
            local box_tile = mget(player.face * MAP_SIZE_IN_TILES + x, MAP_SIZE_IN_TILES + y)
            if fget(box_tile, 1) then
                add(boxes_to_draw, {x = x * 8, y = y * 8, tile = box_tile, fall_height = 0})
            end
        end
    end
end

-- Move boxes according to the gravity of the current face.
function update_boxes(face)
    boxes_to_draw = {}
    for k, v in pairs(connections[face + 1]) do
        for x = 0, MAP_SIZE_IN_TILES - 1 do
            for y = 0, MAP_SIZE_IN_TILES - 1 do
                local box_tile = mget(v[1] * MAP_SIZE_IN_TILES + x, MAP_SIZE_IN_TILES + y)
                if fget(box_tile, 1) then
                    local falling_direction = (v[2] + GLOBAL_ROTATION) % 4
                    local fall_distance = 0
                    local new_pos = {x, y}
                    local step = {0, 0}
                    local escaped_screen = false
                    if falling_direction % 2 == 1 then -- falling in y-direction
                        step[1] = (falling_direction == directions.EAST and 1) or -1
                    else
                        step[2] = (falling_direction == directions.SOUTH and 1) or -1
                    end
                    -- TODO (RobotGandhi): Boxes can "merge" if they end up on the same square.
                    while in_rect(new_pos[1], new_pos[2], 0, 0, 15, 15) and not fget(mget(v[1] * MAP_SIZE_IN_TILES + new_pos[1] + step[1], new_pos[2] + step[2]), 0) do
                        new_pos[1] += step[1]
                        new_pos[2] += step[2]
                        fall_distance += 1
                    end
                    if not in_rect(new_pos[1], new_pos[2], 1, 1, 13, 13) then
                        if falling_direction == directions.NORTH and new_pos[2] <= 0 then 
                            new_pos = {x, 15}
                            escaped_screen = true
                        elseif falling_direction == directions.EAST and new_pos[1] >= 15 then 
                            new_pos = {0, y}
                            escaped_screen = true
                        elseif falling_direction == directions.SOUTH and new_pos[2] >= 15 then 
                            new_pos = {x, 0}
                            escaped_screen = true
                        elseif falling_direction == directions.WEST and new_pos[1] <= 0 then 
                            new_pos = {15, y}
                            escaped_screen = true
                        end
                    end
                    if escaped_screen then
                        if cube_rotation_lookup[v[1]][face] == 90 then
                            new_pos = {new_pos[2], 15 - new_pos[1]}
                        elseif cube_rotation_lookup[v[1]][face] == 180 then
                            new_pos = {15 - new_pos[1], 15 - new_pos[2]}
                        elseif cube_rotation_lookup[v[1]][face] == -90 then
                            new_pos = {15 - new_pos[2], new_pos[1]}
                        end
                    end
                    mset(v[1] * MAP_SIZE_IN_TILES + x, MAP_SIZE_IN_TILES + y, 0)
                    local face_to_place = (escaped_screen and face) or v[1]
                    if mget(face_to_place * MAP_SIZE_IN_TILES + new_pos[1], new_pos[2]) == S.BUTTON.TILE then
                        mset(face_to_place * MAP_SIZE_IN_TILES + new_pos[1], new_pos[2], S.BOX.TILE)
                        if escaped_screen then
                            if falling_direction % 2 == 1 then
                                mset(v[1] * MAP_SIZE_IN_TILES + 15 - new_pos[1], new_pos[2], S.BOX.TILE)
                            else
                                mset(v[1] * MAP_SIZE_IN_TILES + new_pos[1], 15 - new_pos[2], S.BOX.TILE)
                            end
                        end
                    else
                        mset(face_to_place * MAP_SIZE_IN_TILES + new_pos[1], MAP_SIZE_IN_TILES + new_pos[2], box_tile)
                    
                    if escaped_screen then
                        add_box_to_draw(new_pos[1] * 8, new_pos[2] * 8, box_tile, fall_distance)
                    end

                    end
                end
            end
        end
    end
    
    local opposite_face = 0
    if face == faces.BASE then opposite_face = faces.TOP
    elseif face == faces.FRONT then opposite_face = faces.BACK
    elseif face == faces.RIGHT then opposite_face = faces.LEFT
    elseif face == faces.BACK then opposite_face = faces.FRONT
    elseif face == faces.LEFT then opposite_face = faces.RIGHT
    elseif face == faces.TOP then opposite_face = faces.BASE
    end
                          
    for x = 0, MAP_SIZE_IN_TILES - 1 do
        for y = 0, MAP_SIZE_IN_TILES - 1 do
            local box_tile = mget(face * MAP_SIZE_IN_TILES + x, MAP_SIZE_IN_TILES + y)
            if fget(box_tile, 1) then
                mset(opposite_face * MAP_SIZE_IN_TILES + x, MAP_SIZE_IN_TILES + y, 0)
                mset(face * MAP_SIZE_IN_TILES + x, MAP_SIZE_IN_TILES + y, box_tile)
                add_box_to_draw(x * 8, y * 8, box_tile, MAP_SIZE_IN_TILES)
            end
        end
    end
end

function add_box_to_draw(x, y, tile, fall_height)
    add(boxes_to_draw, {
        x = x,
        y = y,
        tile = tile,
        fall_height = fall_height
    })
end


function _draw()
    cls()
    local map_x = player.face * MAP_SIZE_IN_TILES
    
    -- Automatically draw wall sprites for all tiles with collision flags
    draw_map_walls(map_x)
    draw_box_walls()
    
    -- Draw player
    draw_player()

    -- Draw main tiles
    map(map_x, 0, 0, 0, MAP_SIZE_IN_TILES, MAP_SIZE_IN_TILES)
    
    -- Draw boxes and their walls
    draw_boxes()
    draw_minimap()
    draw_particles()

    -- draw the player's pixel position
    -- print("Face: "..player.face, 0, 10, 12)
    -- print("Angle: "..GLOBAL_ROTATION, 0, 20, 12)
end

function draw_boxes()
    for _, box in pairs(boxes_to_draw) do
        mapdrawtile(box.tile, box.x, box.y)
    end
end

function draw_box_walls()
    for _, box in pairs(boxes_to_draw) do
        mapdrawtile(wall_lookup[box.tile], box.x, box.y + 8)
    end
end

function draw_map_walls(map_x)
    -- Automatically draw wall sprites for all tiles with collision flags
    for x=0,MAP_SIZE_IN_TILES-1 do
        for y=0,MAP_SIZE_IN_TILES-1 do
            local tile = mget(map_x + x, y)
            -- Draw all wall tiles beneath this tile if present in lookup
            local wall_tile = wall_lookup[tile]
            while wall_tile do
                mapdrawtile(wall_tile, x*8, y*8 + 8)
                wall_tile = wall_lookup[wall_tile]
            end
        end
    end

    -- draw the player's pixel position
    -- print("Face: "..player.face, 0, 10, 2)
    -- print("Angle: "..GLOBAL_ROTATION, 0, 20, 2)
end

function draw_minimap()
    local minimap_padding = 4
    spr(minimap_face_sprite_lookup[player.face], minimap_padding, MAP_SIZE - 8 * 2 - minimap_padding, 2,2)
end


function draw_tile_walls(map_x, x, y)
    local tile = mget(map_x + x, y)
    if tile == S.WALL.TILE then
        mapdrawtile(S.WALL.WALL, x*8, y*8 + 8)
    end
end

function draw_player()
    -- Draw the player sprite at the current position
    spr(player.sprite, player.x - (player.face * MAP_SIZE), player.y + 2)
end

-- Helper to draw a single tile at screen position
function mapdrawtile(tile, sx, sy)
    spr(tile, sx, sy)
end
-- Map assets

-- Enum for directions to avoid magic numbers.
directions = {NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3}

-- Enum for cube faces to avoid magic numbers.
faces = {BASE = 0, FRONT = 1, RIGHT = 2, BACK = 3, LEFT = 4, TOP = 5}

-- List of connections between faces where connections[CURRENT_FACE][EXIT_DIRECTION] = {[NEW_FACE], [ENTRY_DIRECTION]}.
-- This means the pairs are sorted in exit direction north, east, south, west as in the directions object.

connections = {
    {{faces.FRONT, directions.SOUTH}, {faces.RIGHT, directions.WEST}, {faces.BACK, directions.NORTH}, {faces.LEFT, directions.EAST}},  -- BASE
    {{faces.TOP, directions.SOUTH}, {faces.RIGHT, directions.NORTH}, {faces.BASE, directions.NORTH}, {faces.LEFT, directions.NORTH}},      -- FRONT
    {{faces.FRONT, directions.EAST}, {faces.TOP, directions.EAST}, {faces.BACK, directions.EAST}, {faces.BASE, directions.EAST}},       -- RIGHT
    {{faces.BASE, directions.SOUTH}, {faces.RIGHT, directions.SOUTH}, {faces.TOP, directions.NORTH}, {faces.LEFT, directions.SOUTH}},      -- BACK
    {{faces.FRONT, directions.WEST}, {faces.BASE, directions.WEST}, {faces.BACK, directions.WEST}, {faces.TOP, directions.WEST}},       -- LEFT
    {{faces.BACK, directions.SOUTH}, {faces.RIGHT, directions.EAST}, {faces.FRONT, directions.NORTH}, {faces.LEFT, directions.WEST}}   -- TOP
}

cube_rotation_lookup = {
    [faces.FRONT] = {
        [faces.RIGHT] = -90,
        [faces.LEFT] = 90,
    },
    [faces.TOP] = {
        [faces.RIGHT] = 180,
        [faces.LEFT] = 180,
    },
    [faces.LEFT] = {
        [faces.TOP] = 180,
        [faces.FRONT] = -90,
        [faces.BACK] = 90,
    },
    [faces.RIGHT] = {
        [faces.TOP] = 180,
        [faces.BACK] = -90,
        [faces.FRONT] = 90,
    },
    [faces.BACK] = {
        [faces.LEFT] = -90,
        [faces.RIGHT] = 90,
    },
    [faces.BASE] = { -- No rotations from the base face.
    },
}

minimap_face_sprite_lookup = {
    [faces.BASE] = 10,
    [faces.FRONT] = 12,
    [faces.RIGHT] = 14,
    [faces.BACK] = 16,
    [faces.LEFT] = 18,
    [faces.TOP] = 20,
}


--[[Function for traversing to another face.
    exit_direction: direction the character is exiting through.
    offset: how far from the edge is the character? Counting from the left on north/south and the top on east/west.
]]
function traverse(exit_direction, offset)
    local perspective_exit_direction = exit_direction - GLOBAL_ROTATION
    perspective_exit_direction = exit_direction % 4
    local new_pos = connections[player.face + 1][perspective_exit_direction + 1]
    update_map(player.face, new_pos[1])
    update_boxes(new_pos[1])

    player.face = new_pos[1]
    local new_dir = new_pos[2] + GLOBAL_ROTATION
    local player_offset = player.width * 2
    player_offset += (exit_direction == directions.NORTH or exit_direction == directions.WEST) and player.width * 0.75 or -player.width * 0.75
    new_dir = new_dir % 4
    player.x = player.face*MAP_SIZE + ((new_dir == directions.EAST and MAP_SIZE - (player_offset)) or (new_dir == directions.WEST and player_offset) or offset)
    player.y = ((new_dir == directions.SOUTH and MAP_SIZE - (player_offset)) or (new_dir == directions.NORTH and player_offset) or offset)
end

--VFX & Canera
camera_offset = 5

-- Function to apply screen shake effect
function screen_shake(amt, fade_factor)
  local fade = fade_factor or 0.95
  local offset_x=amt/2-rnd(amt)
  local offset_y=amt/2-rnd(amt)
  offset_x*=camera_offset
  offset_y*=camera_offset
  
  camera(offset_x,offset_y)
  camera_offset*=fade
  if camera_offset<0.05 then
    offset=0
  end
end

-- Function to reset camera shake effect. Always call this after finishing a screen shake.
function reset_shake() 
    camera_offset = 0.2
    camera(0,0)
end

--VFX & Canera
camera_offset = 5

-- Function to apply screen shake effect
function screen_shake(amt, fade_factor)
  local fade = fade_factor or 0.95
  local offset_x=amt/2-rnd(amt)
  local offset_y=amt/2-rnd(amt)
  offset_x*=camera_offset
  offset_y*=camera_offset
  
  camera(offset_x,offset_y)
  camera_offset*=fade
  if camera_offset<0.05 then
    offset=0
  end
end

-- Function to reset camera shake effect. Always call this after finishing a screen shake.
function reset_shake() 
    camera_offset = 0.2
    camera(0,0)
end

-- particles --
-- 0,1 xpos, ypos: x and y position
-- 2 amt: amount of particles
-- 3 frc: initial particle force
-- 4 r_offset: random offset from position
-- 5 spread: emitter spread, adjusted for angle
-- 6 angle: the angle of the emitter
-- 7 lifetime: how long the particle lives
-- 8 start size: how big particle is initially
-- 9 gravity_scale
-- 10 col 1: the primary particle color
-- 11 col 2: the secondary particle color
-- Example: play_particles(player.x - (player.face * MAP_SIZE), player.y, 3, 7, 0.1, 0.1, 180, 4, 1, 1, 6, 7)
function play_particles(xpos, ypos,amt,frc, 
r_offset, spread, angle, lifetime, startsize, g_scale, col1, col2)

 local theta = angle + (rnd(1) - 0.5) * spread
    
    for i=1,amt do
        add(particles,{
            -- initial position
            x=xpos+rnd(r_offset),
            y=ypos+rnd(r_offset),
            -- x velocity
            v_x = frc * cos(theta),
            -- y velocity
            v_y = frc * sin(theta),
            -- graphics
            radius= rnd(1) + startsize,
            color1 = col1,
            color2 = col2,
            used_color = 0,
            max_life = lifetime,
            gravity_scale = g_scale,
            life = 0,
        })
    end
end

function draw_particles(gravity)
    local gravity = gravity or 1
    for p in all(particles) do
     circfill(p.x, p.y, 
        p.radius,
      p.used_color) 
    end
    
    local i = 1
    for p in all(particles) do
        local dt = 1
        -- apply gravity		
        p.v_y += gravity * p.gravity_scale
            
        -- update position
        p.x += p.v_x * dt
        p.y += p.v_y * dt
        
        -- update graphics
        p.life = move_towards(
        p.life, p.max_life, 0.05)
        
        local life_ratio = (p.max_life 
        - p.life) / p.max_life
        
        p.used_color = p.color1
        if(life_ratio < 0.97) then
            p.used_color = p.color2
        end
        
        p.radius = p.radius * life_ratio
        
        if(life_ratio == 0) then
            deli(particles, i)
        end
        
        i += 1
    end
end

-- Math utility
function move_towards(val, target, rate)
    if val > target then
        val -= rate
        if val < target then 
            val = target 
        end
    elseif val < target then
        val += rate
        if val > target then 
            val = target 
        end
    end
    return val
end