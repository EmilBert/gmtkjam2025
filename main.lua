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

    facing_x = 0, -- 1 for right, -1 for left
    
    -- Animation state
    current_animation = "idle",
    animation_frame = 1,
    animation_timer = 0,
}

player_animations = {
    idle = {
        frames = {64},
        speed = 30, -- slower for idle
    },
    walk = {
        frames = {65, 66, 67, 68},
        speed = 4, -- faster for walking
    },
    down = {
        frames = {81, 82, 83, 84},
        speed = 4,
    },
    up = {
        frames = {97, 98, 99, 100},
        speed = 4,
    },
}

GLOBAL_ROTATION = 0
BOX_POS = ""

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
        TILE = 36
    }
}

buttons = {
    {{1,15,15}, {0,15,9}, {0,15,10}, {2,0,9}, {2,0,10}}
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
    
    collect_static_boxes(faces.BASE)
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

    -- Update facing direction
    if x_dir != 0 then
        player.facing_x = x_dir
    end

    -- Determine animation based on movement
    local new_animation = "idle"
    if y_dir < 0 then
        new_animation = "up"
    elseif y_dir > 0 then
        new_animation = "down"
    elseif x_dir != 0 then
        new_animation = "walk"
    end

    -- Change animation if different
    if new_animation != player.current_animation then
        player.current_animation = new_animation
        player.animation_frame = 1
        player.animation_timer = 0
    end

    -- Update animation frame
    update_player_animation()

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
    local offset = player.width/2
    local player_x_center = player.x + (player.width/2)
    local player_y_center = player.y + (player.height/2)
    local left_screen_position = player.face*MAP_SIZE
    if x_dir != 0 or y_dir != 0 then
        direction = -1
        edge_offset = player.y
        if player_y_center - offset <= 0 and y_dir < 0 then
            direction = directions.NORTH
            edge_offset = player.x - left_screen_position
        elseif player_y_center + offset >= MAP_SIZE and y_dir > 0 then
            direction = directions.SOUTH
            edge_offset = player.x - left_screen_position
        elseif player_x_center + offset >= (player.face+1)*MAP_SIZE and x_dir > 0 then
            direction = directions.EAST
        elseif player_x_center - offset <= player.face*MAP_SIZE and x_dir < 0 then
            direction = directions.WEST
        end

        if direction != -1 then traverse(direction, edge_offset) end
    end
end

function update_player_animation()
    local anim = player_animations[player.current_animation]
    if not anim then return end
    
    player.animation_timer += 1
    local speed = anim.speed or 8
    
    if player.animation_timer >= speed then
        player.animation_timer = 0
        player.animation_frame += 1
        if player.animation_frame > #anim.frames then
            player.animation_frame = 1
        end
    end
    
    -- Set current sprite
    player.sprite = anim.frames[player.animation_frame]
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

    for k, v in pairs(buttons) do
        rotated_v = {}
        for k, pos in pairs(v) do
            rotated_v[k] =
                    (angle == 90 and {pos[1], 15 - pos[3], pos[2]}) or 
                    (angle == 180 and {pos[1], 15 - pos[2], 15 - pos[3]}) or 
                    (angle == -90 and {pos[1], pos[3], 15 - pos[2]}) or {}
        end
        buttons[k] = rotated_v
    end
end


function collect_static_boxes(face)
    local occupied_positions = {} -- Track occupied positions
    for x = 0, MAP_SIZE_IN_TILES - 1 do
        for y = 0, MAP_SIZE_IN_TILES - 1 do
            local box_tile = mget(face * MAP_SIZE_IN_TILES + x, MAP_SIZE_IN_TILES + y)
            if fget(box_tile, 1) then
                add_box_to_draw(x * 8, y * 8, box_tile, 0, occupied_positions)
            end
        end
    end
end

-- Move boxes according to the gravity of the current face.
function update_boxes(face)
    boxes_to_draw = {} -- Clear the array first
    local occupied_positions = {} -- Track occupied positions to prevent duplicates
    local opposite_face = get_opposite_face(face)
    
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
                    BOX_DESTINATION = "cur_face: "..face.." pot_face: "..v[1].." res: "..face_to_place
                    
                    
                    if mget(face_to_place * MAP_SIZE_IN_TILES + new_pos[1], new_pos[2]) == S.BUTTON.TILE then
                        BOX_POS = ""..face_to_place.." "..new_pos[1].." "..new_pos[2]
                        mset(face_to_place * MAP_SIZE_IN_TILES + new_pos[1], new_pos[2], S.BOX.TILE)
                        if escaped_screen then
                            local additional_faces = {}
                            if falling_direction % 2 == 1 then
                                -- mset(v[1] * MAP_SIZE_IN_TILES + 15 - new_pos[1], new_pos[2], S.BOX.TILE)
                                add(additional_faces, {v[1], v[2], 15 - new_pos[1], new_pos[2]})
                                if new_pos[2] == 0 then
                                    local temp = connections[face + 1][(directions.NORTH - GLOBAL_ROTATION) % 4 + 1]
                                    add(additional_faces, {temp[1], temp[2], new_pos[1], 15 -new_pos[2]})
                                elseif new_pos[2] == 15 then
                                    local temp = connections[face + 1][(directions.WEST - GLOBAL_ROTATION) % 4 + 1]
                                    add(additional_faces, {temp[1], temp[2], new_pos[1], new_pos[2]})
                                end
                            else
                                -- mset(v[1] * MAP_SIZE_IN_TILES + new_pos[1], 15 - new_pos[2], S.BOX.TILE)
                                add(additional_faces, {v[1], v[2], new_pos[1], 15 - new_pos[2]})
                                if new_pos[1] == 0 then
                                    local temp = connections[face + 1][(directions.SOUTH - GLOBAL_ROTATION) % 4 + 1]
                                    add(additional_faces, {temp[1], temp[2], new_pos[1], new_pos[2]})
                                elseif new_pos[1] == 15 then
                                    local temp = connections[face + 1][(directions.NORTH - GLOBAL_ROTATION) % 4 + 1]
                                    add(additional_faces, {temp[1], temp[2], new_pos[1], new_pos[2]})
                                end
                            end
                            for k, val in pairs(additional_faces) do
                                local dir = (val[2] - GLOBAL_ROTATION) % 4
                                local pos = {val[3], val[4]}
                                        -- (dir == directions.NORTH and {val[3], 15 - val[4]}) or 
                                        -- (dir == directions.EAST and {val[3], val[4]}) or 
                                        -- (dir == directions.SOUTH and {val[3], val[4]}) or 
                                        -- (dir == directions.WEST and {15 - val[3], val[4]}) 
                                local rotated_pos = 
                                        (GLOBAL_ROTATION == 1 and {pos[2], 15 - pos[1]}) or 
                                        (GLOBAL_ROTATION == 2 and {15 - pos[1], 15 - pos[2]}) or
                                        (GLOBAL_ROTATION == 3 and {15 - pos[2], pos[1]}) or pos
                                mset(val[1] * MAP_SIZE_IN_TILES + rotated_pos[1], rotated_pos[2], S.BOX.TILE)
                            end
                        end
                        for k, val in pairs(buttons) do
                            if val[1][1] == face_to_place and val[1][2] == new_pos[1] and val[1][3] == new_pos[2] do
                                BOX_POS = BOX_POS.." success"
                                for i = 2,#val do
                                    mset(val[i][1] * MAP_SIZE_IN_TILES + val[i][2], val[i][3], 0)
                                end
                            else BOX_POS = BOX_POS..val[1][1].." "..val[1][2].." "..val[1][3]
                            end
                        end
                    else
                        mset(face_to_place * MAP_SIZE_IN_TILES + new_pos[1], MAP_SIZE_IN_TILES + new_pos[2], box_tile)
                    end




                            -- local additional_faces = {}
                            -- if new_pos[1] == 0 then
                            --     add(additional_faces, connections[face + 1][(directions.WEST - GLOBAL_ROTATION) % 4 + 1])
                            -- end
                            -- if new_pos[1] == 15 then
                            --     add(additional_faces, connections[face + 1][(directions.EAST - GLOBAL_ROTATION) % 4 + 1])
                            -- end
                            -- if new_pos[2] == 0 then
                            --     add(additional_faces, connections[face + 1][(directions.NORTH - GLOBAL_ROTATION) % 4 + 1])
                            -- end
                            -- if new_pos[2] == 15 then
                            --     add(additional_faces, connections[face + 1][(directions.SOUTH - GLOBAL_ROTATION) % 4 + 1])
                            -- end
                            -- for k, val in pairs(additional_faces) do
                            --     local dir = (val[2] - GLOBAL_ROTATION) % 4
                            --     local pos = 
                            --             (dir == directions.NORTH and {new_pos[1], 15}) or 
                            --             (dir == directions.EAST and {0, new_pos[2]}) or 
                            --             (dir == directions.SOUTH and {new_pos[1], 0}) or 
                            --             (dir == directions.WEST and {15, new_pos[2]}) 
                            --     local rotated_pos =
                            --             (GLOBAL_ROTATION == 3 and {15 - pos[2], pos[1]}) or 
                            --             (GLOBAL_ROTATION == 2 and {15 - pos[1], 15 - pos[2]}) or 
                            --             (GLOBAL_ROTATION == 1 and {pos[2], 15 - pos[1]}) or pos
                            --     mset(val[1] * MAP_SIZE_IN_TILES + rotated_pos[1], rotated_pos[2], S.BOX.TILE)
                            -- end


                    
                    if escaped_screen then
                        add_box_to_draw(new_pos[1] * 8, new_pos[2] * 8, box_tile, fall_distance, occupied_positions)
                    end
                end
            end
        end
    end

    collect_static_boxes(face)
              
    for x = 0, MAP_SIZE_IN_TILES - 1 do
        for y = 0, MAP_SIZE_IN_TILES - 1 do
            local target_tile = mget(face * MAP_SIZE_IN_TILES + x, MAP_SIZE_IN_TILES + y)
            local box_tile = mget(opposite_face * MAP_SIZE_IN_TILES + x, MAP_SIZE_IN_TILES + y)
            if fget(box_tile, 1) and not fget(target_tile, 0) then
                mset(opposite_face * MAP_SIZE_IN_TILES + x, MAP_SIZE_IN_TILES + y, 0)
                mset(face * MAP_SIZE_IN_TILES + x, MAP_SIZE_IN_TILES + y, box_tile)
                add_box_to_draw(x * 8, y * 8, box_tile, MAP_SIZE_IN_TILES, occupied_positions)
            end
        end
    end
end

function get_opposite_face(face)
    if face == faces.BASE then return faces.TOP
    elseif face == faces.FRONT then return faces.BACK
    elseif face == faces.RIGHT then return faces.LEFT
    elseif face == faces.BACK then return faces.FRONT
    elseif face == faces.LEFT then return faces.RIGHT
    elseif face == faces.TOP then return faces.BASE
    end
end

function add_box_to_draw(x, y, tile, fall_height, occupied_positions)
    local pos_key = x..","..y -- Create a unique key for this position
    if not occupied_positions[pos_key] then
        occupied_positions[pos_key] = true
        add(boxes_to_draw, {
            x = x,
            y = y,
            tile = tile,
            fall_height = fall_height * 8
        })
    end
end


function _draw()
    cls()
    local map_x = player.face * MAP_SIZE_IN_TILES
    
    -- Automatically draw wall sprites for all tiles with collision flags
    draw_map_walls(map_x)
    draw_box_fall_shadow()
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
    print("Face: "..player.face, 0, 10, 12)
    print("Angle: "..GLOBAL_ROTATION, 0, 20, 12)
    print("Box pos: "..BOX_POS, 0, 30, 12)
end


function draw_box_fall_shadow ()
    for _, box in pairs(boxes_to_draw) do
        -- Draw a shadow circle under the box, smaller for higher falls (radius 1 at max, 4 just before landing)
        local shadow_max = 128
        local shadow_min_radius = 1
        local shadow_max_radius = 4
        local fall = min(box.fall_height, shadow_max)
        -- When fall=shadow_max, radius=1; when fall=0, radius=4
        local radius = shadow_max_radius - (shadow_max_radius - shadow_min_radius) * (fall / shadow_max)
        circfill(box.x + 3, box.y + 7, radius-1, 1) -- color 5 is dark gray
    end
end


function draw_box_fall_shadow ()
    for _, box in pairs(boxes_to_draw) do
        -- Draw a shadow circle under the box, smaller for higher falls (radius 1 at max, 4 just before landing)
        local shadow_max = 128
        local shadow_min_radius = 1
        local shadow_max_radius = 4
        local fall = min(box.fall_height, shadow_max)
        -- When fall=shadow_max, radius=1; when fall=0, radius=4
        local radius = shadow_max_radius - (shadow_max_radius - shadow_min_radius) * (fall / shadow_max)
        circfill(box.x + 3, box.y + 7, radius-1, 1) -- color 5 is dark gray
    end
end

function draw_boxes()
    for _, box in pairs(boxes_to_draw) do
        -- Ease out the fall for a smoother animation
        local fall_offset = box.fall_height
        if fall_offset > 0 then
            -- Use a quadratic ease-out for a more natural fall
            fall_offset = flr((fall_offset / 8) ^ 1.5) * 2
        end
        mapdrawtile(box.tile, box.x, box.y - fall_offset)
        if box.fall_height > 0 then
            box.fall_height = max(0, box.fall_height - max(1, flr(box.fall_height / 6)))
        end
    end
end

function draw_box_walls()
    for _, box in pairs(boxes_to_draw) do
        -- Match the wall's fall offset to the box
        local fall_offset = box.fall_height
        if fall_offset > 0 then
            fall_offset = flr((fall_offset / 8) ^ 1.5) * 2
        end
        mapdrawtile(wall_lookup[box.tile], box.x, box.y + 8 - fall_offset)
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
    local sprite_x = player.x - (player.face * MAP_SIZE)
    local sprite_y = player.y + 2
    
    -- Flip sprite horizontally if facing left
    if player.facing_x < 0 then
        spr(player.sprite, sprite_x, sprite_y, 1, 1, true, false)
    else
        spr(player.sprite, sprite_x, sprite_y)
    end
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
    [faces.BACK] = 42,
    [faces.LEFT] = 44,
    [faces.TOP] = 46,
}


--[[Function for traversing to another face.
    exit_direction: direction the character is exiting through.
    offset: how far from the edge is the character? Counting from the left on north/south and the top on east/west.
]]
function traverse(exit_direction, offset)
    local perspective_exit_direction = exit_direction - GLOBAL_ROTATION
    perspective_exit_direction = perspective_exit_direction % 4
    local new_pos = connections[player.face + 1][perspective_exit_direction + 1]
    update_map(player.face, new_pos[1])
    update_boxes(new_pos[1])

    player.face = new_pos[1]
    local new_dir = new_pos[2] + GLOBAL_ROTATION
    local player_offset = (exit_direction == directions.NORTH or exit_direction == directions.WEST) and player.width or 0
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