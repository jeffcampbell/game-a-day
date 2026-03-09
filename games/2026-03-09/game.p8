pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
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

-- helper: apply ability visual effects
function apply_fx(dmg, px, py, pcol, pcount, si, sc, fcol, ft)
  if dmg ~= 0 then
    add_damage_popup(dmg, px, py)
    add_particles(px, py, pcol, pcount)
  end
  if si > 0 then screen_shake(si, 5) end
  if fcol then
    anim.flash_color.active = true
    anim.flash_color.col = fcol
    anim.flash_color.timer = ft or 2
  end
  if sc > 0 then sfx(sc) end
end

equipment_list = {
  {name="wooden sword", atk=2},
  {name="iron sword", atk=3},
  {name="steel sword", atk=4},
  {name="silver sword", atk=5},
  {name="cloth armor", def=1},
  {name="leather armor", def=2},
  {name="steel armor", def=2},
  {name="mithril armor", def=3},
  {name="health ring", hp=3},
  {name="vigor amulet", hp=5},
  {name="golden ring", atk=1, def=1, hp=4}
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
  is_elite = false,
  type = 0,
  ability_active = false,
  ability_power = 0,  -- multiplier for damage boost (rage: 1.5, challenge: 1.5)
  ability_def_boost = 0,  -- def boost amount
  ability_duration = 0,  -- remaining turns for buff
  status_effects = {}  -- poison, stun, paralysis
}

-- combat state
combat_log = {}
turn = 0
player_action = nil
combat_over = false
player_won = false
combat_escaped = false
boss_defeated = false
show_equip_menu = false
equip_menu_sel = 0
show_items_menu = false
items_menu_sel = 0

-- multi-floor dungeon progression
current_floor = 1
max_floors = 5
floor_enemies = {
  {type=0, count=2},   -- floor 1: 2 goblins
  {type=1, count=2},   -- floor 2: 2 archers
  {type=2, count=2},   -- floor 3: 2 trolls
  {type=3, count=1},   -- floor 4: 1 orc (mini-boss)
  {type=4, count=1}    -- floor 5: 1 final boss
}
floor_enemy_idx = 1
floor_combat_count = 0
pending_loot = nil

boss_types = {
  warrior = {hp_mult=1.0, atk_mult=1.0, def_mult=1.0, color=8},
  mage = {hp_mult=0.9, atk_mult=1.1, def_mult=0.8, color=12},
  berserker = {hp_mult=1.2, atk_mult=0.9, def_mult=0.7, color=14}
}
enemy.boss_type = "warrior"  -- current boss type

boss_abilities = {
  power_attack = {hp_threshold = 0.5, charged = false, recovery_turn = 0},
  heal = {hp_threshold = 0.75, used = false},
  multi_strike = {hp_threshold = 0.25},
  spell_burst = {hp_threshold = 0.6, used = false},
  arcane_shield = {hp_threshold = 0.4, active = false, duration = 0},
  rampage = {hp_threshold = 0.7, active = false, damage_mult = 1.0, duration = 0},
  crush = {hp_threshold = 0.3, used = false}
}

-- boss pattern system (attack sequences that cycle throughout fight)
boss_pattern_system = {
  patterns = {
    -- warrior patterns
    warrior = {
      {name="aggressive", threshold=0.75, turns={"power_attack","power_attack"}},
      {name="balanced", threshold=0.50, turns={"heal","power_attack"}},
      {name="desperate", threshold=0.25, turns={"multi_strike","multi_strike"}},
      {name="frenzy", threshold=0, turns={"power_attack","multi_strike"}}
    },
    -- mage patterns
    mage = {
      {name="spellcast", threshold=0.75, turns={"spell_burst","spell_burst"}},
      {name="defensive", threshold=0.50, turns={"arcane_shield","spell_burst"}},
      {name="frantic", threshold=0.25, turns={"spell_burst","spell_burst"}},
      {name="desperate", threshold=0, turns={"spell_burst","arcane_shield"}}
    },
    -- berserker patterns
    berserker = {
      {name="rampage", threshold=0.75, turns={"rampage","power_attack"}},
      {name="enraged", threshold=0.50, turns={"power_attack","rampage"}},
      {name="berserk", threshold=0.25, turns={"crush","power_attack"}},
      {name="frenzy", threshold=0, turns={"crush","crush"}}
    }
  },
  current_pattern_idx = 1,
  current_turn_idx = 1,
  prev_hp_pct = 1.0,
  pattern_name = "aggressive"
}

-- enemy abilities (for regular enemies)
enemy_abilities = {
  -- archer (type 1)
  archer_rapid_fire = {
    type = 1,
    hp_threshold = 0.5,
    used = false
  },
  -- troll (type 2)
  troll_stone_skin = {
    type = 2,
    hp_threshold = 0.6,
    active = false,
    duration = 0
  },
  troll_regen = {
    type = 2,
    hp_threshold = 0.3,
    used = false
  },
  -- orc warrior (type 3)
  orc_rage = {
    type = 3,
    hp_threshold = 0.5,
    active = false,
    duration = 0
  },
  orc_challenge = {
    type = 3,
    hp_threshold = 0.4,
    active = false,
    duration = 0
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
          -- auto-pickup loot
          if pending_loot then
            add(player.inventory, pending_loot)
            pending_loot = nil
          end
          -- check if floor is complete
          local floor_info = floor_enemies[current_floor]
          if floor_combat_count >= floor_info.count then
            -- move to next floor
            if current_floor >= max_floors then
              _log("state:gameover")
              _log("gameover:win")
              state = "gameover"
              boss_defeated = true
              prev_input = input
              return
            else
              current_floor += 1
              floor_combat_count = 0
              add(combat_log, "advancing to floor "..current_floor.."...")
              _log("floor:"..current_floor)
              reset_combat()
            end
          else
            reset_combat()
          end
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
        sfx(2)  -- attack sound
        combat_step()
        _log("action:attack")
      -- right (button 1) - defend
      elseif (input & 2) > 0 and (prev_input & 2) == 0 then
        player_action = "defend"
        sfx(6)  -- defend sound
        combat_step()
        _log("action:defend")
      -- up (button 2) - potion
      elseif (input & 4) > 0 and (prev_input & 4) == 0 then
        if player.potions > 0 then
          player_action = "potion"
            sfx(5)  -- heal/potion sound
          combat_step()
          _log("action:potion")
        end
      -- down (button 3) - flee
      elseif (input & 8) > 0 and (prev_input & 8) == 0 then
        player_action = "flee"
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
      local col = get_status_color(s)
      -- draw background for visibility
      rectfill(x-1, 35, x+16, 43, 0)
      rect(x-1, 35, x+16, 43, col)
      print(l, x, 37, col)
      x += 19
    end
  end
end

function draw_play()
  -- header
  print("level "..player.level, 5, 5, 7)
  print("hp: "..player.hp.."/"..player.max_hp, 50, 5, 7)
  print("floor "..current_floor.."/"..max_floors, 90, 5, 11)

  -- equipment in header
  local wep_str = "no weapon"
  if player.weapon then wep_str = player.weapon.name end
  print(wep_str, 5, 13, 6)

  -- enemy
  local enemy_name = "boss"
  local name_col = 8
  if not enemy.is_boss then
    enemy_name = enemy.type == 1 and "goblin archer" or (enemy.type == 2 and "troll" or (enemy.type == 3 and "orc warrior" or "goblin"))
    if enemy.is_elite then
      enemy_name = "ELITE "..enemy_name
      name_col = 9  -- orange for elite
    end
  else
    -- display boss type name
    local btype = boss_types[enemy.boss_type]
    enemy_name = btype.desc.." Boss"
  end
  print(enemy_name.." hp: "..enemy.hp.."/"..enemy.max_hp, 12, 28, name_col)

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
  else
    -- equipment progression color changes
    local equipment_count = (player.weapon and 1 or 0) + (player.armor and 1 or 0)
    if equipment_count >= 2 then
      player_col = 14  -- pink for fully equipped (legendary)
    elseif player.weapon then
      player_col = 8   -- red for weapon
    elseif player.armor then
      player_col = 6   -- gray for armor
    end
  end

  spr(player_spr, player_x, player_y)

  -- draw enhanced equipment indicators
  if player.weapon then
    -- weapon: draw sword-like indicator
    pset(player_x + 6, player_y, 8)   -- weapon glow
    pset(player_x + 7, player_y - 1, 8)
  end
  if player.armor then
    -- armor: draw shield-like indicator
    pset(player_x + 1, player_y - 1, 6)   -- armor glow
    pset(player_x + 0, player_y, 6)
  end

  -- draw health aura based on remaining HP percent
  if player.hp > 0 then
    local hp_pct = player.hp / player.max_hp
    local aura_col = 11  -- green if healthy
    if hp_pct < 0.5 then aura_col = 8  -- red if low HP
    elseif hp_pct < 0.75 then aura_col = 10  -- yellow if medium HP
    end
    if hp_pct <= 0.99 then
      pset(player_x - 1, player_y + 4, aura_col)  -- HP indicator at feet
    end
  end

  -- draw enemy sprite with flinch animation
  local enemy_x = 80
  local enemy_y = 43
  local enemy_spr = 1  -- default goblin
  if enemy.is_boss then
    enemy_spr = 5  -- boss
  elseif enemy.is_elite then
    -- elite variant sprites
    if enemy.type == 1 then
      enemy_spr = 6  -- elite goblin archer
    elseif enemy.type == 2 then
      enemy_spr = 7  -- elite troll
    elseif enemy.type == 3 then
      enemy_spr = 8  -- elite orc warrior
    else
      enemy_spr = 6  -- default elite variant
    end
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
    -- use boss type color
    local btype = boss_types[enemy.boss_type]
    enemy_col = btype.color
  elseif enemy.is_elite then
    enemy_col = 9  -- orange for elite
  elseif enemy.type == 2 then
    enemy_col = 3  -- troll is greenish
  elseif enemy.type == 3 then
    enemy_col = 2  -- warrior is reddish
  end

  spr(enemy_spr, enemy_x, enemy_y)

  -- draw status effect indicators above enemy sprite
  local status_x = enemy_x + 1
  local status_y = enemy_y - 4
  if has_status("poison") then
    -- green poison aura (3x2 indicator)
    pset(status_x, status_y, 11)
    pset(status_x + 1, status_y, 11)
    pset(status_x + 2, status_y, 11)
    pset(status_x, status_y - 1, 11)
    pset(status_x + 2, status_y - 1, 11)
  end
  if has_status("stun") then
    -- yellow stun sparks (zigzag pattern)
    pset(status_x + 3, status_y - 1, 10)
    pset(status_x + 4, status_y, 10)
    pset(status_x + 5, status_y - 1, 10)
    pset(status_x + 4, status_y - 2, 10)
  end
  if has_status("paralysis") then
    -- blue paralysis lines (vertical striped)
    pset(status_x + 6, status_y - 1, 12)
    pset(status_x + 6, status_y, 12)
    pset(status_x + 7, status_y - 1, 12)
    pset(status_x + 7, status_y, 12)
  end

  -- draw damage popups with outline for visibility
  for popup in all(anim.damage_popups) do
    local alpha = popup.timer / 30
    local col = 8  -- red damage
    if popup.val < 0 then col = 11 end  -- green heal
    local px = flr(popup.x)
    local py = flr(popup.y)
    -- draw outline for better visibility
    print(abs(popup.val), px-1, py, 0)
    print(abs(popup.val), px+1, py, 0)
    print(abs(popup.val), px, py-1, 0)
    print(abs(popup.val), px, py+1, 0)
    -- draw main number
    print(abs(popup.val), px, py, col)
  end

  -- draw particles
  for p in all(particles) do
    local fade = p.timer / 15
    if fade > 0.5 then
      pset(flr(p.x), flr(p.y), p.col)
    end
  end

  -- combat log
  local log_y = 61
  for i = max(1, #combat_log - 3), #combat_log do
    if combat_log[i] then
      print(combat_log[i], 5, log_y, 7)
      log_y += 7
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
      local col = get_status_color(s)
      -- draw background for visibility
      rectfill(psx-1, 21, psx+16, 29, 0)
      rect(psx-1, 21, psx+16, 29, col)
      print(l, psx, 23, col)
      psx += 19
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

function drop_loot(is_boss, is_elite)
  if not is_boss and rnd() > (is_elite and 0.85 or 0.65) then return end
  if is_boss and rnd() > 0.9 then return end

  local db = {
    {3,0.95},{7,0.9},{10,0.85},{11,0.4},  -- f5
    {3,0.8},{7,0.75},{10,0.6},            -- f4
    {3,0.5},{7,0.45},{9,0.3},             -- f3
    {2,0.5},{6,0.45},{9,0.2},             -- f2
    {1,0.5},{5,0.45},{9,0.1}              -- f1
  }
  local boff = difficulty == 3 and 0.15 or (difficulty == 1 and -0.1 or 0)
  local f = (is_boss or current_floor == 5) and 1 or (current_floor == 4 and 2 or (current_floor == 3 and 3 or (current_floor == 2 and 4 or 5)))
  local st, ed = f*4-3, f*4

  for i = st, ed do
    if rnd() < db[i][2] + (i % 4 == 1 and boff or 0) then
      local item = equipment_list[db[i][1]]
      pending_loot = item
      add(combat_log, item.name.." dropped!")
      _log("loot:"..item.name)
      break
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

-- update boss attack pattern based on hp threshold
function update_boss_pattern()
  if not enemy.is_boss then return end

  local hp_pct = enemy.hp / enemy.max_hp
  local pattern_idx = 1
  local patterns = boss_pattern_system.patterns[enemy.boss_type]

  -- select pattern by hp threshold
  if difficulty == 1 then  -- easy: use only first 3 patterns
    if hp_pct > 0.5 then pattern_idx = 1
    elseif hp_pct > 0.25 then pattern_idx = 2
    else pattern_idx = 3 end
  else  -- normal/hard: all 4 patterns
    if hp_pct > 0.75 then pattern_idx = 1
    elseif hp_pct > 0.5 then pattern_idx = 2
    elseif hp_pct > 0.25 then pattern_idx = 3
    else pattern_idx = 4 end
  end

  -- pattern changed: log transition and reset turn counter
  if pattern_idx ~= boss_pattern_system.current_pattern_idx then
    local pattern = patterns[pattern_idx]
    boss_pattern_system.current_pattern_idx = pattern_idx
    boss_pattern_system.current_turn_idx = 1
    boss_pattern_system.pattern_name = pattern.name
    add(combat_log, "boss enters "..pattern.name.." phase!")
    _log("boss_pattern:"..pattern.name)
  end
end

-- boss special abilities with pattern system
function get_boss_ability()
  -- return next action in pattern sequence, with randomness for unpredictability
  if not enemy.is_boss then return nil end

  update_boss_pattern()

  local patterns = boss_pattern_system.patterns[enemy.boss_type]
  local pattern = patterns[boss_pattern_system.current_pattern_idx]
  local turn_idx = boss_pattern_system.current_turn_idx
  local pattern_action = pattern.turns[turn_idx]

  -- advance turn counter for next call
  boss_pattern_system.current_turn_idx += 1
  if boss_pattern_system.current_turn_idx > #pattern.turns then
    boss_pattern_system.current_turn_idx = 1
  end

  -- add randomness to make patterns not completely predictable
  -- 25% chance to deviate from pattern and do a normal attack
  if rnd() < 0.25 then
    return nil  -- normal attack
  end

  -- validate ability can be used (check limits like heal.used, arcane_shield active)
  if pattern_action == "heal" and boss_abilities.heal.used then
    return nil
  end
  if pattern_action == "arcane_shield" and boss_abilities.arcane_shield.active then
    return nil
  end
  if pattern_action == "rampage" and boss_abilities.rampage.active then
    return nil
  end
  if pattern_action == "crush" and boss_abilities.crush.used then
    return nil
  end
  if pattern_action == "spell_burst" and boss_abilities.spell_burst.used then
    return nil
  end

  return pattern_action
end

function execute_boss_ability(ability, player_def)
  local ab = {power_attack={msg="boss power attack! ",dmg_mult=2,si=2,sc=12,fcol=8,ft=2,rock=true},
    heal={msg="boss heals +8 hp!",heal=8,sc=13,fcol=11,ft=3},
    multi_strike={msg="boss strikes 3x!",hits=3,dmg_var=2,si=2,sc=14,fcol=8,ft=3},
    spell_burst={msg="mage spells!",hits=2,dmg_mult=1.3,def_mult=0.5,si=0,sc=15,fcol=12,ft=2,px=50,py=30},
    arcane_shield={msg="shield raised!",sc=16,fcol=12,ft=2,shield=true},
    rampage={msg="berserker rages!",dmg_var=3,si=2,sc=12,fcol=14,ft=2,rock=true,ramp=true},
    crush={msg="crush! ",dmg_var=3,dmg_mult=1.8,si=2,sc=14,fcol=14,ft=3}}[ability]

  if not ab then return end
  local dmg, total = 0, 0

  if ab.shield then
    add(combat_log, ab.msg)
    add_particles(85, 45, 12, 5)
    boss_abilities.arcane_shield.active = true
    boss_abilities.arcane_shield.duration = 2
  elseif ab.heal then
    enemy.hp = min(enemy.max_hp, enemy.hp + ab.heal)
    add(combat_log, ab.msg)
    add_damage_popup(-ab.heal, 85, 40)
    add_particles(85, 45, 11, 5)
    boss_abilities.heal.used = true
  else
    local hits = ab.hits or 1
    add(combat_log, ab.msg)
    for i = 1, hits do
      local base = ab.dmg_mult or 1
      local def_r = ab.def_mult or 1
      dmg = max(1, flr(enemy.atk * base) - flr(player_def * def_r) + flr(rnd((ab.dmg_var or 2) - 1)))
      total += dmg
      player.hp -= dmg
      add_damage_popup(dmg, ab.px or 25, ab.py or 40)
    end
    if total > 0 then add(combat_log, "dmg: "..total) end
    add_particles(ab.px or 25, ab.py or 45, ab.fcol or 8, ab.hits and 7 or 5)
    if ab.rock then anim.player_swing.active = true
      anim.player_swing.frame = 0 end
    if ab.ramp then
      boss_abilities.rampage.active = true
      boss_abilities.rampage.duration = 2
      boss_abilities.rampage.damage_mult += 0.2
    end
    if ability == "power_attack" then
      boss_abilities.power_attack.charged = true
      boss_abilities.power_attack.recovery_turn = 1
    elseif ability == "spell_burst" then
      boss_abilities.spell_burst.used = true
    elseif ability == "crush" then
      boss_abilities.crush.used = true
    end
  end
  apply_fx(total > 0 and total or 0, 0, 0, ab.fcol, 0, ab.si or 0, ab.sc or 0, ab.fcol, ab.ft)
  _log("boss_ability:"..ability)
end

-- enemy special abilities
function get_enemy_ability()
  -- return ability to use, or nil for normal attack
  if enemy.is_boss or current_floor < 2 then return nil end  -- no abilities on floor 1

  local hp_pct = enemy.hp / enemy.max_hp
  local ability = nil

  if enemy.type == 1 then  -- archer
    if hp_pct <= 0.5 and not enemy_abilities.archer_rapid_fire.used then
      ability = "archer_rapid_fire"
    end
  elseif enemy.type == 2 then  -- troll
    if hp_pct <= 0.6 and not enemy_abilities.troll_stone_skin.active then
      ability = "troll_stone_skin"
    elseif hp_pct <= 0.3 and not enemy_abilities.troll_regen.used then
      ability = "troll_regen"
    end
  elseif enemy.type == 3 then  -- orc warrior
    if hp_pct <= 0.5 and not enemy_abilities.orc_rage.active then
      ability = "orc_rage"
    elseif hp_pct <= 0.4 and not enemy_abilities.orc_challenge.active then
      ability = "orc_challenge"
    end
  end

  -- difficulty scaling: hard mode has chance to use ability even without threshold
  if ability == nil and difficulty == 3 and rnd() < 0.1 then
    if enemy.type == 1 and not enemy_abilities.archer_rapid_fire.used then
      ability = "archer_rapid_fire"
    elseif enemy.type == 2 and rnd() < 0.5 then
      if not enemy_abilities.troll_stone_skin.active then
        ability = "troll_stone_skin"
      elseif not enemy_abilities.troll_regen.used then
        ability = "troll_regen"
      end
    elseif enemy.type == 3 and rnd() < 0.5 then
      if not enemy_abilities.orc_rage.active then
        ability = "orc_rage"
      elseif not enemy_abilities.orc_challenge.active then
        ability = "orc_challenge"
      end
    end
  end

  return ability
end

function execute_enemy_ability(ability, player_def)
  if ability == "archer_rapid_fire" then
    add(combat_log, "archer uses rapid fire!")
    sfx(11)
    for i = 1, 2 do
      local dmg = max(1, flr(enemy.atk * 0.7) - player_def + flr(rnd(2)))
      player.hp -= dmg
      add_damage_popup(dmg, 25, 40 - i*5)
      add_particles(25, 45, 8, 2)
    end
    screen_shake(2, 4)
    anim.flash_color.active = true
    anim.flash_color.col = 8
    anim.flash_color.timer = 3
    enemy_abilities.archer_rapid_fire.used = true
    _log("enemy_ability:archer_rapid_fire")
  elseif ability == "troll_stone_skin" then
    add(combat_log, "troll hardens its skin!")
    enemy.ability_active = true
    enemy.ability_def_boost = 2
    enemy.ability_duration = 2
    sfx(15)
    add_particles(85, 45, 14, 6)
    anim.flash_color.active = true
    anim.flash_color.col = 6
    anim.flash_color.timer = 3
    enemy_abilities.troll_stone_skin.active = true
    enemy_abilities.troll_stone_skin.duration = 2
    _log("enemy_ability:troll_stone_skin")
  elseif ability == "troll_regen" then
    add(combat_log, "troll regenerates!")
    enemy.hp = min(enemy.max_hp, enemy.hp + 3)
    sfx(13)
    add_damage_popup(-3, 85, 40)
    add_particles(85, 45, 11, 5)
    anim.flash_color.active = true
    anim.flash_color.col = 11
    anim.flash_color.timer = 3
    enemy_abilities.troll_regen.used = true
    _log("enemy_ability:troll_regen")
  elseif ability == "orc_rage" then
    add(combat_log, "orc enters a rage!")
    enemy.ability_active = true
    enemy.ability_power = 1.5
    enemy.ability_duration = 1
    sfx(16)
    add_particles(85, 45, 8, 7)
    screen_shake(2, 4)
    anim.flash_color.active = true
    anim.flash_color.col = 8
    anim.flash_color.timer = 4
    enemy_abilities.orc_rage.active = true
    enemy_abilities.orc_rage.duration = 1
    _log("enemy_ability:orc_rage")
  elseif ability == "orc_challenge" then
    add(combat_log, "orc challenges you!")
    enemy.ability_active = true
    enemy.ability_power = 1.5
    enemy.ability_duration = 2
    sfx(16)
    add_particles(85, 45, 10, 5)
    anim.flash_color.active = true
    anim.flash_color.col = 9
    anim.flash_color.timer = 3
    enemy_abilities.orc_challenge.active = true
    enemy_abilities.orc_challenge.duration = 2
    _log("enemy_ability:orc_challenge")
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

function update_enemy_abilities()
  if enemy.ability_active and enemy.ability_duration > 0 then
    enemy.ability_duration -= 1
    if enemy.ability_duration <= 0 then
      enemy.ability_active = false
      enemy.ability_power = 0
      enemy.ability_def_boost = 0
    end
  end
  for name,ab in pairs(enemy_abilities) do
    if ab.duration and ab.duration > 0 then
      ab.duration -= 1
      if ab.duration <= 0 and ab.active then ab.active = false end
    end
  end
end

function update_boss_abilities()
  for name,ab in pairs(boss_abilities) do
    if ab.duration and ab.duration > 0 then
      ab.duration -= 1
      if ab.duration <= 0 then
        ab.active = false
        if name == "rampage" then ab.damage_mult = 1.0 end
      end
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

    -- screen shake on crit (high damage) - subtle
    if dmg >= 6 then
      screen_shake(1, 5)
      anim.flash_color.active = true
      anim.flash_color.col = 8
      anim.flash_color.timer = 3
    else
      screen_shake(1, 3)
    end
  elseif player_action == "defend" then
    add(combat_log, "you brace! def+2")
    anim.flash_color.active = true
    anim.flash_color.col = 6  -- blue for defense
    anim.flash_color.timer = 3
  elseif player_action == "potion" then
    local heal = 8
    player.hp = min(player.max_hp, player.hp + heal)
    player.potions -= 1
    add(combat_log, "drink potion +"..heal.." hp")
    -- heal effect: green popup and particles
    add_damage_popup(-heal, 25, 40)
    add_particles(25, 45, 11, 4)  -- green healing particles
    sfx(5)  -- heal/potion sound
    anim.flash_color.active = true
    anim.flash_color.col = 11
    anim.flash_color.timer = 2
  elseif player_action == "item_antidote" then
    add(combat_log, "poison removed!")
  elseif player_action == "item_cure" then
    add(combat_log, "status effects removed!")
  elseif player_action == "flee" then
    if rnd() < 0.5 then
      add(combat_log, "fled safely!")
      combat_over = true
      combat_escaped = true
      return
    else
      add(combat_log, "can't escape!")
    end
  end

  -- check enemy defeated
  if enemy.hp <= 0 then
    enemy.hp = 0
    add(combat_log, "enemy defeated!")
    -- 1.5x exp for elite enemies
    local exp_gain = 10
    if enemy.is_elite then
      exp_gain = flr(exp_gain * 1.5)
    end
    player.exp += exp_gain
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
    drop_loot(enemy.is_boss, enemy.is_elite)
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
      screen_shake(1, 6)  -- celebratory but not excessive
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
        ability_chance = 0.5  -- only 50% chance on easy
      elseif difficulty == 3 then  -- hard: increase frequency
        ability_chance = 1.2  -- always use (clamped to 1.0 by rnd comparison)
      end

      ability = get_boss_ability()
      if ability and rnd() < min(ability_chance, 1.0) then
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
        screen_shake(1, 3)  -- subtle shake
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
    -- check for special abilities first
    local ability = get_enemy_ability()
    if ability and rnd() < 0.7 then  -- 70% chance to use ability when available
      execute_enemy_ability(ability, player_def)
    else
      -- normal attack or defend
      local enemy_act = flr(rnd(2))
      if enemy_act == 0 then
        -- calculate base damage
        local base_dmg = enemy.atk - player_def + flr(rnd(2))
        -- apply ability damage boost
        if enemy.ability_active and enemy.ability_power > 0 then
          base_dmg = flr(base_dmg * enemy.ability_power)
        end
        dmg = max(1, base_dmg)
        if has_status("paralysis") then
          dmg = max(1, flr(dmg * 0.5))
          add(combat_log, "enemy paralyzed!")
        end

        -- apply player defend and enemy def bonuses
        local player_def_mod = player_def
        if player_action == "defend" then
          player_def_mod += 2
          dmg = max(1, flr(dmg / 2))
        end
        -- apply troll stone skin bonus
        if enemy.ability_active and enemy.ability_def_boost > 0 then
          player_def_mod += enemy.ability_def_boost
          dmg = max(0, dmg - enemy.ability_def_boost)
        end
        -- apply boss arcane shield (50% damage reduction)
        if enemy.is_boss and boss_abilities.arcane_shield.active then
          dmg = max(1, flr(dmg * 0.5))
          add(combat_log, "arcane shield blocks!")
        end

        player.hp -= dmg
        add(combat_log, "enemy attacks! "..dmg.." dmg")
        -- enemy-specific attack sounds
        if enemy.type == 1 then
          sfx(11)  -- archer sound
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
        screen_shake(1, 3)  -- subtle
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
  update_enemy_abilities()
  update_boss_abilities()

  turn += 1
end

function reset_combat()
  turn = 0
  combat_log = {}
  player_action = nil
  combat_over = false
  player_won = false
  combat_escaped = false
  pending_loot = nil
  enemy.status_effects = {}
  enemy.is_elite = false

  -- reset all abilities
  for name,ab in pairs(boss_abilities) do
    for k,v in pairs(ab) do
      if k == "charged" or k == "active" or k == "used" then
        ab[k] = false
      elseif k == "recovery_turn" or k == "duration" then
        ab[k] = 0
      elseif k == "damage_mult" then
        ab[k] = 1.0
      end
    end
  end

  enemy.ability_active = false
  enemy.ability_power = 0
  enemy.ability_def_boost = 0
  enemy.ability_duration = 0

  for name,ab in pairs(enemy_abilities) do
    for k,v in pairs(ab) do
      if k == "active" or k == "used" then ab[k] = false end
      if k == "duration" then ab[k] = 0 end
    end
  end

  boss_pattern_system.current_pattern_idx = 1
  boss_pattern_system.current_turn_idx = 1
  boss_pattern_system.prev_hp_pct = 1.0
  boss_pattern_system.pattern_name = "aggressive"

  -- multi-floor enemy spawning
  local floor_info = floor_enemies[current_floor]
  if not floor_info then return end

  floor_combat_count += 1

  -- determine enemy type for this floor
  local floor_type = floor_info.type
  enemy.type = floor_type

  -- helper: select boss type by difficulty
  local function select_boss_type()
    -- easy: only warrior
    if difficulty == 1 then return "warrior" end
    -- normal: warrior or mage
    if difficulty == 2 then return rnd() < 0.5 and "warrior" or "mage" end
    -- hard: any type (berserker is hardest)
    local r = rnd()
    return r < 0.33 and "warrior" or (r < 0.67 and "mage" or "berserker")
  end

  -- special handling for mini-boss (floor 4) and final boss (floor 5)
  if current_floor == 4 then
    -- floor 4: warrior mini-boss (always warrior, easier encounters)
    enemy.boss_type = "warrior"
    enemy.hp = 18
    enemy.max_hp = 18
    enemy.atk = 7
    enemy.def = 2
    enemy.is_boss = false
    if difficulty == 1 then
      enemy.hp = 12
      enemy.max_hp = 12
      enemy.atk = 4
    elseif difficulty == 3 then
      enemy.hp = 24
      enemy.max_hp = 24
      enemy.atk = 10
    end
    add(combat_log, "a powerful orc appears!")
    _log("mini_boss:warrior")
  elseif current_floor == 5 then
    -- final boss: difficulty-based boss type
    enemy.boss_type = select_boss_type()
    local btype = boss_types[enemy.boss_type]
    enemy.hp = flr(30 * btype.hp_mult)
    enemy.max_hp = enemy.hp
    enemy.atk = flr(8 * btype.atk_mult)
    enemy.def = flr(2 * btype.def_mult)
    enemy.is_boss = true
    enemy.type = 0

    -- difficulty scaling
    if difficulty == 1 then
      enemy.hp = flr(enemy.hp / 2)  -- 50% for easy
      enemy.max_hp = enemy.hp
      enemy.atk = flr(enemy.atk * 0.6)  -- 60% attack
    elseif difficulty == 3 then
      enemy.hp = flr(enemy.hp * 1.3)  -- 130% for hard
      enemy.max_hp = enemy.hp
      enemy.atk = flr(enemy.atk * 1.3)  -- 130% attack
    end

    add(combat_log, "the "..btype.desc.." appears!")
    _log("boss_fight:start:"..enemy.boss_type)
  else
    -- regular floor enemies
    local base_hp = 8 + (current_floor - 1) * 3
    local base_atk = 3 + (current_floor - 1) * 2

    enemy.hp = flr(base_hp * get_stat(floor_type, "hp"))
    enemy.max_hp = enemy.hp
    enemy.atk = flr(base_atk * get_stat(floor_type, "atk"))
    enemy.def = flr(1 * get_stat(floor_type, "def"))
    enemy.is_boss = false

    -- difficulty scaling
    if difficulty == 1 then
      enemy.hp = flr(enemy.hp * 0.65)  -- easier on easy mode
      enemy.max_hp = enemy.hp
      enemy.atk = flr(enemy.atk * 0.65)
    elseif difficulty == 3 then
      enemy.hp = flr(enemy.hp * 1.35)  -- harder on hard mode
      enemy.max_hp = enemy.hp
      enemy.atk = flr(enemy.atk * 1.35)
    end

    -- elite enemy spawn (10-15% chance)
    enemy.is_elite = rnd() < 0.125  -- 12.5% chance
    if enemy.is_elite then
      -- 1.3-1.5x stat scaling
      local mult = 1.3 + rnd() * 0.2
      enemy.hp = flr(enemy.hp * mult)
      enemy.max_hp = enemy.hp
      enemy.atk = flr(enemy.atk * mult)
      enemy.def = flr(enemy.def * mult)
    end

    local ename = floor_type == 1 and "goblin archer" or (floor_type == 2 and "troll" or (floor_type == 3 and "orc warrior" or "goblin"))
    if enemy.is_elite then ename = "ELITE "..ename end
    add(combat_log, "a "..ename.." appears!")
    _log("elite:"..tostr(enemy.is_elite))
  end

  _log("floor:"..current_floor)
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
    player.antidotes = 0  -- no antidotes on hard
    player.cure_scrolls = 0  -- no cures on hard
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

  -- reset floor progression
  current_floor = 1
  floor_combat_count = 0
  pending_loot = nil
end

__gfx__
00077700000333000003330000053300002088800000dd800000333300002033300000533300003333300003333300000000000000000000000000000000000000
00777770003333300033333002535350002088880000ddd8000033333000203333302053535000333333003333330000000000000000000000000000000000000
00777770003333300033333002535350002088880000ddd8000033333000203333302053535000333333003333330000000000000000000000000000000000000
07777770033333300333333025353530020888800ddddddd00033333000203333302053535000333333003333330000000000000000000000000000000000000
00777700003333000033aaaa0253530000208880000dddddd00033333000203332000235332002333330023333300000000000000000000000000000000000000
00777700003333000033aaaa0253530000208880000dddddd00033333000203332000235332002333330023333300000000000000000000000000000000000000
00077700000333000003a0002053300000088800000ddd000003333000203330000235300000333300023330000000000000000000000000000000000000000000
00007700000033000003300000053300000088000000dd0000003300000203300000235300000033000023300000000000000000000000000000000000000000

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
