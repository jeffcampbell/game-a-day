pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- DICE DUELER: Turn-Based Combat RPG
-- Roll a die to generate actions: attack, defend, heal, critical

-- test infrastructure
testmode = false
test_log = {}
test_inputs = {}
test_input_idx = 0

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

-- game state
state = "menu"
difficulty = "normal"
player_hp = 100
player_max_hp = 100
player_def = 0
enemy_num = 1
enemy_hp = 30
enemy_max_hp = 30
turn_count = 0
message = ""
message_timer = 0
roll_result = 0
action_chosen = ""
enemy_names = {"goblin", "orc", "dragon"}
enemy_hp_values = {30, 50, 100}
difficulty_mults = {easy=0.7, normal=1.0, hard=1.3}
diff_mult = 1.0

-- game mechanics
function player_attack()
  local damage = 20 + rnd(10)
  damage = flr(damage * diff_mult)
  enemy_hp -= damage
  _log("attack:"..damage)
  sfx(0)
  show_message("player attacks for "..damage.."!")
end

function player_defend()
  player_def = 15
  _log("defend")
  sfx(1)
  show_message("player defends!")
end

function player_heal()
  local heal = 25
  player_hp = min(player_hp + heal, player_max_hp)
  _log("heal:"..heal)
  sfx(2)
  show_message("player heals "..heal.."!")
end

function player_critical()
  local damage = 50 + rnd(20)
  damage = flr(damage * diff_mult)
  enemy_hp -= damage
  _log("critical:"..damage)
  sfx(0)
  sfx(3)
  show_message("critical hit for "..damage.."!")
end

function enemy_attack()
  local damage = 15 + rnd(8)
  damage = flr(damage * diff_mult)
  if player_def > 0 then
    damage = max(1, flr(damage / 2))
    player_def -= 5
  end
  player_hp -= damage
  _log("enemy_attack:"..damage)
  sfx(4)
  show_message(enemy_names[enemy_num].." attacks for "..damage.."!")
end

function show_message(msg)
  message = msg
  message_timer = 30
end

-- state functions
function update_menu()
  if btnp(4) or btnp(5) then
    _log("state:difficulty_select")
    state = "difficulty_select"
  end
end

function draw_menu()
  cls(0)
  print("dice dueler", 40, 20, 7)
  print("a turn-based battle game", 20, 40, 6)
  print("press z to start", 30, 80, 3)
end

function update_difficulty_select()
  local old_diff = difficulty
  if btnp(0) then
    difficulty = "easy"
  elseif btnp(1) then
    difficulty = "normal"
  elseif btnp(2) then
    difficulty = "hard"
  end

  if difficulty != old_diff then
    diff_mult = difficulty_mults[difficulty]
    _log("difficulty:"..difficulty)
  end

  if btnp(4) or btnp(5) then
    _log("state:play")
    state = "play"
    init_battle()
  end
end

function draw_difficulty_select()
  cls(0)
  print("select difficulty", 30, 20, 7)
  local c_e = difficulty == "easy" and 3 or 6
  local c_n = difficulty == "normal" and 3 or 6
  local c_h = difficulty == "hard" and 3 or 6
  print("left: easy", 20, 40, c_e)
  print("right: hard", 20, 55, c_h)
  print("normal (default)", 15, 70, c_n)
  print("press z to battle", 25, 100, 3)
end

function init_battle()
  player_hp = 100
  player_max_hp = 100
  player_def = 0
  enemy_num = 1
  enemy_hp = flr(enemy_hp_values[enemy_num] * diff_mult)
  enemy_max_hp = enemy_hp
  turn_count = 0
  action_chosen = ""
  roll_result = 0
  message = ""
end

function update_play()
  if roll_result == 0 then
    if btnp(4) or btnp(5) then
      roll_result = 1 + flr(rnd(10))
      _log("roll:"..roll_result)
      message = "rolled "..roll_result.."!"
      message_timer = 20
    end
  else
    if btnp(0) then
      action_chosen = "attack"
    elseif btnp(1) then
      action_chosen = "defend"
    elseif btnp(2) then
      action_chosen = "heal"
    elseif btnp(3) then
      action_chosen = "critical"
    end

    if action_chosen != "" then
      resolve_turn()
      roll_result = 0
      action_chosen = ""
    end
  end

  if message_timer > 0 then
    message_timer -= 1
  end

  if player_hp <= 0 then
    _log("state:gameover")
    _log("gameover:lose")
    state = "gameover"
  elseif enemy_hp <= 0 then
    _log("enemy_defeated:"..enemy_num)
    if enemy_num >= 3 then
      _log("state:gameover")
      _log("gameover:win")
      state = "gameover"
    else
      enemy_num += 1
      enemy_hp = flr(enemy_hp_values[enemy_num] * diff_mult)
      enemy_max_hp = enemy_hp
      player_def = 0
      roll_result = 0
      message = "next enemy!"
      message_timer = 40
    end
  end
end

function resolve_turn()
  turn_count += 1
  _log("turn:"..turn_count)

  if action_chosen == "attack" then
    player_attack()
  elseif action_chosen == "defend" then
    player_defend()
  elseif action_chosen == "heal" then
    player_heal()
  elseif action_chosen == "critical" then
    player_critical()
  end

  if enemy_hp > 0 then
    enemy_attack()
  end
end

function draw_play()
  cls(0)
  -- draw player
  print("player: "..player_hp.."/"..player_max_hp, 5, 10, 3)
  rectfill(5, 20, 40, 25, 2)
  rectfill(5, 20, 5 + (35 * player_hp / player_max_hp), 25, 3)

  -- draw enemy
  print(enemy_names[enemy_num]..": "..enemy_hp.."/"..enemy_max_hp, 70, 10, 8)
  rectfill(70, 20, 105, 25, 5)
  rectfill(70, 20, 70 + (35 * enemy_hp / enemy_max_hp), 25, 8)

  -- draw actions
  if roll_result == 0 then
    print("press z to roll die", 20, 50, 7)
  else
    print("rolled: "..roll_result, 5, 45, 3)
    print("choose action:", 5, 55, 7)
    print("left: attack", 5, 65, 3)
    print("right: defend", 5, 75, 3)
    print("up: heal", 5, 85, 3)
    print("down: critical", 5, 95, 3)
  end

  -- draw message
  if message_timer > 0 then
    print(message, 10, 115, 7)
  end
end

function update_gameover()
  if btnp(4) or btnp(5) then
    _log("state:menu")
    state = "menu"
  end
end

function draw_gameover()
  cls(0)
  if player_hp <= 0 then
    print("you lost!", 50, 30, 8)
    print("enemy won!", 45, 45, 8)
  else
    print("you won!", 50, 30, 3)
    print("defeated all enemies!", 25, 45, 3)
  end
  print("press z to menu", 30, 100, 7)
end

function _update()
  if state == "menu" then update_menu()
  elseif state == "difficulty_select" then update_difficulty_select()
  elseif state == "play" then update_play()
  elseif state == "gameover" then update_gameover()
  end
end

function _draw()
  if state == "menu" then draw_menu()
  elseif state == "difficulty_select" then draw_difficulty_select()
  elseif state == "play" then draw_play()
  elseif state == "gameover" then draw_gameover()
  end
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
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
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
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
__sfx__
010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
