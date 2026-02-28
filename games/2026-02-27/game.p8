pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

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

alph = "abcdefghijklmnopqrstuvwxyz"

state = "menu"
score = 0
gm2 = 0
ui6 = {}
ui2 = false
ui1 = 0
ui3 = 0
gm1 = 0
lm7 = 1.0
lm8 = 1
combo = 0
lm1 = 0
lives = 3
lm9 = 2
ic3 = 2
ic1 = 0
ic2 = 0

ui7 = {"a", "a", "a"}
ui8 = 1
ui9 = false

ui5 = 0
ui4 = 0

gm3 = true
gm4 = true
cu5 = 1
cu4 = 1
cu3 = 1
lm3 = 2
lm2 = 2
lm4 = 2
lm5 = 2
ss1 = 1
dc1 = 1
cu6 = {}
cu1 = 0

dz1 = {}
lm6 = 0
dz3 = 450

ic9 = 0
ic8 = 0
ic7 = 0
ic6 = 0
ic5 = 0

ad2 = {}
ad1 = {
  {id=1, name="survivor", title="survivor", desc="survive for 30+ seconds", unlocked=false},
  {id=2, name="power_master", title="power master", desc="collect all 6 power-ups", unlocked=false},
  {id=3, name="combo_king", title="combo king", desc="reach 20+ combo", unlocked=false},
  {id=4, name="danger_expert", title="danger expert", desc="collect 5+ from danger zones", unlocked=false},
  {id=5, name="speedrunner", title="speedrunner", desc="score 500+ in one game", unlocked=false},
  {id=6, name="unstoppable", title="unstoppable", desc="reach 2.0x lm7", unlocked=false},
  {id=7, name="collection", title="complete collection", desc="unlock all 3 ball skins", unlocked=false},
  {id=8, name="perfect_wave", title="perfect wave", desc="survive 10s without damage", unlocked=false}
}
ad4 = 0
ad3 = 0
ad5 = {}
ad7 = 0
ad6 = 0

st1 = 0
st2 = 0
st3 = 0
st4 = 0
st5 = 0
st6 = 0
st7 = 0

st8 = 0
st9 = 0
sa1 = 0
sa2 = 0
sa3 = 0
sa4 = 0
sa5 = 0
sa6 = 0
sa7 = 0

sa8 = 0
sa9 = 0
sb1 = 0
sb2 = 0
sb3 = 0
sb4 = 0

sb5 = 0
sb6 = 0

sb7 = 0
sb8 = 1

sk1 = 0
sk2 = 0
sk3 = 0
sk4 = 0

pr1 = "spike"
pr2 = 1.0
pr3 = 0
pr4 = 0
pr5 = 1
pr6 = 2
pr7 = {"spike", "moving", "rotating", "pendulum", "zigzag", "orbiter", "boss"}
pr8 = {"slow", "normal", "fast"}
pr9 = {0.5, 1.0, 1.5}

mc5 = 1
mc6 = false

mc1 = 1
mc2 = {"play", "challenge", "practice", "gauntlet", "tutorial", "bossrush", "variant_leaderboards", "ad2", "statistics", "settings", "progress"}

ct1 = 90
ct2 = false
ct5 = 0
ct3 = 0
ct4 = 0
ic4 = {}
ct6 = 0
mc4 = 1
ct9 = 1
mc3 = 1
ct7 = 3
ct8 = 0

gt1 = false
gt2 = 90 * 30
gt3 = 0
gt4 = 0
gt5 = 0
gt6 = 1
gt7 = 0
gt8 = false
gt9 = false

br1 = false
br2 = 0
br3 = 0
br4 = 0
br5 = 5
br6 = 90
br7 = 1
br8 = 0

vl1 = 0

fx2 = 0
fx1 = 0
fx3 = 0
fx4 = 0
fx5 = 0
bl3 = 0
fx6 = 0
fx7 = 0

ball = {
  x = 64,
  y = 100,
  vx = 0,
  vy = 0,
  r = 3,
  grounded = false
}

bl1 = {}
bl2 = 5

ob4 = {}
ob3 = 0
ob2 = 60
ob6 = 0
ob5 = 150
ob7 = 0.5

pw6 = {}
pw7 = 0
pw2 = 0
pw3 = 0
pw1 = 0
pw4 = 0
pw5 = 0
ob1 = false

fx8 = {}

fx9 = {}

function _init()
  cartdata("bounce_king")

  local old_hs = dget(0)
  if old_hs > 0 then
    gm2 = old_hs
    _log("old_highscore:"..gm2)
  end

  load_settings()

  load_cosmetics()

  load_leaderboard()

  load_achievements()

  load_statistics()

  load_streak()

  local t = dget(53)
  mc6 = t == 1

  local g = dget(93)
  gt9 = g == 1

  br8 = dget(94)
  _log("br8:"..br8)

  load_daily_challenge()

  play_music(2)
  _log("state:menu")
end

function load_settings()
  local m = dget(1)
  local s = dget(2)
  local b = dget(3)

  gm3 = m == 0 or m == 1
  gm4 = s == 0 or s == 1
  cu5 = b >= 1 and b <= 3 and b or 1

  local sr = dget(89)
  local ds = dget(90)
  local cb = dget(91)
  local lp = dget(92)

  lm3 = (sr >= 1 and sr <= 4) and sr or 2
  lm2 = (ds >= 1 and ds <= 4) and ds or 2
  lm4 = (cb >= 1 and cb <= 3) and cb or 2
  lm5 = (lp >= 1 and lp <= 3) and lp or 2

  cu6[cu5] = true

  _log("settings_loaded:m="..tostr(gm3)..",s="..tostr(gm4)..",b="..cu5..",sr="..lm3..",ds="..lm2..",cb="..lm4..",lp="..lm5)
end

function save_settings()
  dset(1, gm3 and 1 or 0)
  dset(2, gm4 and 1 or 0)
  dset(3, cu5)
  dset(89, lm3)
  dset(90, lm2)
  dset(91, lm4)
  dset(92, lm5)
  _log("settings_saved")
end

function load_cosmetics()
  local packed = dget(63)

  cu1 = flr(packed % 256)
  cu4 = flr((packed / 256) % 4) + 1
  cu3 = flr(packed / 1024) + 1

  if cu4 < 1 or cu4 > 3 then cu4 = 1 end
  if cu3 < 1 or cu3 > 5 then cu3 = 1 end
  if cu1 < 0 then cu1 = 0 end

  _log("cosmetics_loaded:te="..cu4..",ct="..cu3..",cu="..cu1)
end

function save_cosmetics()
  local packed = cu1 + (cu4 - 1) * 256 + (cu3 - 1) * 1024
  dset(63, packed)
  _log("cosmetics_saved")
end

function theme_color(col)
  if cu3 == 1 then return col end
  local theme_map = {
    [0] = {1, 1, 1, 1},
    [2] = {14, 9, 8, 12},
    [5] = {13, 9, 2, 13},
    [7] = {14, 10, 8, 12},
    [8] = {14, 10, 8, 8},
    [9] = {14, 10, 8, 1},
    [11] = {14, 9, 8, 13},
    [12] = {14, 10, 2, 12},
    [14] = {14, 10, 8, 12}
  }
  if theme_map[col] then
    return theme_map[col][cu3 - 1]
  end
  return col
end

function load_achievements()
  ad2 = {}
  ad3 = 0
  for i = 1, 8 do
    local unlocked = dget(43 + i) == 1
    ad2[i] = unlocked
    ad1[i].unlocked = unlocked
    if unlocked then
      ad3 += 1
    end
  end
  ad6 = dget(52) or 0
  _log("achievements_loaded:"..ad3.."/8")
end

function save_achievements()
  for i = 1, 8 do
    dset(43 + i, ad2[i] and 1 or 0)
  end
  dset(52, ad6)
  _log("achievements_saved")
end

function load_statistics()
  st1 = dget(64) or 0
  st2 = dget(65) or 0
  st3 = dget(66) or 0
  st4 = dget(67) or 0
  local score_low = dget(68) or 0
  local score_high = dget(69) or 0
  st5 = score_low + score_high * 100000
  st6 = dget(70) or 0
  st7 = dget(71) or 0

  st8 = dget(72) or 0
  st9 = dget(73) or 0
  sa1 = dget(74) or 0
  sa2 = dget(75) or 0
  sa3 = dget(76) or 0
  sa4 = dget(77) or 0
  sa5 = dget(78) or 0
  sa6 = dget(79) or 0
  sa7 = dget(80) or 0

  sa8 = dget(81) or 0
  sa9 = dget(82) or 0
  sb1 = dget(83) or 0
  sb2 = dget(84) or 0
  sb3 = dget(85) or 0
  sb4 = dget(86) or 0

  sb5 = dget(87) or 0
  sb6 = dget(88) or 0

  _log("statistics_loaded:games="..st1)
end

function save_statistics()
  dset(64, st1)
  dset(65, st2)
  dset(66, st3)
  dset(67, st4)
  local score_low = st5 % 100000
  local score_high = flr(st5 / 100000)
  dset(68, score_low)
  dset(69, score_high)
  dset(70, st6)
  dset(71, st7)

  dset(72, st8)
  dset(73, st9)
  dset(74, sa1)
  dset(75, sa2)
  dset(76, sa3)
  dset(77, sa4)
  dset(78, sa5)
  dset(79, sa6)
  dset(80, sa7)

  dset(81, sa8)
  dset(82, sa9)
  dset(83, sb1)
  dset(84, sb2)
  dset(85, sb3)
  dset(86, sb4)

  dset(87, sb5)
  dset(88, sb6)

  _log("statistics_saved:games="..st1)
end

function load_streak()
  sk1 = dget(95) or 0
  sk2 = dget(96) or 0
  sk3 = dget(97) or 0
  _log("streak_loaded:current="..sk1..",best="..sk2..",last="..sk3)
end

function save_streak()
  dset(95, sk1)
  dset(96, sk2)
  dset(97, sk3)
  _log("streak_saved:current="..sk1..",best="..sk2)
end

function update_streak()
  local today = flr(time() / 86400)

  if sk3 == 0 then
    sk3 = today
    save_streak()
    _log("streak_first_day")
    return
  end

  local days_diff = today - sk3

  if days_diff == 0 then
    _log("streak_same_day")
  elseif days_diff == 1 then
    sk1 += 1
    if sk1 > sk2 then
      sk2 = sk1
    end
    sk3 = today
    save_streak()
    _log("streak_continued:"..sk1)
    check_streak_milestone()
  elseif days_diff > 1 then
    sk1 = 1
    sk3 = today
    save_streak()
    _log("streak_reset")
  end
end

function check_streak_milestone()
  if sk1 == 5 or sk1 == 10 or sk1 == 20 or sk1 == 50 then
    add(fx9, {x=64, y=50, txt=sk1.."-day streak!", col=10, age=0, vy=-0.5})
    shake(12, 1.2)
    _log("milestone:"..sk1.."-day")
  end
end

function load_daily_challenge()
  ct5 = flr(time() / 86400)

  local stored_seed = dget(55)
  local stored_best = dget(54)

  if stored_seed == ct5 then
    ct4 = stored_best
  else
    ct4 = 0
    dset(55, ct5)
    dset(54, 0)
  end

  ic4 = {}
  for i = 0, 2 do
    local day_seed = dget(56 + i * 2)
    local day_score = dget(57 + i * 2)
    if day_seed > 0 then
      add(ic4, {seed = day_seed, score = day_score})
    end
  end

  _log("challenge_loaded:seed="..ct5..",best="..ct4..",history="..#ic4)
end

function save_daily_challenge()
  dset(54, ct4)
  dset(55, ct5)

  local found = false
  for i = 1, #ic4 do
    if ic4[i].seed == ct5 then
      ic4[i].score = max(ic4[i].score, ct3)
      found = true
      break
    end
  end

  if not found then
    add(ic4, {seed = ct5, score = ct3})
    while #ic4 > 3 do
      del(ic4, ic4[1])
    end
  end

  for i = 1, 3 do
    if i <= #ic4 then
      dset(56 + (i - 1) * 2, ic4[i].seed)
      dset(57 + (i - 1) * 2, ic4[i].score)
    else
      dset(56 + (i - 1) * 2, 0)
      dset(57 + (i - 1) * 2, 0)
    end
  end

  _log("challenge_saved:score="..ct3..",best="..ct4..",history="..#ic4)
end

function load_leaderboard()
  ui6 = {}
  for i = 1, 10 do
    local slot_base = 4 + (i - 1) * 4
    local sc = dget(slot_base)
    if sc > 0 then
      local c1 = dget(slot_base + 1)
      local c2 = dget(slot_base + 2)
      local c3_packed = dget(slot_base + 3)
      local variant = flr(c3_packed / 32) % 8
      local c3 = c3_packed % 32
      local init1 = c1 >= 1 and c1 <= 26 and sub(alph, c1, c1) or "a"
      local init2 = c2 >= 1 and c2 <= 26 and sub(alph, c2, c2) or "a"
      local init3 = c3 >= 1 and c3 <= 26 and sub(alph, c3, c3) or "a"
      add(ui6, {
        score = sc,
        initials = init1..init2..init3,
        timestamp = 0,
        variant = variant
      })
    end
  end

  if #ui6 == 0 and gm2 > 0 then
    add(ui6, {
      score = gm2,
      initials = "cpu",
      timestamp = 0,
      variant = 0
    })
    save_leaderboard()
    _log("migrated_highscore:"..gm2)
  end

  _log("leaderboard_loaded:"..#ui6)
end

function save_leaderboard()
  for i = 1, 10 do
    local slot_base = 4 + (i - 1) * 4
    if i <= #ui6 then
      local entry = ui6[i]
      dset(slot_base, entry.score)
      local init = entry.initials
      local c1 = sub(init, 1, 1)
      local c2 = sub(init, 2, 2)
      local c3 = sub(init, 3, 3)
      dset(slot_base + 1, ord(c1) - 96)
      dset(slot_base + 2, ord(c2) - 96)
      local variant = entry.variant or 0
      local c3_code = ord(c3) - 96
      dset(slot_base + 3, variant * 32 + c3_code)
    else
      dset(slot_base, 0)
      dset(slot_base + 1, 0)
      dset(slot_base + 2, 0)
      dset(slot_base + 3, 0)
    end
  end
  _log("leaderboard_saved:"..#ui6)
end

function play_sfx(n, ch, off)
  if gm4 then
    sfx(n, ch, off)
  end
end

function play_music(n, fade, mask)
  if gm3 then
    music(n, fade, mask)
  else
    music(-1)
  end
end

function shake(duration, intensity)
  fx2 = duration
  fx1 = intensity
  _log("shake:"..duration..":"..intensity)
end

function get_ball_skin_color()
  if cu5 == 2 then
    return 9
  elseif cu5 == 3 then
    return 12
  else
    return 10
  end
end

function draw_ball_trail()
  for i,t in pairs(bl1) do
    if t.life > 0 then
      local c = (cu5==1 and 6) or (cu5==2 and 9) or 12
      if cu4==2 then c=8+(i%8) elseif cu4==3 then c=7 end
      circfill(t.x,t.y,1,c)
    end
  end
end

function draw_ball()
  local c = (cu5==1 and 7) or (cu5==2 and 10) or 12
  if bl3>0 then c=7 end
  circfill(ball.x,ball.y,ball.r,c)
end

function _update()
  if state == "menu" then
    update_menu()
  elseif state == "tutorial" then
    update_tutorial()
  elseif state == "difficulty_select" then
    update_difficulty_select()
  elseif state == "settings" then
    update_settings()
  elseif state == "difficulty_customize" then
    update_difficulty_customize()
  elseif state == "variant_leaderboards" then
    update_variant_leaderboards()
  elseif state == "ad2" then
    update_achievements()
  elseif state == "statistics" then
    update_statistics()
  elseif state == "progress" then
    update_progress()
  elseif state == "practice_obstacle_select" then
    update_practice_obstacle_select()
  elseif state == "practice_speed_select" then
    update_practice_speed_select()
  elseif state == "practice_play" then
    update_practice_play()
  elseif state == "challenge_variant_menu" then
    update_challenge_variant_menu()
  elseif state == "challenge" then
    update_challenge()
  elseif state == "challenge_summary" then
    update_challenge_summary()
  elseif state == "gauntlet" then
    update_gauntlet()
  elseif state == "gauntlet_gameover" then
    update_gauntlet_gameover()
  elseif state == "bossrush" then
    update_bossrush()
  elseif state == "bossrush_gameover" then
    update_bossrush_gameover()
  elseif state == "play" then
    update_play()
  elseif state == "pause" then
    update_pause()
  elseif state == "gameover" then
    update_gameover()
  elseif state == "enter_initials" then
    update_enter_initials()
  end
end

function _draw()
  cls(1)

  camera(fx3, fx4)

  if state == "menu" then
    draw_menu()
  elseif state == "tutorial" then
    draw_tutorial()
  elseif state == "difficulty_select" then
    draw_difficulty_select()
  elseif state == "settings" then
    draw_settings()
  elseif state == "difficulty_customize" then
    draw_difficulty_customize()
  elseif state == "variant_leaderboards" then
    draw_variant_leaderboards()
  elseif state == "ad2" then
    draw_achievements()
  elseif state == "statistics" then
    draw_statistics()
  elseif state == "progress" then
    draw_progress()
  elseif state == "practice_obstacle_select" then
    draw_practice_obstacle_select()
  elseif state == "practice_speed_select" then
    draw_practice_speed_select()
  elseif state == "practice_play" then
    draw_practice_play()
  elseif state == "challenge_variant_menu" then
    draw_challenge_variant_menu()
  elseif state == "challenge" then
    draw_challenge()
  elseif state == "challenge_summary" then
    draw_challenge_summary()
  elseif state == "gauntlet" then
    draw_gauntlet()
  elseif state == "gauntlet_gameover" then
    draw_gauntlet_gameover()
  elseif state == "bossrush" then
    draw_bossrush()
  elseif state == "bossrush_gameover" then
    draw_bossrush_gameover()
  elseif state == "play" then
    draw_play()
  elseif state == "pause" then
    draw_pause()
  elseif state == "gameover" then
    draw_gameover()
  elseif state == "enter_initials" then
    draw_enter_initials()
  end

  camera()

  if fx5 > 0 then
    for i = 0, 127, 4 do
      for j = 0, 127, 4 do
        pset(i, j, 7)
      end
    end
  end

  if fx2 > 0 then
    fx2 -= 1
    local shake_amt = fx1 * (fx2 / 10)
    fx3 = (rnd(2) - 1) * shake_amt
    fx4 = (rnd(2) - 1) * shake_amt
  else
    fx3 = 0
    fx4 = 0
  end

  if fx5 > 0 then
    fx5 -= 1
  end

  if bl3 > 0 then
    bl3 -= 1
  end

  if fx7 > 0 then
    fx7 -= 1
  end

  if fx6 > 0 then
    fx6 -= 1
  end
end

function update_menu()
  local input = test_input()

  if ic1 > 0 then
    ic1 -= 1
  end

  if ic1 == 0 then
    if input & 4 > 0 then
      mc1 = max(1, mc1 - 1)
      play_sfx(1)
      _log("menu_nav:up:"..mc1)
      _log("sfx_menu_nav")
      ic1 = 10
    end

    if input & 8 > 0 then
      mc1 = min(11, mc1 + 1)
      play_sfx(1)
      _log("menu_nav:down:"..mc1)
      _log("sfx_menu_nav")
      ic1 = 10
    end

    if input & 16 > 0 then
      local selection = mc2[mc1]
      if selection == "play" then
        state = "difficulty_select"
        _log("state:difficulty_select")
        ic3 = lm9
        ic1 = 10
      elseif selection == "challenge" then
        state = "challenge_variant_menu"
        _log("state:challenge_variant_menu")
        mc3 = 1
        ic1 = 10
      elseif selection == "practice" then
        state = "practice_obstacle_select"
        _log("state:practice_obstacle_select")
        pr5 = 1
        ic1 = 10
      elseif selection == "gauntlet" then
        if gt9 then
          init_gauntlet()
          state = "gauntlet"
          _log("state:gauntlet")
        else
          play_sfx(3)
          _log("gauntlet_locked")
        end
        ic1 = 10
      elseif selection == "bossrush" then
        init_bossrush()
        state = "bossrush"
        _log("state:bossrush")
        ic1 = 10
      elseif selection == "tutorial" then
        state = "tutorial"
        _log("state:tutorial")
        mc5 = 1
        ic1 = 10
      elseif selection == "variant_leaderboards" then
        state = "variant_leaderboards"
        _log("state:variant_leaderboards")
        vl1 = 0
        ic1 = 10
      elseif selection == "ad2" then
        state = "ad2"
        _log("state:ad2")
        ad4 = 0
        ic1 = 10
      elseif selection == "statistics" then
        state = "statistics"
        _log("state:statistics")
        sb7 = 0
        sb8 = 1
        ic1 = 10
      elseif selection == "settings" then
        state = "settings"
        _log("state:settings")
        ss1 = 1
        ic1 = 10
      elseif selection == "progress" then
        state = "progress"
        _log("state:progress")
        sk4 = 0
        ic1 = 10
      end
    end
  end
end

function draw_menu()
  print("bounce king", 38, 30, 7)
  print("survive the fall!", 26, 42, 6)

  local menu_y = 50
  local menu_labels = {
    "play",
    "daily challenge",
    "practice mode",
    "boss gauntlet",
    "tutorial",
    "boss rush \x8e",
    "variant boards",
    "ad2",
    "statistics",
    "settings",
    "\x94 progress"
  }

  for i = 1, 11 do
    local col = 6
    local prefix = " "
    if i == mc1 then
      col = 10
      prefix = "> "
    end
    local label = menu_labels[i]
    if i == 4 and not gt9 then
      label = label.." \x94"
      col = 5
    end
    print(prefix..label, 24, menu_y + (i - 1) * 7, col)
  end

  if #ui6 > 0 then
    local top = ui6[1]
    print("best: "..top.score.." ("..top.initials..")", 20, 118, 10)
  end
end

function update_tutorial()
  local input = test_input()

  if ic1 > 0 then
    ic1 -= 1
  end

  if ic1 == 0 then
    if input & 4 > 0 then
      mc5 = max(1, mc5 - 1)
      play_sfx(1)
      _log("tutorial_nav:up:"..mc5)
      ic1 = 10
    end
    if input & 8 > 0 then
      mc5 = min(5, mc5 + 1)
      play_sfx(1)
      _log("tutorial_nav:down:"..mc5)
      ic1 = 10
    end
  end

  if input & 16 > 0 then
    mc6 = true
    dset(53, 1)
    play_music(2)
    state = "menu"
    _log("tutorial_complete")
    _log("state:menu")
  end
end

function draw_tutorial()
  print("how to play", 38, 4, 7)
  print("page "..mc5.."/5", 48, 12, 6)

  if mc5 == 1 then
    print("controls:", 10, 24, 10)
    print("left/right arrows", 20, 32, 7)
    print("move your ball", 20, 40, 6)
    print("ball bounces automatically", 10, 50, 11)

    print("objective:", 10, 62, 10)
    print("dodge falling ob4", 16, 70, 7)
    print("collect power-ups", 24, 78, 7)
    print("survive as long as you can", 10, 86, 7)

  elseif mc5 == 2 then
    print("ob4:", 10, 24, 10)

    circfill(20, 38, 6, 8)
    print("spike: static", 32, 34, 7)

    circfill(20, 54, 10, 8)
    print("moving: left-right", 36, 50, 7)

    circfill(20, 70, 8, 8)
    print("rotating: pulsing", 34, 66, 7)

    print("more types unlock as", 16, 86, 6)
    print("lm9 increases!", 20, 94, 6)

  elseif mc5 == 3 then
    print("power-ups:", 10, 24, 10)

    circfill(16, 34, 4, 11)
    print("shield: +1 life", 26, 32, 7)

    circfill(16, 46, 4, 12)
    print("slowmo: slow time", 26, 44, 7)

    circfill(16, 58, 4, 10)
    print("doublescore: 2x pts", 26, 56, 7)

    circfill(16, 70, 4, 13)
    print("magnet: pull items", 26, 68, 7)

    circfill(16, 82, 4, 8)
    print("bomb: clear screen", 26, 80, 7)

    circfill(16, 94, 4, 12)
    print("freeze: stop enemies", 26, 92, 7)

  elseif mc5 == 4 then
    print("scoring:", 10, 24, 10)

    print("dodge bonus:", 16, 34, 7)
    print("+10 per obstacle", 24, 42, 6)

    print("combo system:", 16, 54, 7)
    print("chain dodges for bonus", 20, 62, 6)
    print("resets on collision", 22, 70, 8)

    print("lm7:", 16, 82, 7)
    print("increases every 10s", 20, 90, 6)
    print("1.0x -> 1.5x -> 2.0x...", 16, 98, 10)

  elseif mc5 == 5 then
    print("you're ready!", 34, 30, 10)

    print("tips:", 10, 46, 7)
    print("- stay near the center", 16, 54, 6)
    print("- watch for patterns", 18, 62, 6)
    print("- time your movements", 14, 70, 6)
    print("- collect power-ups", 18, 78, 6)
    print("- practice makes perfect", 10, 86, 11)

    print("good luck!", 40, 100, 14)
  end

  print("up/down: change page", 16, 118, 13)
  print("o: skip to menu", 26, 124, 13)
end

function update_difficulty_select()
  local input = test_input()

  if ic1 > 0 then
    ic1 -= 1
  end

  if ic1 == 0 then
    if input & 4 > 0 then
      ic3 = max(1, ic3 - 1)
      play_sfx(1)
      _log("difficulty_nav:up")
      ic1 = 10
    end
    if input & 8 > 0 then
      ic3 = min(3, ic3 + 1)
      play_sfx(1)
      _log("difficulty_nav:down")
      ic1 = 10
    end
  end

  if input & 16 > 0 then
    lm9 = ic3
    local diff_names = {"easy", "normal", "hard"}
    _log("difficulty_select:"..diff_names[lm9])
    state = "play"
    _log("state:play")
    init_game()
  end
end

function draw_difficulty_select()
  print("select lm9", 22, 30, 7)

  local col1 = ic3 == 1 and 10 or 6
  print("> easy", 38, 50, col1)
  print("slower ob4", 16, 58, 5)
  print("more forgiving", 20, 64, 5)

  local col2 = ic3 == 2 and 10 or 6
  print("> normal", 34, 76, col2)
  print("balanced gameplay", 14, 84, 5)

  local col3 = ic3 == 3 and 10 or 6
  print("> hard", 38, 96, col3)
  print("faster ob4", 16, 104, 5)
  print("real challenge", 22, 110, 5)

  print("up/down: choose", 18, 122, 13)
end

function update_settings()
  local input = test_input()

  if ic1 > 0 then
    ic1 -= 1
  end

  if ic1 == 0 then
    if input & 4 > 0 then
      ss1 = max(1, ss1 - 1)
      play_sfx(1)
      _log("settings_nav:up")
      ic1 = 10
    end
    if input & 8 > 0 then
      ss1 = min(7, ss1 + 1)
      play_sfx(1)
      _log("settings_nav:down")
      ic1 = 10
    end

    if input & 16 > 0 then
      if ss1 == 1 then
        gm3 = not gm3
        play_sfx(1)
        _log("toggle_music:"..tostr(gm3))
        if not gm3 then
          music(-1)
        end
      elseif ss1 == 2 then
        gm4 = not gm4
        play_sfx(1)
        _log("toggle_sfx:"..tostr(gm4))
      elseif ss1 == 3 then
        repeat
          cu5 = cu5 % 3 + 1
        until cu5 == 1 or (cu5 == 2 and (cu1 & 1) > 0) or (cu5 == 3 and (cu1 & 2) > 0)
        cu6[cu5] = true
        play_sfx(1)
        _log("cu5:"..cu5)
        local all_used = cu6[1] and cu6[2] and cu6[3]
        if all_used and not ad2[7] then
          unlock_achievement(7)
        end
      elseif ss1 == 4 then
      elseif ss1 == 5 then
        state = "difficulty_customize"
        _log("state:difficulty_customize")
        dc1 = 1
        ic1 = 10
      elseif ss1 == 6 then
        repeat
          cu4 = cu4 % 3 + 1
        until cu4 == 1 or (cu4 == 2 and (cu1 & 4) > 0) or (cu4 == 3 and (cu1 & 128) > 0)
        play_sfx(1)
        _log("cu4:"..cu4)
      elseif ss1 == 7 then
        repeat
          cu3 = cu3 % 5 + 1
        until cu3 == 1 or (cu3 == 2 and (cu1 & 8) > 0) or (cu3 == 3 and (cu1 & 16) > 0) or (cu3 == 4 and (cu1 & 32) > 0) or (cu3 == 5 and (cu1 & 64) > 0)
        play_sfx(1)
        _log("cu3:"..cu3)
      end
      save_settings()
      save_cosmetics()
      ic1 = 10
    end
  end

  if input & 32 > 0 then
    play_music(2)
    state = "menu"
    _log("state:menu")
    save_settings()
    ic1 = 10
  end
end

function draw_settings()
  print("settings", 44, 10, 7)

  local col1 = ss1 == 1 and 10 or 6
  local check1 = gm3 and "\x8e" or "\x83"
  print("> music: "..check1, 20, 20, col1)

  local col2 = ss1 == 2 and 10 or 6
  local check2 = gm4 and "\x8e" or "\x83"
  print("> sfx: "..check2, 20, 28, col2)

  local col3 = ss1 == 3 and 10 or 6
  local skin_names = {"white", "gold", "cyan"}
  local skin_str = skin_names[cu5]
  if cu5 > 1 and (cu1 & (cu5 == 2 and 1 or 2)) == 0 then
    skin_str = skin_str.." \x94"
  end
  print("> ball: "..skin_str, 20, 36, col3)

  local col4 = ss1 == 4 and 10 or 6
  print("> controls", 20, 44, col4)

  local col5 = ss1 == 5 and 10 or 6
  print("> lm9...", 20, 52, col5)

  local col6 = ss1 == 6 and 10 or 6
  local trail_names = {"basic", "rainbow", "white"}
  local trail_str = trail_names[cu4]
  if cu4 > 1 and (cu1 & (cu4 == 2 and 4 or 128)) == 0 then
    trail_str = trail_str.." \x94"
  end
  print("> trail: "..trail_str, 20, 60, col6)

  local col7 = ss1 == 7 and 10 or 6
  local theme_names = {"default", "pink", "gold", "red", "blue"}
  local theme_str = theme_names[cu3]
  if cu3 > 1 then
    local bit_map = {0, 8, 16, 32, 64}
    if (cu1 & bit_map[cu3]) == 0 then
      theme_str = theme_str.." \x94"
    end
  end
  print("> theme: "..theme_str, 20, 68, col7)

  if ss1 == 4 then
    print("arrows: move ball", 8, 86, 5)
    print("o: confirm/toggle", 8, 92, 5)
    print("x: pause/back", 14, 98, 5)
  elseif ss1 == 5 then
    print("customize gameplay", 16, 86, 5)
    print("spawn, scaling,", 20, 92, 6)
    print("combo bonus, lives", 18, 98, 6)
  elseif ss1 == 3 then
    print("ball skin cosmetic", 18, 96, 5)
    if (cu1 & 1) == 0 then
      print("gold: score 300+", 20, 102, 6)
    end
    if (cu1 & 2) == 0 then
      print("cyan: combo 15+", 22, 108, 6)
    end
  elseif ss1 == 6 then
    print("ball trail style", 18, 96, 5)
    if (cu1 & 4) == 0 then
      print("rainbow: 15+ pw6", 12, 102, 6)
    end
    if (cu1 & 128) == 0 then
      print("white: survive 60s", 14, 108, 6)
    end
  elseif ss1 == 7 then
    print("color theme overlay", 14, 96, 5)
    if (cu1 & 8) == 0 then
      print("pink: 5+ danger zones", 10, 102, 6)
    end
    if (cu1 & 16) == 0 then
      print("gold: 1.5x lm7", 8, 108, 6)
    end
    if (cu1 & 32) == 0 then
      print("red: lm8 5+", 12, 114, 6)
    end
    if (cu1 & 64) == 0 then
      print("blue: 20+ dodges", 16, 120, 6)
    end
  end

  print("up/down: navigate", 16, 110, 13)
  print("o: toggle/open", 26, 116, 13)
  print("x: back", 36, 122, 13)
end

function update_difficulty_customize()
  local input = test_input()

  if ic1 > 0 then
    ic1 -= 1
  end

  if ic1 == 0 then
    if input & 4 > 0 then
      dc1 = max(1, dc1 - 1)
      play_sfx(1)
      _log("difficulty_customize_nav:up")
      ic1 = 10
    end
    if input & 8 > 0 then
      dc1 = min(4, dc1 + 1)
      play_sfx(1)
      _log("difficulty_customize_nav:down")
      ic1 = 10
    end

    if input & 1 > 0 then
      if dc1 == 1 then
        lm3 = max(1, lm3 - 1)
        play_sfx(1)
        _log("lm3:"..lm3)
      elseif dc1 == 2 then
        lm2 = max(1, lm2 - 1)
        play_sfx(1)
        _log("lm2:"..lm2)
      elseif dc1 == 3 then
        lm4 = max(1, lm4 - 1)
        play_sfx(1)
        _log("lm4:"..lm4)
      elseif dc1 == 4 then
        lm5 = max(1, lm5 - 1)
        play_sfx(1)
        _log("lm5:"..lm5)
      end
      save_settings()
      ic1 = 10
    end

    if input & 2 > 0 then
      if dc1 == 1 then
        lm3 = min(4, lm3 + 1)
        play_sfx(1)
        _log("lm3:"..lm3)
      elseif dc1 == 2 then
        lm2 = min(4, lm2 + 1)
        play_sfx(1)
        _log("lm2:"..lm2)
      elseif dc1 == 3 then
        lm4 = min(3, lm4 + 1)
        play_sfx(1)
        _log("lm4:"..lm4)
      elseif dc1 == 4 then
        lm5 = min(3, lm5 + 1)
        play_sfx(1)
        _log("lm5:"..lm5)
      end
      save_settings()
      ic1 = 10
    end
  end

  if input & 32 > 0 then
    state = "settings"
    _log("state:settings")
    save_settings()
    ic1 = 10
  end
end

function draw_difficulty_customize()
  print("lm9", 40, 10, 7)

  local col1 = dc1 == 1 and 10 or 6
  local spawn_names = {"slow", "normal", "fast", "extreme"}
  print("spawn rate:", 20, 24, col1)
  print("< "..spawn_names[lm3].." >", 44, 32, col1)

  local col2 = dc1 == 2 and 10 or 6
  local scale_names = {"slow", "normal", "fast", "insane"}
  print("scaling:", 24, 46, col2)
  print("< "..scale_names[lm2].." >", 44, 54, col2)

  local col3 = dc1 == 3 and 10 or 6
  local bonus_names = {"1.5x", "1.0x", "0.7x"}
  print("combo bonus:", 18, 68, col3)
  print("< "..bonus_names[lm4].." >", 44, 76, col3)

  local col4 = dc1 == 4 and 10 or 6
  local lives_names = {"5 lives", "3 lives", "1 life"}
  print("lives:", 30, 90, col4)
  print("< "..lives_names[lm5].." >", 44, 98, col4)

  print("left/right: adjust", 18, 110, 13)
  print("up/down: navigate", 16, 116, 13)
  print("x: back", 36, 122, 13)
end

function update_leaderboard()
  local input = test_input()

  if input & 32 > 0 then
    play_music(2)
    state = "menu"
    _log("state:menu")
    ic1 = 10
  end
end

function draw_leaderboard()
  print("ui6", 38, 8, 7)
  print("-- top 10 scores --", 22, 18, 6)

  if #ui6 == 0 then
    print("no entries yet!", 26, 60, 13)
    print("play to set a record!", 14, 70, 11)
  else
    local y = 28
    for i = 1, min(10, #ui6) do
      local entry = ui6[i]
      local col = 13
      if i == 1 then
        col = 10
      elseif i == 2 then
        col = 12
      elseif i == 3 then
        col = 14
      end

      if i == ui4 and ui4 > 0 then
        col = 11
        print(">", 8, y, col)
      end

      local rank_str = i < 10 and " "..i or tostr(i)
      print(rank_str, 14, y, col)

      print(entry.initials, 28, y, col)

      print(entry.score, 52, y, col)

      y += 9
      if y > 118 then break end
    end
  end

  print("x: back to menu", 20, 122, 5)
end

function update_variant_leaderboards()
  local input = test_input()

  if ic1 > 0 then
    ic1 -= 1
  end

  if ic1 == 0 then
    if input & 1 > 0 then
      vl1 = max(0, vl1 - 1)
      play_sfx(1)
      _log("variant_tab:"..vl1)
      ic1 = 10
    end

    if input & 2 > 0 then
      vl1 = min(6, vl1 + 1)
      play_sfx(1)
      _log("variant_tab:"..vl1)
      ic1 = 10
    end

    if input & 32 > 0 then
      play_music(2)
      state = "menu"
      _log("state:menu")
      ic1 = 10
    end
  end
end

function draw_variant_leaderboards()
  local tab_names = {"all-time", "time attack", "survival", "speed run", "combo master", "power-up party", "boss slayer"}

  print("variant leaderboards", 16, 4, 7)

  local tab_x = 4
  for i = 0, 6 do
    local col = (i == vl1) and 10 or 6
    local name = tab_names[i + 1]
    if i == vl1 then
      print(name, tab_x, 12, col)
    end
    tab_x += #name * 4 + 2
    if tab_x > 100 then break end
  end

  print("<   >", 52, 12, 5)

  local filtered = {}
  for i = 1, #ui6 do
    local entry = ui6[i]
    if vl1 == 0 or entry.variant == vl1 then
      add(filtered, entry)
    end
  end

  if #filtered == 0 then
    print("no scores yet!", 30, 60, 13)
    print("play to set a record!", 14, 70, 11)
  else
    local y = 28
    for i = 1, min(10, #filtered) do
      local entry = filtered[i]
      local col = 13
      if i == 1 then
        col = 10
      elseif i == 2 then
        col = 12
      elseif i == 3 then
        col = 14
      end

      local rank_str = i < 10 and " "..i or tostr(i)
      print(rank_str, 8, y, col)
      print(entry.initials, 22, y, col)
      print(entry.score, 46, y, col)

      local var_name = ""
      if entry.variant > 0 and vl1 == 0 then
        local short_names = {"TA", "SV", "SR", "CM", "PP", "BS"}
        var_name = short_names[entry.variant]
        print(var_name, 80, y, 5)
      end

      y += 9
      if y > 110 then break end
    end
  end

  print("arrows: switch tabs", 14, 118, 5)
  print("x: back", 40, 124, 5)
end

function update_pause()
  if ic2 > 0 then
    ic2 -= 1
  end

  local input = test_input()
  if ic2 == 0 and input & 32 > 0 then
    state = "play"
    play_music(0)
    _log("state:resume")
    ic2 = 15
  end
end

function draw_pause()
  draw_play()

  for i = 0, 127, 2 do
    for j = 0, 127, 2 do
      pset(i, j, 0)
    end
  end

  rectfill(24, 40, 104, 90, 0)
  rect(24, 40, 104, 90, 7)
  rect(25, 41, 103, 89, 6)

  print("paused", 48, 46, 7)
  print("score: "..score, 38, 56, 10)
  print("time: "..flr(gm1/30).."s", 36, 64, 11)
  print("combo: "..combo, 40, 72, 9)
  print("press x to resume", 28, 82, 13)
end

function update_achievements()
  if ic1 > 0 then
    ic1 -= 1
  end

  local input = test_input()

  if ic1 == 0 and input & 32 > 0 then
    play_music(2)
    state = "menu"
    _log("state:menu")
    ic1 = 10
  end
end

function draw_achievements()
  print("ad2", 34, 8, 7)
  print(ad3.."/8 unlocked", 32, 18, 10)

  local y_start = 30
  for i = 1, 8 do
    local ach = ad1[i]
    local y = y_start + (i - 1) * 12

    if ach.unlocked then
      print("\x8e "..ach.title, 10, y, 9)
      print(ach.desc, 10, y + 6, 10)
    else
      print("\x94 "..ach.title, 10, y, 5)
      print(ach.desc, 10, y + 6, 5)
    end
  end

  print("press x to return", 24, 118, 13)
end

function update_statistics()
  local input = test_input()

  if ic1 > 0 then
    ic1 -= 1
  end

  if ic1 == 0 then
    if input & 4 > 0 then
      sb8 = max(1, sb8 - 1)
      play_sfx(1)
      _log("stats_nav:up:page="..sb8)
      ic1 = 10
    end

    if input & 8 > 0 then
      sb8 = min(3, sb8 + 1)
      play_sfx(1)
      _log("stats_nav:down:page="..sb8)
      ic1 = 10
    end

    if input & 32 > 0 then
      st1 = 0
      st2 = 0
      st3 = 0
      st4 = 0
      st5 = 0
      st6 = 0
      st7 = 0
      st8 = 0
      st9 = 0
      sa1 = 0
      sa2 = 0
      sa3 = 0
      sa4 = 0
      sa5 = 0
      sa6 = 0
      sa7 = 0
      sa8 = 0
      sa9 = 0
      sb1 = 0
      sb2 = 0
      sb3 = 0
      sb4 = 0
      sb5 = 0
      sb6 = 0
      save_statistics()
      play_sfx(7)
      shake(15, 0.5)
      _log("stats_reset")
      ic1 = 30
    end

    if input & 16 > 0 then
      state = "menu"
      play_music(2)
      _log("state:menu")
      ic1 = 10
    end
  end
end

function draw_statistics()
  print("player statistics", 20, 8, 7)

  print("page "..sb8.."/3", 46, 18, 13)

  if sb8 == 1 then
    print("career overview", 28, 28, 10)

    local y = 38
    print("games played: "..st1, 8, y, 6)
    y += 8

    local mins = flr(st2 / 60)
    local secs = st2 % 60
    print("time played: "..mins.."m "..secs.."s", 8, y, 6)
    y += 8

    local avg_score = st1 > 0 and flr(st5 / st1) or 0
    print("avg score: "..avg_score, 8, y, 6)
    y += 8

    print("best combo: "..st6, 8, y, 6)
    y += 8

    local max_mult_display = st7 / 100
    print("max lm7: "..max_mult_display.."x", 8, y, 6)
    y += 8

    print("total dodges: "..st3, 8, y, 6)
    y += 8

    print("power-ups: "..st4, 8, y, 6)
    y += 8

    print("streak: "..sb5.." (best: "..sb6..")", 8, y, 6)

  elseif sb8 == 2 then
    print("lm9 stats", 28, 28, 10)

    local y = 38
    print("easy mode:", 8, y, 9)
    y += 8
    print(" games: "..st8, 8, y, 6)
    y += 6
    local easy_avg = st8 > 0 and flr(sa2 / st8) or 0
    print(" avg: "..easy_avg, 8, y, 6)
    y += 6
    print(" max combo: "..sa5, 8, y, 6)
    y += 10

    print("normal mode:", 8, y, 12)
    y += 8
    print(" games: "..st9, 8, y, 6)
    y += 6
    local normal_avg = st9 > 0 and flr(sa3 / st9) or 0
    print(" avg: "..normal_avg, 8, y, 6)
    y += 6
    print(" max combo: "..sa6, 8, y, 6)
    y += 10

    print("hard mode:", 8, y, 8)
    y += 8
    print(" games: "..sa1, 8, y, 6)
    y += 6
    local hard_avg = sa1 > 0 and flr(sa4 / sa1) or 0
    print(" avg: "..hard_avg, 8, y, 6)
    y += 6
    print(" max combo: "..sa7, 8, y, 6)

  elseif sb8 == 3 then
    print("power-up usage", 28, 28, 10)

    local y = 38
    local powerup_names = {"shield", "slowmo", "2x score", "magnet", "bomb", "freeze"}
    local powerup_counts = {
      sa8,
      sa9,
      sb1,
      sb2,
      sb3,
      sb4
    }

    local max_count = 0
    local max_idx = 1
    local min_count = 999999
    local min_idx = 1
    for i = 1, 6 do
      if powerup_counts[i] > max_count then
        max_count = powerup_counts[i]
        max_idx = i
      end
      if powerup_counts[i] < min_count then
        min_count = powerup_counts[i]
        min_idx = i
      end
    end

    for i = 1, 6 do
      local col = 6
      local marker = ""
      if i == max_idx and max_count > 0 then
        col = 10
        marker = " \x8e"
      elseif i == min_idx and st4 > 0 then
        col = 13
        marker = " \x97"
      end

      print(powerup_names[i]..": "..powerup_counts[i]..marker, 8, y, col)
      y += 10
    end

    print("total: "..st4, 8, y + 4, 7)
  end

  print("arrows: navigate", 20, 108, 13)
  print("x: reset z: back", 18, 116, 13)
end

function update_progress()
  local input = test_input()

  if ic1 > 0 then
    ic1 -= 1
  end

  if ic1 == 0 then
    if input & 4 > 0 then
      sk4 = max(0, sk4 - 1)
      play_sfx(1)
      _log("progress_nav:up:"..sk4)
      ic1 = 10
    end

    if input & 8 > 0 then
      sk4 = min(7, sk4 + 1)
      play_sfx(1)
      _log("progress_nav:down:"..sk4)
      ic1 = 10
    end

    if input & 32 > 0 or input & 16 > 0 then
      play_music(2)
      state = "menu"
      _log("state:menu:progress_exit")
      ic1 = 10
    end
  end
end

function draw_progress()
  print("unlock progress", 26, 8, 7)

  print("streak: "..sk1.." day"..(sk1 == 1 and "" or "s"), 8, 20, 10)
  print("best: "..sk2.." day"..(sk2 == 1 and "" or "s"), 8, 28, 12)

  local unlocks = {
    {name="gold ball", cur=gm2, max=300, type="score"},
    {name="cyan ball", cur=ic7, max=15, type="combo"},
    {name="rainbow trail", cur=ic5, max=15, type="powerups"},
    {name="pink theme", cur=ad6, max=5, type="danger"},
    {name="gold theme", cur=flr(lm7 * 10), max=15, type="mult"},
    {name="red theme", cur=ob6, max=5, type="diff"},
    {name="blue theme", cur=ic8, max=20, type="dodges"},
    {name="white trail", cur=flr(gm1 / 30), max=60, type="time"}
  }

  for i = 1, 8 do
    local u = unlocks[i]
    local y = 36 + (i - 1) * 9
    local col = sk4 == i - 1 and 7 or 6
    local pct = min(1.0, u.cur / u.max)
    local bar_len = flr(pct * 40)

    print(u.name, 8, y, col)
    print(u.cur.."/"..u.max, 80, y, col)

    for j = 0, 39 do
      local bar_col = j < bar_len and 11 or 5
      pset(8 + j, y + 7, bar_col)
    end
  end

  print("arrows: navigate", 20, 110, 13)
  print("x/z: back to menu", 18, 118, 13)
end

function init_game()
  ball.x = 64
  ball.y = 100
  ball.vx = 0
  ball.vy = 0
  ball.grounded = false
  score = 0
  ui2 = false
  ui1 = 0
  ui3 = 0
  cu2 = false
  gm1 = 0
  lm7 = 1.0
  lm8 = 1
  combo = 0
  lm1 = 0
  lives = lm5 == 1 and 5 or (lm5 == 3 and 1 or 3)
  fx7 = 0
  ob4 = {}
  pw6 = {}
  fx8 = {}
  fx9 = {}
  bl1 = {}
  ob3 = 0
  ob6 = 0
  pw7 = 0
  pw2 = 0
  pw3 = 0
  pw1 = 0
  pw4 = 0
  pw5 = 0
  ob1 = false

  ic9 = 0
  ic8 = 0
  ic7 = 0
  ic6 = 0
  ic5 = 0

  ad5 = {}
  ad7 = gm1

  if lm9 == 1 then
    ob7 = 0.3
    ob2 = 80
  elseif lm9 == 2 then
    ob7 = 0.5
    ob2 = 60
  elseif lm9 == 3 then
    ob7 = 0.8
    ob2 = 40
  end

  if lm3 == 1 then
    ob2 = flr(ob2 * 1.2)
  elseif lm3 == 3 then
    ob2 = flr(ob2 * 0.8)
  elseif lm3 == 4 then
    ob2 = flr(ob2 * 0.5)
  end

  dz1 = {
    {x_min=0, x_max=42, active=false, pulse=0},
    {x_min=43, x_max=85, active=false, pulse=0},
    {x_min=86, x_max=128, active=false, pulse=0}
  }
  lm6 = 0
  dz3 = 450 + rnd(150)
  _log("zones_init")

  play_music(0)
  _log("game_init:lm9="..lm9)
end

function update_challenge_variant_menu()
  local input = test_input()

  if ic1 > 0 then
    ic1 -= 1
  end

  if ic1 == 0 then
    if input & 4 > 0 then
      mc3 = max(1, mc3 - 1)
      play_sfx(1)
      _log("variant_nav:up:"..mc3)
      ic1 = 10
    end

    if input & 8 > 0 then
      mc3 = min(6, mc3 + 1)
      play_sfx(1)
      _log("variant_nav:down:"..mc3)
      ic1 = 10
    end

    if input & 16 > 0 then
      ct9 = mc3
      init_challenge()
      state = "challenge"
      _log("state:challenge:variant="..ct9)
      ic1 = 10
    end

    if input & 32 > 0 then
      play_music(2)
      state = "menu"
      _log("state:menu:variant_cancel")
      ic1 = 10
    end
  end
end

function draw_challenge_variant_menu()
  print("daily challenge", 28, 20, 7)
  print("select variant", 32, 30, 6)

  local variant_names = {
    "time attack",
    "survival",
    "speed run",
    "combo master",
    "power-up party",
    "boss slayer"
  }

  local variant_desc = {
    "90s: max score",
    "3 lives: endure",
    "reach 500 fast",
    "90s: big combo",
    "90s: collect all",
    "90s: bosses only"
  }

  local y = 42
  for i = 1, 6 do
    local col = (i == mc3) and 10 or 6
    local marker = (i == mc3) and "> " or "  "
    print(marker..variant_names[i], 16, y, col)
    print(variant_desc[i], 22, y + 6, 5)
    y += 13
  end

  print("arrows: navigate", 22, 118, 5)
  print("z: select x: back", 18, 124, 5)
end

function init_challenge()
  ct5 = flr(time() / 86400)
  _log("challenge_seed_recomputed:"..ct5)

  local stored_seed = dget(55)
  if stored_seed ~= ct5 then
    ct4 = 0
    dset(55, ct5)
    dset(54, 0)
    _log("challenge_new_day:seed="..ct5)
  else
    ct4 = dget(54)
    _log("challenge_same_day:best="..ct4)
  end

  ball.x = 64
  ball.y = 100
  ball.vx = 0
  ball.vy = 0
  ball.grounded = false
  ct3 = 0
  ct2 = true
  ct1 = 90 * 30
  ct6 = 0
  gm1 = 0
  lm7 = 1.0
  lm8 = 1
  combo = 0
  lm1 = 0
  lives = 3
  fx7 = 0
  ob4 = {}
  pw6 = {}
  fx8 = {}
  fx9 = {}
  bl1 = {}
  ob3 = 0
  ob6 = 0
  pw7 = 0
  pw2 = 0
  pw3 = 0
  pw1 = 0
  pw4 = 0
  pw5 = 0
  ob1 = false

  ic9 = 0
  ic8 = 0
  ic7 = 0
  ic6 = 0
  ic5 = 0
  ad5 = {}

  srand(ct5)
  local seed_mod = ct5 % 3
  if seed_mod == 0 then
    ob7 = 0.6
    ob2 = 50
  elseif seed_mod == 1 then
    ob7 = 0.7
    ob2 = 45
  else
    ob7 = 0.8
    ob2 = 40
  end

  if lm3 == 1 then
    ob2 = flr(ob2 * 1.2)
  elseif lm3 == 3 then
    ob2 = flr(ob2 * 0.8)
  elseif lm3 == 4 then
    ob2 = flr(ob2 * 0.5)
  end

  dz1 = {
    {x_min=0, x_max=42, active=false, pulse=0},
    {x_min=43, x_max=85, active=false, pulse=0},
    {x_min=86, x_max=128, active=false, pulse=0}
  }
  lm6 = 0
  dz3 = 450 + rnd(150)

  ct7 = 3
  ct8 = 0

  if ct9 == 1 then
    ct1 = 90 * 30
  elseif ct9 == 2 then
    ct1 = 99999 * 30
    ob2 = flr(ob2 * 0.5)
    _log("variant:survival:spawn_2x")
  elseif ct9 == 3 then
    ct1 = 99999 * 30
    _log("variant:speed_run:target_500")
  elseif ct9 == 4 then
    ct1 = 90 * 30
    _log("variant:combo_master")
  elseif ct9 == 5 then
    ct1 = 90 * 30
    _log("variant:powerup_party:spawn_3x")
  elseif ct9 == 6 then
    ct1 = 90 * 30
    ob2 = flr(ob2 * 1.5)
    _log("variant:boss_slayer:boss_only")
  end

  local music_pattern = 0
  if ct9 == 2 or ct9 == 5 or ct9 == 6 then
    music_pattern = 1
  end
  play_music(music_pattern)
  _log("challenge_init:variant="..ct9..",music="..music_pattern..",seed="..ct5..",scroll="..ob7..",interval="..ob2)
end

function check_achievements()
  if not ad2[1] and gm1 >= 900 then
    unlock_achievement(1)
  end

  if not ad2[2] then
    local types_count = 0
    for k, v in pairs(ad5) do
      if v then types_count += 1 end
    end
    if types_count >= 6 then
      unlock_achievement(2)
    end
  end

  if not ad2[3] and combo >= 20 then
    unlock_achievement(3)
  end

  if not ad2[4] and ad6 >= 5 then
    unlock_achievement(4)
  end

  if not ad2[5] and score >= 500 then
    unlock_achievement(5)
  end

  if not ad2[6] and lm7 >= 2.0 then
    unlock_achievement(6)
  end

  if not ad2[8] and gm1 - ad7 >= 300 then
    unlock_achievement(8)
  end
end

function unlock_achievement(id)
  if ad2[id] then return end

  ad2[id] = true
  ad1[id].unlocked = true
  ad3 += 1

  local ach = ad1[id]
  _log("achievement:"..ach.name)

  play_sfx(6)
  shake(12, 1.2)
  add_floating_text(64, 50, "achievement!", 10)
  add_floating_text(64, 60, ach.title, 9)

  save_achievements()
end

function check_cosmetic_unlocks()
  local unlocked_any = false

  if score >= 300 and (cu1 & 1) == 0 then
    cu1 = cu1 | 1
    add_floating_text(64, 50, "unlocked!", 10)
    add_floating_text(64, 60, "gold ball", 9)
    play_sfx(6)
    shake(12, 1.2)
    unlocked_any = true
    _log("cosmetic_unlock:gold_ball")
  end

  if ic9 >= 15 and (cu1 & 2) == 0 then
    cu1 = cu1 | 2
    add_floating_text(64, 50, "unlocked!", 10)
    add_floating_text(64, 60, "cyan ball", 12)
    play_sfx(6)
    shake(12, 1.2)
    unlocked_any = true
    _log("cosmetic_unlock:cyan_ball")
  end

  if ic7 >= 15 and (cu1 & 4) == 0 then
    cu1 = cu1 | 4
    add_floating_text(64, 50, "unlocked!", 10)
    add_floating_text(64, 60, "rainbow trail", 14)
    play_sfx(6)
    shake(12, 1.2)
    unlocked_any = true
    _log("cosmetic_unlock:rainbow_trail")
  end

  if ad6 >= 5 and (cu1 & 8) == 0 then
    cu1 = cu1 | 8
    add_floating_text(64, 50, "unlocked!", 10)
    add_floating_text(64, 60, "pink theme", 14)
    play_sfx(6)
    shake(12, 1.2)
    unlocked_any = true
    _log("cosmetic_unlock:pink_theme")
  end

  if ic5 >= 1.5 and (cu1 & 16) == 0 then
    cu1 = cu1 | 16
    add_floating_text(64, 50, "unlocked!", 10)
    add_floating_text(64, 60, "gold theme", 10)
    play_sfx(6)
    shake(12, 1.2)
    unlocked_any = true
    _log("cosmetic_unlock:gold_theme")
  end

  if lm8 >= 5 and (cu1 & 32) == 0 then
    cu1 = cu1 | 32
    add_floating_text(64, 50, "unlocked!", 10)
    add_floating_text(64, 60, "red theme", 8)
    play_sfx(6)
    shake(12, 1.2)
    unlocked_any = true
    _log("cosmetic_unlock:red_theme")
  end

  if ic8 >= 20 and (cu1 & 64) == 0 then
    cu1 = cu1 | 64
    add_floating_text(64, 50, "unlocked!", 10)
    add_floating_text(64, 60, "blue theme", 12)
    play_sfx(6)
    shake(12, 1.2)
    unlocked_any = true
    _log("cosmetic_unlock:blue_theme")
  end

  if gm1 >= 1800 and (cu1 & 128) == 0 then
    cu1 = cu1 | 128
    add_floating_text(64, 50, "unlocked!", 10)
    add_floating_text(64, 60, "white trail", 7)
    play_sfx(6)
    shake(12, 1.2)
    unlocked_any = true
    _log("cosmetic_unlock:white_trail")
  end

  if unlocked_any then
    save_cosmetics()
  end
end

function update_ball()
  ball.vx *= 0.9
  ball.vy += 0.4
  ball.x += ball.vx
  ball.y += ball.vy

  if ball.y >= 122 then
    ball.y = 122
    ball.vy *= -0.7
    ball.grounded = true
    if abs(ball.vy) < 0.5 then
      ball.vy = -3
    end
    play_sfx(0)
    shake(6, 0.5 + lm8 * 0.1)
    add_particles(ball.x, 122, 5, 13)
    _log("bounce")
  else
    ball.grounded = false
  end

  if ball.x < ball.r then
    ball.x = ball.r
    ball.vx *= -0.5
    play_sfx(1)
    shake(4, 0.3)
    add_particles(ball.x, ball.y, 3, 6)
  elseif ball.x > 128 - ball.r then
    ball.x = 128 - ball.r
    ball.vx *= -0.5
    play_sfx(1)
    shake(4, 0.3)
    add_particles(ball.x, ball.y, 3, 6)
  end
end

function update_ball_trail()
  local vel = sqrt(ball.vx^2 + ball.vy^2)
  add(bl1, {x=ball.x, y=ball.y, vel=vel, age=0})
  for tr in all(bl1) do
    tr.age += 1
    if tr.age > 8 then
      del(bl1, tr)
    end
  end
  while #bl1 > bl2 do
    del(bl1, bl1[1])
  end
end

function update_obstacle(o)
  local speed_mod = pw3 > 0 and 0.5 or 1.0

  if not ob1 then
    o.y += ob7 * speed_mod

    if o.type == "moving" then
      o.x += o.vx
      if o.x < 0 or o.x > 128 then
        o.vx *= -1
      end
    elseif o.type == "rotating" then
      o.angle += 0.02
      o.r = 8 + sin(o.angle) * 4
    elseif o.type == "boss" then
      if o.boss_stage == 1 then
        o.wave_time += 0.03
        o.x = o.base_x + sin(o.wave_time) * 30
      elseif o.boss_stage == 2 then
        o.wave_time += 0.05
        o.x = o.base_x + sin(o.wave_time) * 35
      elseif o.boss_stage == 3 then
        o.wave_time += 0.06
        o.vertical_time += 0.04
        o.x = o.base_x + sin(o.wave_time) * 40
        local base_y = o.y
        o.y = base_y + sin(o.vertical_time) * 3

        o.satellite_timer += 1
        if o.satellite_timer >= 90 then
          o.satellite_timer = 0
          spawn_satellite(o)
        end
      end
    elseif o.type == "pendulum" then
      o.swing_time += 0.04
      o.x = o.base_x + sin(o.swing_time) * 25
    elseif o.type == "zigzag" then
      o.zig_time += 0.05
      local amp = 15 + lm8 * 2
      o.x += sin(o.zig_time) * amp * o.zig_dir * 0.1
      if o.x < 10 or o.x > 118 then
        o.zig_dir *= -1
      end
    elseif o.type == "orbiter" then
      o.orbit_angle += 0.05
    elseif o.type == "satellite" then
      o.orbit_angle += o.orbit_speed
      o.x = o.orbit_center_x + cos(o.orbit_angle) * o.orbit_radius
      o.y = o.orbit_center_y + sin(o.orbit_angle) * o.orbit_radius
    end
  end
end

function update_play()
  if ic2 > 0 then
    ic2 -= 1
  end

  local input = test_input()
  if ic2 == 0 and input & 32 > 0 then
    state = "pause"
    play_music(-1)
    _log("state:pause")
    ic2 = 15
    return
  end

  gm1 += 1

  local scale_interval = 600
  if lm2 == 1 then scale_interval = 900
  elseif lm2 == 3 then scale_interval = 300
  elseif lm2 == 4 then scale_interval = 120
  end

  if gm1 % scale_interval == 0 then
    lm8 += 1
    ob7 += 0.1
    ob2 = max(20, ob2 - 5)
    play_sfx(2)
    _log("sfx_difficulty_up:level="..lm8)
    fx6 = 20
    _log("lm9:"..lm8)
    _log("wave:"..lm8)
  end

  lm6 += 1
  if lm6 >= dz3 then
    lm6 = 0
    dz3 = 450 + rnd(150)
    local z = dz1[flr(rnd(3)) + 1]
    z.active = not z.active
    local zone_idx = z == dz1[1] and "L" or (z == dz1[2] and "C" or "R")
    _log("zone_toggle:"..zone_idx..":"..tostr(z.active))
  end
  for z in all(dz1) do
    if z.active then
      z.pulse = (z.pulse + 0.08) % 1
    else
      z.pulse = 0
    end
  end

  if gm1 % 900 == 0 then
    lm7 += 0.5
    ic5 = max(ic5, lm7)
    _log("lm7:"..lm7)
  end

  score += flr(1 * lm7 * (pw1 > 0 and 2 or 1))

  if pw2 > 0 then pw2 -= 1 end
  if pw3 > 0 then pw3 -= 1 end
  if pw1 > 0 then pw1 -= 1 end
  if pw4 > 0 then pw4 -= 1 end
  if pw5 > 0 then
    pw5 -= 1
    ob1 = true
  else
    ob1 = false
  end

  if input & 1 > 0 then
    ball.vx -= 0.5
    _log("steer_left")
  end
  if input & 2 > 0 then
    ball.vx += 0.5
    _log("steer_right")
  end

  update_ball()

  update_ball_trail()

  ob3 += 1
  if ob3 >= ob2 then
    ob3 = 0
    spawn_obstacle()
  end

  if lm8 >= 3 then
    ob6 += 1
    if ob6 >= ob5 then
      ob6 = 0
      if rnd(1) < 0.33 then
        spawn_boss()
      end
    end
  end

  for o in all(ob4) do
    update_obstacle(o)

    local collision = false

    if o.type != "orbiter" then
      local dist = sqrt((ball.x - o.x)^2 + (ball.y - o.y)^2)
      if dist < ball.r + o.r then
        collision = true
      end
    else
      local center_dist = sqrt((ball.x - o.x)^2 + (ball.y - o.y)^2)
      if center_dist < ball.r + 3 then
        collision = true
      end
      local sat1_x = o.x + cos(o.orbit_angle) * o.orbit_radius
      local sat1_y = o.y + sin(o.orbit_angle) * o.orbit_radius
      local sat1_dist = sqrt((ball.x - sat1_x)^2 + (ball.y - sat1_y)^2)
      if sat1_dist < ball.r + 3 then
        collision = true
      end
      local sat2_x = o.x + cos(o.orbit_angle + 0.5) * o.orbit_radius
      local sat2_y = o.y + sin(o.orbit_angle + 0.5) * o.orbit_radius
      local sat2_dist = sqrt((ball.x - sat2_x)^2 + (ball.y - sat2_y)^2)
      if sat2_dist < ball.r + 3 then
        collision = true
      end
    end

    if pw2 == 0 then

      if collision then
        lives -= 1
        fx7 = 10
        ad7 = gm1
        _log("life_lost")
        _log("lives:"..lives)

        play_sfx(3)
        shake(8, 1.0)
        bl3 = 3
        add_particles(ball.x, ball.y, 15, 7)
        combo = 0
        lm1 = 0
        _log("combo_reset")

        del(ob4, o)

        if lives <= 0 then
          play_sfx(7)
          play_music(3, 500)
          state = "gameover"
          _log("state:gameover")
          _log("final_score:"..score)
          _log("ic9:"..ic9)
          _log("ic8:"..ic8)
          _log("ic7:"..ic7)
          _log("lm7:"..lm7)
          local avg = ic8 > 0 and flr(ic6 / ic8) or 0
          _log("avg_bonus:"..avg)

          st1 += 1
          st2 += flr(gm1 / 30)
          st3 += ic8
          st4 += ic7
          st5 += score
          st6 = max(st6, ic9)
          st7 = max(st7, flr(lm7 * 100))
          sb5 += 1
          sb6 = max(sb6, sb5)

          if lm9 == 1 then
            st8 += 1
            sa2 += score
            sa5 = max(sa5, ic9)
          elseif lm9 == 2 then
            st9 += 1
            sa3 += score
            sa6 = max(sa6, ic9)
          elseif lm9 == 3 then
            sa1 += 1
            sa4 += score
            sa7 = max(sa7, ic9)
          end

          save_statistics()
          _log("stats_updated:games="..st1)

          if score > gm2 then
            gm2 = score
            ui2 = true
            ui1 = 60
            dset(0, gm2)
            shake(20, 0.5)
            _log("new_highscore:"..gm2)
            _log("highscore_saved")
          end
        end
        return
      end
    else
      if collision then
        play_sfx(6)
        pw2 = 0
        shake(4, 0.5)
        add_particles(ball.x, ball.y, 10, 11)
        if o.type == "boss" and o.boss_id then
          cleanup_satellites(o.boss_id)
        end
        del(ob4, o)
        _log("shield_absorb")
        return
      end
    end

    if not o.dodged and ball.y < o.y - 10 then
      o.dodged = true
      combo += 1
      _log("combo:"..combo)

      if combo > ic9 then
        ic9 = combo
        _log("ic9:"..ic9)
      end
      ic8 += 1

      local base_bonus = 10 * lm7 * (pw1 > 0 and 2 or 1)
      if o.is_boss then
        base_bonus *= 2
      end

      local ball_zone = get_zone(ball.x)
      local in_danger_zone = ball_zone > 0 and dz1[ball_zone].active
      if in_danger_zone then
        base_bonus *= 1.5
        _log("danger_dodge:zone"..ball_zone)
      end

      local bonus_mod = 1.0
      if lm4 == 1 then bonus_mod = 1.5
      elseif lm4 == 3 then bonus_mod = 0.7
      end

      local combo_mult = 1 + flr(combo / 5)
      local bonus = flr(base_bonus * combo_mult * bonus_mod)
      score += bonus
      ic6 += bonus

      if o.is_boss then
        local stage = o.boss_stage or 1
        local sfx_id = stage == 3 and 7 or (stage == 2 and 2 or 4)
        play_sfx(sfx_id)
        local shake_amt = 6 + stage * 2
        shake(shake_amt, 0.8 + stage * 0.2)
        local particle_count = 25 + stage * 10
        local particle_col = stage == 3 and 14 or (stage == 2 and 9 or 9)
        add_particles(ball.x, ball.y, particle_count, particle_col)
        _log("boss_dodge:stage"..stage..":bonus="..bonus)
        if o.boss_id then
          cleanup_satellites(o.boss_id)
        end
      else
        local pitch_offset = min(flr(combo / 5) * 2, 12)
        play_sfx(8, -1, pitch_offset)
        shake(3, 0.4)
        _log("dodge_bonus:"..bonus)
        _log("sfx_dodge:combo="..combo..",pitch="..pitch_offset)
        local pcol = in_danger_zone and 8 or 11
        add_particles(ball.x, ball.y, 15, pcol)
      end

      local text_col = in_danger_zone and 8 or 11
      if combo_mult > 1 then
        add_floating_text(ball.x - 8, ball.y - 12, "+"..bonus.." x"..combo_mult, text_col)
      else
        add_floating_text(ball.x - 6, ball.y - 12, "+"..bonus, text_col)
      end

      local milestone = 0
      if combo >= 20 then
        milestone = flr(combo / 5) * 5
      elseif combo == 15 or combo == 10 or combo == 5 then
        milestone = combo
      end

      if milestone > 0 and milestone > lm1 then
        lm1 = milestone
        _log("milestone:"..milestone)
        play_sfx(7)
        _log("sfx_combo_milestone:"..milestone)
        shake(3, 0.25)
        local m_col = 10
        if milestone >= 15 then
          m_col = 14
        elseif milestone >= 10 then
          m_col = 9
        end
        add_floating_text(64 - 18, 50, milestone.." combo!", m_col)
      end
    end

    if o.y > 140 then
      if o.type == "boss" and o.boss_id then
        cleanup_satellites(o.boss_id)
      end
      del(ob4, o)
    end
  end

  pw7 += 1
  if pw7 >= 300 and #pw6 < 2 then
    pw7 = 0
    spawn_powerup()
  end

  for p in all(pw6) do
    p.y += ob7 * speed_mod
    p.spawn_time += 1

    if pw4 > 0 then
      local dx = ball.x - p.x
      local dy = ball.y - p.y
      local dist = sqrt(dx^2 + dy^2)
      if dist > 1 then
        p.x += (dx / dist) * 2
        p.y += (dy / dist) * 2
      end
    end

    local dist = sqrt((ball.x - p.x)^2 + (ball.y - p.y)^2)
    if dist < ball.r + 4 then
      collect_powerup(p)
      del(pw6, p)
    end

    if p.y > 140 then
      del(pw6, p)
    end
  end

  for pt in all(fx8) do
    pt.x += pt.vx
    pt.y += pt.vy
    pt.life -= 1
    if pt.life <= 0 then
      del(fx8, pt)
    end
  end

  for ft in all(fx9) do
    ft.y += ft.vy
    ft.lifetime -= 1
    if ft.lifetime <= 0 then
      del(fx9, ft)
    end
  end

  check_achievements()
end

function draw_play()
  for i = 0, 15 do
    line(0, i * 8 + (gm1 % 8), 127, i * 8 + (gm1 % 8), 5)
  end

  for i = 1, 3 do
    local z = dz1[i]
    if z.active then
      local pulse_alpha = 0.5 + sin(z.pulse) * 0.3
      if pulse_alpha > 0.5 then
        for x = z.x_min, z.x_max - 1, 3 do
          for y = 0, 127, 3 do
            pset(x, y, 8)
          end
        end
      end
      local border_col = sin(z.pulse) > 0.5 and 8 or 2
      line(z.x_min, 0, z.x_min, 127, border_col)
      line(z.x_max - 1, 0, z.x_max - 1, 127, border_col)
    end
  end

  for o in all(ob4) do
    if o.type == "spike" then
      pal(8, theme_color(8)); pal(2, theme_color(2))
      if o.in_danger then pal(8, 14) end
      if ob1 then pal(2, 12) end
      spr(0, o.x - 4, o.y - 4)
      pal()
    elseif o.type == "moving" then
      pal(12, theme_color(12)); pal(0, theme_color(0))
      if o.in_danger then pal(12, 8) end
      if ob1 then pal(12, 12) end
      spr(1, o.x - 4, o.y - 4)
      pal()
    elseif o.type == "rotating" then
      pal(14, theme_color(14)); pal(7, theme_color(7))
      if o.in_danger then pal(14, 15) end
      if ob1 then pal(7, 12) end
      spr(2, o.x - 4, o.y - 4)
      pal()
    elseif o.type == "boss" then
      if o.boss_stage == 2 then
        pal(8, theme_color(9)); pal(2, theme_color(9))
      elseif o.boss_stage == 3 then
        pal(8, theme_color(14)); pal(2, theme_color(14))
      else
        pal(8, theme_color(8)); pal(2, theme_color(2))
      end
      if o.in_danger then pal(8, 8); pal(2, 8) end
      spr(3, o.x - 4, o.y - 4)
      pal()
      if not ob1 then
        local pulse = sin(gm1 / 15) * 2
        local ring_col1 = theme_color(o.boss_stage == 3 and 14 or (o.boss_stage == 2 and 9 or 14))
        local ring_col2 = theme_color(o.boss_stage == 3 and 8 or 9)
        circ(o.x, o.y, o.r - 2 + pulse, ring_col1)
        circ(o.x, o.y, o.r + 2 + pulse, ring_col2)
        if o.boss_stage == 3 then
          circ(o.x, o.y, o.r + 4 + pulse, theme_color(2))
        end
      else
        circ(o.x, o.y, o.r, 12)
      end
    elseif o.type == "pendulum" then
      line(o.base_x, 0, o.x, o.y, theme_color(5))
      pal(9, theme_color(9)); pal(5, theme_color(5))
      if o.in_danger then pal(9, 8) end
      if ob1 then pal(9, 12) end
      spr(4, o.x - 4, o.y - 4)
      pal()
    elseif o.type == "zigzag" then
      pal(11, theme_color(11)); pal(12, theme_color(12))
      if o.in_danger then pal(11, 8); pal(12, 8) end
      if ob1 then pal(11, 12); pal(12, 12) end
      spr(5, o.x - 4, o.y - 4)
      pal()
    elseif o.type == "orbiter" then
      pal(2, theme_color(2)); pal(5, theme_color(5))
      if o.in_danger then pal(2, 8); pal(5, 8) end
      spr(6, o.x - 4, o.y - 4)
      pal()
      local sat1_x = o.x + cos(o.orbit_angle) * o.orbit_radius
      local sat1_y = o.y + sin(o.orbit_angle) * o.orbit_radius
      local sat_col = o.in_danger and 14 or theme_color(9)
      circfill(sat1_x, sat1_y, 2, sat_col)
      if ob1 then circ(sat1_x, sat1_y, 2, 12) end
      local sat2_x = o.x + cos(o.orbit_angle + 0.5) * o.orbit_radius
      local sat2_y = o.y + sin(o.orbit_angle + 0.5) * o.orbit_radius
      circfill(sat2_x, sat2_y, 2, sat_col)
      if ob1 then circ(sat2_x, sat2_y, 2, 12) end
    elseif o.type == "satellite" then
      circfill(o.x, o.y, o.r, theme_color(8))
      circ(o.x, o.y, o.r + 1, theme_color(14))
    end
  end

  for p in all(pw6) do
    local pulse = sin(p.spawn_time / 10) * 1.5
    local sprite_map = {shield=7, slowmo=8, doublescore=9, magnet=10, bomb=11, freeze=12}
    local spr_id = sprite_map[p.type]
    spr(spr_id, p.x - 4, p.y - 4)
    local r = 4 + pulse
    circ(p.x, p.y, r, 7)
    if p.spawn_time < 30 then
      circ(p.x, p.y, r + 2, 7)
    end
  end

  for pt in all(fx8) do
    pset(pt.x, pt.y, pt.col)
  end

  for ft in all(fx9) do
    local alpha_step = flr(ft.lifetime / 10)
    if alpha_step >= 2 then
      print(ft.text, ft.x, ft.y, ft.col)
    elseif alpha_step == 1 then
      print(ft.text, ft.x, ft.y, 5)
    end
  end

  for tr in all(bl1) do
    local fade = 1 - (tr.age / 8)
    local vel_factor = min(1, tr.vel / 5)
    local intensity = fade * vel_factor
    if intensity > 0.2 then
      local trail_r = ball.r * fade
      local trail_col = 6
      if cu4 == 2 then
        trail_col = 8 + (tr.age % 8)
      elseif cu4 == 3 then
        trail_col = 7
      else
        if pw2 > 0 then
          trail_col = 11
        elseif combo >= 10 then
          trail_col = 15
        else
          trail_col = 10
        end
      end
      if fade < 0.5 then
        trail_col = 5
      end
      circfill(tr.x, tr.y, trail_r, trail_col)
    end
  end

  if pw4 > 0 then
    local pulse = sin(gm1 / 8) * 1.5
    circ(ball.x, ball.y, ball.r + 4 + pulse, 11)
    circ(ball.x, ball.y, ball.r + 6 + pulse, 3)
  end

  local ball_col = get_ball_skin_color()
  if bl3 > 0 then
    ball_col = 7
  elseif pw2 > 0 then
    ball_col = 11
  elseif combo >= 10 then
    ball_col = 15
  end
  circfill(ball.x, ball.y, ball.r, ball_col)
  circ(ball.x, ball.y, ball.r, 7)

  print("score:"..score, 2, 2, 7)
  print("time:"..flr(gm1/30).."s", 2, 9, 7)
  local lives_col = fx7 > 0 and (fx7 % 4 < 2 and 7 or 8) or 8
  print("lives:"..lives, 2, 16, lives_col)
  print("x"..lm7, 100, 2, 9)
  local combo_col = 7
  if combo >= 15 then
    combo_col = 14
  elseif combo >= 10 then
    combo_col = 9
  elseif combo >= 5 then
    combo_col = 10
  end
  print("combo:"..combo, 86, 9, combo_col)

  local wave_col = 10
  local wave_y = 16
  if fx6 > 0 then
    wave_col = fx6 % 4 < 2 and 9 or 10
    wave_y = 16 + sin(fx6 / 4)
  end
  print("wave:"..lm8, 92, wave_y, wave_col)

  local zone_str = "danger:"
  if dz1[1].active then zone_str = zone_str.."l" end
  if dz1[2].active then zone_str = zone_str.."c" end
  if dz1[3].active then zone_str = zone_str.."r" end
  if zone_str != "danger:" then
    print(zone_str, 2, 24, 8)
  end

  local ind_x = 2
  if pw2 > 0 then
    circfill(ind_x, 120, 3, 11)
    print("s", ind_x-1, 118, 7)
    ind_x += 10
  end
  if pw3 > 0 then
    circfill(ind_x, 120, 3, 12)
    print("m", ind_x-1, 118, 7)
    ind_x += 10
  end
  if pw1 > 0 then
    circfill(ind_x, 120, 3, 10)
    print("2", ind_x-1, 118, 7)
    ind_x += 10
  end
  if pw4 > 0 then
    circfill(ind_x, 120, 3, 13)
    print("g", ind_x-1, 118, 7)
    ind_x += 10
  end
  if pw5 > 0 then
    circfill(ind_x, 120, 3, 12)
    print("f", ind_x-1, 118, 7)
    ind_x += 10
  end
end

function update_gameover()
  local input = test_input()

  if not ui2 and ui3 == 0 then
    local rank = 0
    for i = 1, #ui6 do
      if score > ui6[i].score then
        rank = i
        break
      end
    end
    if rank == 0 and #ui6 < 10 then
      rank = #ui6 + 1
    end

    if rank > 0 then
      ui3 = rank
      ui2 = true
      ui1 = 60
      play_sfx(6)
      shake(20, 0.5)
      _log("ui3:"..rank)
    end
  end

  if not cu2 then
    check_cosmetic_unlocks()
    cu2 = true
    _log("cosmetics_checked")
  end

  if not gt9 and score > 0 then
    gt9 = true
    dset(93, 1)
    _log("gt9")
  end

  if ui3 > 0 and input & 16 > 0 then
    state = "enter_initials"
    _log("state:enter_initials")
    ui7 = {"a", "a", "a"}
    ui8 = 1
    ui9 = false
    ic1 = 15
    return
  end

  if ui3 == 0 and input & 16 > 0 then
    state = "play"
    _log("state:play")
    init_game()
  end
end

function draw_gameover()
  print("game over", 42, 10, 8)

  print("final score", 38, 22, 7)
  print(score, 64 - #tostr(score) * 2, 30, 10)

  if ui2 and ui3 > 0 then
    local flash_col = (ui1 % 8 < 4) and 10 or 9
    print("ui6 rank #"..ui3, 18, 38, flash_col)
    if ui1 > 0 then
      ui1 -= 1
    end
  end

  if #ui6 > 0 then
    local top = ui6[1]
    print("best: "..top.score.." ("..top.initials..")", 20, 48, 12)
  end

  print("-- performance --", 26, 58, 6)

  local combo_col = ic9 >= 10 and 15 or 11
  print("max combo: "..ic9, 28, 66, combo_col)

  print("dodges: "..ic8, 32, 74, 9)

  print("pw6: "..ic7, 28, 82, 11)

  local lives_used = 3 - lives
  print("lives used: "..lives_used.."/3", 22, 90, 8)

  print("lm7: x"..lm7, 24, 98, 10)

  local avg_bonus = 0
  if ic8 > 0 then
    avg_bonus = flr(ic6 / ic8)
  end
  print("avg bonus: "..avg_bonus, 26, 106, 12)

  print("time: "..flr(gm1/30).."s", 36, 114, 6)

  if ui3 > 0 then
    print("press o to enter name", 14, 122, 10)
  else
    print("press o to retry", 24, 122, 13)
  end
end

function update_enter_initials()
  local input = test_input()

  if ic1 > 0 then
    ic1 -= 1
    return
  end

  if ui9 then
    if input & 16 > 0 then
      state = "play"
      _log("state:play")
      init_game()
    end
    return
  end

  if input & 1 > 0 then
    ui8 = max(1, ui8 - 1)
    play_sfx(1)
    _log("initial_cursor:"..ui8)
    ic1 = 8
  end
  if input & 2 > 0 then
    ui8 = min(3, ui8 + 1)
    play_sfx(1)
    _log("initial_cursor:"..ui8)
    ic1 = 8
  end

  if input & 4 > 0 then
    local code = ord(ui7[ui8])
    code = code == 122 and 97 or code + 1
    ui7[ui8] = chr(code)
    play_sfx(1)
    _log("initial_change:"..ui7[ui8])
    ic1 = 5
  end
  if input & 8 > 0 then
    local code = ord(ui7[ui8])
    code = code == 97 and 122 or code - 1
    ui7[ui8] = chr(code)
    play_sfx(1)
    _log("initial_change:"..ui7[ui8])
    ic1 = 5
  end

  if input & 16 > 0 then
    if ui8 < 3 then
      ui8 += 1
      play_sfx(1)
      ic1 = 10
    else
      local initials_str = ui7[1]..ui7[2]..ui7[3]
      local new_entry = {
        score = score,
        initials = initials_str,
        timestamp = 0,
        variant = ct2 and ct9 or 0
      }

      local inserted = false
      for i = 1, #ui6 do
        if score > ui6[i].score then
          local temp = {}
          for j = 1, i - 1 do
            add(temp, ui6[j])
          end
          add(temp, new_entry)
          for j = i, #ui6 do
            if #temp < 10 then
              add(temp, ui6[j])
            end
          end
          ui6 = temp
          inserted = true
          break
        end
      end

      if not inserted and #ui6 < 10 then
        add(ui6, new_entry)
      end

      save_leaderboard()
      ui4 = ui3
      ui9 = true
      play_sfx(6)
      shake(10, 0.3)
      _log("ui9:"..initials_str..":"..score)
      ic1 = 15
    end
  end

  if input & 32 > 0 then
    state = "play"
    _log("state:play")
    _log("entry_skipped")
    init_game()
  end
end

function draw_enter_initials()
  print("new ui6 entry!", 12, 20, 10)
  print("rank #"..ui3, 48, 30, 11)

  if ui9 then
    print("entry saved!", 34, 60, 7)
    print("score: "..score, 42, 70, 10)
    print("press o to continue", 16, 100, 13)
  else
    print("enter your initials:", 16, 50, 7)

    local x_base = 40
    for i = 1, 3 do
      local col = (i == ui8) and 10 or 6
      local char = ui7[i]
      print(char, x_base + (i - 1) * 16, 68, col)

      if i == ui8 then
        print("^", x_base + (i - 1) * 16, 76, 11)
      end
    end

    print("arrows: select/change", 12, 94, 13)
    print("o: confirm letter", 22, 102, 13)
    print("x: skip entry", 28, 110, 5)
  end
end

function get_zone(x)
  for i = 1, 3 do
    if x >= dz1[i].x_min and x < dz1[i].x_max then
      return i
    end
  end
  return 0
end

function mk_obs(type, x)
  local o = {x=x or 20+rnd(88), y=-10, type=type, dodged=false, is_boss=false}
  if type == "spike" then
    o.r = 6
  elseif type == "moving" then
    o.r = 10 o.vx = 0.5+rnd(1) if rnd(1)>0.5 then o.vx *= -1 end
  elseif type == "rotating" then
    o.r = 8 o.angle = 0
  elseif type == "pendulum" then
    o.x = x or 40+rnd(48) o.r = 7 o.swing_time = 0 o.base_x = o.x
  elseif type == "zigzag" then
    o.r = 6 o.zig_time = 0 o.zig_dir = rnd(1)>0.5 and 1 or -1
  elseif type == "orbiter" then
    o.x = x or 40+rnd(48) o.r = 5 o.orbit_angle = 0 o.orbit_radius = 8
  end
  return o
end

function mk_boss(stage)
  return {x=64, base_x=64, y=-10, type="boss", r=13, dodged=false, is_boss=true, wave_time=0, boss_stage=stage, satellite_timer=0, vertical_time=0, boss_id=flr(rnd(10000))}
end

function spawn_obstacle()
  local types = {"spike", "moving", "rotating"}

  if lm8 >= 2 and rnd(1) < 0.20 then
    spawn_pendulum()
    return
  end

  if lm8 >= 3 and rnd(1) < 0.15 then
    spawn_zigzag()
    return
  end

  if lm8 >= 4 and rnd(1) < 0.10 then
    spawn_orbiter()
    return
  end

  local t = types[flr(rnd(3)) + 1]
  local o = {
    x = 20 + rnd(88),
    y = -10,
    type = t,
    dodged = false,
    is_boss = false
  }

  if t == "spike" then
    o.r = 6
  elseif t == "moving" then
    o.r = 10
    o.vx = 0.5 + rnd(1)
    if rnd(1) > 0.5 then o.vx *= -1 end
  elseif t == "rotating" then
    o.r = 8
    o.angle = 0
  end

  o.zone = get_zone(o.x)
  o.in_danger = o.zone > 0 and dz1[o.zone].active or false

  add(ob4, o)
  _log("spawn_obstacle:"..t..(o.in_danger and ":danger" or ""))
end

function spawn_obs_with_zone(type)
  local o = mk_obs(type)
  o.zone = get_zone(o.x)
  o.in_danger = o.zone > 0 and dz1[o.zone].active or false
  add(ob4, o)
  _log("spawn_obstacle:"..type..(o.in_danger and ":danger" or ""))
end

function spawn_pendulum() spawn_obs_with_zone("pendulum") end
function spawn_zigzag() spawn_obs_with_zone("zigzag") end
function spawn_orbiter() spawn_obs_with_zone("orbiter") end

function spawn_boss()
  local stage = lm8 >= 5 and 3 or (lm8 >= 3 and 2 or 1)
  local o = mk_boss(stage)
  o.zone = get_zone(o.x)
  o.in_danger = o.zone > 0 and dz1[o.zone].active or false
  add(ob4, o)
  _log("spawn_obstacle:boss:stage"..stage..(o.in_danger and ":danger" or ""))
  play_sfx(6)
  shake(8 + stage * 2, 1.0 + stage * 0.2)
end

function spawn_satellite(boss)
  local count = flr(rnd(2)) + 1
  for i = 1, count do
    local angle = rnd(1)
    local dist = 40 + rnd(20)
    local s = {
      x = boss.x + cos(angle) * dist,
      y = boss.y + sin(angle) * dist,
      type = "satellite",
      r = 4,
      dodged = false,
      is_boss = false,
      is_satellite = true,
      parent_boss_id = boss.boss_id,
      orbit_angle = angle,
      orbit_speed = 0.02 + rnd(0.02),
      orbit_center_x = boss.x,
      orbit_center_y = boss.y,
      orbit_radius = dist
    }
    add(ob4, s)
    _log("spawn_satellite:boss_id="..boss.boss_id)
  end
end

function cleanup_satellites(boss_id)
  for s in all(ob4) do
    if s.is_satellite and s.parent_boss_id == boss_id then
      del(ob4, s)
      _log("cleanup_satellite:boss_id="..boss_id)
    end
  end
end

function spawn_powerup(spawn_x, spawn_y)
  local types = {"shield", "slowmo", "doublescore", "magnet", "bomb", "freeze"}
  local t = types[flr(rnd(6)) + 1]
  local cols = {shield = 11, slowmo = 12, doublescore = 10, magnet = 13, bomb = 8, freeze = 12}

  local x = spawn_x or (20 + rnd(88))

  if not spawn_x and rnd(1) > 0.25 then
    local attempts = 0
    while attempts < 10 do
      x = 20 + rnd(88)
      local zone = get_zone(x)
      if zone == 0 or not dz1[zone].active then
        break
      end
      attempts += 1
    end
  end

  local p = {
    x = x,
    y = spawn_y or -10,
    type = t,
    col = cols[t],
    spawn_time = 0
  }

  add(pw6, p)
  _log("spawn_powerup:"..t..",x="..flr(x)..",y="..flr(p.y))
end

function collect_powerup(p)
  if ct2 and ct9 == 3 then
    _log("powerup_disabled:speed_run")
    return
  end

  local bonus = flr(50 * lm7 * (pw1 > 0 and 2 or 1))
  if ct2 then
    ct3 += bonus
  else
    score += bonus
  end
  ic7 += 1
  _log("powerup_collected:"..p.type)
  _log("powerup_bonus:"..bonus)
  _log("ic7:"..ic7)

  ad5[p.type] = true

  local zone = get_zone(p.x)
  if zone > 0 and dz1[zone].active then
    ad6 += 1
    _log("danger_zone_pickup:"..ad6)
  end

  play_sfx(1)
  shake(8, 1.0)

  add_floating_text(p.x - 6, p.y - 10, "+"..bonus, 10)

  if p.type == "shield" then
    pw2 = 90
    sa8 += 1
    if lives < 3 then
      lives += 1
      _log("life_restored")
      _log("lives:"..lives)
    end
    play_sfx(5, -1, 0)
    _log("sfx_powerup:shield:pitch=0")
    add_floating_text(p.x - 12, p.y - 20, "shield!", 11)
  elseif p.type == "slowmo" then
    pw3 = 60
    sa9 += 1
    play_sfx(5, -1, 4)
    _log("sfx_powerup:slowmo:pitch=4")
    add_floating_text(p.x - 12, p.y - 20, "slowmo!", 12)
  elseif p.type == "doublescore" then
    pw1 = 150
    sb1 += 1
    play_sfx(5, -1, 8)
    _log("sfx_powerup:doublescore:pitch=8")
    add_floating_text(p.x - 18, p.y - 20, "double score!", 10)
  elseif p.type == "magnet" then
    pw4 = 240
    sb2 += 1
    play_sfx(5, -1, 2)
    _log("sfx_powerup:magnet:pitch=2")
    add_floating_text(p.x - 12, p.y - 20, "magnet!", 13)
    _log("powerup:magnet")
  elseif p.type == "bomb" then
    sb3 += 1
    local cleared = 0
    for o in all(ob4) do
      local dist = sqrt((o.x - ball.x)^2 + (o.y - ball.y)^2)
      if dist < 40 then
        del(ob4, o)
        add_particles(o.x, o.y, 15, 8)
        cleared += 1
      end
    end
    play_sfx(5, -1, 12)
    _log("sfx_powerup:bomb:pitch=12")
    shake(12, 1.5)
    fx5 = 8
    add_floating_text(p.x - 10, p.y - 20, "bomb!", 8)
    _log("powerup:bomb:cleared="..cleared)
  elseif p.type == "freeze" then
    pw5 = 180
    sb4 += 1
    play_sfx(5, -1, 6)
    _log("sfx_powerup:freeze:pitch=6")
    add_floating_text(p.x - 12, p.y - 20, "freeze!", 12)
    _log("powerup:freeze")
  end

  add_particles(p.x, p.y, 20, p.col)
end

function add_particles(x, y, count, col)
  for i = 1, count do
    add(fx8, {
      x = x,
      y = y,
      vx = rnd(2) - 1,
      vy = rnd(2) - 1,
      col = col,
      life = 15 + rnd(10)
    })
  end
end

function add_floating_text(x, y, text, col)
  add(fx9, {
    x = x,
    y = y,
    text = text,
    col = theme_color(col),
    vy = -0.5,
    lifetime = 30
  })
  _log("floating_text:"..text)
end

function update_practice_obstacle_select()
  local input = test_input()

  if ic1 > 0 then
    ic1 -= 1
  end

  if ic1 == 0 then
    if input & 4 > 0 then
      pr5 = max(1, pr5 - 1)
      play_sfx(1)
      _log("practice_obstacle_nav:up")
      ic1 = 10
    end
    if input & 8 > 0 then
      pr5 = min(7, pr5 + 1)
      play_sfx(1)
      _log("practice_obstacle_nav:down")
      ic1 = 10
    end
  end

  if input & 16 > 0 then
    pr1 = pr7[pr5]
    _log("practice_obstacle_selected:"..pr1)
    state = "practice_speed_select"
    _log("state:practice_speed_select")
    ic1 = 10
  end

  if input & 32 > 0 then
    play_music(2)
    state = "menu"
    _log("state:menu")
    ic1 = 10
  end
end

function draw_practice_obstacle_select()
  print("practice mode", 32, 20, 7)
  print("select obstacle", 28, 30, 6)

  local y = 45
  for i = 1, 7 do
    local col = (i == pr5) and 10 or 13
    local prefix = (i == pr5) and "> " or " "
    print(prefix..pr7[i], 32, y, col)
    y += 10
  end

  print("o: select x: back", 14, 118, 5)
end

function update_practice_speed_select()
  local input = test_input()

  if ic1 > 0 then
    ic1 -= 1
  end

  if ic1 == 0 then
    if input & 4 > 0 then
      pr6 = max(1, pr6 - 1)
      play_sfx(1)
      _log("practice_speed_nav:up")
      ic1 = 10
    end
    if input & 8 > 0 then
      pr6 = min(3, pr6 + 1)
      play_sfx(1)
      _log("practice_speed_nav:down")
      ic1 = 10
    end
  end

  if input & 16 > 0 then
    pr2 = pr9[pr6]
    _log("practice_speed_selected:"..pr8[pr6])
    state = "practice_play"
    _log("state:practice_play")
    init_practice_game()
    play_music(0)
    _log("practice_music_start:pattern=0")
  end

  if input & 32 > 0 then
    state = "practice_obstacle_select"
    _log("state:practice_obstacle_select")
    ic1 = 10
  end
end

function draw_practice_speed_select()
  print("practice mode", 32, 20, 7)
  print("select speed", 32, 30, 6)

  print("obstacle: "..pr1, 20, 45, 13)

  local y = 60
  for i = 1, 3 do
    local col = (i == pr6) and 10 or 13
    local prefix = (i == pr6) and "> " or " "
    local mult = pr9[i].."x"
    print(prefix..pr8[i].." ("..mult..")", 32, y, col)
    y += 12
  end

  print("o: start x: back", 18, 118, 5)
end

function init_practice_game()
  ball.x = 64
  ball.y = 100
  ball.vx = 0
  ball.vy = 0
  ball.grounded = false
  ob4 = {}
  fx8 = {}
  fx9 = {}
  bl1 = {}
  ob3 = 0
  pr3 = 0
  pr4 = 0

  ob7 = 0.5 * pr2
  ob2 = flr(60 / pr2)

  _log("practice_game_init:type="..pr1..",speed="..pr2)
end

function spawn_practice_obstacle()
  local o = pr1 == "boss" and mk_boss(3) or mk_obs(pr1)
  add(ob4, o)
  _log("practice_spawn:"..pr1..(pr1=="boss" and ":stage3" or ""))
end

function update_practice_play()
  if pr4 > 0 then
    pr4 -= 1
    if pr4 == 0 then
      ball.x = 64
      ball.y = 100
      ball.vx = 0
      ball.vy = 0
      ball.grounded = false
      _log("practice_reset")
    end
    return
  end

  local input = test_input()

  if input & 32 > 0 then
    play_music(2)
    state = "menu"
    _log("state:menu")
    return
  end

  if input & 1 > 0 then ball.vx -= 0.5 end
  if input & 2 > 0 then ball.vx += 0.5 end

  ball.vx = mid(-3, ball.vx, 3)

  if ball.y < 100 then
    ball.vy += 0.2
  else
    ball.y = 100
    ball.vy = 0
    ball.grounded = true
  end

  if ball.y >= 100 and ball.vy > 0 then
    ball.vy = -4
  end

  ball.x += ball.vx
  ball.y += ball.vy

  ball.vx *= 0.9

  if ball.x < ball.r then
    ball.x = ball.r
    ball.vx = abs(ball.vx)
  end
  if ball.x > 128 - ball.r then
    ball.x = 128 - ball.r
    ball.vx = -abs(ball.vx)
  end

  if #bl1 < bl2 then
    add(bl1, {x = ball.x, y = ball.y, life = 10})
  else
    for i = 1, bl2 - 1 do
      bl1[i] = bl1[i + 1]
    end
    bl1[bl2] = {x = ball.x, y = ball.y, life = 10}
  end

  for t in all(bl1) do
    t.life -= 1
  end

  ob3 += 1
  if ob3 >= ob2 then
    spawn_practice_obstacle()
    ob3 = 0
  end

  for o in all(ob4) do
    o.y += ob7

    if o.type == "moving" then
      o.x += o.vx
      if o.x < 10 or o.x > 118 then o.vx *= -1 end
    elseif o.type == "rotating" then
      o.angle += 0.05
    elseif o.type == "pendulum" then
      o.swing_time += 0.04
      o.x = o.base_x + sin(o.swing_time) * 25
    elseif o.type == "zigzag" then
      o.zig_time += 0.1
      local amplitude = 15
      o.x += o.zig_dir * 1.5
      if o.x < 10 or o.x > 118 then o.zig_dir *= -1 end
    elseif o.type == "orbiter" then
      o.orbit_angle += 0.05
    elseif o.type == "boss" then
      o.wave_time += 0.06
      o.vertical_time += 0.04
      o.x = o.base_x + sin(o.wave_time) * 40
      local base_y = o.y
      o.y = base_y + sin(o.vertical_time) * 3
      o.satellite_timer += 1
      if o.satellite_timer >= 90 then
        o.satellite_timer = 0
        spawn_satellite(o)
      end
    end

    local dist
    if o.type == "orbiter" then
      local dx = ball.x - o.x
      local dy = ball.y - o.y
      dist = sqrt(dx * dx + dy * dy)
      if dist < ball.r + 3 then
        practice_collision()
      else
        for angle_offset = 0, 1, 0.5 do
          local sat_x = o.x + cos(o.orbit_angle + angle_offset) * o.orbit_radius
          local sat_y = o.y + sin(o.orbit_angle + angle_offset) * o.orbit_radius
          local sdx = ball.x - sat_x
          local sdy = ball.y - sat_y
          local sdist = sqrt(sdx * sdx + sdy * sdy)
          if sdist < ball.r + 3 then
            practice_collision()
            break
          end
        end
      end
    else
      local dx = ball.x - o.x
      local dy = ball.y - o.y
      dist = sqrt(dx * dx + dy * dy)
      if dist < ball.r + o.r then
        practice_collision()
      end
    end

    if o.y > 140 then
      if o.type == "boss" and o.boss_id then
        cleanup_satellites(o.boss_id)
      end
      del(ob4, o)
    end
  end

  for p in all(fx8) do
    p.x += p.vx
    p.y += p.vy
    p.life -= 1
    if p.life <= 0 then
      del(fx8, p)
    end
  end

  for ft in all(fx9) do
    ft.y += ft.vy
    ft.lifetime -= 1
    if ft.lifetime <= 0 then
      del(fx9, ft)
    end
  end
end

function practice_collision()
  if pr4 > 0 then return end

  pr3 += 1
  pr4 = 30
  add_particles(ball.x, ball.y, 15, 8)
  play_sfx(4)
  _log("practice_collision:"..pr3)
end

function draw_practice_play()
  draw_ball_trail()
  draw_ball()

  for o in all(ob4) do
    if o.type == "spike" then
      pal(8, theme_color(8)); pal(2, theme_color(2))
      spr(0, o.x - 4, o.y - 4)
      pal()
    elseif o.type == "moving" then
      pal(12, theme_color(12)); pal(0, theme_color(0))
      spr(1, o.x - 4, o.y - 4)
      pal()
    elseif o.type == "rotating" then
      pal(14, theme_color(14)); pal(7, theme_color(7))
      spr(2, o.x - 4, o.y - 4)
      pal()
    elseif o.type == "pendulum" then
      line(o.base_x, 0, o.x, o.y, theme_color(5))
      pal(9, theme_color(9)); pal(5, theme_color(5))
      spr(4, o.x - 4, o.y - 4)
      pal()
    elseif o.type == "zigzag" then
      pal(11, theme_color(11)); pal(12, theme_color(12))
      spr(5, o.x - 4, o.y - 4)
      pal()
    elseif o.type == "orbiter" then
      pal(2, theme_color(2)); pal(5, theme_color(5))
      spr(6, o.x - 4, o.y - 4)
      pal()
      local sat1_x = o.x + cos(o.orbit_angle) * o.orbit_radius
      local sat1_y = o.y + sin(o.orbit_angle) * o.orbit_radius
      circfill(sat1_x, sat1_y, 2, theme_color(9))
      local sat2_x = o.x + cos(o.orbit_angle + 0.5) * o.orbit_radius
      local sat2_y = o.y + sin(o.orbit_angle + 0.5) * o.orbit_radius
      circfill(sat2_x, sat2_y, 2, theme_color(9))
    elseif o.type == "boss" then
      pal(8, theme_color(14)); pal(2, theme_color(14))
      spr(3, o.x - 4, o.y - 4)
      pal()
      circ(o.x, o.y, o.r - 2, theme_color(14))
      circ(o.x, o.y, o.r + 2, theme_color(8))
      circ(o.x, o.y, o.r + 4, theme_color(2))
    elseif o.type == "satellite" then
      circfill(o.x, o.y, o.r, theme_color(8))
      circ(o.x, o.y, o.r + 1, theme_color(14))
    end
  end

  for p in all(fx8) do
    pset(p.x, p.y, p.col)
  end

  for ft in all(fx9) do
    print(ft.text, ft.x, ft.y, ft.col)
  end

  print("practice", 2, 2, 13)
  print(pr1, 2, 9, 10)
  print(pr8[pr6].." ("..pr2.."x)", 2, 16, 11)
  print("hits: "..pr3, 2, 23, 8)
  print("x: exit", 88, 2, 5)

  if pr4 > 0 then
    print("resetting...", 36, 64, 7)
  end
end

function update_challenge()
  if ct9 == 3 and ct3 >= 500 then
    ct2 = false
    local time_taken = flr(gm1 / 30)
    local current_result = time_taken
    if ct4 == 0 or current_result < ct4 then
      ct4 = current_result
    end
    save_daily_challenge()
    update_streak()
    mc4 = 1
    state = "challenge_summary"
    _log("state:challenge_summary:speed_run:time="..time_taken..",best="..ct4)
    return
  end

  if ct1 > 0 then
    ct1 -= 1
  else
    ct2 = false
    local current_result = ct3
    if ct9 == 4 then
      current_result = ct8
    elseif ct9 == 6 then
      current_result = ct8
    end
    if current_result > ct4 then
      ct4 = current_result
    end
    save_daily_challenge()
    update_streak()
    mc4 = 1
    state = "challenge_summary"
    _log("state:challenge_summary:result="..current_result..",best="..ct4)
    return
  end

  if ct1 < 30 * 30 then
    ct6 = (ct6 + 1) % 30
  end

  gm1 += 1

  if ic2 > 0 then
    ic2 -= 1
  end

  local input = test_input()
  if input & 32 > 0 and ic2 == 0 then
    ct2 = false
    play_music(2)
    state = "menu"
    _log("state:menu:challenge_quit")
    ic2 = 15
    return
  end

  if input & 1 > 0 then
    ball.vx = max(ball.vx - 0.5, -2.5)
  end
  if input & 2 > 0 then
    ball.vx = min(ball.vx + 0.5, 2.5)
  end

  ball.vx *= 0.85

  if not ball.grounded then
    ball.vy += 0.4
  end

  ball.x += ball.vx
  ball.y += ball.vy

  if ball.y >= 120 then
    ball.y = 120
    ball.vy = -ball.vy * 0.7
    play_sfx(0)
    _log("bounce:challenge")
    ball.grounded = abs(ball.vy) < 0.5
  else
    ball.grounded = false
  end

  if ball.x <= ball.r then
    ball.x = ball.r
    ball.vx = -ball.vx * 0.7
    play_sfx(1)
    _log("wall_bounce:challenge")
  elseif ball.x >= 128 - ball.r then
    ball.x = 128 - ball.r
    ball.vx = -ball.vx * 0.7
    play_sfx(1)
    _log("wall_bounce:challenge")
  end

  ob3 += 1
  if ob3 >= ob2 then
    if ct9 == 6 then
      spawn_boss()
    else
      spawn_obstacle()
    end
    ob3 = 0
  end

  pw7 += 1
  local pu_interval = 240
  if ct9 == 4 then
    pu_interval = 480
  elseif ct9 == 5 then
    pu_interval = 80
  end
  if pw7 >= pu_interval then
    spawn_powerup()
    pw7 = 0
  end

  lm6 += 1
  if lm6 >= dz3 then
    lm6 = 0
    dz3 = 450 + rnd(150)
    local z = dz1[flr(rnd(3)) + 1]
    z.active = not z.active
    local zone_idx = z == dz1[1] and "L" or (z == dz1[2] and "C" or "R")
    _log("zone_toggle:"..zone_idx..":"..tostr(z.active))
  end
  for z in all(dz1) do
    if z.active then
      z.pulse = (z.pulse + 0.08) % 1
    else
      z.pulse = 0
    end
  end

  local speed_mod = pw3 > 0 and 0.5 or 1.0
  for o in all(ob4) do
    if not ob1 then
      o.y += ob7 * speed_mod
      if o.type == "moving" then
        o.x += o.vx
        if o.x <= o.r or o.x >= 128 - o.r then
          o.vx = -o.vx
        end
      elseif o.type == "rotating" then
        o.angle += 0.02
        o.r = 8 + sin(o.angle) * 4
      elseif o.type == "pendulum" then
        o.swing_time += 0.04
        o.x = o.base_x + sin(o.swing_time) * 25
      elseif o.type == "zigzag" then
        o.zig_time += 0.05
        local amp = 15 + (ct5 % 5) * 2
        o.x += sin(o.zig_time) * amp * o.zig_dir * 0.1
        if o.x < 10 or o.x > 118 then
          o.zig_dir *= -1
        end
      elseif o.type == "orbiter" then
        o.orbit_angle += 0.05
      elseif o.type == "boss" then
        if o.boss_stage == 1 then
          o.wave_time += 0.03
          o.x = o.base_x + sin(o.wave_time) * 30
        elseif o.boss_stage == 2 then
          o.wave_time += 0.05
          o.x = o.base_x + sin(o.wave_time) * 35
        elseif o.boss_stage == 3 then
          o.wave_time += 0.06
          o.vertical_time += 0.04
          o.x = o.base_x + sin(o.wave_time) * 40
          local base_y = o.y
          o.y = base_y + sin(o.vertical_time) * 3
          o.satellite_timer += 1
          if o.satellite_timer >= 90 then
            o.satellite_timer = 0
            spawn_satellite(o)
          end
        end
      elseif o.type == "satellite" then
        o.orbit_angle += o.orbit_speed
        o.x = o.orbit_center_x + cos(o.orbit_angle) * o.orbit_radius
        o.y = o.orbit_center_y + sin(o.orbit_angle) * o.orbit_radius
      end
    end

    if o.y > 140 then
      if o.type == "boss" and o.boss_id then
        cleanup_satellites(o.boss_id)
      end
      del(ob4, o)
      local bonus_mod = 1.0
      if lm4 == 1 then bonus_mod = 1.5
      elseif lm4 == 3 then bonus_mod = 0.7
      end
      local bonus = flr(10 * lm7 * 2 * bonus_mod)
      if ct9 == 5 then
        bonus += 10
      elseif ct9 == 6 and o.type == "boss" then
        ct8 += 1
        bonus = 50
        _log("boss_defeated:count="..ct8)
      end
      ct3 += bonus
      combo += 1
      ic9 = max(ic9, combo)
      if ct9 == 4 then
        ct8 = max(ct8, combo)
      end
      ic8 += 1
      ic6 += bonus
      add_floating_text("+"..bonus, ball.x, ball.y - 10, 10)
      local mult_cap = 5.0
      if ct9 == 4 or ct9 == 5 then
        mult_cap = 1.5
      end
      lm7 = min(lm7 + 0.15, mult_cap)
      ic5 = max(ic5, lm7)
      add_particles(ball.x, ball.y, 15, 10)
      local pitch_offset = min(flr(combo / 5) * 2, 12)
      play_sfx(8, -1, pitch_offset)
      _log("dodge:combo="..combo..",mult="..lm7..",bonus="..bonus)
      _log("sfx_dodge:combo="..combo..",pitch="..pitch_offset)

      local milestone = 0
      if combo == 5 then milestone = 5
      elseif combo == 10 then milestone = 10
      elseif combo == 15 then milestone = 15
      elseif combo == 20 then milestone = 20
      elseif combo == 25 then milestone = 25
      elseif combo >= 30 then milestone = 30 end

      if milestone > 0 and milestone > lm1 then
        lm1 = milestone
        local m_col = (milestone <= 10 and 10) or (milestone <= 20 and 9) or 14
        add_floating_text("combo "..milestone.."!", 46, 50, m_col)
        shake_screen(3, 0.25)
        play_sfx(7)
        _log("milestone:"..milestone)
        _log("sfx_combo_milestone:"..milestone)
      end
    end
  end

  local speed_mod = pw3 > 0 and 0.5 or 1.0
  for pu in all(pw6) do
    pu.y += ob7 * 0.8 * speed_mod
    if pu.y > 130 then
      del(pw6, pu)
    end

    local dx = pu.x - ball.x
    local dy = pu.y - ball.y
    local dist = sqrt(dx * dx + dy * dy)
    if dist < ball.r + 3 then
      collect_powerup(pu)
      del(pw6, pu)
    end
  end

  if pw2 > 0 then pw2 -= 1 end
  if pw3 > 0 then pw3 -= 1 end
  if pw1 > 0 then pw1 -= 1 end
  if pw4 > 0 then pw4 -= 1 end
  if pw5 > 0 then
    pw5 -= 1
    ob1 = true
  else
    ob1 = false
  end

  if pw4 > 0 then
    for pu in all(pw6) do
      local dx = ball.x - pu.x
      local dy = ball.y - pu.y
      local dist = sqrt(dx * dx + dy * dy)
      if dist > 0 and dist < 40 then
        pu.x += (dx / dist) * 1.5
        pu.y += (dy / dist) * 1.5
      end
    end
  end

  for o in all(ob4) do
    local collision = false

    if o.type == "orbiter" then
      local dx = o.x - ball.x
      local dy = o.y - ball.y
      local dist = sqrt(dx * dx + dy * dy)
      if dist < ball.r + 3 then collision = true end

      if not collision then
        for angle_offset = 0, 1, 0.5 do
          local sat_x = o.x + cos(o.orbit_angle + angle_offset) * o.orbit_radius
          local sat_y = o.y + sin(o.orbit_angle + angle_offset) * o.orbit_radius
          local sdx = sat_x - ball.x
          local sdy = sat_y - ball.y
          local sdist = sqrt(sdx * sdx + sdy * sdy)
          if sdist < ball.r + 3 then
            collision = true
            break
          end
        end
      end
    else
      local dx = o.x - ball.x
      local dy = o.y - ball.y
      local dist = sqrt(dx * dx + dy * dy)
      if dist < ball.r + o.r then
        collision = true
      end
    end

    if collision then
      local has_shield = pw2 > 0 and ct9 ~= 3

      if not has_shield then
        if ct9 == 3 then
          combo = 0
          lm1 = 0
          lm7 = max(1.0, lm7 - 0.3)
          shake_screen(6, 1.0)
          add_particles(ball.x, ball.y, 15, 8)
          play_sfx(3)
          _log("collision:combo_reset:combo=0,mult="..lm7)
          del(ob4, o)
        elseif ct9 == 2 then
          ct7 -= 1
          fx7 = 20
          combo = 0
          lm1 = 0
          lm7 = max(1.0, lm7 - 0.5)
          shake_screen(10, 1.5)
          add_particles(ball.x, ball.y, 20, 8)
          play_sfx(3)
          _log("collision:lives="..ct7..",mult="..lm7)
          del(ob4, o)

          if ct7 <= 0 then
            ct2 = false
            local current_result = ct3
            if ct9 == 4 then
              current_result = ct8
            elseif ct9 == 6 then
              current_result = ct8
            end
            if current_result > ct4 then
              ct4 = current_result
            end
            save_daily_challenge()
            play_sfx(7)
            play_music(3, 500)
            mc4 = 1
            state = "challenge_summary"
            _log("state:challenge_summary:death:result="..current_result..",best="..ct4)
            return
          end
        else
          lives -= 1
          fx7 = 20
          combo = 0
          lm1 = 0
          lm7 = max(1.0, lm7 - 0.5)
          shake_screen(10, 1.5)
          add_particles(ball.x, ball.y, 20, 8)
          play_sfx(3)
          _log("collision:lives="..lives..",mult="..lm7)
          del(ob4, o)

          if lives <= 0 then
            ct2 = false
            local current_result = ct3
            if ct9 == 4 then
              current_result = ct8
            elseif ct9 == 6 then
              current_result = ct8
            end
            if current_result > ct4 then
              ct4 = current_result
            end
            save_daily_challenge()
            play_sfx(7)
            play_music(3, 500)
            mc4 = 1
            state = "challenge_summary"
            _log("state:challenge_summary:death:result="..current_result..",best="..ct4)
            return
          end
        end
      else
        play_sfx(6)
        pw2 = 0
        shake_screen(4, 0.5)
        add_particles(ball.x, ball.y, 10, 11)
        if o.type == "boss" and o.boss_id then
          cleanup_satellites(o.boss_id)
        end
        del(ob4, o)
        _log("shield_absorb")
      end
    end
  end

  if gm1 % 3 == 0 then
    add(bl1, {x = ball.x, y = ball.y, life = 5})
    if #bl1 > bl2 then
      del(bl1, bl1[1])
    end
  end
  for t in all(bl1) do
    t.life -= 1
    if t.life <= 0 then
      del(bl1, t)
    end
  end

  for p in all(fx8) do
    p.x += p.vx
    p.y += p.vy
    p.vy += 0.1
    p.life -= 1
    if p.life <= 0 then
      del(fx8, p)
    end
  end

  for ft in all(fx9) do
    ft.y -= 0.5
    ft.life -= 1
    if ft.life <= 0 then
      del(fx9, ft)
    end
  end

  local scale_interval = 600
  if ct9 == 2 then
    scale_interval = 240
  elseif ct9 == 3 then
    scale_interval = 99999
  elseif ct9 == 4 then
    scale_interval = 360
  elseif ct9 == 6 then
    scale_interval = 800
  end
  if lm2 == 1 then scale_interval = flr(scale_interval * 1.5)
  elseif lm2 == 3 then scale_interval = flr(scale_interval * 0.5)
  end

  if gm1 % scale_interval == 0 and gm1 > 0 then
    lm8 = min(lm8 + 1, 10)
    fx6 = 20
    _log("difficulty_up:"..lm8)
  end
end

function draw_challenge()
  draw_ball_trail()
  draw_ball()

  for o in all(ob4) do
    if o.type == "spike" then
      pal(8, theme_color(8)); pal(2, theme_color(2))
      spr(0, o.x - 4, o.y - 4)
      pal()
    elseif o.type == "moving" then
      pal(12, theme_color(12)); pal(0, theme_color(0))
      spr(1, o.x - 4, o.y - 4)
      pal()
    elseif o.type == "rotating" then
      pal(14, theme_color(14)); pal(7, theme_color(7))
      spr(2, o.x - 4, o.y - 4)
      pal()
    elseif o.type == "pendulum" then
      line(o.base_x, 0, o.x, o.y, theme_color(5))
      pal(9, theme_color(9)); pal(5, theme_color(5))
      spr(4, o.x - 4, o.y - 4)
      pal()
    elseif o.type == "zigzag" then
      pal(11, theme_color(11)); pal(12, theme_color(12))
      spr(5, o.x - 4, o.y - 4)
      pal()
    elseif o.type == "orbiter" then
      pal(2, theme_color(2)); pal(5, theme_color(5))
      spr(6, o.x - 4, o.y - 4)
      pal()
      local sat1_x = o.x + cos(o.orbit_angle) * o.orbit_radius
      local sat1_y = o.y + sin(o.orbit_angle) * o.orbit_radius
      circfill(sat1_x, sat1_y, 2, theme_color(9))
      local sat2_x = o.x + cos(o.orbit_angle + 0.5) * o.orbit_radius
      local sat2_y = o.y + sin(o.orbit_angle + 0.5) * o.orbit_radius
      circfill(sat2_x, sat2_y, 2, theme_color(9))
    elseif o.type == "boss" then
      local stage = o.boss_stage or 1
      if stage == 2 then
        pal(8, theme_color(9)); pal(2, theme_color(9))
      elseif stage == 3 then
        pal(8, theme_color(14)); pal(2, theme_color(14))
      else
        pal(8, theme_color(8)); pal(2, theme_color(2))
      end
      spr(3, o.x - 4, o.y - 4)
      pal()
      local ring_col1 = theme_color(stage == 3 and 14 or (stage == 2 and 9 or 14))
      local ring_col2 = theme_color(stage == 3 and 8 or 9)
      circ(o.x, o.y, o.r - 2, ring_col1)
      circ(o.x, o.y, o.r + 2, ring_col2)
      if stage == 3 then
        circ(o.x, o.y, o.r + 4, theme_color(2))
      end
    elseif o.type == "satellite" then
      circfill(o.x, o.y, o.r, theme_color(8))
      circ(o.x, o.y, o.r + 1, theme_color(14))
    end
  end

  for pu in all(pw6) do
    local sprite_map = {shield=7, slowmo=8, doublescore=9, magnet=10, bomb=11, freeze=12}
    spr(sprite_map[pu.type], pu.x - 4, pu.y - 4)
    if pu.type == "magnet" and pw4 > 0 then
      circ(pu.x, pu.y, 5 + sin(gm1 * 0.1) * 2, 9)
    end
  end

  for p in all(fx8) do
    pset(p.x, p.y, p.col)
  end

  for ft in all(fx9) do
    print(ft.text, ft.x, ft.y, ft.col)
  end

  if ct9 == 1 then
    local time_sec = flr(ct1 / 30)
    local time_col = 7
    if time_sec <= 10 then
      time_col = (ct6 < 15) and 8 or 9
    elseif time_sec <= 30 then
      time_col = 9
    end
    print("time attack", 2, 2, 8)
    print("time: "..time_sec.."s", 2, 9, time_col)
    print("score: "..ct3, 2, 16, 10)

    local combo_col = (combo >= 20 and 14) or (combo >= 10 and 9) or 10
    if combo > 0 then print("x"..combo, 100, 2, combo_col) end

    local mult_text = lm7.."x"
    local mult_col = (lm7 >= 3.0 and 14) or (lm7 >= 2.0 and 9) or 10
    print(mult_text, 100, 9, mult_col)

  elseif ct9 == 2 then
    local time_sec = flr(gm1 / 30)
    print("survival", 2, 2, 8)
    print("lives: "..ct7, 2, 9, 10)
    print("time: "..time_sec.."s", 2, 16, 11)

    local combo_col = (combo >= 20 and 14) or (combo >= 10 and 9) or 10
    if combo > 0 then print("x"..combo, 100, 2, combo_col) end
    print("score: "..ct3, 80, 9, 6)

    for i = 1, ct7 do
      local life_col = fx7 > 0 and 8 or 11
      circfill(2 + (i - 1) * 6, 120, 2, life_col)
    end

  elseif ct9 == 3 then
    print("speed run", 2, 2, 8)
    local score_col = ct3 >= 400 and 10 or (ct3 >= 250 and 11 or 6)
    print("score: "..ct3.."/500", 2, 9, score_col)

    local combo_col = (combo >= 20 and 14) or (combo >= 10 and 9) or 10
    if combo > 0 then print("x"..combo, 100, 2, combo_col) end

    local mult_text = lm7.."x"
    local mult_col = (lm7 >= 3.0 and 14) or (lm7 >= 2.0 and 9) or 10
    print(mult_text, 100, 9, mult_col)

  elseif ct9 == 4 then
    local time_sec = flr(ct1 / 30)
    local time_col = time_sec <= 10 and 8 or 7
    print("combo master", 2, 2, 8)
    print("time: "..time_sec.."s", 2, 9, time_col)

    local combo_col = (combo >= 20 and 14) or (combo >= 10 and 9) or 10
    print("combo: "..combo, 2, 16, combo_col)
    print("max: "..ct8, 60, 16, 11)
    print("dodges: "..ic8, 2, 23, 6)

  elseif ct9 == 5 then
    local time_sec = flr(ct1 / 30)
    local time_col = time_sec <= 10 and 8 or 7
    print("power-up party", 2, 2, 8)
    print("time: "..time_sec.."s", 2, 9, time_col)
    print("score: "..ct3, 2, 16, 10)
    print("power-ups: "..ic7, 2, 23, 11)

    local combo_col = (combo >= 20 and 14) or (combo >= 10 and 9) or 10
    if combo > 0 then print("x"..combo, 100, 2, combo_col) end

  elseif ct9 == 6 then
    local time_sec = flr(ct1 / 30)
    local time_col = time_sec <= 10 and 8 or 7
    print("boss slayer", 2, 2, 8)
    print("time: "..time_sec.."s", 2, 9, time_col)
    print("bosses: "..ct8, 2, 16, 10)
    print("score: "..ct3, 60, 16, 11)

    local combo_col = (combo >= 20 and 14) or (combo >= 10 and 9) or 10
    if combo > 0 then print("x"..combo, 100, 2, combo_col) end
  end

  if ct9 ~= 3 then
    local pu_y = 110
    if pw2 > 0 then
      print("shield", 2, pu_y, 11)
      pu_y -= 6
    end
    if pw3 > 0 then
      print("slow", 2, pu_y, 12)
      pu_y -= 6
    end
    if pw1 > 0 then
      print("2x", 2, pu_y, 10)
      pu_y -= 6
    end
    if pw4 > 0 then
      print("magnet", 2, pu_y, 9)
      pu_y -= 6
    end
    if pw5 > 0 then
      print("freeze", 2, pu_y, 14)
    end
  end

  print("x: quit", 88, 120, 5)
end

function update_challenge_summary()
  local input = test_input()

  if ic1 > 0 then
    ic1 -= 1
  end

  if ic1 == 0 then
    if input & 4 > 0 then
      mc4 = max(1, mc4 - 1)
      ic1 = 10
      _log("mc4:up:"..mc4)
    elseif input & 8 > 0 then
      mc4 = min(3, mc4 + 1)
      ic1 = 10
      _log("mc4:down:"..mc4)
    elseif input & 16 > 0 or input & 32 > 0 then
      play_music(2)
      state = "menu"
      mc4 = 1
      _log("state:menu:challenge_summary_exit")
      ic1 = 10
    end
  end
end

function draw_challenge_summary()
  if mc4 == 1 then
    local variant_names = {"time attack", "survival", "speed run", "combo master", "power-up party", "boss slayer"}
    print(variant_names[ct9], 30, 15, 7)
    print("complete!", 42, 23, 6)

    if ct9 == 1 or ct9 == 2 or ct9 == 5 then
      print("your score: "..ct3, 28, 40, 10)
      local best_col = ct3 == ct4 and 10 or 6
      print("today's best: "..ct4, 22, 50, best_col)
      if ct3 == ct4 then
        print("new record!", 32, 60, 9)
      end
    elseif ct9 == 6 then
      print("bosses defeated: "..ct8, 22, 40, 10)
      local best_col = ct8 == ct4 and 10 or 6
      print("today's best: "..ct4, 22, 50, best_col)
      if ct8 == ct4 then
        print("new record!", 32, 60, 9)
      end
      print("total score: "..ct3, 30, 70, 11)
    elseif ct9 == 3 then
      local time_sec = flr(gm1 / 30)
      print("your time: "..time_sec.."s", 32, 40, 10)
      if ct4 > 0 then
        local best_col = ct4 >= time_sec and 10 or 6
        print("best time: "..ct4.."s", 30, 50, best_col)
        if ct4 >= time_sec then
          print("new record!", 32, 60, 9)
        end
      else
        print("first attempt!", 28, 60, 11)
      end
    elseif ct9 == 4 then
      print("max combo: "..ct8, 32, 40, 10)
      local best_col = ct8 == ct4 and 10 or 6
      print("today's best: "..ct4, 22, 50, best_col)
      if ct8 == ct4 then
        print("new record!", 32, 60, 9)
      end
      print("total dodges: "..ic8, 26, 70, 11)
    end

    if ct9 == 1 or ct9 == 4 or ct9 == 5 or ct9 == 6 then
      local time_sec = flr((90 - ct1 / 30))
      print("time: "..time_sec.."s", 45, 80, 12)
    elseif ct9 == 2 then
      local time_sec = flr(gm1 / 30)
      print("survived: "..time_sec.."s", 38, 70, 12)
      print("lives left: "..ct7, 38, 80, ct7 > 0 and 11 or 8)
    elseif ct9 == 3 then
      print("final score: "..ct3, 32, 70, 11)
    end

    local streak_bonus = flr(10 * (1 + flr(sk1 / 5)))
    if sk1 > 0 then
      print("streak: "..sk1.." day"..(sk1 == 1 and "" or "s"), 30, 90, 9)
      print("bonus: +"..streak_bonus.." pts", 28, 98, 10)
    end

    print("page 1/3", 48, 105, 5)

  elseif mc4 == 2 then
    print("combat stats", 32, 20, 7)

    print("best combo: "..ic9, 30, 40, 10)
    print("total dodges: "..ic8, 25, 50, 11)

    local avg = ic8 > 0 and flr(ic6 / ic8) or 0
    print("avg dodge bonus: "..avg, 20, 60, 12)

    local mult_str = ""..flr(ic5*10)/10
    print("max lm7: "..mult_str.."x", 18, 70, 9)

    print("page 2/3", 48, 105, 5)

  elseif mc4 == 3 then
    print("power-ups & history", 18, 20, 7)

    print("power-ups: "..ic7, 30, 40, 10)

    local types_count = 0
    for k, v in pairs(ad5) do
      if v then types_count += 1 end
    end
    print("types found: "..types_count.."/6", 28, 50, 11)

    if #ic4 > 0 then
      print("recent history:", 28, 65, 14)
      local y = 75
      for i = 1, min(3, #ic4) do
        local entry = ic4[#ic4 - i + 1]
        local days_ago = ct5 - entry.seed
        local label = days_ago == 0 and "today" or (days_ago == 1 and "yest." or (days_ago.."d ago"))
        print(label..": "..entry.score, 24, y, 6)
        y += 8
      end
    end

    print("page 3/3", 48, 105, 5)
  end

  print("\x8e\x8f page o/x return", 10, 115, 5)
end

function init_gauntlet()
  ball.x = 64
  ball.y = 100
  ball.vx = 0
  ball.vy = 0
  ball.grounded = false

  gt3 = 0
  gt4 = 0
  gt5 = 0
  gt6 = 1
  gt2 = 90 * 30
  gt7 = 60
  gt8 = false
  gt1 = true

  gm1 = 0
  lm7 = 1.0
  combo = 0
  lm1 = 0
  lives = 3
  fx7 = 0

  ob4 = {}
  pw6 = {}
  fx8 = {}
  fx9 = {}
  bl1 = {}

  ob3 = 0
  ob6 = 0
  pw7 = 0
  pw2 = 0
  pw3 = 0
  pw1 = 0
  pw4 = 0
  pw5 = 0
  ob1 = false

  ic9 = 0
  ic8 = 0
  ic7 = 0
  ic6 = 0
  ic5 = 1.0
  ad5 = {}

  play_music(0)
  _log("state:gauntlet")
  _log("gauntlet_init:stage="..gt6)
end

function update_gauntlet()
  gt2 -= 1
  if gt2 <= 0 then
    state = "gauntlet_gameover"
    play_music(3)
    _log("state:gauntlet_gameover")
    _log("gauntlet_time_up:bosses="..gt4..",score="..gt3)
    return
  end

  gm1 += 1

  update_ball()

  update_ball_trail()

  gt7 -= 1
  if gt7 <= 0 and #ob4 < 2 then
    spawn_gauntlet_boss()
    gt7 = 90 + flr(rnd(60)) - (gt6 * 15)
    _log("gauntlet_boss_spawned:stage="..gt6)
  end

  for o in all(ob4) do
    update_obstacle(o)
  end

  for p in all(pw6) do
    p.y += ob7
    if p.y > 140 then
      del(pw6, p)
    end
  end

  if pw2 > 0 then pw2 -= 1 end
  if pw3 > 0 then pw3 -= 1 end
  if pw1 > 0 then pw1 -= 1 end
  if pw4 > 0 then pw4 -= 1 end
  if pw5 > 0 then
    pw5 -= 1
    ob1 = true
  else
    ob1 = false
  end

  for o in all(ob4) do
    if o.is_boss and not o.dodged and o.y >= ball.y - 10 then
      local dist = sqrt((ball.x - o.x)^2 + (ball.y - o.y)^2)
      if dist < ball.r + o.r then
        if pw2 > 0 then
          pw2 = 0
          play_sfx(6)
          shake(8, 1.2)
          del(ob4, o)
          add_particles(o.x, o.y, 15, 11)
          _log("shield_absorbed")
        else
          lives -= 1
          fx7 = 15
          combo = 0
          lm1 = 0
          play_sfx(3)
          shake(15, 1.5)
          add_particles(ball.x, ball.y, 20, 8)
          _log("gauntlet_damage:lives="..lives)

          del(ob4, o)

          if lives <= 0 then
            state = "gauntlet_gameover"
            play_music(3)
            _log("state:gauntlet_gameover")
            _log("gauntlet_death:bosses="..gt4..",score="..gt3)
            return
          end
        end
      end
    end

    if o.is_boss and not o.dodged and o.y > ball.y + 10 then
      o.dodged = true
      combo += 1
      gt5 = max(gt5, combo)
      ic8 += 1

      local bonus_mult = 1.0
      if lm4 == 1 then bonus_mult = 1.5
      elseif lm4 == 3 then bonus_mult = 0.7
      end
      local dodge_points = flr(5 * lm7 * bonus_mult)
      gt3 += dodge_points
      ic6 += dodge_points

      play_sfx(4)
      add_particles(ball.x, ball.y, 15, 10)
      add_floating_text("+"..dodge_points, ball.x, ball.y - 5, 10)
      _log("gauntlet_dodge:combo="..combo..",score="..gt3)

      local milestone = 0
      if combo >= 30 then milestone = 30
      elseif combo >= 25 then milestone = 25
      elseif combo >= 20 then milestone = 20
      elseif combo >= 15 then milestone = 15
      elseif combo >= 10 then milestone = 10
      elseif combo >= 5 then milestone = 5
      end

      if milestone > lm1 then
        lm1 = milestone
        play_sfx(7)
        shake(3, 0.25)
        local msg = "x"..milestone.." combo!"
        local col = milestone >= 20 and 14 or (milestone >= 10 and 9 or 10)
        add_floating_text(msg, 46, 50, col)
        _log("milestone:"..milestone)
      end
    end

    if o.y > 140 then
      if o.is_boss and o.dodged then
        gt4 += 1
        gt3 += 50

        local new_stage = flr(gt4 / 2) + 1
        if new_stage > gt6 then
          gt6 = new_stage
          _log("gauntlet_stage_up:"..gt6)
        end

        if rnd(1) < 0.3 then
          spawn_powerup(64 + rnd(40) - 20, -10)
        end

        play_sfx(7)
        shake(10, 1.0)
        add_particles(o.x, o.y, 25, 9)
        add_floating_text("boss defeated! +50", 24, 60, 10)
        _log("gauntlet_boss_defeated:"..gt4..",score="..gt3)
      end
      del(ob4, o)
    end
  end

  for p in all(pw6) do
    local dist = sqrt((ball.x - p.x)^2 + (ball.y - p.y)^2)
    if dist < ball.r + 3 then
      collect_powerup(p)
      del(pw6, p)
    end
  end

  if fx2 > 0 then
    fx2 -= 1
    fx3 = (rnd(2) - 1) * fx1
    fx4 = (rnd(2) - 1) * fx1
  else
    fx3 = 0
    fx4 = 0
  end

  if bl3 > 0 then bl3 -= 1 end
  if fx7 > 0 then fx7 -= 1 end

  for p in all(fx8) do
    p.x += p.vx
    p.y += p.vy
    p.life -= 1
    if p.life <= 0 then
      del(fx8, p)
    end
  end

  for f in all(fx9) do
    f.y -= 0.5
    f.life -= 1
    if f.life <= 0 then
      del(fx9, f)
    end
  end

  ic5 = max(ic5, lm7)
end

function spawn_gauntlet_boss()
  local stage = min(3, gt6)
  add(ob4, mk_boss(stage))
  _log("gauntlet_spawn_boss:stage="..stage)
end

function draw_gauntlet()
  cls(1)
  draw_ball_trail()
  draw_ball()

  for o in all(ob4) do
    if o.is_boss then
      circfill(o.x, o.y, o.r, theme_color(8))
      circ(o.x, o.y, o.r, theme_color(2))

      if o.boss_stage >= 3 then
        local sat_count = 2
        for i = 0, sat_count - 1 do
          local angle = o.satellite_timer + (i / sat_count)
          local sx = o.x + cos(angle) * 18
          local sy = o.y + sin(angle) * 18
          circfill(sx, sy, 3, theme_color(12))
        end
      end
    end
  end

  for p in all(pw6) do
    local col = 7
    if p.type == "shield" then col = 12
    elseif p.type == "slowmo" then col = 14
    elseif p.type == "doublescore" then col = 10
    elseif p.type == "magnet" then col = 9
    elseif p.type == "bomb" then col = 8
    elseif p.type == "freeze" then col = 13
    end
    circfill(p.x, p.y, 3, col)
    circ(p.x, p.y, 3, 7)
  end

  for p in all(fx8) do
    pset(p.x, p.y, p.col)
  end

  for f in all(fx9) do
    if f.life > 0 then
      print(f.text, f.x - #f.text * 2, f.y, f.col)
    end
  end

  print("gauntlet", 2, 2, 7)
  print("score: "..gt3, 2, 9, 10)

  local time_sec = flr(gt2 / 30)
  local time_col = time_sec <= 10 and 8 or (time_sec <= 30 and 9 or 11)
  print("time: "..time_sec.."s", 2, 16, time_col)

  print("bosses: "..gt4, 2, 23, 12)

  print("stage "..gt6, 96, 2, 14)

  if combo > 0 then
    local combo_col = combo >= 20 and 14 or (combo >= 10 and 9 or 10)
    print("combo: "..combo, 90, 9, combo_col)
  end

  local lives_col = fx7 > 0 and 8 or 11
  print("\x8e"..lives, 60, 2, lives_col)

  local pu_x = 2
  if pw2 > 0 then
    print("shd", pu_x, 120, 12)
    pu_x += 20
  end
  if pw3 > 0 then
    print("slw", pu_x, 120, 14)
    pu_x += 20
  end
  if pw1 > 0 then
    print("2x", pu_x, 120, 10)
    pu_x += 16
  end
  if pw4 > 0 then
    print("mag", pu_x, 120, 9)
    pu_x += 20
  end
  if pw5 > 0 then
    print("frz", pu_x, 120, 13)
  end
end

function update_gauntlet_gameover()
  local input = test_input()

  if input & 16 > 0 then
    state = "menu"
    play_music(2)
    _log("state:menu")
  end
end

function draw_gauntlet_gameover()
  cls(1)

  print("gauntlet complete!", 20, 15, 7)

  print("bosses defeated: "..gt4, 18, 30, 10)
  print("final score: "..gt3, 24, 40, 10)
  print("max combo: "..gt5, 28, 50, 11)
  print("total dodges: "..ic8, 24, 60, 12)

  local time_sec = flr((90 * 30 - gt2) / 30)
  print("time: "..time_sec.."s / 90s", 28, 70, 9)

  print("final stage: "..gt6, 26, 80, 14)

  print("press o to return", 22, 105, 6)
end

function init_bossrush()
  ball.x = 64
  ball.y = 100
  ball.vx = 0
  ball.vy = 0
  ball.grounded = false

  br2 = 0
  br3 = 0
  br4 = 0
  br7 = 1
  br6 = 90
  br5 = 5
  br1 = true

  gm1 = 0
  lm7 = 1.0
  combo = 0
  lm1 = 0
  fx7 = 0

  ob4 = {}
  pw6 = {}
  fx8 = {}
  fx9 = {}
  bl1 = {}

  ob3 = 0
  ob6 = 0
  pw7 = 0
  pw2 = 0
  pw3 = 0
  pw1 = 0
  pw4 = 0
  pw5 = 0
  ob1 = false

  ic9 = 0
  ic8 = 0
  ic7 = 0
  ic6 = 0
  ic5 = 1.0
  ad5 = {}

  play_music(0)
  _log("state:bossrush")
  _log("bossrush_init:lives="..br5)
end

function update_bossrush()
  gm1 += 1

  update_ball()

  update_ball_trail()

  br6 -= 1
  if br6 <= 0 then
    spawn_bossrush_boss()

    local base_interval = 90
    local min_interval = 15
    local reduction = flr(combo * 3)
    br6 = max(min_interval, base_interval - reduction)

    _log("bossrush_boss_spawned:stage="..br7..",interval="..br6)
  end

  for o in all(ob4) do
    update_obstacle(o)
  end

  for p in all(pw6) do
    p.y += ob7
    if p.y > 140 then
      del(pw6, p)
    end
  end

  if pw2 > 0 then pw2 -= 1 end
  if pw3 > 0 then pw3 -= 1 end
  if pw1 > 0 then pw1 -= 1 end
  if pw4 > 0 then pw4 -= 1 end
  if pw5 > 0 then
    pw5 -= 1
    ob1 = true
  else
    ob1 = false
  end

  for o in all(ob4) do
    if o.is_boss and not o.dodged and o.y >= ball.y - 10 then
      local dist = sqrt((ball.x - o.x)^2 + (ball.y - o.y)^2)
      if dist < ball.r + o.r then
        if pw2 > 0 then
          pw2 = 0
          play_sfx(6)
          shake(8, 1.2)
          del(ob4, o)
          add_particles(o.x, o.y, 15, 11)
          _log("bossrush_shield_absorbed")
        else
          br5 -= 1
          fx7 = 15
          combo = 0
          lm1 = 0
          play_sfx(3)
          shake(15, 1.5)
          add_particles(ball.x, ball.y, 20, 8)
          _log("bossrush_damage:lives="..br5)

          del(ob4, o)

          if br5 <= 0 then
            if br2 > br8 then
              br8 = br2
              dset(94, br8)
              _log("bossrush_new_highscore:"..br8)
            end
            state = "bossrush_gameover"
            play_music(3)
            _log("state:bossrush_gameover")
            _log("bossrush_death:bosses="..br3..",score="..br2)
            return
          end
        end
      end
    end

    if o.is_boss and not o.dodged and o.y > ball.y + 10 then
      o.dodged = true
      combo += 1
      br4 = max(br4, combo)
      ic8 += 1

      local combo_mult = 1.0 + (combo * 0.05)
      local base_points = 5
      local dodge_points = flr(base_points * lm7 * combo_mult)
      br2 += dodge_points
      ic6 += dodge_points

      play_sfx(4)
      add_particles(ball.x, ball.y, 15, 10)
      add_floating_text("+"..dodge_points, ball.x, ball.y - 5, 10)
      _log("bossrush_dodge:combo="..combo..",score="..br2)

      local milestone = 0
      if combo >= 30 then milestone = 30
      elseif combo >= 25 then milestone = 25
      elseif combo >= 20 then milestone = 20
      elseif combo >= 15 then milestone = 15
      elseif combo >= 10 then milestone = 10
      elseif combo >= 5 then milestone = 5
      end

      if milestone > lm1 then
        lm1 = milestone
        play_sfx(7)
        shake(3, 0.25)
        local msg = "x"..milestone.." combo!"
        local col = milestone >= 20 and 14 or (milestone >= 10 and 9 or 10)
        add_floating_text(msg, 46, 50, col)
        _log("bossrush_milestone:"..milestone)
      end
    end

    if o.y > 140 then
      if o.is_boss and o.dodged then
        br3 += 1

        br7 = min(3, flr(br3 / 4) + 1)

        local stage_points = (br7 == 1 and 5) or (br7 == 2 and 8) or 12
        local final_points = flr(stage_points * lm7)
        br2 += final_points

        if br3 % 3 == 0 then
          lm7 += 0.2
          ic5 = max(ic5, lm7)
          play_sfx(7)
          shake(12, 1.5)
          fx5 = 10
          add_floating_text(lm7.."x lm7!", 30, 50, 10)
          _log("bossrush_multiplier:"..lm7)
        end

        if rnd(1) < 0.5 then
          spawn_powerup(64 + rnd(40) - 20, -10)
        end

        if br3 == 10 then
          add_floating_text("10 bosses!", 40, 60, 10)
          _log("bossrush_milestone_10")
        elseif br3 == 50 then
          add_floating_text("50 bosses!", 40, 60, 9)
          _log("bossrush_milestone_50")
        elseif br3 == 100 then
          add_floating_text("100 bosses!!!", 36, 60, 14)
          _log("bossrush_milestone_100")
        end

        play_sfx(7)
        shake(10, 1.0)
        add_particles(o.x, o.y, 25, 9)
        add_floating_text("+"..final_points, o.x, o.y - 5, 10)
        _log("bossrush_boss_defeated:"..br3..",stage="..br7..",score="..br2)
      end
      del(ob4, o)
    end
  end

  for p in all(pw6) do
    local dist = sqrt((ball.x - p.x)^2 + (ball.y - p.y)^2)
    if dist < ball.r + 3 then
      collect_powerup(p)
      del(pw6, p)
    end
  end

  if fx2 > 0 then
    fx2 -= 1
    fx3 = (rnd(2) - 1) * fx1
    fx4 = (rnd(2) - 1) * fx1
  else
    fx3 = 0
    fx4 = 0
  end

  if bl3 > 0 then bl3 -= 1 end
  if fx7 > 0 then fx7 -= 1 end

  for p in all(fx8) do
    p.x += p.vx
    p.y += p.vy
    p.life -= 1
    if p.life <= 0 then
      del(fx8, p)
    end
  end

  for ft in all(fx9) do
    ft.y -= 0.5
    ft.life -= 1
    if ft.life <= 0 then
      del(fx9, ft)
    end
  end
end

function spawn_bossrush_boss()
  add(ob4, mk_boss(br7))
  shake(6, 0.8)
  play_sfx(2)
  _log("bossrush_spawn_boss:stage="..br7)
end

function draw_bossrush()
  cls(1)
  draw_ball_trail()
  draw_ball()

  for o in all(ob4) do
    if o.is_boss then
      circfill(o.x, o.y, o.r, theme_color(8))
      circ(o.x, o.y, o.r, theme_color(2))

      if o.boss_stage >= 2 then
        local sat_count = o.boss_stage >= 3 and 2 or 1
        for i = 0, sat_count - 1 do
          local angle = o.satellite_timer + (i / sat_count)
          local sx = o.x + cos(angle) * 18
          local sy = o.y + sin(angle) * 18
          circfill(sx, sy, 3, theme_color(12))
        end
      end
    end
  end

  for p in all(pw6) do
    local col = 7
    if p.type == "shield" then col = 12
    elseif p.type == "slowmo" then col = 14
    elseif p.type == "doublescore" then col = 10
    elseif p.type == "magnet" then col = 9
    elseif p.type == "bomb" then col = 8
    elseif p.type == "freeze" then col = 13
    end
    circfill(p.x, p.y, 3, col)
    circ(p.x, p.y, 3, 7)
  end

  for p in all(fx8) do
    pset(p.x, p.y, p.col)
  end

  for ft in all(fx9) do
    local alpha = ft.life / 30
    if alpha > 0.3 then
      print(ft.text, ft.x, ft.y, ft.col)
    end
  end

  print("score: "..br2, 2, 2, 7)
  print("bosses: "..br3, 2, 9, 10)

  if lm7 > 1.0 then
    print(lm7.."x", 58, 2, 10)
  end

  if combo > 0 then
    local combo_col = combo >= 20 and 14 or (combo >= 10 and 9 or 10)
    print("combo: "..combo, 90, 9, combo_col)
  end

  local lives_col = fx7 > 0 and 8 or 11
  for i = 1, br5 do
    print("\x8e", 95 + (i - 1) * 6, 2, lives_col)
  end

  local pu_x = 2
  if pw2 > 0 then
    print("shd", pu_x, 120, 12)
    pu_x += 20
  end
  if pw3 > 0 then
    print("slw", pu_x, 120, 14)
    pu_x += 20
  end
  if pw1 > 0 then
    print("2x", pu_x, 120, 10)
    pu_x += 16
  end
  if pw4 > 0 then
    print("mag", pu_x, 120, 9)
    pu_x += 20
  end
  if pw5 > 0 then
    print("frz", pu_x, 120, 13)
  end
end

function update_bossrush_gameover()
  local input = test_input()

  if input & 16 > 0 then
    state = "menu"
    play_music(2)
    _log("state:menu")
  end
end

function draw_bossrush_gameover()
  cls(1)

  print("boss rush complete!", 14, 15, 7)

  print("bosses defeated: "..br3, 18, 30, 10)
  print("final score: "..br2, 24, 40, 10)
  print("max combo: "..br4, 28, 50, 11)
  print("final lm7: "..lm7.."x", 18, 60, 14)

  if br2 > 0 then
    if br2 >= br8 then
      print("new gm2!", 28, 72, 10)
    else
      print("best: "..br8, 38, 72, 12)
    end
  end

  if br3 >= 100 then
    print("legendary!", 36, 85, 14)
  elseif br3 >= 50 then
    print("amazing!", 40, 85, 9)
  elseif br3 >= 10 then
    print("impressive!", 34, 85, 10)
  end

  print("press o to return", 22, 105, 6)
end

__gfx__
000880000000000000eeee00008888000006600000bbb0000005550000bbbb0000cccc000aa00aa0dd0000dd00002000000cc00000077000000000000000000
0088880000cccc000ee77ee00882288000066000bbbbb00055225500bb77bb00cc77cc0a00a0a0add0000dd00022000c0cc0c00077770000000000000000000
0888888000ccccccee7777ee8882288800999000bbbb0005222225bb7777bbcc7777ccc00a0a0add0000dd00888800cccccc0077777700000000000000000000
8888888800ccccccee777777e88000088999999000bbbbb52222225b777777bc777c77ca0a00a00dd0000dd08888880cccccccc07777770000000000000000000
888282880ccccccce777777782888828999999990bbbbbb52222225b777777bc77777c7a00a0a00dd0000dd88788788cccccc0007777770000000000000000000
8822228800ccccccee7777ee8822228899999999bbbbb005222225bb7777bbcc7777ccc0a0a0a0d0dd00dd088888880c0cc0c00077777000000000000000000
8222222800cccc000ee77ee00828828009999900bbbb00005522550bb77bb00cc77cc0a0a00a0a0dddddd00888888000cc00000077770000000000000000000
0022220000000000000eeee000088880000999000bbbb0000055500000bbbb00000cccc0000000000dddd000088880000000000000770000000000000000000
__sfx__
000100003305035050330502e0502e0502a0502805023050200501d0501805014050100500c050090500605004050030500205001050000500005000050000500005000050000500005000050000500005000050
000100001c3501c3501c3501a3501a3501735015350123501035000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000
0002000018050180501a0501c0501e0502105024050270502a0502d05030050330503505037050390503b0503c0503d0503e0503e0503e0503d0503c0503a050380503505032050300502d0502a05027050240500
000200001c2501c2501e2501f25021250242502725029250240501f0501c0501905016050140501205010050000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000240503005038050300502a0503005028050300502405030050380503005024050300502805030050200502a05035050300502805024050200501c0500000000000000000000000000000000000000000
00020000180501e050240501e05018050180501e050240502a0502a0502a0502805027050250502405022050210501f0501d0501c0501a05018050160501405012050100500e0500c0500a050080500605004050
00040000240502405024050240502705027050270502705029050290502905029050270502705027050270502405024050240502405020050200502005020050190501905019050190501605016050160501605014
0004000000050000500005000050000502405027050290502c0502e050300503205034050360503805039050390503a0503a0503a050390503805037050360503405032050300502e0502c0502905027050240500
001000000c0530c0530c0530c0530e0530e0530e0530e053100531005310053100531105311053110531105313053130531305313053110531105311053110530e0530e0530e0530e0530c0530c0530c0530c053
001000001805318053180531805318053180531805318053180531805318053180531805318053180531805318053180531805318053180531805318053180531605316053160531605314053140531405314053
0010000024053240532405324053240532405324053240532705327053270532705327053270532705327053290532905329053290532705327053270532705324053240532405324053200532005320053200531
001000000c0330c0330c0330c033000000000000000000000e0330e0330e0330e03300000000000000000000000000000000000000001103311033110331103300000000000000000013033130331303313033000
__music__
01 08090a0b
01 08090a0b
01 08090a0b
01 08090a0b
__label__
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111777aaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111777aaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111777aaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111777aaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111177aaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111177aaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111177aaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111177aaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111111117aaaaaaaaaaaaa71111111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111111117aaaaaaaaaaaaa71111111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111111117aaaaaaaaaaaaa71111111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111111117aaaaaaaaaaaaa71111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117aaaaaaaaaaaaaaa7111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117aaaaaaaaaaaaaaa7111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117aaaaaaaaaaaaaaa7111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117aaaaaaaaaaaaaaa7111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111117aaaaaaaaaaaaaaaaa711111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111117aaaaaaaaaaaaaaaaa711111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111117aaaaaaaaaaaaaaaaa711111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111117aaaaaaaaaaaaaaaaa711111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111117aaaaaaaaaaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111117aaaaaaaaaaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111117aaaaaaaaaaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111117aaaaaaaaaaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111117aaaaaaaaaaaaaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111117aaaaaaaaaaaaaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111117aaaaaaaaaaaaaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111117aaaaaaaaaaaaaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111117aaaaaaaaaaaaaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111117aaaaaaaaaaaaaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111117aaaaaaaaaaaaaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111117aaaaaaaaaaaaaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaa77111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaa77111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaa77111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaa77111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaa777111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaa777111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaa777111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaa777111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaa777771111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaa777771111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaa777771111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaa777771111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaa77777771111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaa77777771111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaa77777771111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaa77777771111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaa7777777771111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaa7777777771111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaa7777777771111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaa7777777771111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777771111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777771111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777771111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777771111111111111111111111111111111111111111111111111111111111
111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaa77777777777771111111111111111111111111111111111111111111111111111111
111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaa77777777777771111111111111111111111111111111111111111111111111111111
111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaa77777777777771111111111111111111111111111111111111111111111111111111
111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaa77777777777771111111111111111111111111111111111111111111111111111111
11111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa7777777777777771111111111111111111111111111111111111111111111111111
11111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa7777777777777771111111111111111111111111111111111111111111111111111
11111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa7777777777777771111111111111111111111111111111111111111111111111111
11111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa7777777777777771111111111111111111111111111111111111111111111111111
1111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777777777771111111111111111111111111111111111111111111111111
1111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777777777771111111111111111111111111111111111111111111111111
1111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777777777771111111111111111111111111111111111111111111111111
1111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777777777771111111111111111111111111111111111111111111111111
11111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa77777777777777777771111111111111111111111111111111111111111111111
11111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa77777777777777777771111111111111111111111111111111111111111111111
11111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa77777777777777777771111111111111111111111111111111111111111111111
11111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa77777777777777777771111111111111111111111111111111111111111111111
1111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa7777777777777777777771111111111111111111111111111111111111111111
1111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa7777777777777777777771111111111111111111111111111111111111111111
1111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa7777777777777777777771111111111111111111111111111111111111111111
1111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa7777777777777777777771111111111111111111111111111111111111111111
111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777777777777777771111111111111111111111111111111111111111
111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777777777777777771111111111111111111111111111111111111111
111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777777777777777771111111111111111111111111111111111111111
111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777777777777777771111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
