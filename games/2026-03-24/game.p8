pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- tile tactics: turn-based strategy game
-- player controls a unit on an 8x8 grid, defeat all enemies to win

-- test infrastructure
testmode = false
test_log = {}
test_inputs = {}
test_input_idx = 0
testmode_curr_input = 0
testmode_prev_input = 0

function _log(msg)
  if testmode then add(test_log, msg) end
end

function _capture()
  if testmode then add(test_log, "SCREEN:"..tostr(stat(0))) end
end

function test_input(b)
  if testmode and test_input_idx < #test_inputs then
    test_input_idx += 1
    return test_inputs[test_input_idx] or 0
  end
  return btn()
end

function read_input()
  testmode_prev_input = testmode_curr_input
  if testmode and test_input_idx < #test_inputs then
    test_input_idx += 1
    testmode_curr_input = test_inputs[test_input_idx] or 0
  else
    testmode_curr_input = btn()
  end
end

function test_btn(b)
  return (testmode_curr_input & (1 << b)) ~= 0
end

function test_btnp(b)
  local curr = test_btn(b)
  local prev = (testmode_prev_input & (1 << b)) ~= 0
  return curr and not prev
end

-- game state
state = "menu"
player = {x=1, y=1, hp=3}
enemies = {}
turn_count = 0
selected_x, selected_y = 1, 1
message = ""
message_timer = 0
difficulty = 1  -- 1=easy, 2=normal, 3=hard
score = 0
difficulty_select = 2  -- currently selected difficulty in menu

-- combat system
attack_mode = 1  -- 1=normal (1 dmg), 2=power (2 dmg, costs 2 hp)
combo_multiplier = 1.0
turns_without_damage = 0

-- animation and effects
screen_shake = 0
flash_timer = 0
flash_color = 0
animation_frame = 0

-- map: 0=walkable, 1=obstacle
function init_map()
  local m = {}
  for y=0,7 do
    m[y] = {}
    for x=0,7 do
      m[y][x] = 0
    end
  end
  -- add some obstacles
  m[2][2] = 1
  m[2][3] = 1
  m[5][5] = 1
  m[5][6] = 1
  return m
end

function init_enemies()
  local e = {}
  if difficulty == 1 then  -- easy: 1 standard
    add(e, {x=6, y=0, hp=1, type=1, move_counter=0})
  elseif difficulty == 2 then  -- normal: 1 scout + 2 standard
    add(e, {x=6, y=0, hp=1, type=2, move_counter=0})  -- scout
    add(e, {x=7, y=3, hp=1, type=1, move_counter=0})  -- standard
    add(e, {x=3, y=6, hp=1, type=1, move_counter=0})  -- standard
  else  -- hard: 1 tank + 1 scout + 2 standard
    add(e, {x=6, y=0, hp=3, type=3, move_counter=0})  -- tank
    add(e, {x=7, y=3, hp=1, type=2, move_counter=0})  -- scout
    add(e, {x=3, y=6, hp=1, type=1, move_counter=0})  -- standard
    add(e, {x=2, y=1, hp=1, type=1, move_counter=0})  -- standard
  end
  return e
end

function is_walkable(x, y, map)
  if x < 0 or x > 7 or y < 0 or y > 7 then
    return false
  end
  if map[y][x] == 1 then
    return false
  end
  -- check if enemy occupies tile
  for e in all(enemies) do
    if e.x == x and e.y == y then
      return false
    end
  end
  return true
end

function enemy_at(x, y)
  for e in all(enemies) do
    if e.x == x and e.y == y then
      return e
    end
  end
  return nil
end

function distance(x1, y1, x2, y2)
  return abs(x1-x2) + abs(y1-y2)
end

function move_towards_player(enemy, player, map)
  -- tanks move every 2 turns
  if enemy.type == 3 then
    enemy.move_counter += 1
    if enemy.move_counter < 2 then return end
    enemy.move_counter = 0
  end

  local best_dist = distance(enemy.x, enemy.y, player.x, player.y)
  local best_x, best_y = enemy.x, enemy.y

  -- try moving in each direction
  local moves = {{0,-1}, {0,1}, {-1,0}, {1,0}}
  for m in all(moves) do
    local nx, ny = enemy.x + m[1], enemy.y + m[2]
    if is_walkable(nx, ny, map) then
      local d = distance(nx, ny, player.x, player.y)
      if d < best_dist then
        best_dist = d
        best_x, best_y = nx, ny
      end
    end
  end

  enemy.x = best_x
  enemy.y = best_y

  -- scouts move twice per turn
  if enemy.type == 2 then
    local best_dist = distance(enemy.x, enemy.y, player.x, player.y)
    local best_x, best_y = enemy.x, enemy.y
    for m in all(moves) do
      local nx, ny = enemy.x + m[1], enemy.y + m[2]
      if is_walkable(nx, ny, map) then
        local d = distance(nx, ny, player.x, player.y)
        if d < best_dist then
          best_dist = d
          best_x, best_y = nx, ny
        end
      end
    end
    enemy.x = best_x
    enemy.y = best_y
  end
end

function update_menu()
  -- difficulty selection
  if test_btnp(0) then
    difficulty_select = max(1, difficulty_select - 1)
    sfx(1)
  elseif test_btnp(1) then
    difficulty_select = min(3, difficulty_select + 1)
    sfx(1)
  end

  if test_btnp(4) then  -- z button to start
    _log("state:play")
    _log("difficulty:"..difficulty_select)
    sfx(0)  -- menu confirm sound
    music(0)  -- start background music
    state = "play"
    difficulty = difficulty_select
    player = {x=1, y=1, hp=3}
    game_map = init_map()
    enemies = init_enemies()
    turn_count = 0
    score = 0
    selected_x, selected_y = 1, 1
    attack_mode = 1
    combo_multiplier = 1.0
    turns_without_damage = 0
  end
end

function update_play()
  -- update animations
  animation_frame = (animation_frame + 1) % 16

  -- decay effects
  if screen_shake > 0 then screen_shake -= 1 end
  if flash_timer > 0 then flash_timer -= 1 end

  -- player movement
  local old_x, old_y = player.x, player.y

  if test_btnp(0) and is_walkable(player.x-1, player.y, game_map) then
    player.x -= 1
    sfx(1)  -- movement sound
  elseif test_btnp(1) and is_walkable(player.x+1, player.y, game_map) then
    player.x += 1
    sfx(1)  -- movement sound
  elseif test_btnp(2) and is_walkable(player.x, player.y-1, game_map) then
    player.y -= 1
    sfx(1)  -- movement sound
  elseif test_btnp(3) and is_walkable(player.x, player.y+1, game_map) then
    player.y += 1
    sfx(1)  -- movement sound
  end

  -- attack mode toggle and attack
  if test_btnp(4) then  -- z button
    local target = nil
    for e in all(enemies) do
      if distance(player.x, player.y, e.x, e.y) == 1 then
        target = e
        break
      end
    end
    if target then
      -- execute attack with current mode
      local damage = 1
      local attack_type = "normal"
      if attack_mode == 2 then
        -- power attack costs 2 hp and does 2 damage
        if player.hp >= 2 then
          player.hp -= 2
          damage = 2
          attack_type = "power"
        end
      end

      target.hp -= damage
      sfx(2)  -- attack sound
      screen_shake = 3
      flash_timer = 4
      flash_color = 8
      _log("attack:"..attack_type)
      if target.hp <= 0 then
        del(enemies, target)
        _log("enemy_defeated")
        sfx(4)  -- damage/defeat sound
      end
    else
      -- no target adjacent - toggle attack mode
      attack_mode = 3 - attack_mode  -- toggle between 1 and 2
    end
  end

  if player.x ~= old_x or player.y ~= old_y then
    _log("move:"..player.x..","..player.y)
  end

  -- track damage before enemy turn
  local took_damage = false

  -- enemy turn
  for e in all(enemies) do
    if distance(e.x, e.y, player.x, player.y) == 1 then
      -- attack player
      player.hp -= 1
      took_damage = true
      sfx(3)  -- enemy attack sound
      flash_timer = 6
      flash_color = 8
      screen_shake = 4
      _log("enemy_hit")
    else
      -- move towards player
      move_towards_player(e, player, game_map)
    end
  end

  -- update combo multiplier
  if took_damage then
    turns_without_damage = 0
    combo_multiplier = 1.0
  else
    turns_without_damage += 1
    if turns_without_damage >= 3 then
      combo_multiplier = 2.0
    elseif turns_without_damage >= 1 then
      combo_multiplier = 1.5
    else
      combo_multiplier = 1.0
    end
  end

  turn_count += 1

  -- check win/lose
  if #enemies == 0 then
    _log("gameover:win")
    local base_score = 100 + (player.hp * 50) + (300 / max(1, turn_count))
    score = base_score * combo_multiplier
    _log("score:"..flr(score))
    _log("combo:"..combo_multiplier)
    sfx(5)  -- victory sound
    music()  -- stop music
    state = "gameover"
    message = "victory!"
  elseif player.hp <= 0 then
    _log("gameover:lose")
    sfx(5)  -- defeat sound
    music()  -- stop music
    state = "gameover"
    message = "defeated!"
  end
end

function update_gameover()
  if test_btnp(4) then  -- z to restart
    _log("state:menu")
    music()  -- stop music
    state = "menu"
  end
end

function _update()
  read_input()
  if state == "menu" then update_menu()
  elseif state == "play" then update_play()
  elseif state == "gameover" then update_gameover()
  end
end

function draw_menu()
  cls(0)

  -- title with styling
  print("========", 40, 10, 5)
  print("tile tactics", 38, 18, 11)
  print("========", 40, 26, 5)

  -- subtitle
  print("turn-based strategy", 28, 35, 7)
  print("defeat all enemies to win", 19, 45, 3)

  -- difficulty selection with styling
  local diff_colors = {3, 7, 8}
  local diff_names = {"easy", "normal", "hard"}
  local y_pos = 65

  print("select difficulty:", 26, 55, 7)

  for i=1,3 do
    local col = diff_colors[i]
    if i == difficulty_select then
      col = 11  -- highlight selected
      print("[>]", 33, y_pos, col)
    else
      print("[ ]", 33, y_pos, col)
    end
    print(diff_names[i], 46, y_pos, col)
    y_pos += 8
  end

  print("press z to start", 28, 110, 5)
end

function draw_grid(offset_x, offset_y, tile_size)
  for y=0,7 do
    for x=0,7 do
      local px = offset_x + x * tile_size
      local py = offset_y + y * tile_size

      -- draw tile background with enhanced checkerboard pattern
      local tile_color = 1
      if (x + y) % 2 == 0 then
        tile_color = 2
      end
      rectfill(px, py, px+tile_size-1, py+tile_size-1, tile_color)

      -- draw tile borders and effects
      if game_map[y][x] == 1 then
        -- obstacle sprite with depth shading
        spr(3, px, py)
        -- add subtle shadow
        line(px, py+tile_size-1, px+tile_size-1, py+tile_size-1, 0)
        line(px+tile_size-1, py, px+tile_size-1, py+tile_size-1, 0)
      else
        -- walkable tile border with subtle gradient
        rect(px, py, px+tile_size-1, py+tile_size-1, 5)
      end
    end
  end
end

function draw_attack_range(offset_x, offset_y, tile_size)
  -- show valid attack tiles with enhanced pulse effect
  for y=0,7 do
    for x=0,7 do
      if distance(player.x, player.y, x, y) == 1 then
        local px = offset_x + x * tile_size
        local py = offset_y + y * tile_size
        -- draw attack range indicator with double border pulse
        local pulse_phase = (animation_frame / 3) % 2
        local outer_col = pulse_phase < 1 and 11 or 7
        local inner_col = pulse_phase < 1 and 7 or 11
        rect(px, py, px+tile_size-1, py+tile_size-1, outer_col)
        rect(px+1, py+1, px+tile_size-2, py+tile_size-2, inner_col)
      end
    end
  end
end

function draw_units(offset_x, offset_y, tile_size)
  -- player with enhanced sprite and glow effect
  local px = offset_x + player.x * tile_size
  local py = offset_y + player.y * tile_size

  -- player enhanced glow with pulse
  local glow_size = 6 + (animation_frame % 8 > 4 and 1 or 0)
  circfill(px + 4, py + 4, glow_size, 13)
  circfill(px + 4, py + 4, glow_size - 1, 14)
  spr(0, px, py)

  -- player hp indicator with styled background
  if player.hp > 0 then
    rectfill(px + 2, py - 5, px + 13, py - 1, 0)
    rect(px + 1, py - 6, px + 14, py, 11)
    for i=1,player.hp do
      rectfill(px + 2 + (i-1)*3, py - 4, px + 3 + (i-1)*3, py - 2, 11)
    end
  end

  -- enemies with enhanced effects and type-specific sprites
  for e in all(enemies) do
    local ex = offset_x + e.x * tile_size
    local ey = offset_y + e.y * tile_size

    -- select sprite based on enemy type
    local enemy_sprite = 1  -- standard enemy
    if e.type == 2 then
      enemy_sprite = 2  -- scout: smaller/faster
    elseif e.type == 3 then
      enemy_sprite = 4  -- tank: heavier/stronger
    end

    -- enemy glow with threat pulse
    local threat = distance(e.x, e.y, player.x, player.y) == 1
    local glow_col = threat and 8 or 9

    -- glow color varies by enemy type
    if e.type == 2 then glow_col = threat and 7 or 10  -- scout: yellow
    elseif e.type == 3 then glow_col = threat and 8 or 5  -- tank: dark colors
    end

    local glow_r = threat and (5 + (animation_frame % 4 > 2 and 1 or 0)) or 5
    circfill(ex + 4, ey + 4, glow_r, glow_col)
    spr(enemy_sprite, ex, ey)

    -- enemy hp indicator with styled background
    if e.hp > 0 then
      rectfill(ex + 2, ey - 5, ex + 13, ey - 1, 0)
      rect(ex + 1, ey - 6, ex + 14, ey, 8)
      for i=1,e.hp do
        rectfill(ex + 2 + (i-1)*3, ey - 4, ex + 3 + (i-1)*3, ey - 2, 8)
      end
    end

    -- show threat range (where enemies can attack) with animation
    if threat then
      local tx = offset_x + e.x * tile_size
      local ty = offset_y + e.y * tile_size
      local pulse = (animation_frame / 3) % 2 < 1 and 8 or 9
      rect(tx, ty, tx+tile_size-1, ty+tile_size-1, pulse)
      rect(tx+1, ty+1, tx+tile_size-2, ty+tile_size-2, pulse)
    end
  end
end

function draw_play()
  cls(0)

  local tile_size = 10
  local offset_x = 8
  local offset_y = 8

  -- apply screen shake
  if screen_shake > 0 then
    offset_x += rnd(3) - 1
    offset_y += rnd(3) - 1
  end

  draw_grid(offset_x, offset_y, tile_size)
  draw_attack_range(offset_x, offset_y, tile_size)
  draw_units(offset_x, offset_y, tile_size)

  -- flash effect
  if flash_timer > 0 then
    local alpha = max(1, flash_timer / 3)
    rectfill(0, 0, 127, 127, flash_color)
  end

  -- ui background panel
  rectfill(0, 104, 127, 127, 1)
  rect(0, 103, 127, 127, 5)

  -- ui panel with better visuals
  local diff_col = 7
  if difficulty == 1 then diff_col = 3
  elseif difficulty == 3 then diff_col = 8 end

  -- draw ui elements with separators
  print("arrows:move", 2, 109, 7)
  local mode_text = attack_mode == 1 and "z:nrm" or "z:pow"
  local mode_col = attack_mode == 1 and 11 or 8
  print(mode_text, 60, 109, mode_col)

  print("turn:", 2, 119, 5)
  print(turn_count, 20, 119, 5)
  print("hp:", 30, 119, 11)
  print(player.hp, 40, 119, 11)
  print("foes:", 48, 119, 8)
  print(#enemies, 65, 119, 8)

  -- combo display
  local combo_text = "cx"..flr(combo_multiplier*10)/10
  local combo_col = 11
  if combo_multiplier >= 2.0 then combo_col = 3
  elseif combo_multiplier >= 1.5 then combo_col = 7
  end
  print(combo_text, 85, 119, combo_col)
end

function draw_gameover()
  cls(0)

  -- game over title
  print("=============", 34, 15, 5)
  print("   game over   ", 33, 23, 7)
  print("=============", 34, 31, 5)

  if message == "victory!" then
    print("*** victory! ***", 32, 45, 3)
    rectfill(25, 60, 102, 80, 1)
    rect(25, 60, 102, 80, 3)
    print("score:", 35, 65, 11)
    print(flr(score), 65, 65, 11)

    -- bonus display
    local bonus_text = "+"..max(50, player.hp * 50).." for hp"
    print(bonus_text, 30, 75, 3)
  else
    print("*** defeated! ***", 31, 45, 8)
    rectfill(20, 60, 107, 80, 1)
    rect(20, 60, 107, 80, 8)
    print("enemies remaining:", 25, 70, 8)
    print(#enemies, 85, 70, 8)
  end

  print("press z to menu", 30, 110, 5)
end

function _draw()
  if state == "menu" then draw_menu()
  elseif state == "play" then draw_play()
  elseif state == "gameover" then draw_gameover()
  end
end

__gfx__
003bbb00008cc800009aa9000777777705555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
033bb330088cc880099aa9907755555755555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33bbbb3388cccc8899aaaa9975333357588888500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3bb33bb38cc88cc89aa99aa9975333357588558500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33bbbb3388cccc8899aaaa9975333357588888500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
033bb330088cc880099aa9907755555755555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
003bbb00008cc80000099900077555557058008500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00033300008880000099990077777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__sfx__
000e000012350f3350123400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00080000153501335010350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600000c3500b35003350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00060000093500833006350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000071a3500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001e0007183501c3501535010350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
331c241c241c241c301c301c301c3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 00000000
06 06ffffff

__label__
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
