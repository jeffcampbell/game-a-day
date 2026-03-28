pico-8 cartridge // http://www.pico-8.com
version 42

__lua__

-- Comet Clash - fast-paced action arcade game
-- Dodge incoming comets and asteroids, shoot to survive

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

-- game state
state = "menu"
score = 0
health = 3
wave = 1
boss_health = 0
combo = 0
combo_timer = 0

-- player
player = {x=64, y=110, w=6, h=6, speed=2, alive=true}

-- projectiles
projectiles = {}
boss_projectiles = {}

-- particles
particles = {}

-- enemies
enemies = {}
enemy_spawn_timer = 0
enemy_spawn_rate = 30

-- wave system
wave_timer = 0
wave_duration = 240
boss_active = false
boss_telegraph = 0
boss_attack_interval = 120
boss_last_attack = false
wave_just_changed = false
wave_change_flash = 0

-- functions
function init_game()
  score = 0
  health = 3
  wave = 1
  boss_health = 0
  combo = 0
  combo_timer = 0
  player.x = 64
  player.y = 110
  player.alive = true
  projectiles = {}
  boss_projectiles = {}
  particles = {}
  enemies = {}
  enemy_spawn_timer = 0
  enemy_spawn_rate = 30
  wave_timer = 0
  boss_active = false
  boss_telegraph = 0
  boss_last_attack = false
  wave_just_changed = false
  wave_change_flash = 0
  _log("state:play")
  _log("wave:1")
  _log("difficulty:easy")
end

function create_explosion(x, y)
  for i=1,8 do
    local angle = i / 8
    add(particles, {
      x=x, y=y,
      vx=cos(angle)*0.5,
      vy=sin(angle)*0.5,
      life=30
    })
  end
end

function update_menu()
  if test_input(4) > 0 then
    state = "play"
    init_game()
  end
end

function update_play()
  if not player.alive then
    state = "gameover"
    _log("state:gameover")
    _log("gameover:lose")
    return
  end

  -- player movement
  if test_input(0) > 0 then
    player.x = max(4, player.x - player.speed)
    _log("move:left")
  end
  if test_input(1) > 0 then
    player.x = min(124, player.x + player.speed)
    _log("move:right")
  end

  -- shooting
  if test_input(4) > 0 then
    add(projectiles, {x=player.x, y=player.y-4, speed=3})
    sfx(0)
    _log("shoot")
  end

  -- update projectiles
  for i=#projectiles,1,-1 do
    local p = projectiles[i]
    p.y -= p.speed
    if p.y < 0 then
      deli(projectiles, i)
    end
  end

  -- update boss projectiles
  for i=#boss_projectiles,1,-1 do
    local p = boss_projectiles[i]
    p.y += p.speed
    if p.y > 128 then
      deli(boss_projectiles, i)
    end
  end

  -- update particles
  for i=#particles,1,-1 do
    local pt = particles[i]
    pt.x += pt.vx
    pt.y += pt.vy
    pt.vy += 0.05
    pt.life -= 1
    if pt.life <= 0 then
      deli(particles, i)
    end
  end

  -- combo decay
  if combo > 0 then
    combo_timer -= 1
    if combo_timer <= 0 then
      combo = 0
    end
  end

  -- wave change flash animation
  if wave_just_changed then
    wave_change_flash -= 1
    if wave_change_flash <= 0 then
      wave_just_changed = false
    end
  end

  -- spawn enemies with progressive difficulty
  enemy_spawn_timer += 1
  -- more aggressive spawn rate decrease: 8 per wave instead of 3-5
  local spawn_threshold = max(8, enemy_spawn_rate - wave * 8)

  if enemy_spawn_timer > spawn_threshold and not boss_active then
    local spawn_count = 1

    for s=1,spawn_count do
      local enemy_type = rnd() > 0.5 and "comet" or "asteroid"
      -- more aggressive speed scaling: 0.4 per wave instead of 0.3
      local enemy_speed = 1 + wave * 0.4
      add(enemies, {
        x = rnd(120),
        y = -8,
        speed = enemy_speed,
        type = enemy_type,
        health = enemy_type == "comet" and 2 or 1
      })
      _log("enemy_spawn:"..enemy_type)
    end
    enemy_spawn_timer = 0
  end

  -- update enemies
  for i=#enemies,1,-1 do
    local e = enemies[i]
    e.y += e.speed

    -- check collision with projectiles
    for j=#projectiles,1,-1 do
      local p = projectiles[j]
      if abs(p.x - e.x) < 6 and abs(p.y - e.y) < 6 then
        e.health -= 1
        deli(projectiles, j)
        sfx(1)
        -- score scales with wave (difficulty multiplier)
        score += 10 * wave
        combo += 1
        combo_timer = 180
        _log("hit:"..e.type.."_wave"..wave)
        if e.health <= 0 then
          create_explosion(e.x, e.y)
          deli(enemies, i)
          _log("destroy:"..e.type)
        end
        break
      end
    end
  end

  -- check collision with player
  for i=#enemies,1,-1 do
    local e = enemies[i]
    if abs(e.x - player.x) < 8 and abs(e.y - player.y) < 8 then
      health -= 1
      deli(enemies, i)
      sfx(2)
      _log("damage")
      _log("health:"..health)
      if health <= 0 then
        player.alive = false
      end
    end
  end

  -- check collision with boss projectiles
  for i=#boss_projectiles,1,-1 do
    local p = boss_projectiles[i]
    if abs(p.x - player.x) < 6 and abs(p.y - player.y) < 6 then
      health -= 1
      deli(boss_projectiles, i)
      sfx(2)
      _log("boss_damage")
      _log("health:"..health)
      if health <= 0 then
        player.alive = false
      end
    end
  end

  -- remove off-screen enemies
  for i=#enemies,1,-1 do
    if enemies[i].y > 128 then
      deli(enemies, i)
    end
  end

  -- wave progression with difficulty milestones
  wave_timer += 1
  if wave_timer > wave_duration then
    if wave >= 3 then
      -- boss wave
      if not boss_active then
        boss_active = true
        boss_health = 5
        _log("boss_active")
        sfx(3)
        add(enemies, {
          x = 64,
          y = 20,
          speed = 0.5,
          type = "boss",
          health = 5,
          boss = true
        })
      end
    else
      wave += 1
      wave_just_changed = true
      wave_change_flash = 30
      _log("wave:"..wave)

      -- log difficulty tier change at wave 3 (final wave before boss)
      if wave == 3 then
        _log("difficulty:medium")
      end

      sfx(3)
      enemy_spawn_rate -= 8
      wave_timer = 0
    end
  end

  -- boss attack timing with difficulty scaling
  if boss_active then
    boss_telegraph += 1
    -- scale attack frequency: faster attacks for higher waves
    local attack_interval = max(60, boss_attack_interval - (wave - 3) * 12)

    if boss_telegraph > attack_interval then
      -- telegraph phase is over, fire attack if in active phase
      if not boss_last_attack then
        -- fire boss projectiles
        for e in all(enemies) do
          if e.type == "boss" then
            add(boss_projectiles, {x=e.x, y=e.y+8, speed=1.5})
            add(boss_projectiles, {x=e.x-6, y=e.y+8, speed=1.5})
            add(boss_projectiles, {x=e.x+6, y=e.y+8, speed=1.5})
            sfx(4)
            _log("boss_attack")
          end
        end
        boss_last_attack = true
      end
      boss_telegraph = 0
      boss_last_attack = false
    end
  end

  -- boss defeat
  if boss_active and #enemies == 0 then
    state = "gameover"
    _log("state:gameover")
    _log("gameover:win")
  end
end

function update_gameover()
  if test_input(4) > 0 then
    state = "menu"
    _log("state:menu")
  end
end

function draw_menu()
  cls(1)
  print("comet clash", 40, 30, 7)
  print("dodge comets", 35, 50, 3)
  print("and asteroids", 32, 60, 3)
  print("shoot with o", 33, 75, 5)
  print("survive waves", 33, 85, 5)
  print("press o to start", 27, 105, 11)
end

function draw_play()
  cls(0)

  -- wave change flash effect
  if wave_just_changed and wave_change_flash > 15 then
    -- bright flash for the first half
    local flash_col = 7
    rectfill(0, 0, 128, 128, flash_col)
  end

  -- draw particles
  for pt in all(particles) do
    local col = 8 + flr(pt.life / 30 * 4)
    pset(flr(pt.x), flr(pt.y), col)
  end

  -- draw player
  if player.alive then
    spr(0, player.x-3, player.y-3)
  end

  -- draw projectiles with trails
  for p in all(projectiles) do
    pset(flr(p.x), flr(p.y-1), 7)
    spr(1, p.x-2, p.y-2)
  end

  -- draw boss projectiles (red color, different from player)
  for p in all(boss_projectiles) do
    pset(flr(p.x), flr(p.y+1), 8)
    circfill(flr(p.x), flr(p.y), 2, 8)
  end

  -- draw enemies
  for e in all(enemies) do
    if e.type == "comet" then
      spr(2, e.x-4, e.y-4)
    elseif e.type == "asteroid" then
      spr(3, e.x-4, e.y-4)
    elseif e.type == "boss" then
      -- draw boss with telegraph flash effect
      local attack_interval = max(60, boss_attack_interval - (wave - 3) * 12)
      if boss_telegraph > attack_interval - 30 then
        -- flash the boss during telegraph
        local flash = flr((30 - (attack_interval - boss_telegraph)) / 5)
        if flash % 2 == 0 then
          -- draw boss with bright background
          rectfill(e.x-8, e.y-8, e.x+8, e.y+8, 8)
          -- draw telegraph warning outline and text (on top of background)
          rect(e.x-8, e.y-8, e.x+8, e.y+8, 8)
          print("!", e.x-2, e.y-12, 8)
        end
      end
      spr(4, e.x-6, e.y-6)
    end
  end

  -- draw wave transition message
  if wave_just_changed and wave_change_flash > 0 then
    local msg_y = 50 + flr(sin(1 - wave_change_flash/30) * 5)
    print("wave "..wave, 40, msg_y, 11)
  end

  -- draw ui
  print("score:"..score, 2, 2, 7)
  print("wave:"..wave, 2, 10, 7)
  local health_str = ""
  for i=1,health do
    health_str = health_str.."*"
  end
  print("health:"..health_str, 70, 2, 8)

  -- draw combo multiplier prominently
  if combo > 0 then
    print("combo x"..combo, 45, 60, 11)
  end

  -- draw boss health bar at top
  if boss_active then
    local boss_bar_width = 40
    local boss_health_pct = 0
    for e in all(enemies) do
      if e.type == "boss" then
        boss_health_pct = e.health / 5
      end
    end
    rectfill(44, 2, 84, 7, 1)
    rectfill(44, 2, 44 + flr(boss_bar_width * boss_health_pct), 7, 8)
    rect(44, 2, 84, 7, 7)
    print("boss hp", 47, 10, 10)
  end
end

function draw_gameover()
  cls(0)
  local won = wave >= 3 and #enemies == 0

  if won then
    print("victory!", 43, 40, 11)
    print("you defeated", 32, 55, 7)
    print("the comet boss!", 28, 65, 7)
  else
    print("game over", 40, 40, 8)
    print("waves survived:"..wave, 24, 55, 7)
  end

  print("final score:"..score, 24, 75, 7)
  print("press o to menu", 27, 105, 11)
end

function _update()
  if state == "menu" then update_menu()
  elseif state == "play" then update_play()
  elseif state == "gameover" then update_gameover()
  end
end

function _draw()
  if state == "menu" then draw_menu()
  elseif state == "play" then draw_play()
  elseif state == "gameover" then draw_gameover()
  end
end

__gfx__
00000000007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000008800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000088880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000088080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000aaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000aaaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000009aa0900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000099aaaa9900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000099aaaaaa9900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0009aa9aaaaaa9a900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0099aaaaaaaaaaaa9900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00999aaaaaaaaaa99900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000099aaaaaaaaaa99000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000009aaaaaaa9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__sfx__
000100000e6330e6330e6300e6330e6330e630000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100001c6321c6321c6301c6300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000026630266302663026630266302663000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100003c6333c6333c6303c6303c6300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200003c6333c6330c6303c6303c6300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__label__
0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f0f
0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f
