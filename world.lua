-- Enum for directions to avoid magic numbers.
directions = {NORTH = 1, EAST = 2, SOUTH = 3, WEST = 4}

-- Enum for cube faces to avoid magic numbers.
faces = {BASE = 1, FRONT = 2, RIGHT = 3, BACK = 4, LEFT = 5, TOP = 6}

-- List of connections between faces where connections[CURRENT_FACE][EXIT_DIRECTION] = {[NEW_FACE], [ENTRY_DIRECTION]}.
-- This means the pairs are sorted in exit direction north, east, south, west as in the directions object.

local connections = {
    {{faces.FRONT, directions.SOUTH}, {faces.RIGHT, directions.SOUTH}, {faces.BACK, directions.SOUTH}, {faces.LEFT, directions.SOUTH}},  -- BASE
    {{faces.TOP, directions.SOUTH}, {faces.RIGHT, directions.WEST}, {faces.BASE, directions.NORTH}, {faces.LEFT, directions.EAST}},      -- FRONT
    {{faces.TOP, directions.EAST}, {faces.BACK, directions.WEST}, {faces.BASE, directions.NORTH}, {faces.FRONT, directions.EAST}},       -- RIGHT
    {{faces.TOP, directions.NORTH}, {faces.LEFT, directions.WEST}, {faces.BASE, directions.NORTH}, {faces.RIGHT, directions.EAST}},      -- BACK
    {{faces.TOP, directions.WEST}, {faces.FRONT, directions.WEST}, {faces.BASE, directions.NORTH}, {faces.BACK, directions.EAST}},       -- LEFT
    {{faces.BACK, directions.NORTH}, {faces.RIGHT, directions.NORTH}, {faces.FRONT, directions.NORTH}, {faces.LEFT, directions.NORTH}}   -- TOP
}

--[[Function for traversing to another face.
    old_face: cube face the character is currently on.
    exit_direction: direction the character is exiting through.
    tile_offset: how far from the edge is the character? Counting from the left on north/south and the top on east/west.
]]
function traverse(old_face, exit_direction, tile_offset)
  new_location = connections[old_face][exit_direction]
  return new_location
end