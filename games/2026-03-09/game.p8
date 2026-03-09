pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- dungeon crawler rpg
-- turn-based combat, leveling, equipment, inventory

-- test infrastructure
testmode = false
test_log = {}
test_inputs = {}
test_input_idx = 0

function _log(msg)
  if testmode then add(test_log, msg) end
end

function test_input(b)
  if testmode and test_input_idx < #test_inputs then
    test_input_idx += 1
    return test_inputs[test_input_idx] or 0
  end
  return btn()
end

-- game state machine
state = "menu"
menu_sel = 0
prev_input = 0

-- equipment system
equipment_list = {
  {name="wooden sword", atk=1, def=0},
  {name="iron sword", atk=2, def=0},
  {name="steel sword", atk=3, def=0},
  {name="cloth armor", atk=0, def=1},
  {name="leather armor", atk=0, def=1},
  {name="steel armor", atk=0, def=2},
  {name="magic ring", atk=1, def=1}
}

-- player stats
player = {
  hp = 20,
  max_hp = 20,
  atk = 5,
  def = 2,
  level = 1,
  exp = 0,
  potions = 2,
  weapon = nil,
  armor = nil,
  inventory = {}
}

-- enemy stats
enemy = {
  hp = 8,
  max_hp = 8,
  atk = 3,
  def = 1,
  name = "goblin",
  is_boss = false
}

-- combat state
combat_log = {}
turn = 0
player_action = nil
player_act_val = 0
combat_over = false
player_won = false
combat_escaped = false
enemy_count = 0
boss_defeated = false
show_equip_menu = false
equip_menu_sel = 0

function _update()
  if state == "menu" then update_menu()
  elseif state == "play" then update_play()
  elseif state == "gameover" then update_gameover()
  end
end

function _draw()
  cls(1)
  if state == "menu" then draw_menu()
  elseif state == "play" then draw_play()
  elseif state == "gameover" then draw_gameover()
  end

  if show_equip_menu then
    draw_equip_menu()
  end
end

-- menu
function update_menu()
  local input = test_input()

  -- right (button 1)
  if (input & 2) > 0 and (prev_input & 2) == 0 then
    menu_sel = min(menu_sel + 1, 1)
  end
  -- left (button 0)
  if (input & 1) > 0 and (prev_input & 1) == 0 then
    menu_sel = max(menu_sel - 1, 0)
  end
  -- O button (button 4)
  if (input & 16) > 0 and (prev_input & 16) == 0 then
    if menu_sel == 0 then
      _log("state:play")
      state = "play"
      reset_combat()
    elseif menu_sel == 1 then
      _log("state:gameover")
      state = "gameover"
    end
  end

  prev_input = input
end

function draw_menu()
  print("dungeon crawler", 28, 20, 7)
  print("level "..player.level.." | hp "..player.hp.."/"..player.max_hp, 16, 40, 7)

  local y = 60
  local sel_col = 8
  if menu_sel == 0 then
    print(">", 50, y, sel_col)
    print("start quest", 60, y, 7)
  else
    print("start quest", 60, y, 5)
  end

  y += 12
  if menu_sel == 1 then
    print(">", 50, y, sel_col)
    print("quit", 60, y, 7)
  else
    print("quit", 60, y, 5)
  end

  print("z/c to select", 22, 110, 5)
end

-- play state
function update_play()
  local input = test_input()

  -- equipment menu
  if show_equip_menu then
    local max_menu = #player.inventory  -- position 1 to #inventory, plus 0 for unequip
    -- up (button 2)
    if (input & 4) > 0 and (prev_input & 4) == 0 then
      equip_menu_sel = max(0, equip_menu_sel - 1)
    end
    -- down (button 3)
    if (input & 8) > 0 and (prev_input & 8) == 0 then
      equip_menu_sel = min(max_menu, equip_menu_sel + 1)
    end
    -- O button (button 4) - equip/unequip
    if (input & 16) > 0 and (prev_input & 16) == 0 then
      equip_item(equip_menu_sel)
    end
    -- X button (button 5) - close menu
    if (input & 32) > 0 and (prev_input & 32) == 0 then
      show_equip_menu = false
      equip_menu_sel = 0
    end
  else
    if combat_over then
      -- O button (button 4)
      if (input & 16) > 0 and (prev_input & 16) == 0 then
        if combat_escaped then
          _log("combat_escaped")
          reset_combat()
        elseif player_won then
          _log("enemy_defeated")
          enemy_count += 1
          if enemy_count >= 3 then
            _log("state:gameover")
            _log("gameover:win")
            state = "gameover"
            boss_defeated = true
            prev_input = input
            return
          end
          reset_combat()
        else
          _log("state:gameover")
          _log("gameover:lose")
          state = "gameover"
          prev_input = input
          return
        end
      end
    else
      -- player action selection
      -- left (button 0) - attack
      if (input & 1) > 0 and (prev_input & 1) == 0 then
        player_action = "attack"
        player_act_val = 0
        combat_step()
        _log("action:attack")
      -- right (button 1) - defend
      elseif (input & 2) > 0 and (prev_input & 2) == 0 then
        player_action = "defend"
        player_act_val = 0
        combat_step()
        _log("action:defend")
      -- up (button 2) - potion
      elseif (input & 4) > 0 and (prev_input & 4) == 0 then
        if player.potions > 0 then
          player_action = "potion"
          player_act_val = 0
          combat_step()
          _log("action:potion")
        end
      -- down (button 3) - flee
      elseif (input & 8) > 0 and (prev_input & 8) == 0 then
        player_action = "flee"
        player_act_val = 0
        combat_step()
        _log("action:flee")
      -- X button (button 5) - open equipment menu
      elseif (input & 32) > 0 and (prev_input & 32) == 0 then
        show_equip_menu = true
        equip_menu_sel = 0
      end
    end
  end

  prev_input = input
end

function draw_play()
  -- header
  print("level "..player.level, 5, 5, 7)
  print("hp: "..player.hp.."/"..player.max_hp, 50, 5, 7)
  print("potions: "..player.potions, 90, 5, 7)

  -- equipment in header
  local wep_str = "no weapon"
  if player.weapon then wep_str = player.weapon.name end
  print(wep_str, 5, 13, 6)

  -- enemy
  local enemy_name = "boss"
  if not enemy.is_boss then enemy_name = "enemy" end
  print(enemy_name.." hp: "..enemy.hp.."/"..enemy.max_hp, 20, 28, 8)

  -- sprites (simple placeholder)
  spr(0, 20, 43)  -- player
  spr(1, 80, 43)  -- enemy

  -- combat log
  local log_y = 63
  for i = max(1, #combat_log - 3), #combat_log do
    if combat_log[i] then
      print(combat_log[i], 5, log_y, 7)
      log_y += 8
    end
  end

  -- status
  if combat_over then
    if player_won then
      print("victory! press z/c", 24, 105, 11)
    else
      print("defeated! press z/c", 22, 105, 8)
    end
  else
    print("left:atk right:def up:pot down:flee x:equip", 0, 115, 5)
  end
end

-- gameover
function update_gameover()
  local input = test_input()

  -- O button (button 4)
  if (input & 16) > 0 and (prev_input & 16) == 0 then
    _log("state:menu")
    state = "menu"
    menu_sel = 0
    reset_game()
  end

  prev_input = input
end

function draw_gameover()
  if boss_defeated then
    print("you defeated the boss!", 18, 30, 11)
    print("quest complete!", 32, 45, 11)
    print("level: "..player.level, 40, 60, 7)
    print("exp: "..player.exp, 40, 72, 7)
  else
    print("game over", 40, 30, 8)
    print("you were defeated", 24, 45, 8)
    print("level: "..player.level, 40, 60, 5)
  end
  print("press z/c to continue", 18, 110, 7)
end

-- equipment system helpers
function get_player_atk()
  local total = player.atk
  if player.weapon then total += player.weapon.atk end
  if player.armor and player.armor.atk > 0 then total += player.armor.atk end
  return total
end

function get_player_def()
  local total = player.def
  if player.armor then total += player.armor.def end
  if player.weapon and player.weapon.def > 0 then total += player.weapon.def end
  return total
end

function drop_loot(is_boss)
  local drop_table = {
    {item=1, chance=0.6},  -- wooden sword
    {item=4, chance=0.4},  -- cloth armor
  }

  if enemy_count >= 1 then
    drop_table = {
      {item=2, chance=0.5},  -- iron sword
      {item=5, chance=0.4},  -- leather armor
    }
  end

  if is_boss then
    drop_table = {
      {item=3, chance=0.8},  -- steel sword
      {item=6, chance=0.6},  -- steel armor
      {item=7, chance=0.7},  -- magic ring
    }
  end

  for entry in all(drop_table) do
    if rnd() < entry.chance then
      add(player.inventory, equipment_list[entry.item])
      add(combat_log, equipment_list[entry.item].name.." dropped!")
      _log("loot:"..equipment_list[entry.item].name)
    end
  end
end

-- equipment menu
function draw_equip_menu()
  -- overlay
  rectfill(5, 30, 123, 100, 0)
  rect(5, 30, 123, 100, 7)

  print("equipment", 40, 33, 7)

  local y = 43
  -- unequip option
  local sel_marker = " "
  if equip_menu_sel == 0 then sel_marker = ">" end
  print(sel_marker.." unequip all", 10, y, 7)
  y += 8

  if #player.inventory == 0 then
    print("no items", 45, y, 5)
  else
    for i = 1, #player.inventory do
      local item = player.inventory[i]
      local sel_marker = " "
      if i == equip_menu_sel then sel_marker = ">" end

      local equipped = ""
      if player.weapon == item or player.armor == item then
        equipped = " (eq)"
      end

      print(sel_marker.." "..item.name..equipped, 10, y, 7)
      y += 8
    end
  end

  print("z:equip x:close", 15, 95, 5)
end

function equip_item(idx)
  if idx == 0 then
    -- unequip all
    _log("unequip_all")
    player.weapon = nil
    player.armor = nil
    return
  end

  local item = player.inventory[idx]
  if not item then return end

  -- determine if weapon or armor based on atk/def bonuses
  if item.atk > 0 and item.def == 0 then
    -- weapon
    if player.weapon == item then
      player.weapon = nil
      _log("unequip:"..item.name)
    else
      player.weapon = item
      _log("equip:"..item.name)
    end
  elseif item.def > 0 and item.atk == 0 then
    -- armor
    if player.armor == item then
      player.armor = nil
      _log("unequip:"..item.name)
    else
      player.armor = item
      _log("equip:"..item.name)
    end
  else
    -- accessory (bonus to both)
    if player.weapon == item then
      player.weapon = nil
      _log("unequip:"..item.name)
    else
      player.weapon = item
      _log("equip:"..item.name)
    end
  end
end

-- combat system
function combat_step()
  add(combat_log, "--- turn "..turn.." ---")

  -- player action
  local dmg = 0
  local player_atk = get_player_atk()
  local player_def = get_player_def()

  if player_action == "attack" then
    dmg = max(1, player_atk - enemy.def + flr(rnd(3)))
    enemy.hp -= dmg
    add(combat_log, "you attack! "..dmg.." dmg")
  elseif player_action == "defend" then
    add(combat_log, "you defend!")
  elseif player_action == "potion" then
    local heal = 8
    player.hp = min(player.max_hp, player.hp + heal)
    player.potions -= 1
    add(combat_log, "you heal "..heal.." hp")
  elseif player_action == "flee" then
    if rnd() < 0.5 then
      add(combat_log, "escaped!")
      combat_over = true
      combat_escaped = true
      return
    else
      add(combat_log, "flee failed!")
    end
  end

  -- check enemy defeated
  if enemy.hp <= 0 then
    enemy.hp = 0
    add(combat_log, "enemy defeated!")
    player.exp += 10
    drop_loot(enemy.is_boss)
    if player.exp >= 30 then
      player.level += 1
      player.exp = 0
      player.max_hp += 5
      player.hp = player.max_hp
      player.atk += 1
      player.def += 1
      add(combat_log, "level up!")
      _log("level_up:"..player.level)
    end
    combat_over = true
    player_won = true
    return
  end

  -- enemy action
  local enemy_act = flr(rnd(2))
  if enemy_act == 0 then
    dmg = max(1, enemy.atk - player_def + flr(rnd(2)))
    if player_action == "defend" then
      dmg = max(1, flr(dmg / 2))
    end
    player.hp -= dmg
    add(combat_log, "enemy attacks! "..dmg.." dmg")
  else
    add(combat_log, "enemy defend!")
  end

  -- check player defeated
  if player.hp <= 0 then
    player.hp = 0
    add(combat_log, "you were defeated!")
    combat_over = true
    player_won = false
  end

  turn += 1
end

function reset_combat()
  turn = 0
  combat_log = {}
  player_action = nil
  combat_over = false
  player_won = false
  combat_escaped = false

  -- spawn new enemy
  if enemy_count < 2 then
    enemy.hp = 8 + enemy_count * 3
    enemy.max_hp = enemy.hp
    enemy.atk = 3 + enemy_count
    enemy.is_boss = false
    add(combat_log, "a goblin appears!")
  else
    -- boss fight
    enemy.hp = 25
    enemy.max_hp = 25
    enemy.atk = 6
    enemy.def = 2
    enemy.is_boss = true
    add(combat_log, "the boss appears!")
  end

  _log("enemy_spawn:"..enemy.is_boss)
end

function reset_game()
  player.hp = 20
  player.max_hp = 20
  player.atk = 5
  player.def = 2
  player.level = 1
  player.exp = 0
  player.potions = 2
  player.weapon = nil
  player.armor = nil
  player.inventory = {}

  enemy_count = 0
  boss_defeated = false
  combat_over = false
  player_won = false
  combat_escaped = false
  combat_log = {}
  turn = 0
  show_equip_menu = false
  equip_menu_sel = 0
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
__sfx__
010100000a5501a350235503a55004300d3500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010100000f5402a5401f54000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101000029340394003a3503a3401a350233500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
