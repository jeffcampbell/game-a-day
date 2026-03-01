pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- lunar lander
-- gravity-based arcade lander

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

function test_input(i)
  if testmode and test_input_idx < #test_inputs then
    test_input_idx += 1
    return test_inputs[test_input_idx] or 0
  end
  return btn(i)
end

function test_inputp(i)
  if testmode and test_input_idx < #test_inputs then
    test_input_idx += 1
    local val = test_inputs[test_input_idx] or 0
    return val > 0
  end
  return btnp(i)
end

-- game state
state = "menu"
difficulty = 1  -- 0=easy, 1=normal, 2=hard
difficulty_cursor = 1  -- menu cursor position
level = 1
score = 0
chain = 0
total_fuel_saved = 0
last_chain_milestone = 0

-- bonus tracking
collision_count = 0
total_bonuses = 0
soft_landing_count = 0
fuel_efficiency_count = 0
precision_landing_count = 0
perfect_run_count = 0
best_landing_score = 0

-- ship physics
ship = {}
particles = {}
shake_frames = 0
shake_intensity = 0
thrust_sfx_timer = 0

-- level data
landing_zones = {}
asteroids = {}
fuel_pickups = {}
enemies = {}
powerups = {}
active_powerups = {}
hazard_zones = {}
surface_y = 0
camera_y = 0
last_cam_log = -999

function _init()
  _log("state:menu")
  music(0)  -- start menu music
end

function _update()
  if state == "menu" then
    update_menu()
  elseif state == "difficulty_select" then
    update_difficulty_select()
  elseif state == "play" then
    update_play()
  elseif state == "pause" then
    update_pause()
  elseif state == "gameover" then
    update_gameover()
  end

  -- update particles
  for p in all(particles) do
    p.x += p.vx
    p.y += p.vy
    p.life -= 1
    if p.life <= 0 then
      del(particles, p)
    end
  end

  -- update shake
  if shake_frames > 0 then
    shake_frames -= 1
  end

  -- update thrust sfx timer
  if thrust_sfx_timer > 0 then
    thrust_sfx_timer -= 1
  end
end

function _draw()
  cls(0)

  -- apply shake and camera offset
  local sx, sy = 0, 0
  if shake_frames > 0 then
    sx = rnd(shake_intensity * 2) - shake_intensity
    sy = rnd(shake_intensity * 2) - shake_intensity
  end

  -- apply camera_y only during play state
  local cam_y = (state == "play" or state == "pause") and camera_y or 0
  camera(sx, sy + cam_y)

  if state == "menu" then
    draw_menu()
  elseif state == "difficulty_select" then
    draw_difficulty_select()
  elseif state == "play" then
    draw_world()  -- draw world elements in world space
  elseif state == "pause" then
    draw_world()  -- draw frozen world
  elseif state == "gameover" then
    draw_gameover()
  end

  camera(0, 0)  -- reset camera before HUD

  -- draw HUD in screen space (play and pause states)
  if state == "play" then
    draw_hud()
  elseif state == "pause" then
    draw_pause()
  end
end

-- menu state
function update_menu()
  if test_inputp(4) then  -- O button
    state = "difficulty_select"
    difficulty_cursor = 1  -- reset cursor to normal
    _log("state:difficulty_select")
  end
end

function draw_menu()
  print("lunar lander", 32, 20, 7)
  print("land safely on green zones", 8, 40, 6)
  print("controls:", 8, 52, 7)
  print("left/right: rotate", 8, 60, 13)
  print("up: thrust", 8, 68, 13)
  print("o: cut engines", 8, 76, 13)
  print("press o to start", 28, 100, 11)
end

-- difficulty selection state
function update_difficulty_select()
  -- left/right navigation
  if test_inputp(0) then  -- left
    difficulty_cursor = max(0, difficulty_cursor - 1)
    sfx(4)
    _log("difficulty:cursor:"..difficulty_cursor)
  end
  if test_inputp(1) then  -- right
    difficulty_cursor = min(2, difficulty_cursor + 1)
    sfx(4)
    _log("difficulty:cursor:"..difficulty_cursor)
  end

  -- confirm selection
  if test_inputp(4) then  -- O button
    difficulty = difficulty_cursor
    local diff_names = {"easy", "normal", "hard"}
    _log("difficulty:"..diff_names[difficulty + 1])

    state = "play"
    level = 1
    score = 0
    chain = 0
    last_chain_milestone = 0
    total_fuel_saved = 0

    -- reset bonus tracking
    collision_count = 0
    total_bonuses = 0
    soft_landing_count = 0
    fuel_efficiency_count = 0
    precision_landing_count = 0
    perfect_run_count = 0
    best_landing_score = 0

    init_level()
    music(1)  -- start gameplay music
    _log("state:play")
  end
end

function draw_difficulty_select()
  print("select difficulty", 24, 20, 7)

  -- difficulty options
  local diff_names = {"easy", "normal", "hard"}
  local diff_x = {16, 48, 88}

  for i = 0, 2 do
    local col = (i == difficulty_cursor) and 11 or 6
    print(diff_names[i + 1], diff_x[i + 1], 40, col)
  end

  -- cursor indicator
  print(">", diff_x[difficulty_cursor + 1] - 8, 40, 11)

  -- description based on cursor
  local desc = ""
  if difficulty_cursor == 0 then
    print("easy mode:", 20, 60, 10)
    print("less gravity", 20, 70, 6)
    print("more fuel", 20, 78, 6)
    print("wider landing zones", 20, 86, 6)
    print("score x0.8", 20, 94, 6)
  elseif difficulty_cursor == 1 then
    print("normal mode:", 18, 60, 10)
    print("standard challenge", 18, 70, 6)
    print("balanced gameplay", 18, 78, 6)
    print("score x1.0", 18, 94, 6)
  else
    print("hard mode:", 20, 60, 10)
    print("more gravity", 20, 70, 6)
    print("less fuel", 20, 78, 6)
    print("narrow landing zones", 20, 86, 6)
    print("score x1.5", 20, 94, 6)
  end

  print("arrows: select", 24, 115, 13)
  print("o: confirm", 32, 122, 13)
end

-- play state
function init_level()
  _log("level:"..level)

  -- difficulty scaling factors
  local fuel_mult = {1.15, 1.0, 0.8}  -- easy, normal, hard
  local grav_mult = {0.8, 1.0, 1.15}
  local zone_mult = {1.3, 1.0, 0.75}
  local ast_adjust = {-2, -1, 0}  -- asteroid count adjustment

  -- init ship
  local fuel_table = {80, 70, 60, 50, 40}
  local grav_table = {0.15, 0.2, 0.22, 0.24, 0.3}

  local base_fuel = fuel_table[level] or 40
  local base_grav = grav_table[level] or 0.3

  ship = {
    x = 64,
    y = 20,
    vx = 0,
    vy = 0,
    angle = 0,  -- 0 = up, 0.25 = right, 0.5 = down, 0.75 = left
    fuel = flr(base_fuel * fuel_mult[difficulty + 1]),
    gravity = base_grav * grav_mult[difficulty + 1],
    alive = true,
    thrusting = false
  }

  -- init camera
  camera_y = 0
  last_cam_log = -999
  surface_y = 400 + (level * 50)

  -- reset collision count for perfect run bonus
  collision_count = 0

  -- generate landing zones
  landing_zones = {}
  local zone_count = min(3 + level - 1, 5)
  local base_width = 20
  local zone_width = flr(base_width * zone_mult[difficulty + 1])
  for i = 1, zone_count do
    local zx = 10 + (i - 1) * (108 / (zone_count - 1))
    local zy = surface_y - 2
    add(landing_zones, {
      x = zx,
      y = zy,
      w = zone_width,
      h = 2
    })
  end

  -- generate asteroids
  asteroids = {}
  local ast_count = max(0, level + ast_adjust[difficulty + 1])
  for i = 1, ast_count do
    add(asteroids, {
      x = 15 + rnd(98),
      y = 80 + rnd(surface_y - 120),
      r = 4 + rnd(4)
    })
  end

  -- generate fuel pickups
  fuel_pickups = {}
  local pickup_counts = {4, 3, 2}  -- easy, normal, hard
  local pickup_count = pickup_counts[difficulty + 1]
  if rnd(1) < 0.5 then
    pickup_count -= 1  -- randomize: easy=3-4, normal=2-3, hard=1-2
  end
  for i = 1, pickup_count do
    local px, py, valid
    local attempts = 0
    repeat
      px = 20 + rnd(88)
      py = 60 + rnd(surface_y - 100)
      valid = true
      attempts += 1

      -- check distance from asteroids
      for a in all(asteroids) do
        local dx = px - a.x
        local dy = py - a.y
        if sqrt(dx * dx + dy * dy) < a.r + 15 then
          valid = false
          break
        end
      end

      -- check distance from landing zones
      for z in all(landing_zones) do
        if py > z.y - 30 and py < z.y + 10 and px > z.x - 10 and px < z.x + z.w + 10 then
          valid = false
          break
        end
      end
    until valid or attempts > 20

    if valid then
      add(fuel_pickups, {
        x = px,
        y = py,
        anim = rnd(1)  -- animation offset
      })
      _log("fuel_pickup:spawn:"..flr(px)..","..flr(py))
    end
  end

  -- generate enemies
  enemies = {}
  if level >= 2 then
    local enemy_counts = {1, 2, 3}  -- easy, normal, hard
    local enemy_count = enemy_counts[difficulty + 1]
    for i = 1, enemy_count do
      local patrol_type = flr(rnd(2))  -- 0=horizontal, 1=vertical
      local ex, ey, evx, evy, patrol_min, patrol_max

      if patrol_type == 0 then
        -- horizontal patrol
        ex = 16 + rnd(96)
        ey = 80 + rnd(surface_y - 160)
        evx = 0.3 + rnd(0.4)  -- speed 0.3-0.7
        evy = 0
        patrol_min = 16
        patrol_max = 112
      else
        -- vertical patrol
        ex = 20 + rnd(88)
        ey = 60 + rnd(140)
        evx = 0
        evy = 0.3 + rnd(0.4)  -- speed 0.3-0.7
        patrol_min = 60
        patrol_max = 200
      end

      add(enemies, {
        x = ex,
        y = ey,
        vx = evx,
        vy = evy,
        r = 5,
        patrol_type = patrol_type,
        patrol_min = patrol_min,
        patrol_max = patrol_max
      })

      _log("enemy:spawn:"..flr(ex)..","..flr(ey)..":type:"..patrol_type)
    end

    -- spawn sfx (warning beep)
    if enemy_count > 0 then
      sfx(7)
    end
  end

  -- generate power-ups
  powerups = {}
  active_powerups = {}
  local powerup_count = 2 + flr(rnd(2))  -- 2-3 power-ups per level
  for i = 1, powerup_count do
    local px, py, valid
    local attempts = 0
    repeat
      px = 20 + rnd(88)
      py = 60 + rnd(surface_y - 100)
      valid = true
      attempts += 1

      -- check distance from asteroids
      for a in all(asteroids) do
        local dx = px - a.x
        local dy = py - a.y
        if sqrt(dx * dx + dy * dy) < a.r + 20 then
          valid = false
          break
        end
      end

      -- check distance from enemies
      for e in all(enemies) do
        local dx = px - e.x
        local dy = py - e.y
        if sqrt(dx * dx + dy * dy) < e.r + 20 then
          valid = false
          break
        end
      end

      -- check distance from landing zones
      for z in all(landing_zones) do
        if py > z.y - 35 and py < z.y + 10 and px > z.x - 10 and px < z.x + z.w + 10 then
          valid = false
          break
        end
      end
    until valid or attempts > 20

    if valid then
      -- power-up types: 1=shield, 2=fuel_restorer, 3=rocket_boost, 4=gravity_reducer
      local ptype = flr(rnd(4)) + 1
      add(powerups, {
        x = px,
        y = py,
        type = ptype,
        anim = rnd(1)  -- animation offset
      })
      _log("powerup:spawn:type"..ptype..":"..flr(px)..","..flr(py))
    end
  end

  -- generate thermal hazard zones
  hazard_zones = {}
  local hazard_counts = {0, 2, 3, 4, 4}  -- level 1: 0, level 2: 2, level 3: 3, level 4+: 4
  local hazard_count = hazard_counts[min(level, 5)]

  -- adjust for difficulty (easy=fewer, hard=more)
  if difficulty == 0 and hazard_count > 0 then
    hazard_count -= 1  -- easy mode: one fewer hazard
  elseif difficulty == 2 and level >= 3 then
    hazard_count = min(hazard_count + 1, 5)  -- hard mode: one more hazard (max 5)
  end

  for i = 1, hazard_count do
    local hx, hy, valid
    local attempts = 0
    repeat
      hx = 15 + rnd(98)
      hy = surface_y - 2  -- on the surface
      valid = true
      attempts += 1

      -- check distance from landing zones (must be at least 25px away)
      for z in all(landing_zones) do
        if abs(hx - (z.x + z.w / 2)) < 25 then
          valid = false
          break
        end
      end

      -- check distance from asteroids near surface (must be at least 20px away)
      for a in all(asteroids) do
        if a.y > surface_y - 30 then  -- only check asteroids near surface
          local dx = hx - a.x
          if abs(dx) < a.r + 15 then
            valid = false
            break
          end
        end
      end

      -- check distance from other hazard zones (must be at least 30px apart)
      for h in all(hazard_zones) do
        if abs(hx - h.x) < 30 then
          valid = false
          break
        end
      end
    until valid or attempts > 30

    if valid then
      add(hazard_zones, {
        x = hx,
        y = hy,
        r = 6,  -- radius
        anim = rnd(1)  -- animation offset for variation
      })
      _log("hazard:spawn:"..flr(hx)..","..flr(hy))
    end
  end

  particles = {}
end

function update_enemies()
  for e in all(enemies) do
    if e.patrol_type == 0 then
      -- horizontal patrol
      e.x += e.vx
      if e.x < e.patrol_min or e.x > e.patrol_max then
        e.vx = -e.vx  -- reverse direction
      end
    else
      -- vertical patrol
      e.y += e.vy
      if e.y < e.patrol_min or e.y > e.patrol_max then
        e.vy = -e.vy  -- reverse direction
      end
    end
  end
end

function update_play()
  if not ship.alive then
    -- wait for input after crash
    if test_inputp(4) or test_inputp(5) then
      state = "gameover"
      _log("state:gameover")
    end
    return
  end

  -- check for pause (X button)
  if test_inputp(5) then
    state = "pause"
    _log("state:pause")
    return
  end

  -- update enemies
  update_enemies()

  -- update active power-ups
  for p in all(active_powerups) do
    if p.time then
      p.time -= 1

      -- expiry warning flash (2 blinks in last 2 seconds)
      if p.time == 120 or p.time == 90 or p.time == 60 or p.time == 30 then
        shake_frames = 2
        shake_intensity = 0.15
      end

      -- remove expired
      if p.time <= 0 then
        del(active_powerups, p)
        _log("powerup:expired:type"..p.type)
      end
    end
  end

  -- rotation
  if test_input(0) then  -- left
    ship.angle = (ship.angle - 0.02) % 1
  end
  if test_input(1) then  -- right
    ship.angle = (ship.angle + 0.02) % 1
  end

  -- thrust
  ship.thrusting = false
  if test_input(2) and ship.fuel > 0 then  -- up
    ship.thrusting = true
    ship.fuel -= 1

    -- apply thrust force (check for rocket boost)
    local thrust = 0.4
    for p in all(active_powerups) do
      if p.type == 3 then  -- rocket boost
        thrust = thrust * 3
        break
      end
    end
    ship.vx += cos(ship.angle) * thrust
    ship.vy += sin(ship.angle) * thrust

    -- thrust particles
    local px = ship.x - cos(ship.angle) * 6
    local py = ship.y - sin(ship.angle) * 6
    for i = 1, 3 do
      add(particles, {
        x = px,
        y = py,
        vx = -cos(ship.angle) * 2 + rnd(1) - 0.5,
        vy = -sin(ship.angle) * 2 + rnd(1) - 0.5,
        life = 8,
        col = 10
      })
    end

    -- thrust sfx (limit frequency)
    if thrust_sfx_timer == 0 then
      sfx(0)
      thrust_sfx_timer = 8
      _log("thrust:sfx")
    end

    _log("thrust")
  end

  -- gravity (check for gravity reducer)
  local grav = ship.gravity
  for p in all(active_powerups) do
    if p.type == 4 then  -- gravity reducer
      grav = grav * 0.5
      break
    end
  end
  ship.vy += grav

  -- movement
  ship.x += ship.vx
  ship.y += ship.vy

  -- update camera to follow ship smoothly
  local target_y = ship.y - 60
  camera_y += (target_y - camera_y) * 0.1

  -- clamp camera
  camera_y = max(0, camera_y)  -- don't go above world origin
  camera_y = min(camera_y, surface_y - 64)  -- keep surface visible

  -- log camera at milestones
  local cam_floor = flr(camera_y)
  if cam_floor % 50 == 0 and cam_floor > 0 and abs(cam_floor - last_cam_log) > 1 then
    _log("camera:"..cam_floor)
    last_cam_log = cam_floor
  end

  -- horizontal bounds check
  if ship.x < 0 or ship.x > 128 then
    ship.alive = false
    _log("crash:outofbounds")
    do_crash()
    return
  end

  -- collision with asteroids
  for a in all(asteroids) do
    local dx = ship.x - a.x
    local dy = ship.y - a.y
    if sqrt(dx * dx + dy * dy) < 4 + a.r then
      -- check for shield
      local shield_active = false
      for p in all(active_powerups) do
        if p.type == 1 then  -- shield type
          shield_active = true
          del(active_powerups, p)
          _log("shield:absorbed:asteroid")

          -- shield absorption particles (red)
          for i = 1, 15 do
            add(particles, {
              x = ship.x,
              y = ship.y,
              vx = rnd(3) - 1.5,
              vy = rnd(3) - 1.5,
              life = 20,
              col = 8
            })
          end

          -- shield absorption sfx
          sfx(6)

          -- screen shake
          shake_frames = 5
          shake_intensity = 0.5

          break
        end
      end

      if not shield_active then
        ship.alive = false
        collision_count += 1
        _log("crash:asteroid")
        do_crash()
        return
      end
    end
  end

  -- collision with enemies
  for e in all(enemies) do
    local dx = ship.x - e.x
    local dy = ship.y - e.y
    if sqrt(dx * dx + dy * dy) < 4 + e.r then
      -- check for shield
      local shield_active = false
      for p in all(active_powerups) do
        if p.type == 1 then  -- shield type
          shield_active = true
          del(active_powerups, p)
          _log("shield:absorbed:enemy")

          -- shield absorption particles (red)
          for i = 1, 15 do
            add(particles, {
              x = ship.x,
              y = ship.y,
              vx = rnd(3) - 1.5,
              vy = rnd(3) - 1.5,
              life = 20,
              col = 8
            })
          end

          -- shield absorption sfx
          sfx(6)

          -- screen shake
          shake_frames = 5
          shake_intensity = 0.5

          break
        end
      end

      if not shield_active then
        ship.alive = false
        collision_count += 1
        _log("crash:enemy")
        do_crash()
        return
      end
    end
  end

  -- collision with thermal hazard zones
  for h in all(hazard_zones) do
    local dx = ship.x - h.x
    local dy = ship.y - h.y
    if sqrt(dx * dx + dy * dy) < 4 + h.r then
      -- check for shield
      local shield_active = false
      for p in all(active_powerups) do
        if p.type == 1 then  -- shield type
          shield_active = true
          del(active_powerups, p)
          _log("shield:absorbed:hazard")

          -- shield absorption particles (orange/red)
          for i = 1, 15 do
            add(particles, {
              x = ship.x,
              y = ship.y,
              vx = rnd(3) - 1.5,
              vy = rnd(3) - 1.5,
              life = 20,
              col = (i % 2 == 0) and 8 or 9  -- alternating red/orange
            })
          end

          -- shield absorption sfx
          sfx(6)

          -- screen shake
          shake_frames = 5
          shake_intensity = 0.5

          break
        end
      end

      if not shield_active then
        ship.alive = false
        collision_count += 1
        _log("crash:hazard")
        do_crash()
        return
      end
    end
  end

  -- collision with fuel pickups
  for pickup in all(fuel_pickups) do
    local dx = ship.x - pickup.x
    local dy = ship.y - pickup.y
    if sqrt(dx * dx + dy * dy) < 8 then
      -- collect fuel pickup
      local fuel_restore = 10 + rnd(11)  -- 10-20 fuel
      local bonus_points = 25 + rnd(26)  -- 25-50 points
      ship.fuel += fuel_restore
      score += flr(bonus_points)

      _log("fuel_pickup:collect:fuel+"..flr(fuel_restore)..":score+"..flr(bonus_points))

      -- pickup particles
      for i = 1, 10 do
        add(particles, {
          x = pickup.x,
          y = pickup.y,
          vx = rnd(2) - 1,
          vy = rnd(2) - 1,
          life = 15,
          col = 10
        })
      end

      -- pickup sfx
      sfx(4)

      -- screen shake
      shake_frames = 4
      shake_intensity = 0.3

      -- remove pickup
      del(fuel_pickups, pickup)
    end
  end

  -- collision with power-ups
  for pup in all(powerups) do
    local dx = ship.x - pup.x
    local dy = ship.y - pup.y
    if sqrt(dx * dx + dy * dy) < 8 then
      -- check if already have this type
      local already_have = false
      for ap in all(active_powerups) do
        if ap.type == pup.type then
          already_have = true
          break
        end
      end

      if not already_have then
        -- collect power-up
        local ptype = pup.type
        local pname = ({"shield", "fuel_restorer", "rocket_boost", "gravity_reducer"})[ptype]
        local pcol = ({8, 12, 9, 11})[ptype]  -- red, blue, orange, cyan

        _log("powerup:collect:type"..ptype..":"..pname)

        -- instant effects
        if ptype == 2 then
          -- fuel restorer: instant refill
          local fuel_table = {80, 70, 60, 50, 40}
          local fuel_mult = {1.15, 1.0, 0.8}
          local max_fuel = flr((fuel_table[level] or 40) * fuel_mult[difficulty + 1])
          ship.fuel = max_fuel
          _log("powerup:fuel_restorer:refill:"..max_fuel)
        else
          -- add to active power-ups with timer
          local duration = ({0, 0, 600, 720})[ptype]  -- shield=no timer, fuel=no timer, boost=10s, gravity=12s
          add(active_powerups, {
            type = ptype,
            time = duration
          })
        end

        -- power-up particles (color-coded)
        for i = 1, 12 do
          add(particles, {
            x = pup.x,
            y = pup.y,
            vx = rnd(2.5) - 1.25,
            vy = rnd(2.5) - 1.25,
            life = 18,
            col = pcol
          })
        end

        -- power-up sfx (pitch varies by type)
        sfx(5, -1, ptype * 2)

        -- screen shake
        shake_frames = 3
        shake_intensity = 0.25

        -- remove power-up
        del(powerups, pup)
      end
    end
  end

  -- collision with surface
  if ship.y >= surface_y - 4 then
    local landed = false
    local velocity = sqrt(ship.vx * ship.vx + ship.vy * ship.vy)

    -- difficulty-based velocity threshold
    local vel_thresh = {3.0, 2.0, 2.0}  -- easy, normal, hard

    -- check landing zones
    for z in all(landing_zones) do
      if ship.x >= z.x and ship.x <= z.x + z.w then
        if velocity < vel_thresh[difficulty + 1] and (abs(ship.angle) < 0.1 or abs(ship.angle - 1) < 0.1) then
          -- successful landing
          landed = true
          do_landing(velocity, z.x, z.w)
          break
        end
      end
    end

    if not landed then
      -- crashed
      ship.alive = false
      _log("crash:surface:velocity:"..flr(velocity * 10))
      do_crash()
    end
  end

  -- out of fuel check
  if ship.fuel <= 0 and ship.y < surface_y - 10 then
    -- check if drifting to death
    if ship.vy > 3 then
      ship.alive = false
      _log("crash:nofuel")
      do_crash()
    end
  end
end

function do_landing(velocity, zone_x, zone_w)
  _log("landing:velocity:"..flr(velocity * 10))

  -- landing sfx
  sfx(1)

  -- calculate base score
  local base = 100
  local fuel_bonus = ship.fuel * 5
  local speed_bonus = (velocity < 1) and 20 or 0
  chain += 1
  local chain_multiplier = min(1 + (chain - 1) * 0.5, 2)

  -- difficulty score multipliers
  local diff_mult = {0.8, 1.0, 1.5}  -- easy, normal, hard

  -- precision bonuses
  local precision_bonuses = 0

  -- 1. soft landing bonus (velocity < 0.5)
  if velocity < 0.5 then
    local soft_bonus = 50
    precision_bonuses += soft_bonus
    soft_landing_count += 1
    _log("bonus:soft_landing:"..soft_bonus)

    -- gold particles
    for i = 1, 12 do
      add(particles, {
        x = ship.x,
        y = ship.y,
        vx = rnd(2) - 1,
        vy = rnd(2) - 1,
        life = 25,
        col = 10  -- gold
      })
    end

    sfx(16)  -- soft landing sfx
  end

  -- 2. fuel efficiency bonus (>60% fuel)
  local fuel_table = {80, 70, 60, 50, 40}
  local fuel_mult = {1.15, 1.0, 0.8}
  local max_fuel = flr((fuel_table[level] or 40) * fuel_mult[difficulty + 1])
  local fuel_pct = ship.fuel / max_fuel

  if fuel_pct > 0.6 then
    local fuel_eff_bonus = flr(ship.fuel * 3)
    precision_bonuses += fuel_eff_bonus
    fuel_efficiency_count += 1
    _log("bonus:fuel_efficiency:"..fuel_eff_bonus)

    -- cyan particles
    for i = 1, 10 do
      add(particles, {
        x = ship.x,
        y = ship.y,
        vx = rnd(2) - 1,
        vy = rnd(2) - 1,
        life = 20,
        col = 12  -- cyan
      })
    end

    sfx(17)  -- fuel efficiency sfx
  end

  -- 3. precision landing bonus (center third of zone)
  local zone_center = zone_x + zone_w / 2
  local zone_third = zone_w / 3
  local dist_from_center = abs(ship.x - zone_center)

  if dist_from_center < zone_third / 2 then
    local precision_bonus = 75
    precision_bonuses += precision_bonus
    precision_landing_count += 1
    _log("bonus:precision_landing:"..precision_bonus)

    -- white star burst
    for i = 1, 8 do
      add(particles, {
        x = ship.x,
        y = ship.y,
        vx = cos(i / 8) * 2,
        vy = sin(i / 8) * 2,
        life = 18,
        col = 7  -- white
      })
    end

    sfx(18)  -- precision landing sfx
  end

  -- 4. perfect run bonus (no collisions this level)
  if collision_count == 0 then
    local perfect_bonus = 100
    precision_bonuses += perfect_bonus
    perfect_run_count += 1
    _log("bonus:perfect_run:"..perfect_bonus)

    -- rainbow particles
    for i = 1, 15 do
      add(particles, {
        x = ship.x,
        y = ship.y,
        vx = rnd(3) - 1.5,
        vy = rnd(3) - 1.5,
        life = 30,
        col = 8 + (i % 8)  -- rainbow colors
      })
    end

    sfx(19)  -- perfect run sfx
  end

  -- 5. hazard near-miss bonus (landed within 10px of a thermal hazard)
  local nearest_hazard_dist = 999
  for h in all(hazard_zones) do
    local dist = abs(ship.x - h.x)
    if dist < nearest_hazard_dist then
      nearest_hazard_dist = dist
    end
  end

  if nearest_hazard_dist < 10 then
    local near_miss_bonus = 25 + rnd(16)  -- 25-40 points
    precision_bonuses += flr(near_miss_bonus)
    _log("bonus:hazard_near_miss:"..flr(near_miss_bonus))

    -- orange/red warning particles
    for i = 1, 10 do
      add(particles, {
        x = ship.x,
        y = ship.y,
        vx = rnd(2.5) - 1.25,
        vy = rnd(2.5) - 1.25,
        life = 22,
        col = (i % 2 == 0) and 8 or 9  -- alternating red/orange
      })
    end

    sfx(20)  -- near-miss warning sfx
  end

  -- apply multipliers to bonuses
  local multiplied_bonuses = flr(precision_bonuses * chain_multiplier * diff_mult[difficulty + 1])
  total_bonuses += multiplied_bonuses

  -- calculate total landing score
  local landing_score = flr((base + fuel_bonus + speed_bonus) * chain_multiplier * diff_mult[difficulty + 1]) + multiplied_bonuses
  score += landing_score
  total_fuel_saved += ship.fuel

  -- track best landing
  if landing_score > best_landing_score then
    best_landing_score = landing_score
    _log("best_landing:"..best_landing_score)
  end

  _log("score:"..score)
  _log("chain:"..chain)

  -- check chain milestones
  if chain >= 10 and last_chain_milestone < 10 then
    sfx(6)
    last_chain_milestone = 10
    _log("chain:milestone:10")
  elseif chain >= 5 and last_chain_milestone < 5 then
    sfx(5)
    last_chain_milestone = 5
    _log("chain:milestone:5")
  elseif chain >= 3 and last_chain_milestone < 3 then
    sfx(4)
    last_chain_milestone = 3
    _log("chain:milestone:3")
  end

  -- landing particles
  for i = 1, 15 do
    add(particles, {
      x = ship.x,
      y = ship.y,
      vx = rnd(2) - 1,
      vy = rnd(2) - 1,
      life = 20,
      col = 11
    })
  end

  -- shake
  shake_frames = 6
  shake_intensity = 0.5

  -- advance level
  if level < 5 then
    level += 1
    sfx(3)  -- level up sfx
    _log("levelup")
    init_level()
  else
    -- game complete
    state = "gameover"
    music(3)  -- victory music
    _log("state:gameover:win")
  end
end

function do_crash()
  -- track collision (skip if already counted from asteroid hit)
  if ship.alive then
    collision_count += 1
  end

  -- crash sfx and music
  sfx(2)
  music(2)  -- game over music

  -- crash particles
  for i = 1, 25 do
    add(particles, {
      x = ship.x,
      y = ship.y,
      vx = rnd(4) - 2,
      vy = rnd(4) - 2,
      life = 30,
      col = 8
    })
  end

  -- shake
  shake_frames = 12
  shake_intensity = 2

  -- reset chain
  chain = 0
  last_chain_milestone = 0
  _log("chain:reset")
end

function draw_world()
  -- draw moon surface
  rectfill(0, surface_y, 128, 128, 13)
  line(0, surface_y, 128, surface_y, 5)

  -- draw landing zones
  for z in all(landing_zones) do
    rectfill(z.x, z.y, z.x + z.w, z.y + z.h, 11)
  end

  -- draw thermal hazard zones (pulsing red/orange circles)
  for h in all(hazard_zones) do
    -- pulsing animation (slower pulse for hazards)
    local pulse = sin((t() * 1.5 + h.anim)) * 2 + h.r
    local glow = sin((t() * 3 + h.anim)) * 1.5 + 3

    -- outer glow (warning effect)
    circfill(h.x, h.y, glow, 2)  -- dark red glow

    -- main hazard circle (alternating colors for heat effect)
    local heat_phase = flr((t() * 4 + h.anim) % 2)
    local heat_col = (heat_phase == 0) and 8 or 9  -- alternate red/orange
    circfill(h.x, h.y, pulse, heat_col)

    -- bright center
    circfill(h.x, h.y, pulse * 0.5, 10)  -- yellow center
  end

  -- draw asteroids
  for a in all(asteroids) do
    circfill(a.x, a.y, a.r, 8)
    circ(a.x, a.y, a.r, 2)
  end

  -- draw enemies
  for e in all(enemies) do
    circfill(e.x, e.y, e.r, 9)  -- orange circle
    circ(e.x, e.y, e.r, 2)  -- red outline
    -- cross marker
    line(e.x - 3, e.y, e.x + 3, e.y, 7)  -- horizontal
    line(e.x, e.y - 3, e.x, e.y + 3, 7)  -- vertical
  end

  -- draw fuel pickups
  for pickup in all(fuel_pickups) do
    -- pulsing animation
    local pulse = sin((t() * 2 + pickup.anim)) * 1.5 + 4.5
    circfill(pickup.x, pickup.y, pulse, 10)
    circ(pickup.x, pickup.y, pulse + 1, 9)
    -- spark effect
    if pulse > 5 then
      pset(pickup.x + 3, pickup.y, 7)
      pset(pickup.x - 3, pickup.y, 7)
      pset(pickup.x, pickup.y + 3, 7)
      pset(pickup.x, pickup.y - 3, 7)
    end
  end

  -- draw power-ups
  for pup in all(powerups) do
    -- pulsing animation
    local pulse = sin((t() * 2 + pup.anim)) * 1.5 + 4.5
    local pcol = ({8, 12, 9, 11})[pup.type]  -- red, blue, orange, cyan
    local pcol2 = ({2, 6, 4, 3})[pup.type]  -- dark variants
    circfill(pup.x, pup.y, pulse, pcol)
    circ(pup.x, pup.y, pulse + 1, pcol2)
    -- type indicator (small symbol)
    if pup.type == 1 then
      -- shield: plus sign
      line(pup.x - 2, pup.y, pup.x + 2, pup.y, 7)
      line(pup.x, pup.y - 2, pup.x, pup.y + 2, 7)
    elseif pup.type == 2 then
      -- fuel: F
      pset(pup.x - 1, pup.y - 1, 7)
      pset(pup.x, pup.y - 1, 7)
      pset(pup.x - 1, pup.y, 7)
      pset(pup.x, pup.y, 7)
      pset(pup.x - 1, pup.y + 1, 7)
    elseif pup.type == 3 then
      -- boost: up arrow
      pset(pup.x, pup.y - 1, 7)
      pset(pup.x - 1, pup.y, 7)
      pset(pup.x + 1, pup.y, 7)
    else
      -- gravity: down arrow
      pset(pup.x, pup.y + 1, 7)
      pset(pup.x - 1, pup.y, 7)
      pset(pup.x + 1, pup.y, 7)
    end
  end

  -- draw particles
  for p in all(particles) do
    pset(p.x, p.y, p.col)
  end

  -- draw ship
  if ship.alive then
    local x, y = ship.x, ship.y

    -- ship body (triangle)
    local s1x = x + cos(ship.angle) * 5
    local s1y = y + sin(ship.angle) * 5
    local s2x = x + cos(ship.angle + 0.3) * 3
    local s2y = y + sin(ship.angle + 0.3) * 3
    local s3x = x + cos(ship.angle - 0.3) * 3
    local s3y = y + sin(ship.angle - 0.3) * 3

    line(s1x, s1y, s2x, s2y, 7)
    line(s2x, s2y, s3x, s3y, 7)
    line(s3x, s3y, s1x, s1y, 7)

    -- thrust flame
    if ship.thrusting then
      local fx = x - cos(ship.angle) * 6
      local fy = y - sin(ship.angle) * 6
      line(s2x, s2y, fx, fy, 9)
      line(s3x, s3y, fx, fy, 9)
    end
  end
end

function draw_hud()
  -- draw hud in screen space (camera independent)
  local vel = sqrt(ship.vx * ship.vx + ship.vy * ship.vy)
  local height = max(0, surface_y - ship.y)
  local angle_deg = flr((ship.angle * 360) % 360)

  print("vel:"..flr(vel * 10) / 10, 2, 2, 7)
  print("fuel:"..flr(ship.fuel), 2, 9, 7)

  -- fuel bar (calculate max based on difficulty)
  local fuel_table = {80, 70, 60, 50, 40}
  local fuel_mult = {1.15, 1.0, 0.8}
  local max_fuel = flr((fuel_table[level] or 40) * fuel_mult[difficulty + 1])
  local fuel_pct = ship.fuel / max_fuel
  rectfill(30, 10, 30 + fuel_pct * 30, 13, 8)
  rect(30, 10, 60, 13, 7)

  print("alt:"..flr(height), 2, 16, 7)
  print("ang:"..angle_deg, 2, 23, 7)
  print("lvl:"..level, 100, 2, 7)
  print("score:"..score, 80, 9, 10)

  if chain > 1 then
    print("x"..flr((1 + (chain - 1) * 0.5) * 10) / 10, 110, 16, 11)
  end

  -- active power-ups display
  local pup_y = 30
  for p in all(active_powerups) do
    local pname = ({"shd", "ful", "bst", "grv"})[p.type]
    local pcol = ({8, 12, 9, 11})[p.type]

    -- draw icon
    circfill(2, pup_y, 2, pcol)

    -- draw time (if applicable)
    if p.time then
      local sec = flr(p.time / 60) + 1
      print(pname..":"..sec, 6, pup_y - 2, 7)
    else
      print(pname, 6, pup_y - 2, 7)
    end

    pup_y += 6
  end

  if not ship.alive then
    print("crashed!", 40, 60, 8)
    print("press o/x", 40, 70, 7)
  end
end

-- gameover state
function update_gameover()
  if test_inputp(4) or test_inputp(5) then
    state = "menu"
    music(0)  -- restart menu music
    _log("state:menu")
  end
end

function draw_gameover()
  if level > 5 then
    print("mission complete!", 24, 20, 11)
  else
    print("mission failed", 32, 20, 8)
  end

  print("final score: "..score, 28, 35, 7)
  print("best landing: "..best_landing_score, 24, 43, 10)
  print("total bonuses: "..total_bonuses, 20, 51, 10)

  -- bonus breakdown
  print("bonus breakdown:", 24, 62, 6)
  print("soft landings: "..soft_landing_count, 8, 70, 7)
  print("fuel efficient: "..fuel_efficiency_count, 8, 77, 7)
  print("precision: "..precision_landing_count, 8, 84, 7)
  print("perfect runs: "..perfect_run_count, 8, 91, 7)

  print("levels: "..(level - 1), 8, 102, 6)
  print("fuel: "..total_fuel_saved, 64, 102, 6)

  print("press o/x to restart", 16, 115, 6)
end

-- pause state
function update_pause()
  if test_inputp(5) then  -- X button - resume
    state = "play"
    _log("state:play")
  elseif test_inputp(4) then  -- O button - quit to menu
    state = "menu"
    music(0)  -- restart menu music
    _log("state:menu")
  end
end

function draw_pause()
  -- semi-transparent overlay
  rectfill(0, 0, 128, 128, 0)

  -- title
  print("paused", 48, 10, 7)

  -- current stats
  print("score: "..score, 32, 25, 10)
  print("level: "..level, 32, 33, 7)

  -- chain multiplier
  if chain > 1 then
    local mult = flr((1 + (chain - 1) * 0.5) * 10) / 10
    print("chain: x"..mult, 32, 41, 11)
  end

  -- fuel status
  local fuel_table = {80, 70, 60, 50, 40}
  local fuel_mult = {1.15, 1.0, 0.8}
  local max_fuel = flr((fuel_table[level] or 40) * fuel_mult[difficulty + 1])
  print("fuel: "..flr(ship.fuel).."/"..max_fuel, 32, 49, 7)

  -- active power-ups
  if #active_powerups > 0 then
    print("active power-ups:", 24, 60, 6)
    local pup_y = 68
    for p in all(active_powerups) do
      local pname = ({"shield", "fuel+", "boost", "low-g"})[p.type]
      local pcol = ({8, 12, 9, 11})[p.type]

      circfill(26, pup_y + 2, 2, pcol)

      if p.time then
        local sec = flr(p.time / 60) + 1
        print(pname.." ("..sec.."s)", 30, pup_y, 7)
      else
        print(pname, 30, pup_y, 7)
      end

      pup_y += 8
    end
  end

  -- controls
  print("x: resume", 40, 105, 11)
  print("o: quit to menu", 28, 113, 8)
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
__sfx__
001000001c0501c0501c0501c050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001c5501e5502055023550255502755029550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000030540285501f5401854010530085200752007510075100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001c5501e5502155023550275502a5502d550305500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000020550235502555027550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001d5502055023550275502a5500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000018550205502355027550295502c550305503355000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000c5300c5300c5300c53018530185301853018530245302453024530245302d5302d5302d5302d53000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001f5301f5301f5301f5301f5301f5301f5301f5301f5301f5301f530000001f5301f5301f5301f53000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001c5301c5301c5301c5301c5301c5301c5301c5301c5301c5301c530000001c5301c5301c5301c53000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000275302753027530275302753027530275302753027530275302753000000275302753027530275300000000000000000000000000000000000000000000000000000000000000000000000000000000
001000003053030530305303053030530305303053030530305303053030530000003053030530305303053000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000002d5302d5302d5302d5302d5302d5302d5302d5302d5302d5302d53000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000245302453024530245302453024530245302453024530245302453000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000205302053020530205302053020530205302053020530205302053000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001c5301c5301c5301c5301c5301c5301c5301c53000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000002055023550265502a5502d550305503355037550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001855020550235502655028550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000002355027550295502d5503055033550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001855020550235502755029550305503555038550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 08090a0b
00 0c0d0e0f
00 0e0d0c41
00 08090a0b
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
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
