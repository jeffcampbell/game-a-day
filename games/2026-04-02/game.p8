pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- dungeon escape: turn-based roguelike
-- navigate the dungeon, avoid enemies, reach the exit to win

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

-- difficulty settings per level
function get_enemy_count(lv)
  if lv == 1 then return 8
  elseif lv == 2 then return 10
  elseif lv >= 3 then return 12
  end
  return 8
end

function get_enemy_ai_aggression(lv)
  -- higher level = more likely to move toward player
  if lv == 1 then return 0.7
  elseif lv == 2 then return 0.75
  elseif lv >= 3 then return 0.8
  end
  return 0.7
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

function update_menu()
  if btnp(4) or btnp(5) then
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

  -- player input
  if btnp(0) then px = max(1, px - 1) moved = true end
  if btnp(1) then px = min(8, px + 1) moved = true end
  if btnp(2) then py = max(1, py - 1) moved = true end
  if btnp(3) then py = min(8, py + 1) moved = true end

  if moved then
    _log("player:move:"..px..","..py)
    sfx(1)  -- movement tick
  end

  -- check exit condition
  if px == 8 and py == 8 then
    advance_level()
    return
  end

  -- enemy AI: type-specific movement
  for e in all(enemies) do
    if e.alive then
      if e.type == AGGRESSIVE then
        -- aggressive: chase player with level-scaled aggression
        local agg = get_enemy_ai_aggression(level)
        if rnd() < agg then
          if e.x < px then e.x += 1 end
          if e.x > px then e.x -= 1 end
          if e.y < py then e.y += 1 end
          if e.y > py then e.y -= 1 end
        end
      elseif e.type == LUMBERER then
        -- lumberer: slow, methodical chase (lower aggression)
        local agg = get_enemy_aggression(LUMBERER, level)
        if rnd() < agg then
          if e.x < px then e.x += 1 end
          if e.x > px then e.x -= 1 end
          if e.y < py then e.y += 1 end
          if e.y > py then e.y -= 1 end
        end
      else
        -- bouncer: erratic, random movement (ignores player position)
        if rnd() < 0.6 then
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
      break
    end
  end

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
  print("navigate the dungeon", 20, 40, 7)
  print("reach the exit (bottom right)", 12, 55, 7)
  print("avoid: red (aggressive)", 25, 68, 8)
  print("orange (slow) purple (bouncy)", 12, 78, 5)
  print("z or x to start", 30, 90, 7)
end

function draw_play()
  cls(1)

  -- draw grid
  for x = 1, 8 do
    for y = 1, 8 do
      -- draw cell background
      local col = 1
      if x == 8 and y == 8 then
        col = 11  -- exit is yellow
      end
      rectfill((x-1)*16, (y-1)*16, x*16-1, y*16-1, col)
      rect((x-1)*16, (y-1)*16, x*16-1, y*16-1, 5)
    end
  end

  -- draw enemies (color based on type)
  for e in all(enemies) do
    if e.alive then
      local col = get_enemy_color(e.type)
      circfill((e.x-1)*16+8, (e.y-1)*16+8, 5, col)
    end
  end

  -- draw player
  circfill((px-1)*16+8, (py-1)*16+8, 4, 3)

  -- draw UI
  print("level "..level.."/"..max_levels, 2, 2, 7)
  print("health: "..health.."/"..max_health, 2, 10, 7)
  print("reach: ("..8..","..8..")", 60, 2, 7)

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
