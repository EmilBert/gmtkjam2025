player = {
    x = 64,
    y = 64,
    dx = 0,
    dy = 0,
    width = 8,
    height = 8,
    sprite = 1,
    speed = 2,
}

function _update()
   player_update()
end

function is_solid_at(px, py)
    local tile_x = flr(px / 8) -- pga spritesen är 8x8
    local tile_y = flr(py / 8)
    return fget(mget(tile_x, tile_y), 0)
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
end

function _draw()
    cls()
    map(0, 0, 0, 0, 16, 16) -- ritar kartan
    spr(player.sprite, player.x, player.y)
    -- draw the player's pixel position
end
