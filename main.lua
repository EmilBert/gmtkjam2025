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

MAP_SIZE_IN_TILES = 16
MAP_SIZE = MAP_SIZE_IN_TILES * 8

function _update()
   player_update()
end

function is_solid_at(px, py)
    local tile_x = flr(px / 8) -- pga spritesen är 8x8
    local tile_y = flr(py / 8)
    return fget(mget(tile_x, tile_y), 0)
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

    local next_x = player.x + x_dir * player.speed
    local next_y = player.y + y_dir * player.speed

    -- kolla kollision i x-led
    if x_dir != 0 then
        local test_x = next_x + (x_dir > 0 and player.width-1 or 0)
        if not is_solid_at(test_x, player.y) and not is_solid_at(test_x, player.y + player.height-1) then
            player.x = next_x
        end
    end

    -- kolla kollision i y-led
    if y_dir != 0 then
        local test_y = next_y + (y_dir > 0 and player.height-1 or 0)
        if not is_solid_at(player.x, test_y) and not is_solid_at(player.x + player.width-1, test_y) then
            player.y = next_y
        end
    end

    -- Check room transition
    local offset = player.width
    player_x_center = player.x + (player.width/2)
    player_y_center = player.y + (player.height/2)
    if not in_rect(player_x_center, player_y_center, player.face*MAP_SIZE + offset, offset, MAP_SIZE - (offset*2), MAP_SIZE - (offset*2)) then
        direction = directions.WEST
        edge_offset = player.y
        if player_y_center - offset < 0 then
            direction = directions.NORTH
            edge_offset = player.x - player.face*MAP_SIZE
        elseif player_y_center + offset > MAP_SIZE then
            direction = directions.SOUTH
            edge_offset = player.x - player.face*MAP_SIZE
        elseif player_x_center + offset > (player.face+1)*MAP_SIZE then
            direction = directions.EAST
        end

        traverse(direction, edge_offset)
    end
end

function _draw()
    cls()
    map(player.face * MAP_SIZE_IN_TILES, 0, 0, 0, MAP_SIZE_IN_TILES, MAP_SIZE_IN_TILES) -- ritar kartan
    spr(player.sprite, player.x - (player.face*MAP_SIZE), player.y)
    -- draw the player's pixel position
    print("Face: "..player.face, 0, 10, 2)
    print("X: "..player.x, 0, 20, 2)
    print("Y: "..player.y, 0, 30, 2)
end

-- Map assets

-- Enum for directions to avoid magic numbers.
directions = {NORTH = 1, EAST = 2, SOUTH = 3, WEST = 4}

-- Enum for cube faces to avoid magic numbers.
faces = {BASE = 0, FRONT = 1, RIGHT = 2, BACK = 3, LEFT = 4, TOP = 5}

-- List of connections between faces where connections[CURRENT_FACE][EXIT_DIRECTION] = {[NEW_FACE], [ENTRY_DIRECTION]}.
-- This means the pairs are sorted in exit direction north, east, south, west as in the directions object.

connections = { -- TODO (RobotGandhi): Double check these, could be incorrect. Also very disorienting, even if correct.
    {{faces.FRONT, directions.SOUTH}, {faces.RIGHT, directions.SOUTH}, {faces.BACK, directions.SOUTH}, {faces.LEFT, directions.SOUTH}},  -- BASE
    {{faces.TOP, directions.SOUTH}, {faces.RIGHT, directions.WEST}, {faces.BASE, directions.NORTH}, {faces.LEFT, directions.EAST}},      -- FRONT
    {{faces.TOP, directions.EAST}, {faces.BACK, directions.WEST}, {faces.BASE, directions.EAST}, {faces.FRONT, directions.EAST}},       -- RIGHT
    {{faces.TOP, directions.NORTH}, {faces.LEFT, directions.WEST}, {faces.BASE, directions.SOUTH}, {faces.RIGHT, directions.EAST}},      -- BACK
    {{faces.TOP, directions.WEST}, {faces.FRONT, directions.WEST}, {faces.BASE, directions.WEST}, {faces.BACK, directions.EAST}},       -- LEFT
    {{faces.BACK, directions.NORTH}, {faces.RIGHT, directions.NORTH}, {faces.FRONT, directions.NORTH}, {faces.LEFT, directions.NORTH}}   -- TOP
}

--[[Function for traversing to another face.
    exit_direction: direction the character is exiting through.
    offset: how far from the edge is the character? Counting from the left on north/south and the top on east/west.
]]
function traverse(exit_direction, offset)
    local new_pos = connections[player.face + 1][exit_direction]
    player.face = new_pos[1]
    player.x = player.face*MAP_SIZE
    if new_pos[2] == directions.NORTH then
        player.x += offset
        player.y = player.height*2
    elseif new_pos[2] == directions.EAST then
        player.x += MAP_SIZE - (player.width*2)
        player.y = offset
    elseif new_pos[2] == directions.SOUTH then
        player.x += offset
        player.y = MAP_SIZE - (player.height*2)
    elseif new_pos[2] == directions.WEST then
        player.x += player.width*2
        player.y = offset
    end
    -- player.x += ((new_pos[2] == directions.EAST and MAP_SIZE - (player.width*2)) or (new_pos[2] == directions.WEST and player.width*2) or x_offset)
    -- player.y = ((new_pos[2] == directions.SOUTH and MAP_SIZE - (player.height*2)) or (new_pos[2] == directions.NORTH and player.height*2) or player.y)
end