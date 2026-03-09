pico-8 cartridge // http://www.pico-8.com
version 41
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
menu_sel = 0  -- 0=easy, 1=normal, 2=hard, 3=quit
prev_input = 0
difficulty = 2  -- 1=easy, 2=normal, 3=hard

-- animation system
anim = {
  player_swing = {active=false, frame=0, dur=6},
  enemy_flinch = {active=false, frame=0, dur=4},
  damage_popups = {},
  screen_shake = {intensity=0, timer=0},
  flash_color = {active=false, col=0, timer=0}
}

-- particle system for visual effects
particles = {}

-- helper: add damage popup
function add_damage_popup(dmg_val, x, y)
  add(anim.damage_popups, {
    val = dmg_val,
    x = x,
    y = y,
    timer = 30,
    vx = rnd(1) - 0.5,
    vy = -0.5
  })
end

-- helper: trigger screen shake
function screen_shake(intensity, duration)
  anim.screen_shake.intensity = intensity
  anim.screen_shake.timer = duration or 8
end

-- helper: add particles
function add_particles(x, y, col, count)
  for i = 1, count do
    add(particles, {
      x = x,
      y = y,
      vx = (rnd(2) - 1) * 0.5,
      vy = (rnd(2) - 1) * 0.3,
      timer = 15,
      col = col
    })
  end
end

-- equipment system
-- rarity: 1=common, 2=uncommon, 3=rare
equipment_list = {
  -- common weapons
  {name="wooden sword", atk=2, def=0, hp=0, rarity=1},
  {name="iron sword", atk=3, def=0, hp=0, rarity=1},
  -- uncommon weapons
  {name="steel sword", atk=4, def=0, hp=0, rarity=2},
  {name="silver sword", atk=5, def=0, hp=0, rarity=2},
  -- common armor
  {name="cloth armor", atk=0, def=1, hp=0, rarity=1},
  {name="leather armor", atk=0, def=2, hp=0, rarity=1},
  -- uncommon armor
  {name="steel armor", atk=0, def=2, hp=0, rarity=2},
  {name="mithril armor", atk=0, def=3, hp=0, rarity=2},
  -- accessories
  {name="health ring", atk=0, def=0, hp=3, rarity=1},
  {name="vigor amulet", atk=0, def=0, hp=5, rarity=2},
  {name="golden ring", atk=1, def=1, hp=4, rarity=3}
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
  antidotes = 1,  -- removes poison
  cure_scrolls = 1,  -- removes any status
  weapon = nil,
  armor = nil,
  accessory = nil,
  inventory = {},
  status_effects = {},  -- poison, stun, paralysis
  last_equip_feedback = ""
}

-- enemy stats
enemy = {
  hp = 8,
  max_hp = 8,
  atk = 3,
  def = 1,
  name = "goblin",
  is_boss = false,
  type = 0,  -- 0=default, 1-3=type index
  armor_active = false,  -- for troll armor buff
  status_effects = {}  -- poison, stun, paralysis
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
show_items_menu = false
items_menu_sel = 0

-- boss abilities
boss_abilities = {
  power_attack = {
    enabled = true,
    hp_threshold = 0.5,  -- trigger at 50% hp
    charged = false,
    recovery_turn = 0
  },
  heal = {
    enabled = true,
    hp_threshold = 0.75,  -- trigger at 75% hp
    used = false
  },
  multi_strike = {
    enabled = true,
    hp_threshold = 0.25  -- trigger at 25% hp
  }
}

function _update()
  -- update animations
  if anim.player_swing.active then
    anim.player_swing.frame += 1
    if anim.player_swing.frame > anim.player_swing.dur then
      anim.player_swing.active = false
    end
  end

  if anim.enemy_flinch.active then
    anim.enemy_flinch.frame += 1
    if anim.enemy_flinch.frame > anim.enemy_flinch.dur then
      anim.enemy_flinch.active = false
    end
  end

  -- update damage popups
  for i = #anim.damage_popups, 1, -1 do
    local p = anim.damage_popups[i]
    p.timer -= 1
    p.y -= 0.3
    if p.timer <= 0 then
      deli(anim.damage_popups, i)
    end
  end

  -- update particles
  for i = #particles, 1, -1 do
    local p = particles[i]
    p.timer -= 1
    p.x += p.vx
    p.y += p.vy
    p.vy -= 0.05  -- gravity
    if p.timer <= 0 then
      deli(particles, i)
    end
  end

  -- update screen shake
  if anim.screen_shake.timer > 0 then
    anim.screen_shake.timer -= 1
  end

  -- update flash
  if anim.flash_color.active then
    anim.flash_color.timer -= 1
    if anim.flash_color.timer <= 0 then
      anim.flash_color.active = false
    end
  end

  if state == "menu" then update_menu()
  elseif state == "play" then update_play()
  elseif state == "gameover" then update_gameover()
  end
end

function _draw()
  cls(1)

  -- apply screen shake
  local shake_x = 0
  local shake_y = 0
  if anim.screen_shake.timer > 0 then
    shake_x = flr(rnd(anim.screen_shake.intensity * 2)) - anim.screen_shake.intensity
    shake_y = flr(rnd(anim.screen_shake.intensity * 2)) - anim.screen_shake.intensity
  end
  camera(shake_x, shake_y)

  if state == "menu" then draw_menu()
  elseif state == "play" then draw_play()
  elseif state == "gameover" then draw_gameover()
  end

  camera(0, 0)

  -- apply flash color overlay
  if anim.flash_color.active then
    local alpha = anim.flash_color.timer / 8
    if alpha > 0.5 then
      rectfill(0, 0, 127, 127, anim.flash_color.col)
    end
  end

  if show_items_menu then
    draw_items_menu()
  elseif show_equip_menu then
    draw_equip_menu()
  end
end

-- menu
function update_menu()
  local input = test_input()

  -- right (button 1)
  if (input & 2) > 0 and (prev_input & 2) == 0 then
    menu_sel = min(menu_sel + 1, 3)
    sfx(0)  -- menu nav sound
  end
  -- left (button 0)
  if (input & 1) > 0 and (prev_input & 1) == 0 then
    menu_sel = max(menu_sel - 1, 0)
    sfx(0)  -- menu nav sound
  end
  -- O button (button 4)
  if (input & 16) > 0 and (prev_input & 16) == 0 then
    sfx(1)  -- menu confirm sound
    if menu_sel == 0 then
      difficulty = 1  -- easy
      _log("difficulty:easy")
      _log("state:play")
      state = "play"
      reset_combat()
    elseif menu_sel == 1 then
      difficulty = 2  -- normal
      _log("difficulty:normal")
      _log("state:play")
      state = "play"
      reset_combat()
    elseif menu_sel == 2 then
      difficulty = 3  -- hard
      _log("difficulty:hard")
      _log("state:play")
      state = "play"
      reset_combat()
    elseif menu_sel == 3 then
      _log("quit")
      _log("state:gameover")
      state = "gameover"
      boss_defeated = false
    end
  end

  prev_input = input
end

function draw_menu()
  print("dungeon crawler", 28, 20, 7)
  print("level "..player.level.." | hp "..player.hp.."/"..player.max_hp, 16, 40, 7)
  print("select difficulty:", 28, 52, 7)

  local y = 62
  local sel_col = 8

  -- helper to draw menu item
  local function draw_item(idx, name, col)
    local is_sel = menu_sel == idx
    local x_offset = is_sel and 2 or 0
    local text_col = is_sel and col or 5
    local arrow = is_sel and ">" or " "

    print(arrow, 48 + x_offset, y, sel_col)
    print(name, 60 + x_offset, y, text_col)
  end

  -- easy
  draw_item(0, "easy", 7)
  y += 10

  -- normal
  draw_item(1, "normal", 7)
  y += 10

  -- hard
  draw_item(2, "hard", 7)
  y += 10

  -- quit
  draw_item(3, "quit", 8)

  print("z/c to select", 22, 110, 5)
end

-- play state
function update_play()
  local input = test_input()

  -- items menu
  if show_items_menu then
    -- up (button 2)
    if (input & 4) > 0 and (prev_input & 4) == 0 then
      items_menu_sel = max(0, items_menu_sel - 1)
    end
    -- down (button 3)
    if (input & 8) > 0 and (prev_input & 8) == 0 then
      items_menu_sel = min(1, items_menu_sel + 1)
    end
    -- O button (button 4) - use item
    if (input & 16) > 0 and (prev_input & 16) == 0 then
      use_item(items_menu_sel)
    end
    -- X button (button 5) - close menu
    if (input & 32) > 0 and (prev_input & 32) == 0 then
      show_items_menu = false
      items_menu_sel = 0
      sfx(0)
    end
  -- equipment menu
  elseif show_equip_menu then
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
        sfx(2)  -- attack sound
        combat_step()
        _log("action:attack")
      -- right (button 1) - defend
      elseif (input & 2) > 0 and (prev_input & 2) == 0 then
        player_action = "defend"
        player_act_val = 0
        sfx(6)  -- defend sound
        combat_step()
        _log("action:defend")
      -- up (button 2) - potion
      elseif (input & 4) > 0 and (prev_input & 4) == 0 then
        if player.potions > 0 then
          player_action = "potion"
          player_act_val = 0
          sfx(5)  -- heal/potion sound
          combat_step()
          _log("action:potion")
        end
      -- down (button 3) - flee
      elseif (input & 8) > 0 and (prev_input & 8) == 0 then
        player_action = "flee"
        player_act_val = 0
        sfx(7)  -- flee sound
        combat_step()
        _log("action:flee")
      -- O button (button 4) - open items menu
      elseif (input & 16) > 0 and (prev_input & 16) == 0 then
        show_items_menu = true
        items_menu_sel = 0
        sfx(0)  -- menu nav sound
      -- X button (button 5) - open equipment menu
      elseif (input & 32) > 0 and (prev_input & 32) == 0 then
        show_equip_menu = true
        equip_menu_sel = 0
        sfx(0)  -- menu nav sound
      end
    end
  end

  prev_input = input
end

function draw_status_icons()
  local x = 12
  for s, d in pairs(enemy.status_effects) do
    if d.d > 0 then
      local l = s == "poison" and "POI" or (s == "stun" and "STN" or "PAR")
      print(l, x, 36, get_status_color(s))
      x += 10
    end
  end
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
  if not enemy.is_boss then
    enemy_name = enemy.type == 1 and "goblin archer" or (enemy.type == 2 and "troll" or (enemy.type == 3 and "orc warrior" or "goblin"))
  end
  print(enemy_name.." hp: "..enemy.hp.."/"..enemy.max_hp, 12, 28, 8)

  -- draw status effects
  draw_status_icons()

  -- draw player sprite with swing animation
  local player_x = 20
  local player_y = 43
  local player_spr = 0
  local player_col = 7

  if anim.player_swing.active then
    -- swing animation: move sprite right and down
    player_x += flr(anim.player_swing.frame / 2)
    player_y += flr(sin(anim.player_swing.frame / 6) * 2)
  end

  if player.hp <= 0 then
    -- hurt state: change color/position
    player_y += 1
    player_col = 5
  elseif player.weapon then
    -- equipped weapon visual indicator (slight color change)
    player_col = 8
  end

  spr(player_spr, player_x, player_y)

  -- draw simple equipment indicator dots
  if player.weapon then
    pset(player_x + 1, player_y - 1, 8)  -- weapon dot
  end
  if player.armor then
    pset(player_x + 5, player_y - 1, 6)  -- armor dot
  end

  -- draw enemy sprite with flinch animation
  local enemy_x = 80
  local enemy_y = 43
  local enemy_spr = 1  -- default goblin
  if enemy.is_boss then
    enemy_spr = 5  -- boss
  elseif enemy.type == 1 then
    enemy_spr = 2  -- goblin archer
  elseif enemy.type == 2 then
    enemy_spr = 3  -- troll
  elseif enemy.type == 3 then
    enemy_spr = 4  -- orc warrior
  end
  local enemy_col = 7

  if anim.enemy_flinch.active then
    enemy_col = (anim.enemy_flinch.frame % 2 == 0) and 8 or 7
    enemy_x += 1
  end

  if enemy.hp <= 0 then
    enemy_y += 2
  elseif enemy.is_boss then
    enemy_col = 10
  elseif enemy.type == 2 then
    enemy_col = 3  -- troll is greenish
  elseif enemy.type == 3 then
    enemy_col = 2  -- warrior is reddish
  end

  spr(enemy_spr, enemy_x, enemy_y)

  -- draw damage popups
  for popup in all(anim.damage_popups) do
    local alpha = popup.timer / 30
    local col = 8  -- red damage
    if popup.val < 0 then col = 11 end  -- green heal
    print(abs(popup.val), flr(popup.x), flr(popup.y), col)
  end

  -- draw particles
  for p in all(particles) do
    local fade = p.timer / 15
    if fade > 0.5 then
      pset(flr(p.x), flr(p.y), p.col)
    end
  end

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
    print("left:atk right:def up:pot down:flee z:items x:equip", 0, 115, 5)
  end

  -- draw player status effects
  local psx = 12
  for s, d in pairs(player.status_effects) do
    if d.d > 0 then
      local l = s == "poison" and "POI" or (s == "stun" and "STN" or "PAR")
      print(l, psx, 22, get_status_color(s))
      psx += 10
    end
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
  local difficulty_str = "normal"
  if difficulty == 1 then
    difficulty_str = "easy"
  elseif difficulty == 3 then
    difficulty_str = "hard"
  end

  if boss_defeated then
    -- victory screen with color flash
    local flash_col = flr(t() * 4) % 2 == 0 and 11 or 7
    print("you defeated the boss!", 18, 30, flash_col)
    print("quest complete!", 32, 45, 11)
    print("level: "..player.level, 40, 60, 7)
    print("exp: "..player.exp, 40, 72, 7)
  else
    print("game over", 40, 30, 8)
    print("you were defeated", 24, 45, 8)
    print("level: "..player.level, 40, 60, 5)
  end
  print("difficulty: "..difficulty_str, 30, 85, 6)
  print("press z/c to continue", 18, 110, 7)
end

-- equipment system helpers
function get_player_atk()
  local total = player.atk
  if player.weapon then total += player.weapon.atk end
  if player.armor and player.armor.atk > 0 then total += player.armor.atk end
  if player.accessory and player.accessory.atk > 0 then total += player.accessory.atk end
  return total
end

function get_player_def()
  local total = player.def
  if player.armor then total += player.armor.def end
  if player.weapon and player.weapon.def > 0 then total += player.weapon.def end
  if player.accessory and player.accessory.def > 0 then total += player.accessory.def end
  return total
end

function get_player_max_hp()
  local total = player.max_hp
  if player.accessory and player.accessory.hp > 0 then
    total += player.accessory.hp
  end
  return total
end

function drop_loot(is_boss)
  local drop_table = {}

  -- difficulty modifier affects drop chances
  local diff_bonus = 0
  if difficulty == 3 then diff_bonus = 0.15 end  -- hard: +15% chance for rare loot
  if difficulty == 1 then diff_bonus = -0.1 end  -- easy: -10% chance

  if is_boss then
    -- boss drops guaranteed good loot
    drop_table = {
      {item=3, chance=0.9},    -- steel sword (uncommon weapon)
      {item=7, chance=0.85},   -- mithril armor (uncommon armor)
      {item=10, chance=0.7},   -- vigor amulet (rare accessory)
      {item=11, chance=0.2 + diff_bonus},   -- golden ring (rare)
    }
  elseif enemy_count >= 2 then
    -- late game: better weapons and armor
    drop_table = {
      {item=3, chance=0.4 + diff_bonus},   -- steel sword
      {item=7, chance=0.35 + diff_bonus},  -- mithril armor
      {item=9, chance=0.3},    -- vigor amulet
    }
  elseif enemy_count >= 1 then
    -- mid game: mix of common and uncommon
    drop_table = {
      {item=2, chance=0.45},    -- iron sword (common)
      {item=6, chance=0.4},     -- leather armor (common)
      {item=9, chance=0.15 + diff_bonus},  -- health ring (uncommon accessory)
    }
  else
    -- early game: common drops only
    drop_table = {
      {item=1, chance=0.5},     -- wooden sword (common)
      {item=5, chance=0.45},    -- cloth armor (common)
      {item=9, chance=0.08},    -- health ring (rare for early)
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
  -- overlay with border animation
  rectfill(5, 30, 123, 105, 0)
  rect(5, 30, 123, 105, 7)
  rect(4, 29, 124, 106, 7)  -- double border for polish

  print("equipment", 38, 33, 7)

  local y = 43
  -- unequip option with highlight
  local sel_marker = " "
  local sel_col = 7
  if equip_menu_sel == 0 then
    sel_marker = ">"
    sel_col = 8
  end
  print(sel_marker.." unequip all", 10, y, sel_col)
  y += 8

  if #player.inventory == 0 then
    print("no items", 45, y, 5)
  else
    for i = 1, #player.inventory do
      local item = player.inventory[i]
      local sel_marker = " "
      local sel_col = 7
      if i == equip_menu_sel then
        sel_marker = ">"
        sel_col = 8
      end

      local equipped = ""
      if player.weapon == item or player.armor == item or player.accessory == item then
        equipped = "✓"
      end

      -- show item name and bonuses
      local bonus_str = ""
      if item.atk > 0 then bonus_str = "a"..item.atk end
      if item.def > 0 then
        if bonus_str ~= "" then bonus_str = bonus_str.." " end
        bonus_str = bonus_str.."d"..item.def
      end
      if item.hp > 0 then
        if bonus_str ~= "" then bonus_str = bonus_str.." " end
        bonus_str = bonus_str.."h"..item.hp
      end

      print(sel_marker, 10, y, sel_col)
      print(item.name, 16, y, sel_col)
      print(bonus_str, 75, y, 6)
      print(equipped, 118, y, 11)
      y += 8
    end
  end

  print("z:equip x:close", 12, 100, 5)
end

function draw_items_menu()
  -- overlay with border animation
  rectfill(10, 35, 118, 100, 0)
  rect(10, 35, 118, 100, 7)
  rect(9, 34, 119, 101, 7)

  print("items", 50, 38, 7)

  local y = 48
  -- antidote option
  local sel_marker = " "
  local sel_col = 7
  if items_menu_sel == 0 then
    sel_marker = ">"
    sel_col = 8
  end
  local antidote_col = player.antidotes > 0 and 7 or 5
  print(sel_marker.." antidote: "..player.antidotes, 15, y, sel_col)
  print("remove poison", 60, y, antidote_col)
  y += 8

  -- cure scroll option
  sel_marker = " "
  sel_col = 7
  if items_menu_sel == 1 then
    sel_marker = ">"
    sel_col = 8
  end
  local cure_col = player.cure_scrolls > 0 and 7 or 5
  print(sel_marker.." cure scroll: "..player.cure_scrolls, 15, y, sel_col)
  print("remove all", 60, y, cure_col)
  y += 8

  print("z:use x:close", 20, 95, 5)
end

function equip_item(idx)
  if idx == 0 then
    -- unequip all
    _log("unequip_all")
    local old_hp = player.max_hp
    if player.weapon then
      add(combat_log, "unequipped "..player.weapon.name)
      player.weapon = nil
    end
    if player.armor then
      add(combat_log, "unequipped "..player.armor.name)
      player.armor = nil
    end
    if player.accessory then
      add(combat_log, "unequipped "..player.accessory.name)
      player.accessory = nil
    end
    local new_hp = get_player_max_hp()
    if new_hp < player.hp then
      player.hp = new_hp
    end
    return
  end

  local item = player.inventory[idx]
  if not item then return end

  -- save old stats
  local old_atk = get_player_atk()
  local old_def = get_player_def()
  local old_max_hp = get_player_max_hp()

  -- weapon: atk bonus only
  if item.atk > 0 and item.def == 0 and item.hp == 0 then
    if player.weapon == item then
      player.weapon = nil
      add(combat_log, "unequipped "..item.name)
      _log("unequip:"..item.name)
    else
      player.weapon = item
      add(combat_log, "equipped "..item.name)
      _log("equip:"..item.name)
    end
  -- armor: def bonus only
  elseif item.def > 0 and item.atk == 0 and item.hp == 0 then
    if player.armor == item then
      player.armor = nil
      add(combat_log, "unequipped "..item.name)
      _log("unequip:"..item.name)
    else
      player.armor = item
      add(combat_log, "equipped "..item.name)
      _log("equip:"..item.name)
    end
  -- accessory: hp bonus (can have atk/def too)
  else
    if player.accessory == item then
      player.accessory = nil
      add(combat_log, "unequipped "..item.name)
      _log("unequip:"..item.name)
    else
      player.accessory = item
      add(combat_log, "equipped "..item.name)
      _log("equip:"..item.name)
    end
  end

  -- apply new stat calculations
  local new_atk = get_player_atk()
  local new_def = get_player_def()
  local new_max_hp = get_player_max_hp()

  -- adjust current hp if max hp changed
  if new_max_hp > old_max_hp then
    player.hp = min(new_max_hp, player.hp + (new_max_hp - old_max_hp))
  elseif new_max_hp < old_max_hp then
    if player.hp > new_max_hp then
      player.hp = new_max_hp
    end
  end

  -- update max_hp
  player.max_hp = new_max_hp

  -- log stat changes
  _log("stat_change:atk="..old_atk.."->"..new_atk.."|def="..old_def.."->"..new_def.."|hp="..old_max_hp.."->"..new_max_hp)
end

function use_item(idx)
  if idx == 0 then
    -- antidote: removes poison
    if player.antidotes > 0 then
      if player_has_status("poison") then
        remove_player_status("poison")
        player.antidotes -= 1
        sfx(5)  -- healing sound
        add_particles(25, 45, 11, 3)
        player_action = "item_antidote"
        combat_step()
        _log("action:item_antidote")
      else
        add(combat_log, "no poison!")
      end
    end
    show_items_menu = false
  elseif idx == 1 then
    -- cure scroll: removes any status
    if player.cure_scrolls > 0 then
      local has_any = false
      for s, d in pairs(player.status_effects) do
        has_any = true
        break
      end
      if has_any then
        for s, d in pairs(player.status_effects) do
          remove_player_status(s)
        end
        player.cure_scrolls -= 1
        sfx(5)  -- healing sound
        add_particles(25, 45, 11, 3)
        player_action = "item_cure"
        combat_step()
        _log("action:item_cure")
      else
        add(combat_log, "no status effects!")
      end
    end
    show_items_menu = false
  end
  items_menu_sel = 0
end

function get_stat(t, stat)
  if t == 1 then
    return stat == "hp" and 0.8 or (stat == "atk" and 1.3 or 0.8)
  elseif t == 2 then
    return stat == "hp" and 1.5 or (stat == "atk" and 0.8 or 1.0)
  elseif t == 3 then
    return stat == "hp" and 1.0 or (stat == "atk" and 1.2 or 1.2)
  end
  return 1.0
end

-- boss special abilities
function get_boss_ability()
  -- return which ability the boss should use, or nil for normal attack
  if not enemy.is_boss then return nil end

  local hp_pct = enemy.hp / enemy.max_hp

  -- power attack at 50% hp (50% chance if enabled)
  if boss_abilities.power_attack.enabled and hp_pct <= boss_abilities.power_attack.hp_threshold then
    if not boss_abilities.power_attack.charged and rnd() < 0.6 then
      return "power_attack"
    end
  end

  -- heal at 75% hp (first time only)
  if boss_abilities.heal.enabled and hp_pct <= boss_abilities.heal.hp_threshold then
    if not boss_abilities.heal.used and rnd() < 0.5 then
      return "heal"
    end
  end

  -- multi strike at 25% hp (desperation move)
  if boss_abilities.multi_strike.enabled and hp_pct <= boss_abilities.multi_strike.hp_threshold then
    if rnd() < 0.7 then
      return "multi_strike"
    end
  end

  return nil
end

function execute_boss_ability(ability, player_def)
  local dmg = 0

  if ability == "power_attack" then
    -- double damage, but boss needs recovery
    dmg = max(1, (enemy.atk * 2) - player_def + flr(rnd(3)))
    player.hp -= dmg
    add(combat_log, "boss power attack! "..dmg.." dmg")
    add_damage_popup(dmg, 25, 40)
    add_particles(25, 45, 8, 5)
    sfx(12)  -- boss power attack sound
    anim.player_swing.active = true
    anim.player_swing.frame = 0
    screen_shake(2, 6)
    anim.flash_color.active = true
    anim.flash_color.col = 8
    anim.flash_color.timer = 3
    boss_abilities.power_attack.charged = true
    boss_abilities.power_attack.recovery_turn = 1
    _log("boss_ability:power_attack")

  elseif ability == "heal" then
    -- boss heals itself (limited uses)
    local heal = 8
    enemy.hp = min(enemy.max_hp, enemy.hp + heal)
    add(combat_log, "boss heals "..heal.." hp!")
    add_damage_popup(-heal, 85, 40)
    add_particles(85, 45, 11, 5)
    sfx(13)  -- boss heal sound
    anim.flash_color.active = true
    anim.flash_color.col = 11
    anim.flash_color.timer = 3
    boss_abilities.heal.used = true
    _log("boss_ability:heal")

  elseif ability == "multi_strike" then
    -- hit player 3 times
    local hits = 3
    local total_dmg = 0
    add(combat_log, "boss multi-strike!")
    sfx(14)  -- boss multi-strike sound
    for i = 1, hits do
      dmg = max(1, enemy.atk - player_def + flr(rnd(2)))
      total_dmg += dmg
      player.hp -= dmg
      add_damage_popup(dmg, 25 - i*2, 40)
    end
    add_particles(25, 45, 8, 7)
    anim.player_swing.active = true
    anim.player_swing.frame = 0
    screen_shake(2, 6)
    anim.flash_color.active = true
    anim.flash_color.col = 8
    anim.flash_color.timer = 4
    add(combat_log, "total: "..total_dmg.." dmg")
    _log("boss_ability:multi_strike")
  end
end

-- status effects system
function apply_status(s, d)
  if enemy.status_effects[s] then
    enemy.status_effects[s].d = max(enemy.status_effects[s].d, d)
  else
    enemy.status_effects[s] = {d = d}
  end
  add(combat_log, s.."!")
  _log("status:"..s)
  sfx(11)  -- reuse enemy sound
  add_particles(85, 45, 12, 3)
end

function update_status_effects()
  for s, d in pairs(enemy.status_effects) do
    d.d -= 1
    if d.d <= 0 or (s == "stun" and rnd() < 0.3) then
      enemy.status_effects[s] = nil
      add(combat_log, s.." gone!")
      _log("status:"..s)
    end
  end
end

function has_status(s)
  return enemy.status_effects[s] ~= nil
end

function get_status_color(s)
  return s == "poison" and 11 or (s == "stun" and 13 or 12)
end

function player_has_status(s)
  return player.status_effects[s] ~= nil
end

function apply_player_status(s, d)
  if player.status_effects[s] then
    player.status_effects[s].d = max(player.status_effects[s].d, d)
  else
    player.status_effects[s] = {d = d}
  end
  add(combat_log, "you're "..s.."!")
  sfx(11)
  add_particles(25, 45, 12, 3)
end

function update_player_status()
  for s, d in pairs(player.status_effects) do
    d.d -= 1
    if d.d <= 0 then
      player.status_effects[s] = nil
      add(combat_log, s.." cured!")
    end
  end
end

function remove_player_status(s)
  if player.status_effects[s] then
    player.status_effects[s] = nil
    add(combat_log, s.." cured!")
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
    dmg = max(1, player_atk - enemy.def + (has_status("poison") and 1 or 0) + flr(rnd(3)))
    enemy.hp -= dmg
    add(combat_log, "attack! "..dmg.." dmg")
    anim.player_swing.active = true
    anim.player_swing.frame = 0
    anim.enemy_flinch.active = true
    anim.enemy_flinch.frame = 0
    add_damage_popup(dmg, 85, 40)
    add_particles(85, 45, 8, 3)
    sfx(4)
    if rnd() < 0.2 then apply_status("poison", 3) end
    if rnd() < 0.15 then apply_status("stun", 1) end
    if rnd() < 0.15 then apply_status("paralysis", 2) end

    -- screen shake on crit (high damage)
    if dmg >= 6 then
      screen_shake(2, 6)
      anim.flash_color.active = true
      anim.flash_color.col = 8
      anim.flash_color.timer = 4
    else
      screen_shake(1, 4)
    end
  elseif player_action == "defend" then
    add(combat_log, "you defend!")
    anim.flash_color.active = true
    anim.flash_color.col = 14
    anim.flash_color.timer = 3
  elseif player_action == "potion" then
    local heal = 8
    player.hp = min(player.max_hp, player.hp + heal)
    player.potions -= 1
    add(combat_log, "you heal "..heal.." hp")
    -- heal effect: green popup and particles
    add_damage_popup(-heal, 25, 40)
    add_particles(25, 45, 11, 4)  -- green healing particles
    sfx(5)  -- heal/potion sound
    anim.flash_color.active = true
    anim.flash_color.col = 11
    anim.flash_color.timer = 3
  elseif player_action == "item_antidote" then
    add(combat_log, "poison removed!")
  elseif player_action == "item_cure" then
    add(combat_log, "status effects removed!")
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
    screen_shake(3, 10)
    anim.flash_color.active = true
    anim.flash_color.col = 11
    anim.flash_color.timer = 8
    -- enemy defeat fanfare
    if enemy.is_boss then
      sfx(10)  -- boss defeat fanfare
    else
      sfx(9)  -- enemy defeat sound
    end
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
      -- level up particles and effects
      add_particles(25, 35, 7, 6)
      screen_shake(2, 8)
      anim.flash_color.active = true
      anim.flash_color.col = 7
      anim.flash_color.timer = 5
      sfx(8)  -- level up fanfare
    end
    combat_over = true
    player_won = true
    return
  end

  -- enemy action
  local stun = has_status("stun")
  if stun then
    add(combat_log, "enemy stunned!")
  elseif enemy.is_boss then
    -- boss has special abilities
    local ability = nil

    -- check if recovering from power attack
    if boss_abilities.power_attack.recovery_turn > 0 then
      boss_abilities.power_attack.recovery_turn -= 1
      add(combat_log, "boss recovers...")
      _log("boss_action:recovering")
      -- reset charged flag after recovery is complete
      if boss_abilities.power_attack.recovery_turn == 0 then
        boss_abilities.power_attack.charged = false
      end
    else
      -- check for special abilities (with difficulty adjustment)
      local ability_chance = 1.0
      if difficulty == 1 then  -- easy: reduce special ability frequency
        ability_chance = 0.7
      end

      ability = get_boss_ability()
      if ability and rnd() < ability_chance then
        execute_boss_ability(ability, player_def)
      else
        -- normal boss attack
        dmg = max(1, enemy.atk - player_def + flr(rnd(2)))
        if has_status("paralysis") then
          dmg = max(1, flr(dmg * 0.5))
          add(combat_log, "boss paralyzed!")
        end

        if player_action == "defend" then
          dmg = max(1, flr(dmg / 2))
        end
        player.hp -= dmg
        add(combat_log, "boss attacks! "..dmg.." dmg")
        sfx(3)  -- boss attack sound
        anim.player_swing.active = true
        anim.player_swing.frame = 0
        add_damage_popup(dmg, 25, 40)
        add_particles(25, 45, 8, 3)
        screen_shake(1, 4)
        anim.flash_color.active = true
        anim.flash_color.col = 8
        anim.flash_color.timer = 2
        if rnd() < 0.1 then apply_player_status("poison", 2) end
        if rnd() < 0.08 then apply_player_status("stun", 1) end
        _log("boss_action:attack")
      end
    end
  elseif not stun then
    -- regular enemy combat (but not if stunned)
    local enemy_act = flr(rnd(2))
    if enemy_act == 0 then
      dmg = max(1, enemy.atk - player_def + flr(rnd(2)))
      if has_status("paralysis") then
        dmg = max(1, flr(dmg * 0.5))
        add(combat_log, "enemy paralyzed!")
      end

      if player_action == "defend" then
        dmg = max(1, flr(dmg / 2))
        if enemy.type == 2 then  -- troll armor
          enemy.armor_active = true
          dmg = max(0, flr(dmg * 0.5))
          add(combat_log, "troll hardens!")
        end
      end
      player.hp -= dmg
      add(combat_log, "enemy attacks! "..dmg.." dmg")
      -- enemy-specific attack sounds
      if enemy.type == 1 then
        sfx(11)  -- goblin archer sound
      elseif enemy.type == 2 then
        sfx(15)  -- troll sound
      elseif enemy.type == 3 then
        sfx(16)  -- orc warrior sound
      else
        sfx(3)  -- default enemy attack sound
      end
      anim.player_swing.active = true
      anim.player_swing.frame = 0
      add_damage_popup(dmg, 25, 40)
      add_particles(25, 45, 8, 3)
      screen_shake(1, 4)
      if rnd() < 0.15 then apply_player_status("poison", 2) end
      if rnd() < 0.1 then apply_player_status("stun", 1) end
      anim.flash_color.active = true
      anim.flash_color.col = 8
      anim.flash_color.timer = 2
      _log("enemy_action:attack")
    else
      add(combat_log, "enemy defend!")
      _log("enemy_action:defend")
    end
  end

  -- check player defeated
  if player.hp <= 0 then
    player.hp = 0
    add(combat_log, "you were defeated!")
    screen_shake(4, 12)
    anim.flash_color.active = true
    anim.flash_color.col = 8
    anim.flash_color.timer = 10
    sfx(17)  -- game over/defeat sound
    combat_over = true
    player_won = false
  end

  -- update status effects at end of turn
  update_status_effects()
  update_player_status()

  turn += 1
end

function reset_combat()
  turn = 0
  combat_log = {}
  player_action = nil
  combat_over = false
  player_won = false
  combat_escaped = false

  -- clear status effects
  enemy.status_effects = {}

  -- reset boss abilities for new fight
  boss_abilities.power_attack.charged = false
  boss_abilities.power_attack.recovery_turn = 0
  boss_abilities.heal.used = false

  -- spawn new enemy
  if enemy_count < 2 then
    enemy.type = flr(rnd(3)) + 1  -- pick type 1-3
    enemy.armor_active = false

    -- base stats with type multipliers
    local base_hp = 8 + enemy_count * 3
    local base_atk = 3 + enemy_count

    enemy.hp = flr(base_hp * get_stat(enemy.type, "hp"))
    enemy.max_hp = enemy.hp
    enemy.atk = flr(base_atk * get_stat(enemy.type, "atk"))
    enemy.def = flr(1 * get_stat(enemy.type, "def"))
    enemy.is_boss = false

    -- difficulty scaling
    if difficulty == 1 then
      enemy.hp = flr(enemy.hp * 3 / 4)
      enemy.max_hp = enemy.hp
      enemy.atk = flr(enemy.atk * 3 / 4)
    elseif difficulty == 3 then
      enemy.hp = flr(enemy.hp * 5 / 4)
      enemy.max_hp = enemy.hp
      enemy.atk = flr(enemy.atk * 5 / 4)
    end

    local ename = enemy.type == 1 and "goblin archer" or (enemy.type == 2 and "troll" or (enemy.type == 3 and "orc warrior" or "goblin"))
    add(combat_log, "a "..ename.." appears!")
  else
    -- boss fight
    enemy.hp = 25
    enemy.max_hp = 25
    enemy.atk = 6
    enemy.def = 2
    enemy.is_boss = true
    enemy.type = 0
    enemy.armor_active = false

    -- apply difficulty scaling to boss
    if difficulty == 1 then  -- easy
      enemy.hp = flr(enemy.hp * 3 / 4)
      enemy.max_hp = enemy.hp
      enemy.atk = flr(enemy.atk * 3 / 4)
    elseif difficulty == 3 then  -- hard
      enemy.hp = flr(enemy.hp * 5 / 4)
      enemy.max_hp = enemy.hp
      enemy.atk = flr(enemy.atk * 5 / 4)
    end

    add(combat_log, "the boss appears!")
    _log("boss_fight:start")
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

  -- set potions based on difficulty
  if difficulty == 1 then  -- easy
    player.potions = 3
    player.antidotes = 2
    player.cure_scrolls = 2
  elseif difficulty == 2 then  -- normal
    player.potions = 2
    player.antidotes = 1
    player.cure_scrolls = 1
  else  -- hard
    player.potions = 1
    player.antidotes = 1
    player.cure_scrolls = 1
  end

  player.weapon = nil
  player.armor = nil
  player.accessory = nil
  player.inventory = {}
  player.status_effects = {}

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
0007770000033300000333000005550000088800000ddd0000000000000000000000000000000000000000000000000000000000000000000000000000000000
007777700033333000333330005555500088888000ddddd000000000000000000000000000000000000000000000000000000000000000000000000000000000
007777700033333000333330005555500088888000ddddd000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777770033333300333333005555550088888800ddddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000
007777000033330000333aaa005555000088880000ddddd000000000000000000000000000000000000000000000000000000000000000000000000000000000
007777000033330000333aaa005555000088880000ddddd000000000000000000000000000000000000000000000000000000000000000000000000000000000
000777000003330000033a000005550000088800000ddd0000000000000000000000000000000000000000000000000000000000000000000000000000000000
00007700000033000000330000005500000088000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

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
010100003c3403d3403e3003a3100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01010000115401f5402a540000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010100001f5402f6403f640255640266605166501f55000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010100002f3402f5403f5403f6402f6402e5402d5402c5400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010200000e5502d5502c5503b5502a5502950239550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01010000175003d3003f3004a30043300393002f3002a3002530000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011100003c2603c2603c26023250332503c2703c2703c27023350362703e300053000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010100003f4403d4403a4404f4002f4100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011100003c3003a2703e370233301f3403d3404c3601a2602b30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01010000205002040024500325042250424504000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010100003a2003f2003e20033200342003120030200302002a2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101000034100341003410034100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010100001a5001a5001a500195001850017500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01010000265502755025550235502e55011550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
