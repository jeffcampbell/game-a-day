pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

-- mini quest: adventure exploration rpg
-- explore a dungeon, defeat enemies, find the exit

-- test infrastructure
testmode = false
test_log = {}
test_inputs = {}
test_input_idx = 0
test_frame_advanced = false

function _log(msg)
  if testmode then add(test_log, msg) end
end

function _capture()
  if testmode then add(test_log, "SCREEN:"..tostr(stat(0))) end
end

function test_input(b)
  if testmode then
    if not test_frame_advanced and test_input_idx < #test_inputs then
      test_input_idx += 1
      test_frame_advanced = true
    end
    local buttons = test_inputs[test_input_idx] or 0
    return band(buttons, shl(1, b)) and 1 or 0
  end
  return btn(b)
end

-- game state
state = "menu"
score = 0
level = 1
max_levels = 5
player_hp = 10
player_maxhp = 10
player_x = 2
player_y = 2
enemy_x = 5
enemy_y = 4
enemy_hp = 3
enemy_type = "normal"  -- "normal" or "boss"
enemy_maxhp = 3
has_key = false
combat_active = false
combat_turn = 0
message = ""
message_timer = 0
current_width = 14
current_height = 14
respawn_x = 3
respawn_y = 12
exit_x = 12
exit_y = 12
boss_move_pattern = 0  -- telegraphic boss movement

-- visual effects
shake_x = 0
shake_y = 0
shake_timer = 0
damage_flash_timer = 0
combat_flash_timer = 0
key_flash_timer = 0
state_transition_timer = 0

-- level data: 0=floor, 1=wall
-- level 1: maze (14x14)
level_data = {
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1},
  {1,0,0,0,0,0,0,1,0,0,0,0,0,1},
  {1,0,1,1,0,1,0,1,0,1,1,1,0,1},
  {1,0,0,0,0,1,0,0,0,0,0,1,0,1},
  {1,1,1,0,1,1,1,1,1,1,0,1,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,1,1,0,1,1,1,1,1,0,1,1,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,1,0,1,1,0,1,1,1,0,1,1,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,1,1,1,1,0,1,1,1,1,0,1,1},
  {1,0,0,0,0,0,0,0,0,0,1,0,0,1},
  {1,1,0,1,0,1,1,1,0,1,1,1,0,1},
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1}
}

-- level 2: boss arena (16x16)
level_data_2 = {
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,1,1,0,1,1,1,1,1,0,1,1,0,0,1},
  {1,0,1,1,0,1,1,1,1,1,0,1,1,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,1,1,1,0,1,1,1,1,0,1,1,1,0,1},
  {1,0,1,1,1,0,1,1,1,1,0,1,1,1,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,1,0,1,1,1,1,1,1,1,1,0,1,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,1,1,0,1,1,1,1,1,1,1,1,0,1,1,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
}

-- level 3: treasure vault (16x16)
level_data_3 = {
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
  {1,0,0,1,0,0,0,0,0,0,0,0,1,0,0,1},
  {1,0,0,1,0,1,1,1,1,1,0,0,1,0,0,1},
  {1,0,0,0,0,1,0,0,0,1,0,0,0,0,0,1},
  {1,0,1,1,0,1,0,1,0,1,0,1,1,1,0,1},
  {1,0,0,0,0,1,0,0,0,1,0,0,0,0,0,1},
  {1,1,0,1,1,1,1,0,1,1,1,0,1,1,1,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,1,1,0,1,1,1,1,1,1,0,1,1,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,1,0,1,1,1,0,1,1,1,0,1,1,0,1,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,1,1,1,0,1,1,1,0,1,1,1,1,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,1,0,1,1,1,1,0,1,1,1,0,1,1,1,1},
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
}

-- level 4: deep dungeon (16x16) - multiple enemies, patrol patterns
level_data_4 = {
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,1,1,1,0,1,0,1,0,1,1,1,0,0,1},
  {1,0,1,0,0,0,1,0,1,0,1,0,0,0,0,1},
  {1,0,1,0,1,1,1,0,1,0,1,0,1,1,1,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,1,0,1,1,1,1,1,1,0,1,1,1,0,1,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,1,1,1,0,1,1,1,0,1,1,1,1,1,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,1,0,1,1,0,1,0,1,1,1,0,1,0,1,1},
  {1,0,0,0,1,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,1,1,1,1,1,1,1,0,1,1,1,0,1,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,1,1,1,0,1,1,1,0,1,1,1,1,0,1},
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
}

-- level 5: boss chamber (16x16) - arena with boss
level_data_5 = {
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,1,0,1,1,0,0,0,1,1,0,1,0,0,1},
  {1,0,1,0,1,1,0,0,0,1,1,0,1,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,1,0,1,1,1,1,1,1,1,1,1,0,1,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,1,1,1,1,0,1,1,0,1,1,1,1,0,1},
  {1,0,1,1,1,1,0,1,1,0,1,1,1,1,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,1,0,1,0,1,1,1,1,1,1,0,1,1,1,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,1,1,1,1,0,0,0,1,1,1,1,0,1,1},
  {1,0,1,1,1,1,0,0,0,1,1,1,1,0,1,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
}

function _init()
  _log("init:start")
  music(0)  -- start background music
end

function _update()
  test_frame_advanced = false

  if state == "menu" then update_menu()
  elseif state == "play" then update_play()
  elseif state == "gameover" then update_gameover()
  end

  if message_timer > 0 then
    message_timer -= 1
  end

  -- update visual effects
  if shake_timer > 0 then
    shake_timer -= 1
    shake_x = (rnd(2) - 1) * 2
    shake_y = (rnd(2) - 1) * 2
  else
    shake_x = 0
    shake_y = 0
  end

  if damage_flash_timer > 0 then
    damage_flash_timer -= 1
  end

  if combat_flash_timer > 0 then
    combat_flash_timer -= 1
  end

  if key_flash_timer > 0 then
    key_flash_timer -= 1
  end

  if state_transition_timer > 0 then
    state_transition_timer -= 1
  end
end

function update_menu()
  if test_input(4) > 0 or btnp(4) > 0 then
    sfx(0)  -- menu select sound
    _log("state:play")
    state = "play"
    score = 0
    player_hp = 10
    has_key = false
    combat_active = false
    state_transition_timer = 15
    setup_level(level)
    message = "level "..level..": defeat the beast!"
    message_timer = 60
  end
end

function setup_level(lv)
  _log("level:"..lv)
  boss_move_pattern = 0
  if lv == 1 then
    current_width = 14
    current_height = 14
    player_x = 2
    player_y = 2
    enemy_x = 5
    enemy_y = 4
    enemy_hp = 3
    enemy_maxhp = 3
    enemy_type = "normal"
    exit_x = 12
    exit_y = 12
    respawn_x = 3
    respawn_y = 12
  elseif lv == 2 then
    current_width = 16
    current_height = 16
    player_x = 2
    player_y = 2
    enemy_x = 13
    enemy_y = 2
    enemy_hp = 5
    enemy_maxhp = 5
    enemy_type = "normal"
    exit_x = 13
    exit_y = 14
    respawn_x = 2
    respawn_y = 12
  elseif lv == 3 then
    current_width = 16
    current_height = 16
    player_x = 2
    player_y = 2
    enemy_x = 12
    enemy_y = 12
    enemy_hp = 4
    enemy_maxhp = 4
    enemy_type = "normal"
    exit_x = 13
    exit_y = 14
    respawn_x = 2
    respawn_y = 12
  elseif lv == 4 then
    current_width = 16
    current_height = 16
    player_x = 2
    player_y = 2
    enemy_x = 8
    enemy_y = 5
    enemy_hp = 6
    enemy_maxhp = 6
    enemy_type = "normal"
    exit_x = 13
    exit_y = 14
    respawn_x = 2
    respawn_y = 12
    _log("enemies:aggressive")
  else  -- lv == 5 (boss)
    current_width = 16
    current_height = 16
    player_x = 2
    player_y = 2
    enemy_x = 8
    enemy_y = 8
    enemy_hp = 4
    enemy_maxhp = 4
    enemy_type = "boss"
    exit_x = 13
    exit_y = 14
    respawn_x = 2
    respawn_y = 12
    _log("boss:encounter")
  end
end

function update_play()
  local old_x = player_x
  local old_y = player_y

  -- player movement
  if test_input(0) > 0 or btn(0) > 0 then player_x -= 1 end
  if test_input(1) > 0 or btn(1) > 0 then player_x += 1 end
  if test_input(2) > 0 or btn(2) > 0 then player_y -= 1 end
  if test_input(3) > 0 or btn(3) > 0 then player_y += 1 end

  -- clamp to bounds
  player_x = mid(1, player_x, current_width)
  player_y = mid(1, player_y, current_height)

  -- check if moved into wall
  if is_wall(player_x, player_y) then
    player_x = old_x
    player_y = old_y
  end

  -- check enemy encounter
  if player_x == enemy_x and player_y == enemy_y then
    if not combat_active then
      sfx(1)  -- enemy encounter sound
      _log("combat:start")
      combat_active = true
      combat_turn = 0
      message = "enemy appears!"
      message_timer = 40
      combat_flash_timer = 20
    end
  end

  -- combat
  if combat_active then
    combat_turn += 1

    -- player attack
    if test_input(4) > 0 or btnp(4) > 0 then
      sfx(2)  -- attack hit sound
      local dmg = 2 + rnd(2)
      enemy_hp -= dmg
      _log("attack:"..dmg)
      message = "hit for "..dmg.."!"
      message_timer = 40
      shake_timer = 5
      damage_flash_timer = 8

      if enemy_hp <= 0 then
        sfx(4)  -- victory/enemy defeated sound
        if enemy_type == "boss" then
          _log("boss:defeated")
          message = "boss defeated!"
          message_timer = 80
          score += 100
          -- boss drops health powerup
          player_hp = min(player_hp + 3, player_maxhp)
          _log("powerup:health")
          sfx(6)  -- special victory sound for boss
        else
          _log("enemy:defeated")
          message = "victory!"
          message_timer = 60
          score += 10
        end
        enemy_x = respawn_x
        enemy_y = respawn_y
        enemy_hp = enemy_maxhp
        combat_active = false
        has_key = true
        key_flash_timer = 30
      else
        -- enemy counter
        sfx(3)  -- enemy attack/player damage sound
        local enemy_dmg = 1 + rnd(2)
        player_hp -= enemy_dmg
        _log("enemy_attack:"..enemy_dmg)
        shake_timer = 5
        damage_flash_timer = 8

        if player_hp <= 0 then
          sfx(5)  -- gameover/lose sound
          _log("gameover:lose")
          state = "gameover"
          message = "you were defeated!"
          message_timer = 999
          state_transition_timer = 15
        end
      end
    end
  end

  -- check exit
  if has_key and player_x == exit_x and player_y == exit_y then
    sfx(6)  -- exit/level transition sound
    score += 50
    if level < max_levels then
      _log("level:complete")
      level += 1
      state = "menu"
      message = "level complete!"
      message_timer = 999
      state_transition_timer = 15
    else
      _log("gameover:win")
      _log("score:"..score)
      state = "gameover"
      message = "all levels cleared!"
      message_timer = 999
      state_transition_timer = 15
    end
  end

  -- boss movement pattern (telegraphic)
  if enemy_type == "boss" and combat_active then
    boss_move_pattern = (boss_move_pattern + 1) % 4
    if boss_move_pattern == 0 then
      enemy_y -= 1
      _log("boss:move_up")
    elseif boss_move_pattern == 1 then
      enemy_x -= 1
      _log("boss:move_left")
    elseif boss_move_pattern == 2 then
      enemy_y += 1
      _log("boss:move_down")
    else
      enemy_x += 1
      _log("boss:move_right")
    end
    -- keep boss in bounds
    enemy_x = mid(1, enemy_x, current_width)
    enemy_y = mid(1, enemy_y, current_height)
    if is_wall(enemy_x, enemy_y) then
      boss_move_pattern = (boss_move_pattern + 1) % 4
    end
  end
end

function update_gameover()
  if test_input(4) > 0 or btnp(4) > 0 then
    _log("state:menu")
    state = "menu"
    state_transition_timer = 15
  end
end

function is_wall(x, y)
  -- bounds check
  if x < 1 or x > current_width or y < 1 or y > current_height then return true end

  -- use level-specific data
  local level_data_ptr = level_data
  if level == 2 then
    level_data_ptr = level_data_2
  elseif level == 3 then
    level_data_ptr = level_data_3
  elseif level == 4 then
    level_data_ptr = level_data_4
  elseif level == 5 then
    level_data_ptr = level_data_5
  end

  -- check tile (1-indexed in lua, table is 1-indexed)
  if level_data_ptr[y] and level_data_ptr[y][x] then
    return level_data_ptr[y][x] == 1
  end
  return true
end

function draw_hp_bar(x, y)
  local bar_width = 30
  local hp_ratio = player_hp / player_maxhp
  local bar_fill = flr(bar_width * hp_ratio)

  -- background
  rectfill(x, y, x + bar_width, y + 4, 1)

  -- hp bar (with color based on health)
  local bar_col = 11
  if player_hp < player_maxhp / 3 then
    bar_col = 8
  elseif player_hp < player_maxhp / 2 then
    bar_col = 9
  end
  rectfill(x + 1, y + 1, x + bar_fill, y + 3, bar_col)

  -- border
  rect(x, y, x + bar_width, y + 4, 7)
end

function _draw()
  cls(1)

  if state == "menu" then draw_menu()
  elseif state == "play" then draw_play()
  elseif state == "gameover" then draw_gameover()
  end
end

function draw_menu()
  cls(1)

  print("mini quest", 40, 20, 7)
  print("level "..level.." / "..max_levels, 38, 35, 10)
  print("explore dungeon", 20, 50, 7)
  if level == 5 then
    print("defeat the boss!", 20, 60, 8)
  else
    print("defeat enemy", 25, 60, 7)
  end
  print("find exit", 30, 70, 7)
  print("press z to start", 18, 95, 7)
end

function draw_play()
  -- apply screen shake
  camera(shake_x, shake_y)

  -- draw dungeon based on current level size
  local tile_size = 4  -- smaller tiles for larger dungeons
  if current_width > 14 then
    tile_size = 3
  end

  for y = 1, current_height do
    for x = 1, current_width do
      local sx = 8 + x * tile_size
      local sy = 8 + y * tile_size
      if is_wall(x, y) then
        rectfill(sx, sy, sx+tile_size-2, sy+tile_size-2, 5)
      else
        rectfill(sx, sy, sx+tile_size-2, sy+tile_size-2, 1)
      end
    end
  end

  -- draw exit marker
  local exit_sx = 8 + exit_x * tile_size + tile_size/2
  local exit_sy = 8 + exit_y * tile_size + tile_size/2
  if has_key then
    circfill(exit_sx, exit_sy, 2, 10)
  else
    circfill(exit_sx, exit_sy, 2, 6)
  end

  -- draw key if found (with flash effect)
  if has_key then
    local key_col = 7
    if key_flash_timer > 0 and (flr(key_flash_timer / 3) % 2) == 0 then
      key_col = 10
    end
    print("*", exit_sx-2, exit_sy-4, key_col)
  end

  -- draw enemy (with damage flash and combat entrance flash)
  local enemy_sx = 8 + enemy_x * tile_size
  local enemy_sy = 8 + enemy_y * tile_size
  local player_sx = 8 + player_x * tile_size
  local player_sy = 8 + player_y * tile_size

  local enemy_col = 8
  if damage_flash_timer > 0 then
    enemy_col = 10
  end

  if enemy_type == "boss" then
    -- draw boss as larger shape
    if combat_active then
      if damage_flash_timer > 0 then
        rectfill(enemy_sx, enemy_sy, enemy_sx + tile_size - 1, enemy_sy + tile_size - 1, 10)
      else
        rectfill(enemy_sx, enemy_sy, enemy_sx + tile_size - 1, enemy_sy + tile_size - 1, 14)
      end
      -- boss aura
      if combat_flash_timer > 0 and (flr(combat_flash_timer / 3) % 2) == 0 then
        rect(enemy_sx - 1, enemy_sy - 1, enemy_sx + tile_size, enemy_sy + tile_size, 8)
      end
    end
  else
    -- draw normal enemy
    if combat_active then
      if damage_flash_timer > 0 then
        circfill(enemy_sx + tile_size/2, enemy_sy + tile_size/2, 2, 10)
      else
        circfill(enemy_sx + tile_size/2, enemy_sy + tile_size/2, 2, 8)
      end
      -- flash border when combat starts
      if combat_flash_timer > 0 and (flr(combat_flash_timer / 3) % 2) == 0 then
        circ(enemy_sx + tile_size/2, enemy_sy + tile_size/2, 3, 8)
      end
    end
    circfill(enemy_sx + tile_size/2, enemy_sy + tile_size/2, 1, enemy_col)
  end

  -- draw player
  local player_col = 11
  if damage_flash_timer > 0 then
    player_col = 8
  end
  rectfill(player_sx + 1, player_sy + 1, player_sx + tile_size - 2, player_sy + tile_size - 2, player_col)

  -- reset camera
  camera(0, 0)

  -- draw ui
  print("hp:"..player_hp.."/"..player_maxhp, 2, 2, 7)
  draw_hp_bar(26, 2)
  print("score:"..score, 2, 10, 7)
  if has_key then
    print("key", 100, 2, 10)
  end

  -- draw message
  if message_timer > 0 then
    print(message, 30, 120, 7)
  end

  -- draw combat indicator
  if combat_active and (flr(t() * 4) % 2) == 0 then
    print("[combat]", 5, 120, 8)
  end
end

function draw_gameover()
  local text_col = 7
  local bg_col = 0

  -- flash effect on gameover with proper text contrast
  if state_transition_timer > 0 and (flr(state_transition_timer / 2) % 2) == 0 then
    bg_col = 10
    text_col = 0  -- black text on light blue background
  end

  cls(bg_col)

  if score > 50 then
    print("you won!", 50, 30, text_col)
    print("final score: "..score, 30, 50, text_col)
  else
    print("game over", 45, 30, text_col)
    print("final score: "..score, 30, 50, text_col)
  end
  print("press z to return", 20, 100, text_col)
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001b5511b5311b5111b4f11b4d11b4b11b4911b4711b4511b4311b4111b3f11b3d00000000000000000000000000000000000000000000000000000000
00100000355533555035550255502555015550055500555005550055500555005550055500555005550055500000000000000000000000000000000000000000000
002000001d5401d5201d5001d4e01d4c01d4a01d4801d4601d4401d4201d4001d3e01d3c0000000000000000000000000000000000000000000000000000000000
011000001e5101e4f01e4d01e4b01e4901e4701e4501e4301e4101e3f01e3d01e3b01e3901e3701e3501e3301e3101e2f01e2d01e2b01e2901e2701e2501e2301
00100000155101550115511551015510155100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000002a5502a5402a5302a5202a5102a5002a4f02a4e02a4d02a4c02a4b02a4a0000000000000000000000000000000000000000000000000000000000000

__music__
00 00000000
01 00000000
02 00000000
03 00000000

__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
