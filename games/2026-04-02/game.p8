pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- dungeon escape: turn-based roguelike with power-ups
-- navigate the dungeon, avoid enemies, collect power-ups, reach the exit to win

-- test infrastructure
testmode = false
test_log = {}
test_inputs = {}
test_input_idx = 0

function _log(msg)
  if testmode then add(test_log, msg) end
end

function _capture()
  if testmode then add(test_log, "screen:"..tostr(stat(0))) end
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
gameover_reason = ""

-- difficulty settings
difficulty = 2  -- 1=easy, 2=normal, 3=hard
selected_difficulty = 2  -- for menu navigation

-- level progression
level = 1
max_levels = 3
level_transition = false
level_transition_timer = 0

-- player data
px, py = 2, 2
health = 3
max_health = 3

-- dungeon
dungeon = {
  width = 8,
  height = 8,
  cells = {}
}

-- enemies
enemies = {}

-- enemy type constants
AGGRESSIVE = 1
LUMBERER = 2
BOUNCER = 3

-- power-up type constants
SHIELD = 1
SPEED = 2
HEALTH = 3
SLOW = 4

-- power-up colors
function get_powerup_color(typ)
  if typ == SHIELD then return 12  -- blue
  elseif typ == SPEED then return 10  -- green
  elseif typ == HEALTH then return 11  -- pink/magenta
  else return 14 end  -- yellow (slow)
end

-- power-ups array
powerups = {}

-- active effects: {type, duration_turns, cooldown}
active_effects = {
  shield = {active = false, duration = 0},
  speed = {active = false, duration = 0, cooldown = 0},
  slow = {active = false, duration = 0}
}

-- difficulty settings per level
function get_enemy_count(lv)
  local base = 0
  if lv == 1 then base = 8
  elseif lv == 2 then base = 10
  elseif lv >= 3 then base = 12
  end

  -- apply difficulty multiplier
  if difficulty == 1 then return flr(base * 0.75)  -- easy: 6-9 enemies
  elseif difficulty == 3 then return flr(base * 1.2)  -- hard: 10-14 enemies
  end
  return base  -- normal: baseline
end

function get_enemy_ai_aggression(lv)
  -- higher level = more likely to move toward player
  local base = 0.7
  if lv == 1 then base = 0.7
  elseif lv == 2 then base = 0.75
  elseif lv >= 3 then base = 0.8
  end

  -- apply difficulty multiplier
  if difficulty == 1 then return base * 0.5  -- easy: 0.35-0.4
  elseif difficulty == 3 then return min(base * 1.2, 0.95)  -- hard: 0.84-0.95
  end
  return base  -- normal: baseline
end

-- determine enemy type distribution per level
-- level 1: mostly bouncers/balanced
-- level 2: more aggressive
-- level 3: very aggressive
function get_enemy_type(lv)
  local r = rnd()
  if lv == 1 then
    -- level 1: 40% aggressive, 30% lumberer, 30% bouncer
    if r < 0.4 then return AGGRESSIVE end
    if r < 0.7 then return LUMBERER end
    return BOUNCER
  elseif lv == 2 then
    -- level 2: 50% aggressive, 25% lumberer, 25% bouncer
    if r < 0.5 then return AGGRESSIVE end
    if r < 0.75 then return LUMBERER end
    return BOUNCER
  else
    -- level 3: 60% aggressive, 25% lumberer, 15% bouncer
    if r < 0.6 then return AGGRESSIVE end
    if r < 0.85 then return LUMBERER end
    return BOUNCER
  end
end

function get_enemy_color(typ)
  if typ == AGGRESSIVE then return 8   -- red
  elseif typ == LUMBERER then return 9 -- orange
  else return 5 end                     -- purple (bouncer)
end

function get_enemy_aggression(typ, lv)
  -- aggressive: standard aggression based on level
  -- lumberer: lower, slower ramp
  -- bouncer: random/erratic (we use special logic for this)
  if typ == AGGRESSIVE then
    return get_enemy_ai_aggression(lv)
  elseif typ == LUMBERER then
    -- lumberer moves slower, aggression ramps slower
    if lv == 1 then return 0.3
    elseif lv == 2 then return 0.35
    else return 0.4 end
  else
    -- bouncer is random, doesn't follow normal aggression
    return 0
  end
end

-- init
function _init()
  reset_game()
end

function reset_game()
  level = 1
  px, py = 2, 2
  health = max_health
  level_transition = false
  level_transition_timer = 0
  setup_level()
  _log("state:play")
  state = "play"
end

function setup_level()
  enemies = {}
  powerups = {}

  -- reset active effects
  active_effects.shield.active = false
  active_effects.shield.duration = 0
  active_effects.speed.active = false
  active_effects.speed.duration = 0
  active_effects.speed.cooldown = 0
  active_effects.slow.active = false
  active_effects.slow.duration = 0

  local enemy_count = get_enemy_count(level)

  -- place random enemies (not in starting area)
  for i = 1, enemy_count do
    local ex, ey = rnd(8), rnd(8)
    while (ex < 1 or ey < 1) or (abs(ex - px) < 2 and abs(ey - py) < 2) do
      ex, ey = rnd(8), rnd(8)
    end
    local etype = get_enemy_type(level)
    add(enemies, {x = flr(ex), y = flr(ey), alive = true, type = etype})
    local type_name = "unknown"
    if etype == AGGRESSIVE then type_name = "aggressive"
    elseif etype == LUMBERER then type_name = "lumberer"
    else type_name = "bouncer" end
    _log("enemy:type:"..type_name)
  end

  -- spawn power-ups (2-3 per level, fewer on level 1, more on level 3)
  -- difficulty affects spawn rate: easy has more, hard has fewer
  local powerup_count = 2
  if level == 1 then powerup_count = 2
  elseif level == 3 then powerup_count = 3
  end

  -- apply difficulty multiplier
  if difficulty == 1 then powerup_count = flr(powerup_count * 1.5)  -- easy: +50%
  elseif difficulty == 3 then powerup_count = max(1, flr(powerup_count * 0.6))  -- hard: -40%
  end

  for i = 1, powerup_count do
    local px2, py2 = flr(rnd(8)) + 1, flr(rnd(8)) + 1
    local on_enemy = true
    -- ensure powerup not in starting area, not on enemy, and not at exit
    while on_enemy or (abs(px2 - 2) < 2 and abs(py2 - 2) < 2) or (px2 == 8 and py2 == 8) do
      px2, py2 = flr(rnd(8)) + 1, flr(rnd(8)) + 1
      on_enemy = false
      for e in all(enemies) do
        if e.alive and e.x == px2 and e.y == py2 then
          on_enemy = true
          break
        end
      end
    end

    -- pick random powerup type
    local ptype = flr(rnd(4)) + 1
    add(powerups, {x = px2, y = py2, type = ptype})
    local ptype_name = "unknown"
    if ptype == SHIELD then ptype_name = "shield"
    elseif ptype == SPEED then ptype_name = "speed"
    elseif ptype == HEALTH then ptype_name = "health"
    else ptype_name = "slow" end
    _log("powerup:spawn:"..ptype_name)
  end

  _log("level:"..level)
end

function advance_level()
  level += 1
  if level > max_levels then
    -- final level reached, player wins
    _log("gameover:win")
    sfx(3)  -- win chime
    gameover_reason = "win"
    state = "gameover"
  else
    -- advance to next level
    _log("level_advance:"..level)
    sfx(0)  -- level up sound
    level_transition = true
    level_transition_timer = 60  -- 1 second at 60fps
    px, py = 2, 2  -- reset position
    setup_level()
  end
end

function apply_powerup(ptype)
  sfx(5)  -- power-up collection sound
  if ptype == SHIELD then
    _log("powerup:shield")
    active_effects.shield.active = true
    active_effects.shield.duration = 4
  elseif ptype == SPEED then
    _log("powerup:speed")
    if active_effects.speed.cooldown <= 0 then
      active_effects.speed.active = true
      active_effects.speed.duration = 5
      active_effects.speed.cooldown = 3  -- cooldown after effect expires
    end
  elseif ptype == HEALTH then
    _log("powerup:health")
    if health < max_health then
      health += 1
      _log("health:"..health)
    end
  else  -- SLOW
    _log("powerup:slow")
    active_effects.slow.active = true
    active_effects.slow.duration = 4
  end
end

function update_effects()
  -- decrement duration timers
  if active_effects.shield.duration > 0 then
    active_effects.shield.duration -= 1
    if active_effects.shield.duration <= 0 then
      active_effects.shield.active = false
    end
  end

  if active_effects.speed.duration > 0 then
    active_effects.speed.duration -= 1
    if active_effects.speed.duration <= 0 then
      active_effects.speed.active = false
      active_effects.speed.cooldown = 3
    end
  end

  if active_effects.speed.cooldown > 0 then
    active_effects.speed.cooldown -= 1
  end

  if active_effects.slow.duration > 0 then
    active_effects.slow.duration -= 1
    if active_effects.slow.duration <= 0 then
      active_effects.slow.active = false
    end
  end
end

function update_menu()
  -- navigate difficulty selection
  if btnp(2) then  -- up
    selected_difficulty = max(1, selected_difficulty - 1)
  end
  if btnp(3) then  -- down
    selected_difficulty = min(3, selected_difficulty + 1)
  end

  -- confirm selection
  if btnp(4) or btnp(5) then  -- z or x
    difficulty = selected_difficulty
    _log("difficulty:"..difficulty)
    _log("game:start")
    sfx(0)  -- menu beep
    reset_game()
  end
end

function update_play()
  -- handle level transition
  if level_transition then
    level_transition_timer -= 1
    if level_transition_timer <= 0 then
      level_transition = false
    end
    return
  end

  local moved = false

  -- read button input once
  local left = btnp(0)
  local right = btnp(1)
  local up = btnp(2)
  local down = btnp(3)

  -- first move
  if left then px = max(1, px - 1) moved = true end
  if right then px = min(8, px + 1) moved = true end
  if up then py = max(1, py - 1) moved = true end
  if down then py = min(8, py + 1) moved = true end

  -- speed boost: allow second move this turn (same inputs)
  if active_effects.speed.active and moved then
    if left then px = max(1, px - 1) end
    if right then px = min(8, px + 1) end
    if up then py = max(1, py - 1) end
    if down then py = min(8, py + 1) end
  end

  if moved then
    _log("player:move:"..px..","..py)
    sfx(1)  -- movement tick
  end

  -- check power-up collection
  for i = #powerups, 1, -1 do
    local p = powerups[i]
    if p.x == px and p.y == py then
      apply_powerup(p.type)
      deli(powerups, i)
    end
  end

  -- check exit condition
  if px == 8 and py == 8 then
    advance_level()
    return
  end

  -- enemy AI: type-specific movement
  for e in all(enemies) do
    if e.alive then
      -- apply slowdown if slow effect is active
      local slow_mult = 1
      if active_effects.slow.active then
        slow_mult = 0.3  -- 30% chance to move
      end

      if e.type == AGGRESSIVE then
        -- aggressive: chase player with level-scaled aggression
        local agg = get_enemy_ai_aggression(level) * slow_mult
        if rnd() < agg then
          if e.x < px then e.x += 1 end
          if e.x > px then e.x -= 1 end
          if e.y < py then e.y += 1 end
          if e.y > py then e.y -= 1 end
        end
      elseif e.type == LUMBERER then
        -- lumberer: slow, methodical chase (lower aggression)
        local agg = get_enemy_aggression(LUMBERER, level) * slow_mult
        if rnd() < agg then
          if e.x < px then e.x += 1 end
          if e.x > px then e.x -= 1 end
          if e.y < py then e.y += 1 end
          if e.y > py then e.y -= 1 end
        end
      else
        -- bouncer: erratic, random movement (ignores player position)
        local bounce_chance = 0.6 * slow_mult
        if rnd() < bounce_chance then
          -- random direction
          local dx = rnd(3) - 1  -- -1, 0, or 1
          local dy = rnd(3) - 1
          if abs(dx) + abs(dy) > 0 then
            e.x += sgn(dx)
            e.y += sgn(dy)
          end
        end
      end
      e.x = mid(1, e.x, 8)
      e.y = mid(1, e.y, 8)
    end
  end

  -- check collision with enemies
  for e in all(enemies) do
    if e.alive and e.x == px and e.y == py then
      if active_effects.shield.active then
        _log("player:shield_blocked")
        sfx(6)  -- shield block sound
        -- move player back randomly
        px = mid(1, px + rnd(3) - 1, 8)
        py = mid(1, py + rnd(3) - 1, 8)
      else
        health -= 1
        _log("player:hit")
        sfx(2)  -- hit sound
        -- move player back randomly
        px = mid(1, px + rnd(3) - 1, 8)
        py = mid(1, py + rnd(3) - 1, 8)
        if health <= 0 then
          _log("gameover:lose")
          sfx(4)  -- lose sound
          gameover_reason = "lose"
          state = "gameover"
        end
      end
      break
    end
  end

  -- update active effects
  update_effects()

  -- spawn new enemy occasionally
  local max_enemies = get_enemy_count(level) + 4
  if rnd() < 0.05 and #enemies < max_enemies then
    local ex = rnd(2) < 1 and 1 or 8
    local ey = flr(rnd(8)) + 1
    local etype = get_enemy_type(level)
    add(enemies, {x = flr(ex), y = flr(ey), alive = true, type = etype})
    local type_name = "unknown"
    if etype == AGGRESSIVE then type_name = "aggressive"
    elseif etype == LUMBERER then type_name = "lumberer"
    else type_name = "bouncer" end
    _log("enemy:type:"..type_name)
  end
end

function update_gameover()
  if btnp(4) or btnp(5) then
    _log("state:menu")
    state = "menu"
  end
end

function _update()
  if state == "menu" then update_menu()
  elseif state == "play" then update_play()
  elseif state == "gameover" then update_gameover()
  end
end

-- drawing
function draw_menu()
  cls(1)
  print("dungeon escape", 35, 20, 7)

  -- draw difficulty selector
  print("select difficulty:", 24, 38, 7)

  -- easy
  local easy_col = 8
  if selected_difficulty == 1 then
    easy_col = 11
    print(">", 20, 52, 11)
  end
  print("easy", 28, 52, easy_col)
  print("6-8 enemies, slow", 28, 59, 8)

  -- normal
  local norm_col = 8
  if selected_difficulty == 2 then
    norm_col = 11
    print(">", 20, 70, 11)
  end
  print("normal", 28, 70, norm_col)
  print("8-10 enemies, balanced", 24, 77, 8)

  -- hard
  local hard_col = 8
  if selected_difficulty == 3 then
    hard_col = 11
    print(">", 20, 88, 11)
  end
  print("hard", 28, 88, hard_col)
  print("10-14 enemies, fast", 24, 95, 8)

  print("^/v to select, z/x to start", 12, 110, 7)
end

function draw_play()
  cls(1)

  -- draw grid with wall sprites
  for x = 1, 8 do
    for y = 1, 8 do
      -- draw wall background
      if x == 8 and y == 8 then
        -- exit cell - use exit sprite
        sspr(40, 0, 8, 8, (x-1)*16, (y-1)*16, 16, 16)
      else
        -- regular wall cell
        sspr(32, 0, 8, 8, (x-1)*16, (y-1)*16, 16, 16)
      end
    end
  end

  -- draw power-ups as colored circles
  for p in all(powerups) do
    local col = get_powerup_color(p.type)
    circfill((p.x-1)*16 + 8, (p.y-1)*16 + 8, 4, col)
  end

  -- draw enemies (sprite based on type)
  for e in all(enemies) do
    if e.alive then
      local sprite_x = 8 + (e.type - 1) * 8  -- sprites 8, 16, 24 for types 1, 2, 3
      sspr(sprite_x, 0, 8, 8, (e.x-1)*16, (e.y-1)*16, 16, 16)
    end
  end

  -- draw player
  sspr(0, 0, 8, 8, (px-1)*16, (py-1)*16, 16, 16)

  -- draw UI
  print("level "..level.."/"..max_levels, 2, 2, 7)
  print("health: "..health.."/"..max_health, 2, 10, 7)
  print("reach: ("..8..","..8..")", 60, 2, 7)

  -- draw active power-ups status
  local hud_y = 20
  if active_effects.shield.active then
    print("shield:"..active_effects.shield.duration, 2, hud_y, 12)
    hud_y += 8
  end
  if active_effects.speed.active then
    print("speed:"..active_effects.speed.duration, 2, hud_y, 10)
    hud_y += 8
  end
  if active_effects.slow.active then
    print("slow enemies:"..active_effects.slow.duration, 2, hud_y, 14)
    hud_y += 8
  end

  -- draw level transition feedback
  if level_transition then
    print("level "..level.."!", 45, 60, 11)
  end
end

function draw_gameover()
  cls(1)
  if gameover_reason == "win" then
    print("you win!", 50, 30, 11)
    print("escaped the dungeon!", 28, 45, 7)
    print("level "..level.."/"..max_levels.." cleared", 25, 55, 11)
  else
    print("you lose!", 50, 30, 8)
    print("defeated by enemies", 28, 45, 7)
    print("level "..level.." reached", 35, 55, 8)
  end
  print("z or x to menu", 35, 70, 7)
end

function _draw()
  if state == "menu" then draw_menu()
  elseif state == "play" then draw_play()
  elseif state == "gameover" then draw_gameover()
  end
end

__gfx__
00033000000880000009900000055000055555555abbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000
00333300008888000099990005555500555555550ab0bb0b000000000000000000000000000000000000000000000000000000000000000000000000000000
00333300088888809999999055555550555555550ab0bb0b000000000000000000000000000000000000000000000000000000000000000000000000000000
00033000088888809999999055555550555555550ab0bb0b000000000000000000000000000000000000000000000000000000000000000000000000000000
00033000088888809999999055555550555555550ab0bb0b000000000000000000000000000000000000000000000000000000000000000000000000000000
00333300008888000099990005555500555555550ab0bb0b000000000000000000000000000000000000000000000000000000000000000000000000000000
00333300000880000009900000055000055555555abbbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000
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
000700000f6f00f6f00f6f00f6f00f6f00f6f00f6f00f6f00f6f00f6f00f6f00f6f000000000000000000000000000000000000000000000000000000000000000
000100000f7f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0006000005750575057505750475047504750375037503750275027502750000000000000000000000000000000000000000000000000000000000000000000000
00110000067f077f087f097f0a7f0a7f0a7f097f087f077f067f057f047f0000000000000000000000000000000000000000000000000000000000000000000000
00110000097f087f077f067f057f047f037f027f017f007f0000000000000000000000000000000000000000000000000000000000000000000000000000000000

__label__
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
