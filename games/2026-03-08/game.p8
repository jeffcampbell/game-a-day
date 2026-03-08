pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- Cave Escape
-- Navigate the cave, avoid enemies, reach the exit!

testmode=false
test_log={}
test_inputs={}
test_input_idx=0

function _log(msg)
 if testmode then add(test_log,msg) end
end

function _capture()
 if testmode then add(test_log,"SCREEN:"..tostr(stat(0))) end
end

function test_input(b)
 if testmode and test_input_idx<#test_inputs then
  test_input_idx+=1
  return test_inputs[test_input_idx] or 0
 end
 return btn()
end

state="menu"
game_mode="adventure"  -- "adventure" or "endless"
difficulty="normal"
difficulty_cursor=2
mode_cursor=1  -- 1=adventure, 2=endless, 3=tutorial
score=0

-- tutorial mode variables
tutorial_phase=0  -- 0=intro, 1=dash, 2=shield, 3=challenge
tutorial_frames=0
tutorial_dash_count=0
tutorial_shield_count=0
tutorial_enemy=nil
best_score=0
best_endless_score=0
level_score=0
health=3
level=1
frames=0
level_start_frame=0
is_endless=false
wave=1
wave_start_frame=-10000

-- player
player={x=64,y=100,w=8,h=8,speed=1.5,alive=true}

-- enemies array
enemies={}

-- exit portal
exit_portal={x=115,y=15,w=8,h=8}

-- boss entity (only in level 3)
boss=nil
boss_health=0
boss_hit_frame=-1000
boss_invuln_frames=30  -- 0.5 seconds visual feedback

-- difficulty ramp-up: ease in enemies during first 30s (1800 frames)
difficulty_ramp_duration=1800

-- audio state tracking
last_move_frame=-10
last_hit_frame=-10

-- dash mechanics
dash_cooldown=30  -- 0.5 seconds at 60fps
last_dash_frame=-100
dash_invuln_frames=10
dash_invuln_start=-100
dash_speed_mult=2.5

-- shield mechanics
shield_cooldown=90  -- 1.5 seconds at 60fps
last_shield_frame=-100
shield_invuln_frames=30  -- 0.5 seconds at 60fps
shield_invuln_start=-100
prev_down_btn=0  -- track previous down button state for press detection

-- discovery cues: track ready state for audio feedback
dash_ready_last_frame=-1000
shield_ready_last_frame=-1000
player_used_dash=false
player_used_shield=false
level_2_dash_reminder=false
level_3_shield_reminder=false

-- adaptive difficulty tracking
hit_times={}  -- sliding window of last hit frames
last_difficulty_check=0
adaptive_speed_mult=1.0
adaptive_spawn_mult=1.0

-- passive playstyle detection
is_passive_player=false
dash_count_first_5s=0
passive_check_done=false

-- power-up system
power_ups={}
player_power_up=nil  -- current held power-up: {type,spawn_frame}
prev_down_btn=0  -- track down button state for power-up activation
power_up_spawn_frame=-10000
power_up_spawned=false  -- track if power-up has spawned for this level

function init_level()
 enemies={}
 power_ups={}
 player_power_up=nil
 power_up_spawn_frame=frames
 level_start_frame=frames
 level_score=0
 power_up_spawned=false
 boss=nil
 boss_health=0
 boss_hit_frame=-1000

 -- reset adaptive difficulty tracking
 hit_times={}
 adaptive_speed_mult=1.0
 adaptive_spawn_mult=1.0
 last_difficulty_check=frames

 -- reset passive playstyle detection
 is_passive_player=false
 dash_count_first_5s=0
 passive_check_done=false

 -- reset reminder flags for new level
 level_2_dash_reminder=false
 level_3_shield_reminder=false

 -- start background music
 music(0)

 -- difficulty modifiers
 local speed_mult=1
 local health_val=3
 if difficulty=="easy" then
  speed_mult=0.4
  health_val=5
 elseif difficulty=="hard" then
  speed_mult=1.3
  health_val=2
 end

 health=health_val
 -- passive players get +1 health on level 3 for better survivability
 if is_passive_player and level==3 then
  health=health+1
  _log("health_boost:passive_level3")
 end
 _log("difficulty:"..difficulty)
 _log("level:"..level)

 if level==1 then
  player.x=12
  player.y=100

  -- difficulty ramp-up: spawn enemies gradually during first 30 seconds
  -- start with 2 enemies, add 2 more at 15 seconds
  if level_start_frame==0 then
   local passive_speed_mult=1.0
   if is_passive_player then
    passive_speed_mult=0.8  -- 20% speed reduction for passive players
    _log("difficulty:passive_adjust")
   end
   add(enemies,{x=60,y=30,w=8,h=8,speed=0.6*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=1})
   add(enemies,{x=100,y=60,w=8,h=8,speed=0.6*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=-1})
  end

 elseif level==2 then
  player.x=12
  player.y=100

  -- level 2: 3 enemies initially (2 for passive players), 2 more at 15 seconds
  if level_start_frame>0 then
   local passive_speed_mult=1.0
   if is_passive_player then
    passive_speed_mult=0.8  -- 20% speed reduction for passive players
    _log("difficulty:passive_adjust")
   end
   add(enemies,{x=50,y=25,w=8,h=8,speed=0.9*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=1})
   add(enemies,{x=95,y=40,w=8,h=8,speed=0.9*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=-1})
   -- only add 3rd enemy if not passive
   if not is_passive_player then
    add(enemies,{x=25,y=60,w=8,h=8,speed=0.9*speed_mult*adaptive_speed_mult,dir=1})
   end
  end

 elseif level==3 then
  player.x=12
  player.y=100

  -- level 3: boss encounter
  -- boss spawns at center-top
  local boss_speed=0.7
  local boss_health_val=3
  if difficulty=="hard" then
   boss_speed=0.8
   boss_health_val=4
  elseif difficulty=="easy" then
   boss_speed=0.6
   boss_health_val=3
  end

  boss={x=64,y=25,w=12,h=12,speed=boss_speed,dir=1,health=boss_health_val}
  boss_health=boss_health_val
  _log("boss_encounter")

  -- level 3: 3-5 enemies initially, 5-10% faster than level 2
  -- reduced to 3 for passive players to improve completion rate
  if level_start_frame>0 then
   local passive_speed_mult=1.0
   if is_passive_player then
    passive_speed_mult=0.75  -- 25% speed reduction for passive players (increased from 20%)
    _log("difficulty:passive_adjust_level3")
   end
   -- base speed 0.95 is ~5% faster than level 2's 0.9
   add(enemies,{x=40,y=30,w=8,h=8,speed=0.95*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=1})
   add(enemies,{x=90,y=50,w=8,h=8,speed=0.95*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=-1})
   add(enemies,{x=30,y=80,w=8,h=8,speed=0.95*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=1})
   -- 4th enemy: only add if not passive (reduces initial spawn for passive)
   if not is_passive_player then
    add(enemies,{x=100,y=100,w=8,h=8,speed=0.95*speed_mult*adaptive_speed_mult,dir=-1})
   end
   -- 5th enemy only if not passive
   if not is_passive_player then
    add(enemies,{x=60,y=60,w=8,h=8,speed=0.95*speed_mult*adaptive_speed_mult,dir=1})
   end
  end
  _log("level_3_start")
 end
end

function init_endless_level()
 enemies={}
 power_ups={}
 player_power_up=nil
 power_up_spawn_frame=frames
 level_start_frame=frames
 level_score=0

 -- reset shield state
 shield_invuln_start=-100
 last_shield_frame=-100
 prev_down_btn=0

 -- reset adaptive difficulty tracking
 hit_times={}
 adaptive_speed_mult=1.0
 adaptive_spawn_mult=1.0
 last_difficulty_check=frames

 -- reset passive playstyle detection
 is_passive_player=false
 dash_count_first_5s=0
 passive_check_done=false

 -- start background music
 music(0)

 player.x=12
 player.y=100
 health=3
 wave=1
 wave_start_frame=frames

 -- spawn initial wave: 3 enemies (match new wave scaling)
 add(enemies,{x=60,y=30,w=8,h=8,speed=0.6*adaptive_speed_mult,dir=1})
 add(enemies,{x=100,y=60,w=8,h=8,speed=0.6*adaptive_speed_mult,dir=-1})
 add(enemies,{x=30,y=80,w=8,h=8,speed=0.6*adaptive_speed_mult,dir=1})

 _log("difficulty:endless")
 _log("wave:1")
end

function update_adaptive_difficulty()
 -- disable adaptive scaling in hard mode
 if difficulty=="hard" then return end

 local elapsed_since_check=frames-last_difficulty_check

 -- check every 60 frames (1 second) to avoid excessive updates
 if elapsed_since_check<60 then return end

 last_difficulty_check=frames

 -- count recent hits: sliding window of 300 frames (5 seconds)
 local recent_hits=0
 for i=1,#hit_times do
  if frames-hit_times[i]<300 then
   recent_hits+=1
  end
 end

 -- count hits in last 30 seconds (1800 frames)
 local recent_30s_hits=0
 for i=1,#hit_times do
  if frames-hit_times[i]<1800 then
   recent_30s_hits+=1
  end
 end

 -- struggling: 2+ hits in last 5 seconds
 if recent_hits>=2 then
  -- reduce enemy speed by 15%
  adaptive_speed_mult=max(0.6,adaptive_speed_mult*0.85)
  -- increase spawn delays by 20% (spawn_mult < 1 delays spawns)
  adaptive_spawn_mult=min(1.0,adaptive_spawn_mult*0.8)
  _log("difficulty:down")

 -- thriving: no hits in last 30 seconds AND game is long enough
 elseif recent_30s_hits==0 and frames-level_start_frame>1800 then
  -- increase enemy speed by 5%
  adaptive_speed_mult=min(1.5,adaptive_speed_mult*1.05)
  -- increase spawn frequency slightly
  adaptive_spawn_mult=min(1.5,adaptive_spawn_mult*1.02)
  _log("difficulty:up")
 end
end

function update_menu()
 if test_input(4)>0 or test_input(5)>0 then
  state="tutorial_mode_select"
  mode_cursor=1
  _log("state:tutorial_mode_select")
 end
end

function update_tutorial_mode_select()
 if test_input(0)>0 or test_input(2)>0 then
  mode_cursor=max(1,mode_cursor-1)
 end
 if test_input(1)>0 or test_input(3)>0 then
  mode_cursor=min(3,mode_cursor+1)
 end

 if test_input(4)>0 or test_input(5)>0 then
  if mode_cursor==1 then
   game_mode="adventure"
   state="difficulty_select"
   difficulty_cursor=2
   _log("state:difficulty_select")
  elseif mode_cursor==2 then
   game_mode="endless"
   difficulty="normal"
   is_endless=true
   state="play"
   score=0
   level=1
   wave=1
   init_endless_level()
   _log("state:play")
  else
   state="tutorial_intro"
   tutorial_phase=0
   tutorial_frames=0
   tutorial_dash_count=0
   tutorial_shield_count=0
   player.x=32
   player.y=64
   enemies={}
   _log("state:tutorial_intro")
  end
 end
end

function update_difficulty_select()
 if test_input(2)>0 then
  difficulty_cursor=max(1,difficulty_cursor-1)
 end
 if test_input(3)>0 then
  difficulty_cursor=min(3,difficulty_cursor+1)
 end

 if test_input(4)>0 or test_input(5)>0 then
  if difficulty_cursor==1 then
   difficulty="easy"
  elseif difficulty_cursor==2 then
   difficulty="normal"
  elseif difficulty_cursor==3 then
   difficulty="hard"
  end
  is_endless=false
  state="play"
  score=0
  level=1
  wave=1
  wave_start_frame=0
  init_level()
  _log("state:play")
 end
end

function draw_menu()
 cls(1)
 print("cave escape",36,20,7)
 print("find the glowing",24,35,7)
 print("exit portal",32,44,7)
 print("avoid red enemies",24,56,7)
 print("reach both levels",24,68,11)
 print("arrow keys move",28,80,11)
 print("x button dash!",32,90,11)
 print("down button: activate",22,98,11)
 print("power-ups!",40,104,11)
 print("z or x to start",32,114,11)
end

function draw_tutorial_mode_select()
 cls(1)
 print("select game mode",28,30,7)

 local col1=7
 local col2=7
 local col3=7
 if mode_cursor==1 then
  col1=11
 elseif mode_cursor==2 then
  col2=11
 else
  col3=11
 end

 print("adventure",40,50,col1)
 print("endless",44,70,col2)
 print("tutorial",44,90,col3)

 print("arrows select",32,105,7)
 print("z/x confirm",36,115,7)
end

function draw_difficulty_select()
 cls(1)
 print("select difficulty",28,20,7)

 local colors={8,7,11}
 local y_positions={50,70,90}
 local labels={"easy","normal","hard"}

 for i=1,3 do
  local col=colors[i]
  if i==difficulty_cursor then
   col=11
  end
  print(labels[i],56,y_positions[i],col)
 end

 print("up/down select",32,110,7)
 print("z/x confirm",36,118,7)
end

-- tutorial functions
function update_tutorial_intro()
 tutorial_frames+=1
 if tutorial_frames>120 then  -- 2 seconds at 60fps
  state="tutorial_dash"
  tutorial_phase=1
  tutorial_frames=0
  tutorial_dash_count=0
  _log("state:tutorial_dash")
 end
 if test_input(4)>0 or test_input(5)>0 then
  state="menu"
  _log("tutorial_skip")
 end
end

function update_tutorial_dash()
 tutorial_frames+=1

 -- handle movement
 local dx=0
 local dy=0
 if test_input(0)>0 then dx-=player.speed end
 if test_input(1)>0 then dx+=player.speed end
 if test_input(2)>0 then dy-=player.speed end
 if test_input(3)>0 then dy+=player.speed end

 player.x=mid(8,player.x+dx,120)
 player.y=mid(8,player.y+dy,120)

 -- dash detection
 if test_input(5)>0 and frames-last_dash_frame>=dash_cooldown then
  tutorial_dash_count+=1
  last_dash_frame=frames
  _log("tutorial_dash_performed")
  if tutorial_dash_count>=3 then
   state="tutorial_shield"
   tutorial_phase=2
   tutorial_frames=0
   tutorial_shield_count=0
   _log("state:tutorial_shield")
  end
 end

 if test_input(4)>0 or tutorial_frames>300 then  -- 5 seconds max
  state="menu"
  _log("tutorial_skip")
 end
end

function update_tutorial_shield()
 tutorial_frames+=1

 -- handle movement
 local dx=0
 local dy=0
 if test_input(0)>0 then dx-=player.speed end
 if test_input(1)>0 then dx+=player.speed end
 if test_input(2)>0 then dy-=player.speed end
 if test_input(3)>0 then dy+=player.speed end

 player.x=mid(8,player.x+dx,120)
 player.y=mid(8,player.y+dy,120)

 -- shield detection (down button + not pressing it previously)
 local down_input=test_input(3)
 if down_input>0 and prev_down_btn==0 and frames-last_shield_frame>=shield_cooldown then
  tutorial_shield_count+=1
  last_shield_frame=frames
  shield_invuln_start=frames
  _log("tutorial_shield_performed")
  if tutorial_shield_count>=3 then
   state="menu"
   _log("tutorial_complete")
  end
 end
 prev_down_btn=down_input

 if test_input(4)>0 or tutorial_frames>300 then  -- 5 seconds max
  state="menu"
  _log("tutorial_skip")
 end
end

function draw_tutorial_intro()
 cls(1)
 print("welcome to tutorial",20,20,7)
 print("learn advanced tactics",16,35,11)
 print("x button dash fast",22,50,11)
 print("down shield protect",20,65,11)
 print("arrows to move",28,90,7)
 print("starting soon...",28,110,7)
end

function draw_tutorial_dash()
 cls(1)
 print("dash practice",32,15,7)
 print("press x to dash",28,35,11)
 print("try 3 dashes",32,50,11)
 print("progress: "..tutorial_dash_count.."/3",24,70,14)

 -- draw player
 spr(1,player.x-4,player.y-4)

 -- flash player if recently dashed
 if frames-last_dash_frame<dash_invuln_frames then
  spr(2,player.x-4,player.y-4)
 end

 print("z to skip",40,115,8)
end

function draw_tutorial_shield()
 cls(1)
 print("shield practice",28,15,7)
 print("hold down to shield",20,35,11)
 print("try 3 shields",32,50,11)
 print("progress: "..tutorial_shield_count.."/3",24,70,14)

 -- draw player
 spr(1,player.x-4,player.y-4)

 -- show shield if active
 if frames-shield_invuln_start<shield_invuln_frames then
  circ(player.x,player.y,12,14)
 end

 print("z to skip",40,115,8)
end

function update_play()
 if not player.alive then return end

 -- update adaptive difficulty based on player performance
 update_adaptive_difficulty()

 local dx=0
 local dy=0

 if test_input(0)>0 then dx=-player.speed end
 if test_input(1)>0 then dx=player.speed end
 if test_input(2)>0 then dy=-player.speed end
 if test_input(3)>0 then dy=player.speed end

 -- play move sound on input
 if (dx~=0 or dy~=0) and frames-last_move_frame>10 then
  sfx(0)
  last_move_frame=frames
 end

 -- calculate elapsed time for passive playstyle detection
 local elapsed=frames-level_start_frame

 -- dash mechanic (x button)
 local dash_ready=frames-last_dash_frame>=dash_cooldown
 if test_input(5)>0 and dash_ready then
  local dash_dx=0
  local dash_dy=0

  -- determine dash direction from current input
  if dx~=0 then dash_dx=sgn(dx) end
  if dy~=0 then dash_dy=sgn(dy) end

  -- if no directional input, dash forward (right)
  if dash_dx==0 and dash_dy==0 then dash_dx=1 end

  -- apply dash boost
  dx+=dash_dx*player.speed*dash_speed_mult
  dy+=dash_dy*player.speed*dash_speed_mult

  -- activate invulnerability window
  dash_invuln_start=frames
  last_dash_frame=frames
  player_used_dash=true

  -- play dash sound
  sfx(3)
  _log("dash")

  -- track dashes in first 5 seconds for passive detection
  if not passive_check_done and elapsed<300 then
   dash_count_first_5s+=1
  end
 end

 -- play ready cue when dash becomes available (transition from not ready to ready)
 if dash_ready and frames-dash_ready_last_frame>60 then
  if frames-last_dash_frame>dash_cooldown+5 then  -- just became ready
   sfx(7)  -- dash ready beep (higher pitch)
   dash_ready_last_frame=frames
  end
 end

 -- shield mechanic (o button)
 local shield_ready=frames-last_shield_frame>=shield_cooldown
 if test_input(4)>0 and shield_ready then
  shield_invuln_start=frames
  last_shield_frame=frames
  player_used_shield=true
  sfx(8)  -- shield activate beep (lower pitch)
  _log("shield")
 end

 -- play ready cue when shield becomes available
 if shield_ready and frames-shield_ready_last_frame>60 then
  if frames-last_shield_frame>shield_cooldown+5 then  -- just became ready
   sfx(7)  -- shield ready beep
   shield_ready_last_frame=frames
  end
 end

 -- passive playstyle detection: check at 5 seconds mark
 if not passive_check_done and elapsed>=300 then
  passive_check_done=true
  if dash_count_first_5s<2 then
   is_passive_player=true
   _log("playstyle:passive")
  else
   _log("playstyle:active")
  end
 end

 -- power-up activation (down button)
 local down_btn=test_input(3)
 if down_btn>0 and prev_down_btn==0 and player_power_up~=nil then
  -- activate held power-up
  local ptype=player_power_up.type
  sfx(4)
  _log("power_use:"..ptype)

  if ptype=="shield" then
   shield_invuln_start=frames
   last_shield_frame=frames
  elseif ptype=="speed" then
   player.speed=player.speed*2.0
   player.speed_boost_end=frames+90  -- 1.5 seconds
  elseif ptype=="slow" then
   adaptive_speed_mult=0.5
   player.slow_end=frames+120  -- 2 seconds
  elseif ptype=="heal" then
   health=min(health+1,3)
  end

  player_power_up=nil
 end

 -- auto-drop power-up if held for 10 seconds without use (600 frames)
 if player_power_up~=nil and frames-player_power_up.spawn_frame>600 then
  _log("power_drop")
  player_power_up=nil
 end

 prev_down_btn=down_btn

 player.x+=dx
 player.y+=dy

 player.x=max(2,min(player.x,126))
 player.y=max(2,min(player.y,126))

 if is_endless then
  -- endless mode: wave-based spawning every 30-40 seconds (adaptive)
  local wave_elapsed=frames-wave_start_frame
  local spawn_interval=flr(1800/adaptive_spawn_mult)  -- 30 seconds base, adaptive wave timing
  if wave_elapsed>=spawn_interval then  -- adaptive spawn interval
   wave+=1
   wave_start_frame=frames

   -- progressive difficulty: start at 3, increase by 1-2 per wave, cap at 10
   local enemy_count
   if wave<=2 then
    enemy_count=2+wave  -- wave 1: 3, wave 2: 4
   else
    enemy_count=min(4+flr((wave-2)/2),10)  -- wave 3+: increase by 1 every 2 waves
   end

   -- award points: 10 per enemy + 100 for wave survival
   score+=enemy_count*10+100

   for j=1,enemy_count do
    local spawn_y=20+flr(rnd(80))
    local spawn_x=10+flr(rnd(100))
    local speed_base=0.6+wave*0.05  -- slightly more conservative speed increase
    local passive_speed_mult=1.0
    if is_passive_player then passive_speed_mult=0.8 end  -- 20% speed reduction for passive players
    local dir=1
    if j%2==0 then dir=-1 end
    add(enemies,{x=spawn_x,y=spawn_y,w=8,h=8,speed=speed_base*adaptive_speed_mult*passive_speed_mult,dir=dir})
   end
   _log("wave:"..wave)
  end

  -- endless mode power-up spawning: every 25 seconds (1500 frames)
  if player_power_up==nil then
   local endless_power_spawn_interval=1500

   -- spawn power-up regularly in endless mode
   if frames-power_up_spawn_frame>endless_power_spawn_interval then
    power_up_spawn_frame=frames
    local power_types={"shield","speed","slow","heal"}
    local ptype=power_types[flr(rnd(4))+1]
    local spawn_x=20+flr(rnd(88))
    local spawn_y=20+flr(rnd(88))
    add(power_ups,{x=spawn_x,y=spawn_y,w=8,h=8,type=ptype})
    _log("power_spawn:"..ptype)
   end
  end

 else
  -- standard mode: difficulty ramp-up
  local speed_mult=1
  if difficulty=="easy" then
   speed_mult=0.4
  elseif difficulty=="hard" then
   speed_mult=1.3
  end

  -- apply spawn timing modulation based on adaptive difficulty
  local spawn_delay_mult=1.0/adaptive_spawn_mult  -- invert so < 1 means delayed
  -- passive players get 2 extra seconds delay (120 frames)
  local passive_spawn_delay=0
  if is_passive_player then passive_spawn_delay=120 end

  if elapsed==flr(900*spawn_delay_mult)+passive_spawn_delay then  -- 15 seconds (adaptive)
   if level==1 then
    local passive_speed_mult=1.0
    if is_passive_player then passive_speed_mult=0.8 end
    add(enemies,{x=30,y=70,w=8,h=8,speed=0.6*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=1})
    _log("enemy_spawn_ramp")
   elseif level==2 then
    local passive_speed_mult=1.0
    if is_passive_player then passive_speed_mult=0.8 end
    add(enemies,{x=70,y=80,w=8,h=8,speed=0.9*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=-1})
    _log("enemy_spawn_ramp")
   elseif level==3 then
    local passive_speed_mult=1.0
    if is_passive_player then passive_speed_mult=0.8 end
    add(enemies,{x=50,y=35,w=8,h=8,speed=0.95*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=1})
    _log("enemy_spawn_ramp")
   end
  elseif elapsed==flr(1200*spawn_delay_mult)+passive_spawn_delay then  -- 20 seconds (adaptive)
   if level==1 then
    local passive_speed_mult=1.0
    if is_passive_player then passive_speed_mult=0.8 end
    add(enemies,{x=80,y=90,w=8,h=8,speed=0.6*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=-1})
    _log("enemy_spawn_ramp")
   elseif level==2 then
    local passive_speed_mult=1.0
    if is_passive_player then passive_speed_mult=0.8 end
    add(enemies,{x=40,y=110,w=8,h=8,speed=0.9*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=1})
    _log("enemy_spawn_ramp")
   elseif level==3 then
    local passive_speed_mult=1.0
    if is_passive_player then passive_speed_mult=0.8 end
    -- level 3: ramp to 6-7 enemies by 20 seconds
    add(enemies,{x=80,y=110,w=8,h=8,speed=0.98*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=-1})
    add(enemies,{x=20,y=50,w=8,h=8,speed=0.98*speed_mult*adaptive_speed_mult,dir=1})
    _log("enemy_spawn_ramp")
   end
  end

  -- hard mode: add extra enemy mid-level (no adaptive in hard)
  if difficulty=="hard" and elapsed==600 then  -- 10 seconds
   if level==1 then
    add(enemies,{x=50,y=50,w=8,h=8,speed=0.6*speed_mult,dir=-1})
    _log("enemy_spawn_ramp")
   elseif level==2 then
    add(enemies,{x=60,y=30,w=8,h=8,speed=0.9*speed_mult,dir=1})
    _log("enemy_spawn_ramp")
   elseif level==3 then
    add(enemies,{x=70,y=70,w=8,h=8,speed=0.95*speed_mult,dir=-1})
    _log("enemy_spawn_ramp")
   end
  end

  -- calculate time bonus: 10 points per second survived, max 300 per level
  local level_elapsed=(frames-level_start_frame)/60
  level_score=flr(min(level_elapsed*10,300))

  -- spawn power-up at specific time (only if not holding one)
  if player_power_up==nil then
   local power_types={"shield","speed","slow","heal"}
   -- spawn power-up at 15 seconds (900 frames)
   if not power_up_spawned and elapsed>=900 then
    power_up_spawned=true
    local ptype=power_types[flr(rnd(4))+1]
    local spawn_x=20+flr(rnd(88))
    local spawn_y=20+flr(rnd(88))
    add(power_ups,{x=spawn_x,y=spawn_y,w=8,h=8,type=ptype})
    _log("power_spawn:"..ptype)
   end
  end
 end

 -- update speed boost duration
 if player.speed_boost_end~=nil and frames>=player.speed_boost_end then
  player.speed=player.speed/2.0
  player.speed_boost_end=nil
 end

 -- update slow enemies duration
 if player.slow_end~=nil and frames>=player.slow_end then
  adaptive_speed_mult=1.0
  player.slow_end=nil
 end

 -- boss update and collision (level 3 only)
 if boss~=nil then
  boss.x+=boss.speed*boss.dir

  if boss.x<2 or boss.x>126 then
   boss.dir=-boss.dir
  end

  -- boss collision detection
  local is_dash_invuln=frames-dash_invuln_start<dash_invuln_frames
  local is_shield_invuln=frames-shield_invuln_start<shield_invuln_frames

  if collide(player,boss) then
   if is_shield_invuln then
    -- shield blocks the collision
    _log("shield_block")
   elseif not is_dash_invuln then
    -- hit boss
    boss.health-=1
    boss_hit_frame=frames
    _log("boss_hit")
    sfx(5)  -- boss hit sound

    if boss.health<=0 then
     score+=500
     _log("boss_defeated")
     -- fanfare sound
     sfx(6)
    else
     player.x-=dx*4
    end
   end
  end
 end

 for i=1,#enemies do
  local e=enemies[i]
  e.x+=e.speed*e.dir

  if e.x<2 or e.x>126 then
   e.dir=-e.dir
  end

  -- check collision only if not in invulnerability window (dash or shield)
  local is_dash_invuln=frames-dash_invuln_start<dash_invuln_frames
  local is_shield_invuln=frames-shield_invuln_start<shield_invuln_frames
  if collide(player,e) then
   if is_shield_invuln then
    -- shield blocks the collision
    _log("shield_block")
   elseif not is_dash_invuln then
    -- take damage from enemy
    health-=1
    -- track hit for adaptive difficulty
    add(hit_times,frames)
    _log("hit_enemy")
    sfx(1)

    if health<=0 then
     player.alive=false
     state="gameover"
     if level==3 then _log("level_3_fail") end
     _log("gameover:lose")
    else
     player.x-=dx*4
    end
   end
  end
 end

 -- power-up collision detection
 for i=#power_ups,1,-1 do
  local p=power_ups[i]
  if collide(player,p) then
   player_power_up={type=p.type,spawn_frame=frames}
   _log("power_pickup:"..p.type)
   sfx(4)
   del(power_ups,p)
  end
 end

 -- exit portal only used in standard mode (not endless)
 if not is_endless and collide(player,exit_portal) then
  sfx(2)
  level+=1

  -- award level completion bonus
  score+=level_score
  score+=500
  _log("score:"..score)

  if level>2 then
   _log("level_3_complete")
   state="gameover"
   -- check boss status for perfect victory
   if boss~=nil and boss.health<=0 then
    _log("gameover:win_perfect")
   else
    _log("gameover:win")
   end
  else
   init_level()
   _log("level_complete")
  end
 end

 frames+=1
end

function draw_play()
 cls(0)

 for x=0,128,8 do
  for y=0,128,8 do
   if (x+y)%16==0 then
    rectfill(x,y,x+7,y+7,5)
   end
  end
 end

 if player.alive then
  -- change color during shield or dash invulnerability
  local is_dash_invuln=frames-dash_invuln_start<dash_invuln_frames
  local is_shield_invuln=frames-shield_invuln_start<shield_invuln_frames

  if is_shield_invuln then
   pal(11,9)  -- shield: change to cyan
  elseif is_dash_invuln then
   pal(11,7)  -- dash: change to white
  end

  spr(0,player.x-4,player.y-4)
  pal()
 end

 -- draw boss with visual feedback on hit
 if boss~=nil then
  -- flash on hit (0.5s visual feedback)
  local boss_draw_color=8  -- darker red normally
  if frames-boss_hit_frame<boss_invuln_frames then
   boss_draw_color=15  -- white flash on hit
  end
  -- draw boss as larger sprite with outline
  rectfill(boss.x-6,boss.y-6,boss.x+6,boss.y+6,boss_draw_color)
  rect(boss.x-6,boss.y-6,boss.x+6,boss.y+6,15)  -- white outline
  -- draw enemy sprite (1) in center
  pal(8,boss_draw_color)
  spr(1,boss.x-4,boss.y-4)
  pal()
 end

 for i=1,#enemies do
  local e=enemies[i]
  spr(1,e.x-4,e.y-4)
 end

 if not is_endless then
  spr(2,exit_portal.x-4,exit_portal.y-4)
 end

 -- draw power-ups
 for i=1,#power_ups do
  local p=power_ups[i]
  local spr_id=2  -- default
  if p.type=="shield" then spr_id=3
  elseif p.type=="speed" then spr_id=4
  elseif p.type=="slow" then spr_id=5
  elseif p.type=="heal" then spr_id=6
  end
  spr(spr_id,p.x-4,p.y-4)
 end

 -- draw mechanic ready indicators at top right
 local dash_ready=frames-last_dash_frame>=dash_cooldown
 local shield_ready=frames-last_shield_frame>=shield_cooldown

 -- dash indicator (X button)
 local dash_color=5  -- red when on cooldown
 if dash_ready then dash_color=11 end  -- cyan when ready
 rectfill(110,1,121,9,dash_color)
 if dash_ready then
  print("x",113,2,0)  -- show "x" in black when ready
 end

 -- shield indicator (O button)
 local shield_color=5  -- red when on cooldown
 if shield_ready then shield_color=11 end  -- cyan when ready
 rectfill(110,11,121,19,shield_color)
 if shield_ready then
  print("o",114,12,0)  -- show "o" in black when ready
 end

 if is_endless then
  -- endless mode display
  local survival_time=flr((frames-level_start_frame)/60)
  print("sc "..score,2,2,7)
  print("wave "..wave,40,2,7)
  print("time "..survival_time.."s",75,2,7)
  print("hp "..max(0,health),2,12,7)
 else
  -- standard mode display
  local total_score=score+level_score
  print("sc "..total_score,2,2,7)
  print("lvl "..level,40,2,7)
  print("hp "..max(0,health),90,2,7)
  -- display boss health on level 3
  if boss~=nil then
   print("boss hp:"..max(0,boss.health),55,12,8)
  end
  -- display held power-up with activation hint
  if player_power_up~=nil then
   print("pow:"..player_power_up.type,50,22,10)
   print("press down!",52,32,11)
  end

  -- show tutorial reminders for unused mechanics
  local elapsed=frames-level_start_frame
  if level==2 and not player_used_dash and elapsed>600 and not level_2_dash_reminder then
   print("try x!",58,120,11)  -- prompt for dash
   level_2_dash_reminder=true
  end
  if level==3 and not player_used_shield and elapsed>600 and not level_3_shield_reminder then
   print("press o!",55,120,11)  -- prompt for shield
   level_3_shield_reminder=true
  end

  print("find exit (top right)",10,120,14)
 end
end

function update_gameover()
 -- stop background music when game ends
 music(-1)
 if test_input(4)>0 or test_input(5)>0 then
  state="menu"
  prev_down_btn=0
  _log("state:menu")
 end
end

function draw_gameover()
 cls(0)

 if is_endless then
  -- endless mode gameover
  print("endless failed",32,20,8)
  print("waves survived:"..wave,28,35,11)
  print("score:"..score,48,50,7)
  if score>best_endless_score then
   best_endless_score=score
   print("new record!",44,60,11)
  else
   print("best:"..best_endless_score,44,60,7)
  end
 else
  -- standard mode gameover
  local final_score=score
  if level>2 then
   final_score+=level_score+500
   print("victory!",44,20,11)
   print("escaped all three",28,35,11)
   print("cave levels!",36,46,11)
  else
   final_score+=level_score
   print("game over",40,20,8)
   print("caught!",48,35,8)
  end

  print("score:"..final_score,44,60,7)
  if final_score>best_score then
   best_score=final_score
   print("new best!",44,70,11)
  else
   print("best:"..best_score,44,70,7)
  end
 end

 print("z or x to menu",32,100,7)
end

function _update()
 if state=="menu" then update_menu()
 elseif state=="tutorial_mode_select" then update_tutorial_mode_select()
 elseif state=="difficulty_select" then update_difficulty_select()
 elseif state=="tutorial_intro" then update_tutorial_intro()
 elseif state=="tutorial_dash" then update_tutorial_dash()
 elseif state=="tutorial_shield" then update_tutorial_shield()
 elseif state=="play" then update_play()
 elseif state=="gameover" then update_gameover()
 end
 if state~="play" then frames+=1 end
end

function _draw()
 if state=="menu" then draw_menu()
 elseif state=="tutorial_mode_select" then draw_tutorial_mode_select()
 elseif state=="difficulty_select" then draw_difficulty_select()
 elseif state=="tutorial_intro" then draw_tutorial_intro()
 elseif state=="tutorial_dash" then draw_tutorial_dash()
 elseif state=="tutorial_shield" then draw_tutorial_shield()
 elseif state=="play" then draw_play()
 elseif state=="gameover" then draw_gameover()
 end
end

function collide(a,b)
 return a.x<b.x+b.w and
        a.x+a.w>b.x and
        a.y<b.y+b.h and
        a.y+a.h>b.y
end

__gfx__
00bbbb0000888800000cccc0000999900a0a00a0022222222003303000099900099909990099099a9a0a0aa0a0aa000aa0000a8a800a8a80000000000000000
0b7777b0088888800ceeeec009999990aaaa0aa020000002003333330099900099909990099a99aa9a9a0a9a0a0aaa00aaa0a8888aa8888a0000000000000000
0b7ff7b008ff888000ceeeec099999999a0aa0a920000002033333333099aa00099a99a099a9aa9a99a9a09a909aaaa00aaaa8a8aa88a8aa80000000000000000
0b7777b0088888800ceeeec099999999aa0aa0aa20202020033333330099aa00099a99a099aaa9aa99a099a9aa0aaa00aaa0a8a88a8a8a8a0000000000000000
00777700088888800ceeeec099999999a0a00a0a20202020033333330099aa00099099a0099a99aa9a009a0a90aaa00aaa0a8a88a8a8a8a0000000000000000
00777700008888000ceeeec009999990aaaa0aa020000002033333333099900099909900099909a9a00a0aa0a0aaaa00aaaa0a8888aa8888a0000000000000000
07700770088008800000cccc00999900a0a00a0022222222003333330099900099909900099999a9a0a0aa0a0aa000aa0000a8a800a8a80000000000000000
00700700008008000000000000000000a0a00a0000000000003303000000000000000000000000000000000000000000000000000000000000000000000000000000
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
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa111111111111
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
__music__
000 40000000
001 40000000

__sfx__
001004,255,000,000,3003,3003,3003,3003,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000
001004,255,000,000,1001,1001,1001,1001,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000
001004,255,000,000,4004,5005,6006,7007,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000
001004,255,000,000,6006,6006,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000
001004,255,000,000,2020,3030,4040,3030,2020,1010,2020,3030,4040,3030,2020,1010,2020,3030,4040,3030,2020,1010,2020,3030,0000,0000,0000,0000,0000,0000,0000,0000
001004,255,000,000,7007,6006,5005,4004,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000
001004,255,000,000,5005,6006,7007,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000
