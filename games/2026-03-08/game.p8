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
paused=false  -- pause flag for play state
pause_debounce=0  -- independent debounce counter for pause toggle
game_mode="adventure"  -- "adventure" or "endless"
difficulty="normal"
difficulty_cursor=2
mode_cursor=1  -- 1=adventure, 2=endless, 3=tutorial
score=0

-- tutorial mode variables
tutorial_frames=0
tutorial_dash_count=0
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
boss_max_health=0
boss_hit_frame=-1000
boss_invuln_frames=30  -- 0.5 seconds visual feedback
boss_phase=1  -- 1, 2, or 3 based on health
boss_phase_change_frame=-1000
boss_dash_charging=false  -- is boss in dash charge state
boss_dash_charge_frame=-1000  -- when dash started
boss_dash_target_x=0  -- target x position for dash
boss_flash_warning=false  -- flash yellow warning before dash
boss_warning_frame=-1000  -- when warning started
boss_minion_spawn_frame=-1000  -- when last minion spawned
boss_minion_spawn_interval=600  -- spawn minion every 10 seconds in phase 2+
boss_active_minions=0  -- track active boss minions

-- difficulty ramp-up: ease in enemies during first 30s (1800 frames)
difficulty_ramp_duration=1800

-- audio state tracking
last_move_frame=-10
last_hit_frame=-10
last_dash_avoid_frame=-100  -- debounce dash-avoid sound
last_near_miss_frame=-100  -- debounce near-miss sound
last_difficulty_change_frame=-1000  -- debounce difficulty transition sound
last_wave_escalation_frame=-1000  -- debounce wave escalation sound
dash_hit_shield_frame=-100  -- track when dash prevented damage
dash_shake_intensity=0  -- screen shake intensity on dash hits

-- dash mechanics
dash_cooldown=30  -- 0.5 seconds at 60fps
last_dash_frame=-100
dash_invuln_frames=12  -- increased from 10 for better protection feel
dash_invuln_start=-100
dash_speed_mult=2.5
dash_streak=0  -- consecutive dashes without damage
dash_flash_frames=0  -- screen flash effect duration
dash_near_miss=false  -- did this dash avoid an enemy?

-- discovery cues: track ready state for audio feedback
dash_ready_last_frame=-1000
player_used_dash=false
level_2_dash_reminder=false
damage_prompt_frame=-1000  -- when player took damage to show prompt
first_hit_shown=false  -- track if we've shown first hit prompt
first_enemy_shown=false  -- track if we've shown first enemy encounter prompt

-- adaptive difficulty tracking
hit_times={}  -- sliding window of last hit frames
last_difficulty_check=0
adaptive_speed_mult=1.0
adaptive_spawn_mult=1.0

-- passive playstyle detection
is_passive_player=false
dash_count_first_5s=0
passive_check_done=false

-- animation system
anim_frame=0  -- 0-2, cycles at ~6fps (every 10 frames at 60fps)
anim_counter=0  -- frame counter for animation cycling

function update_anim()
 anim_counter=(anim_counter+1)%30  -- cycle every 30 frames (2 fps)
 anim_frame=flr(anim_counter/10)  -- gives 0,1,2,1,2,0... pattern
end

function get_player_sprite()
 -- sprite 0 is standing, 3-5 are animation frames
 if not player.alive then return 0 end
 local recent_move=frames-last_move_frame<15
 if recent_move then
  return 3+anim_frame  -- cycle through sprites 3, 4, 5
 end
 return 0  -- idle sprite
end

function get_enemy_sprite(e)
 -- sprite 1 is base, 6-7 are animation frames
 return 6+anim_frame%2  -- cycle between 6 and 7
end

function get_portal_sprite()
 -- sprite 2 is base, 8-9 are animation frames (pulsing glow)
 return 8+anim_frame%2  -- cycle between 8 and 9
end

function init_level()
 enemies={}
 level_start_frame=frames
 level_score=0
 boss=nil
 boss_health=0
 boss_max_health=0
 boss_hit_frame=-1000
 boss_phase=1
 boss_phase_change_frame=-1000
 boss_dash_charging=false
 boss_dash_charge_frame=-1000
 boss_flash_warning=false
 boss_warning_frame=-1000
 boss_minion_spawn_frame=-1000
 boss_active_minions=0

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
 first_enemy_shown=false

 -- reset damage prompt for new level
 damage_prompt_frame=-1000
 if level==1 then first_hit_shown=false end

 -- reset dash streak
 dash_streak=0

 -- reset pause state for new level
 paused=false

 -- reset sound debouncing for new level
 last_dash_avoid_frame=-100
 last_near_miss_frame=-100

 -- start background music
 music(0)

 -- difficulty modifiers
 -- target completion rates: easy 80%+, normal 60-65%, hard 35-40%
 -- strategy: easy has slowest enemies + most health for accessibility
 --           normal baseline with boosted health for 60-65% target
 --           hard increased speed + reduced health for 35-40% challenge
 local speed_mult=1.0  -- normal mode baseline
 local health_val=4    -- +1 health vs original 3 to boost normal completion to 60-65%
 if difficulty=="easy" then
  speed_mult=0.35  -- 35% speed: very forgiving, accessible for all skill levels
  health_val=5     -- +2 health vs normal, gives large margin for error
 elseif difficulty=="hard" then
  speed_mult=1.35  -- 135% speed: fast enemies, tight spacing, expert challenge
  health_val=2     -- -2 health vs normal, punishes careless play but not instant-death
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
    passive_speed_mult=0.75  -- 25% speed reduction for passive players (improved from 20%)
    _log("difficulty:passive_level1_adjust_25pct")
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
    passive_speed_mult=0.75  -- 25% speed reduction for passive players (improved from 20%)
    _log("difficulty:passive_level2_adjust_25pct")
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
  local boss_minion_spawn_interval_val=600
  if difficulty=="hard" then
   boss_speed=0.8  -- slightly faster than normal
   boss_health_val=5  -- more health than normal (harder to defeat)
   boss_minion_spawn_interval_val=450  -- spawn minions more frequently on hard
  elseif difficulty=="easy" then
   boss_speed=0.6  -- slower than normal
   boss_health_val=2  -- less health on easy (more accessible)
   boss_minion_spawn_interval_val=800  -- spawn minions less frequently on easy
  end

  boss={x=64,y=25,w=12,h=12,speed=boss_speed,dir=1,health=boss_health_val}
  boss_health=boss_health_val
  boss_max_health=boss_health_val
  boss_phase=1
  boss_phase_change_frame=frames
  boss_dash_charging=false
  boss_minion_spawn_frame=frames+300  -- first minion spawn at 5 seconds
  boss_minion_spawn_interval=boss_minion_spawn_interval_val
  boss_active_minions=0
  _log("boss_encounter")

  -- level 3: 3-5 enemies initially, 5-10% faster than level 2
  -- reduced to 2 for passive players to improve completion rate
  if level_start_frame>0 then
   local passive_speed_mult=1.0
   if is_passive_player then
    passive_speed_mult=0.75  -- 25% speed reduction for passive players (increased from 20%)
    _log("difficulty:passive_level3_adjust_25pct_2enemies")
   end
   -- base speed 0.95 is ~5% faster than level 2's 0.9
   add(enemies,{x=40,y=30,w=8,h=8,speed=0.95*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=1})
   add(enemies,{x=90,y=50,w=8,h=8,speed=0.95*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=-1})
   -- 3rd enemy: only add if not passive (passive gets 2, non-passive gets 5)
   if not is_passive_player then
    add(enemies,{x=30,y=80,w=8,h=8,speed=0.95*speed_mult*adaptive_speed_mult,dir=1})
   end
   -- 4th enemy: only add if not passive
   if not is_passive_player then
    add(enemies,{x=100,y=100,w=8,h=8,speed=0.95*speed_mult*adaptive_speed_mult,dir=-1})
   end
   -- 5th enemy only if not passive
   if not is_passive_player then
    add(enemies,{x=60,y=60,w=8,h=8,speed=0.95*speed_mult*adaptive_speed_mult,dir=1})
   end
  end
  _log("level_3_start")

 elseif level==4 then
  player.x=12
  player.y=100

  -- level 4: dash tutorial - tight corridors require dashing
  -- design: enemies in strategic positions creating gaps to navigate
  if level_start_frame>0 then
   local passive_speed_mult=1.0
   if is_passive_player then
    passive_speed_mult=0.75
    _log("difficulty:passive_level4_adjust")
   end
   -- create tight corridor pattern: enemies at y=40, y=80, y=120 (vertical lanes)
   -- only center lane passable without dash
   add(enemies,{x=50,y=30,w=8,h=8,speed=0.85*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=1})
   add(enemies,{x=100,y=90,w=8,h=8,speed=0.85*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=-1})
   add(enemies,{x=40,y=60,w=8,h=8,speed=0.85*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=1})
  end
  _log("level_4_start:dash_tutorial")

 elseif level==5 then
  player.x=12
  player.y=100

  -- level 5: expert dash challenge - rapid enemy sequences
  if level_start_frame>0 then
   local passive_speed_mult=1.0
   if is_passive_player then
    passive_speed_mult=0.75
    _log("difficulty:passive_level5_adjust")
   end
   -- spawn 5 enemies in aggressive pattern
   add(enemies,{x=35,y=20,w=8,h=8,speed=1.0*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=1})
   add(enemies,{x=95,y=40,w=8,h=8,speed=1.0*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=-1})
   add(enemies,{x=45,y=70,w=8,h=8,speed=1.0*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=1})
   add(enemies,{x=85,y=100,w=8,h=8,speed=1.0*speed_mult*adaptive_speed_mult,dir=-1})
   add(enemies,{x=60,y=50,w=8,h=8,speed=1.0*speed_mult*adaptive_speed_mult,dir=1})
  end
  _log("level_5_start:expert_challenge")
 end
end

function init_endless_level()
 enemies={}
 level_start_frame=frames
 level_score=0

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
 -- adaptive difficulty system helps players find their skill level
 -- enables smoother learning curve in easy and normal modes
 -- disabled in hard mode to maintain consistent challenge
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
  -- reduce enemy speed by 17% (balanced between 15% and 20%)
  adaptive_speed_mult=max(0.55,adaptive_speed_mult*0.83)
  -- increase spawn delays by 22% (balanced improvement)
  adaptive_spawn_mult=min(1.0,adaptive_spawn_mult*0.78)
  _log("difficulty:down")

 -- thriving: no hits in last 30 seconds AND game is long enough
 elseif recent_30s_hits==0 and frames-level_start_frame>1800 then
  -- increase enemy speed by 6% (balanced between 5% and 7%)
  adaptive_speed_mult=min(1.5,adaptive_speed_mult*1.06)
  -- increase spawn frequency by 2.5% (slight increase from 2%)
  adaptive_spawn_mult=min(1.5,adaptive_spawn_mult*1.025)
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
   state="endless_difficulty_select"
   difficulty_cursor=2
   _log("state:endless_difficulty_select")
  else
   state="tutorial_intro"
   tutorial_frames=0
   tutorial_dash_count=0
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
   sfx(9)  -- easy mode: gentle ascending tone
  elseif difficulty_cursor==2 then
   difficulty="normal"
   sfx(7)  -- normal mode: neutral beep
  elseif difficulty_cursor==3 then
   difficulty="hard"
   sfx(8)  -- hard mode: ominous descending progression
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

function update_endless_difficulty_select()
 if test_input(2)>0 then
  difficulty_cursor=max(1,difficulty_cursor-1)
 end
 if test_input(3)>0 then
  difficulty_cursor=min(3,difficulty_cursor+1)
 end

 if test_input(4)>0 or test_input(5)>0 then
  if difficulty_cursor==1 then
   difficulty="easy"
   sfx(9)  -- easy mode: gentle ascending tone
  elseif difficulty_cursor==2 then
   difficulty="normal"
   sfx(7)  -- normal mode: neutral beep
  elseif difficulty_cursor==3 then
   difficulty="hard"
   sfx(8)  -- hard mode: ominous descending progression
  end
  is_endless=true
  state="play"
  score=0
  level=1
  wave=1
  init_endless_level()
  _log("state:play")
  _log("endless:difficulty:"..difficulty)
 end
end

function draw_menu()
 cls(1)
 print("cave escape",36,15,7)
 print("adventure: 5 cave levels",16,28,7)
 print("endless: infinite waves",20,40,11)
 print("dash to dodge (x)",24,52,11)
 print("survive + score points",16,64,7)
 print("arrow keys move",28,80,11)
 print("x button dash!",32,90,11)
 print("z or x to start",32,110,11)
end

function draw_tutorial_mode_select()
 cls(1)
 print("select game mode",28,20,7)

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

 print("adventure",40,45,col1)
 print("5 escalating levels",20,54,7)
 print("endless",44,65,col2)
 print("infinite waves",28,74,7)
 print("tutorial",44,85,col3)
 print("learn dash mechanic",20,94,7)

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

function draw_endless_difficulty_select()
 cls(1)
 print("endless mode",40,15,11)
 print("difficulty",44,25,7)

 local colors={8,7,11}
 local y_positions={50,70,90}
 local labels={"easy","normal","hard"}
 local desc={"45s between waves","30s between waves","21s between waves"}

 for i=1,3 do
  local col=colors[i]
  if i==difficulty_cursor then
   col=11
  end
  print(labels[i],56,y_positions[i],col)
  print(desc[i],48,y_positions[i]+8,7)
 end

 print("up/down select",32,110,7)
 print("z/x confirm",36,118,7)
end

-- tutorial functions
function update_tutorial_intro()
 tutorial_frames+=1
 if tutorial_frames>120 then  -- 2 seconds at 60fps
  state="tutorial_dash"
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
   state="menu"
   tutorial_frames=0
   _log("tutorial_complete")
  end
 end

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
 spr(get_player_sprite(),player.x-4,player.y-4)

 -- flash player if recently dashed
 if frames-last_dash_frame<dash_invuln_frames then
  spr(2,player.x-4,player.y-4)
 end

 print("z to skip",40,115,8)
end

function update_play()
 if not player.alive then return end

 -- handle pause toggle (O button index 4 to pause, O or X to resume)
 -- use separate debounce counter that increments even while paused
 pause_debounce+=1
 local o_pressed=test_input(4)>0
 local x_pressed=test_input(5)>0
 if (o_pressed or (paused and x_pressed)) and pause_debounce>20 then
  paused=not paused
  pause_debounce=0
  if paused then
   _log("pause")
   music(-1)  -- stop music
  else
   _log("resume")
   music(0)  -- resume music
  end
 end

 -- if paused, skip game logic updates and stop frame progression
 if paused then return end

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

  -- increment dash streak
  dash_streak+=1

  -- visual feedback: screen flash
  dash_flash_frames=3

  -- award points for dash action
  level_score+=5

  -- play dash sound with escalating pitch based on streak
  local dash_pitch=3+flr(dash_streak*0.2)
  sfx(3,0,dash_pitch%8)
  _log("dash:"..dash_streak)

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


 player.x+=dx
 player.y+=dy

 player.x=max(2,min(player.x,126))
 player.y=max(2,min(player.y,126))

 if is_endless then
  -- endless mode: wave-based spawning (difficulty-adjusted)
  -- difficulty modifiers: easy=slower, normal=balanced, hard=faster
  local wave_elapsed=frames-wave_start_frame
  local base_interval=1800  -- 30 seconds base
  local interval_mult=1.0
  local speed_mult=1.0
  local enemy_mult=1.0

  if difficulty=="easy" then
   interval_mult=1.5  -- 45s between waves
   speed_mult=0.6
   enemy_mult=0.8
  elseif difficulty=="hard" then
   interval_mult=0.7  -- 21s between waves
   speed_mult=1.3
   enemy_mult=1.2
  end

  local spawn_interval=flr(base_interval*interval_mult/adaptive_spawn_mult)
  if wave_elapsed>=spawn_interval then  -- adaptive spawn interval
   wave+=1
   wave_start_frame=frames

   -- progressive difficulty: start at 3, increase by 1-2 per wave, cap at difficulty-dependent max
   local max_enemies=10
   if difficulty=="easy" then max_enemies=7
   elseif difficulty=="hard" then max_enemies=12 end

   local enemy_count
   if wave<=2 then
    enemy_count=flr((2+wave)*enemy_mult+0.5)  -- Scaled by difficulty: easy 0.8x, normal 1.0x, hard 1.2x. Wave 1: easy 2, normal 3, hard 4
   else
    enemy_count=min(flr((4+flr((wave-2)/2))*enemy_mult+0.5),max_enemies)
   end

   -- award points: 30 per enemy + 100 for wave survival (scaled by difficulty)
   local difficulty_multiplier=1.0
   if difficulty=="easy" then difficulty_multiplier=0.7
   elseif difficulty=="hard" then difficulty_multiplier=1.5 end
   score+=flr(enemy_count*30*difficulty_multiplier+100*difficulty_multiplier)

   for j=1,enemy_count do
    local spawn_y=20+flr(rnd(80))
    local spawn_x=10+flr(rnd(100))
    local speed_base=(0.6+wave*0.05)*speed_mult
    local passive_speed_mult=1.0
    if is_passive_player then passive_speed_mult=0.75 end
    local dir=1
    if j%2==0 then dir=-1 end
    add(enemies,{x=spawn_x,y=spawn_y,w=8,h=8,speed=speed_base*adaptive_speed_mult*passive_speed_mult,dir=dir})
   end

   -- audio feedback for wave escalation
   if frames-last_wave_escalation_frame>60 then
    if difficulty=="hard" then
     -- hard mode escalation: ominous 4-note progression
     sfx(8,0,flr(wave/3)%7)
     last_difficulty_change_frame=frames
    else
     -- normal/easy mode escalation: ascending pair for buildup
     sfx(9,0,flr(wave/2)%6)
    end
    last_wave_escalation_frame=frames
   end
   _log("wave:"..wave.." enemies:"..enemy_count)
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
    if is_passive_player then passive_speed_mult=0.75 end
    add(enemies,{x=30,y=70,w=8,h=8,speed=0.6*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=1})
    _log("enemy_spawn_ramp:passive_25pct")
   elseif level==2 then
    local passive_speed_mult=1.0
    if is_passive_player then passive_speed_mult=0.75 end
    add(enemies,{x=70,y=80,w=8,h=8,speed=0.9*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=-1})
    _log("enemy_spawn_ramp:passive_25pct")
   elseif level==3 then
    local passive_speed_mult=1.0
    if is_passive_player then passive_speed_mult=0.75 end
    add(enemies,{x=50,y=35,w=8,h=8,speed=0.95*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=1})
    _log("enemy_spawn_ramp:passive_25pct")
   elseif level==4 then
    local passive_speed_mult=1.0
    if is_passive_player then passive_speed_mult=0.75 end
    add(enemies,{x=75,y=25,w=8,h=8,speed=0.85*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=-1})
    _log("enemy_spawn_ramp:level4")
   elseif level==5 then
    local passive_speed_mult=1.0
    if is_passive_player then passive_speed_mult=0.75 end
    add(enemies,{x=30,y=120,w=8,h=8,speed=1.0*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=1})
    _log("enemy_spawn_ramp:level5")
   end
  elseif elapsed==flr(1200*spawn_delay_mult)+passive_spawn_delay then  -- 20 seconds (adaptive)
   if level==1 then
    local passive_speed_mult=1.0
    if is_passive_player then passive_speed_mult=0.75 end
    add(enemies,{x=80,y=90,w=8,h=8,speed=0.6*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=-1})
    _log("enemy_spawn_ramp:passive_25pct")
   elseif level==2 then
    local passive_speed_mult=1.0
    if is_passive_player then passive_speed_mult=0.75 end
    add(enemies,{x=40,y=110,w=8,h=8,speed=0.9*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=1})
    _log("enemy_spawn_ramp:passive_25pct")
   elseif level==3 then
    local passive_speed_mult=1.0
    if is_passive_player then passive_speed_mult=0.75 end
    -- level 3: ramp to 6-7 enemies by 20 seconds
    add(enemies,{x=80,y=110,w=8,h=8,speed=0.98*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=-1})
    add(enemies,{x=20,y=50,w=8,h=8,speed=0.98*speed_mult*adaptive_speed_mult,dir=1})
    _log("enemy_spawn_ramp:passive_25pct")
   elseif level==4 then
    local passive_speed_mult=1.0
    if is_passive_player then passive_speed_mult=0.75 end
    add(enemies,{x=60,y=95,w=8,h=8,speed=0.85*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=1})
    _log("enemy_spawn_ramp:level4")
   elseif level==5 then
    local passive_speed_mult=1.0
    if is_passive_player then passive_speed_mult=0.75 end
    add(enemies,{x=90,y=80,w=8,h=8,speed=1.0*speed_mult*passive_speed_mult*adaptive_speed_mult,dir=-1})
    add(enemies,{x=25,y=110,w=8,h=8,speed=1.0*speed_mult*adaptive_speed_mult,dir=1})
    _log("enemy_spawn_ramp:level5")
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
   elseif level==4 then
    add(enemies,{x=70,y=50,w=8,h=8,speed=0.85*speed_mult,dir=-1})
    _log("enemy_spawn_ramp")
   elseif level==5 then
    add(enemies,{x=50,y=120,w=8,h=8,speed=1.0*speed_mult,dir=-1})
    _log("enemy_spawn_ramp")
   end
  end

  -- calculate time bonus: 10 points per second survived, max 300 per level
  local level_elapsed=(frames-level_start_frame)/60
  level_score=flr(min(level_elapsed*10,300))
 end


 -- boss update and collision (level 3 only)
 if boss~=nil then
  -- update boss phase based on health
  local health_pct=boss.health/boss_max_health
  local new_phase=1
  if health_pct>0.5 then
   new_phase=1
  elseif health_pct>0.25 then
   new_phase=2
  else
   new_phase=3
  end

  if new_phase~=boss_phase then
   boss_phase=new_phase
   boss_phase_change_frame=frames
   _log("boss_phase:"..new_phase)
   sfx(7)  -- phase transition sound
  end

  -- boss movement and dash attack logic
  if boss_dash_charging then
   local dash_duration=60  -- 1 second dash
   local elapsed=frames-boss_dash_charge_frame
   if elapsed<dash_duration then
    -- accelerate toward target
    local dx_to_target=boss_dash_target_x-boss.x
    boss.x+=sgn(dx_to_target)*2.5  -- fast dash speed
   else
    -- dash ended
    boss_dash_charging=false
    boss_flash_warning=false
   end
  else
   -- normal bouncing movement
   boss.x+=boss.speed*boss.dir
   if boss.x<2 or boss.x>126 then
    boss.dir=-boss.dir
   end

   -- trigger dash attack based on phase
   if boss_phase>=1 and frames>boss_dash_charge_frame+180 then
    -- boss initiates dash charge every 3 seconds
    boss_dash_charging=true
    boss_dash_charge_frame=frames+30  -- 0.5s warning, then dash
    boss_dash_target_x=player.x
    boss_flash_warning=true
    boss_warning_frame=frames
    _log("boss_dash_warning")
   end
  end

  -- show warning flash
  if boss_flash_warning and frames-boss_warning_frame<30 then
   -- visual warning (handled in draw)
  elseif boss_flash_warning then
   boss_flash_warning=false
  end

  -- minion spawning in phase 2+ (limit to max 2 active minions)
  -- note: minions are marked with is_boss_minion=true flag.
  -- when boss is defeated, all minions are explicitly removed from
  -- the enemies array (see boss defeat logic ~line 938-944).
  -- the boss_active_minions counter acts as a spawn rate limiter.
  if boss_phase>=2 and frames>boss_minion_spawn_frame then
   if boss_active_minions<2 then
    local minion_speed=1.1*speed_mult
    local minion_dir=rnd(2)<1 and 1 or -1
    add(enemies,{x=boss.x,y=boss.y,w=8,h=8,speed=minion_speed,dir=minion_dir,is_boss_minion=true})
    boss_active_minions+=1
    boss_minion_spawn_frame=frames+boss_minion_spawn_interval
    _log("boss_minion_spawn")
   end
  end

  -- boss collision detection
  local is_dash_invuln=frames-dash_invuln_start<dash_invuln_frames

  if collide(player,boss) then
   if not is_dash_invuln then
    -- hit boss
    boss.health-=1
    boss_hit_frame=frames
    _log("boss_hit")
    sfx(5)  -- boss hit sound

    if boss.health<=0 then
     score+=500
     _log("boss_defeated")
     -- victory fanfare
     sfx(6)
     -- clear boss minions
     local new_enemies={}
     for i=1,#enemies do
      if enemies[i].is_boss_minion~=true then
       add(new_enemies,enemies[i])
      end
     end
     enemies=new_enemies
     boss_active_minions=0
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

  -- check collision only if not in invulnerability window (dash)
  local is_dash_invuln=frames-dash_invuln_start<dash_invuln_frames
  if collide(player,e) then
   if not is_dash_invuln then
    -- take damage from enemy
    health-=1
    dash_streak=0  -- reset dash streak on damage
    -- track hit for adaptive difficulty
    add(hit_times,frames)
    -- show damage prompt on first hit in level 1
    if level==1 and not first_hit_shown then
     damage_prompt_frame=frames
     first_hit_shown=true
     _log("first_hit_damage_prompt")
    end
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
   elseif is_dash_invuln then
    -- near-miss: dash avoided enemy
    if frames-last_dash_avoid_frame>10 then
     sfx(6)  -- success tone
     last_dash_avoid_frame=frames
     -- track dash hit shield for visual feedback
     dash_hit_shield_frame=frames
     dash_shake_intensity=2  -- screen shake on successful dodge
    end
    level_score+=10*(1+flr(dash_streak*0.1))  -- streak bonus
    _log("dash_avoid:"..dash_streak)
   end
  elseif is_dash_invuln then
   -- check for near-miss (enemy close to player)
   local dx_dist=abs(e.x-player.x)
   local dy_dist=abs(e.y-player.y)
   if dx_dist<14 and dy_dist<14 then
    if frames-last_near_miss_frame>10 then
     sfx(4)  -- near-miss feedback
     last_near_miss_frame=frames
    end
   end
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

  if level>4 then
   _log("level_5_complete")
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

 -- screen shake on dash hit shield
 local shake_x=0
 local shake_y=0
 if dash_shake_intensity>0 then
  shake_x=flr((frames%3-1)*dash_shake_intensity)
  shake_y=flr(((frames+1)%3-1)*dash_shake_intensity)
  dash_shake_intensity=max(0,dash_shake_intensity-0.5)
 end
 camera(shake_x,shake_y)

 -- screen flash effect on dash
 if dash_flash_frames>0 then
  rectfill(0,0,128,128,14)  -- bright yellow flash
 end

 for x=0,128,8 do
  for y=0,128,8 do
   if (x+y)%16==0 then
    rectfill(x,y,x+7,y+7,5)
   end
  end
 end

 if player.alive then
  -- change color during dash invulnerability
  local is_dash_invuln=frames-dash_invuln_start<dash_invuln_frames

  if is_dash_invuln then
   pal(11,7)  -- dash: change to white
  end

  spr(get_player_sprite(),player.x-4,player.y-4)
  pal()
 end

 -- draw boss with visual feedback on hit
 if boss~=nil then
  -- flash on hit (0.5s visual feedback)
  -- phase-based color: phase 1=red, phase 2=orange, phase 3=yellow
  local boss_draw_color=8  -- phase 1: darker red
  if boss_phase==2 then
   boss_draw_color=9  -- phase 2: orange
  elseif boss_phase==3 then
   boss_draw_color=10  -- phase 3: yellow
  end

  -- flash warning before dash
  if boss_flash_warning then
   if frames%10<5 then  -- blink warning
    boss_draw_color=10  -- yellow flash
   end
  end

  -- white flash on hit
  if frames-boss_hit_frame<boss_invuln_frames then
   boss_draw_color=15  -- white flash on hit
  end

  -- visual effect for dash attack
  if boss_dash_charging and frames>boss_dash_charge_frame then
   -- draw dash motion trail (5 frames)
   if frames%3==0 then
    rectfill(boss.x-2,boss.y-2,boss.x+2,boss.y+2,boss_draw_color)
   end
  end

  -- draw boss as larger sprite with outline
  rectfill(boss.x-6,boss.y-6,boss.x+6,boss.y+6,boss_draw_color)
  rect(boss.x-6,boss.y-6,boss.x+6,boss.y+6,15)  -- white outline

  -- draw enemy sprite (1) in center
  pal(8,boss_draw_color)
  spr(get_enemy_sprite(boss),boss.x-4,boss.y-4)
  pal()
 end

 for i=1,#enemies do
  local e=enemies[i]
  spr(get_enemy_sprite(e),e.x-4,e.y-4)
 end

 if not is_endless then
  spr(get_portal_sprite(),exit_portal.x-4,exit_portal.y-4)
 end

 -- draw mechanic ready indicators at top right
 local dash_ready=frames-last_dash_frame>=dash_cooldown

 -- dash indicator (X button) - always visible HUD
 local dash_color=5  -- red when on cooldown
 if dash_ready then dash_color=11 end  -- cyan when ready
 print("x:",100,1,7)  -- label
 rectfill(110,1,121,9,dash_color)
 if dash_ready then
  print("x",113,2,0)  -- show "x" in black when ready
 end

 if is_endless then
  -- endless mode display
  local survival_time=flr((frames-level_start_frame)/60)
  local diff_col=7
  if difficulty=="easy" then diff_col=3
  elseif difficulty=="hard" then diff_col=8 end
  print("sc "..score,2,2,7)
  print("wave "..wave,40,2,7)
  print(difficulty,68,2,diff_col)
  print("time "..survival_time.."s",75,12,7)
  print("hp "..max(0,health),2,12,7)
  print("best:"..best_endless_score,40,12,11)
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

  -- show tutorial reminders for unused mechanics
  local elapsed=frames-level_start_frame

  -- first enemy encounter prompt (level 1)
  if level==1 and #enemies>0 and not player_used_dash and not first_enemy_shown then
   print("enemy! press x to dash",18,115,10)  -- first enemy prompt
   first_enemy_shown=true
   sfx(7)  -- play dash-ready sound to draw attention
   _log("first_enemy_prompt")
  end

  if level==2 and not player_used_dash and elapsed>600 and not level_2_dash_reminder then
   print("try x!",58,120,11)  -- prompt for dash
   level_2_dash_reminder=true
  end

  -- level 4: dash tutorial prompt
  if level==4 and elapsed<180 then
   print("dash through tight spots!",20,115,11)
  end

  -- level 5: expert challenge prompt
  if level==5 and elapsed<180 then
   print("master rapid dashes!",28,115,10)
  end

  -- dash streak counter and early game prompt
  if dash_streak>0 then
   print("dash x"..dash_streak,2,22,11)  -- show dash streak
  end
  if elapsed<450 and not player_used_dash and not first_enemy_shown then
   print("x:dash!",48,115,10)  -- early game prompt (extended to 7.5s)
  end

  -- damage prompt: show for 2 seconds (120 frames) after taking first hit
  if frames-damage_prompt_frame<120 then
   local prompt_color=8  -- red for urgency
   -- large centered message
   rectfill(20,50,108,70,1)  -- background
   rect(20,50,108,70,8)  -- red border
   print("press x to dodge!",26,57,prompt_color)
  end

  -- dash feedback: show "DASH!" briefly when player dashes
  local is_dash_invuln=frames-dash_invuln_start<dash_invuln_frames
  if is_dash_invuln and frames-last_dash_frame<6 then
   print("dash!",54,50,11)  -- cyan feedback text
   _log("dash_feedback")
  end

  print("find exit (top right)",10,120,14)
 end

 -- draw pause ui
 if paused then
  -- semi-transparent overlay
  rectfill(0,0,128,128,0)
  for i=0,128,2 do
   for j=0,128,2 do
    pset(i,j,1)
   end
  end

  -- pause dialog box
  rectfill(32,45,96,83,1)
  rect(32,45,96,83,15)

  -- paused text
  print("paused",48,52,15)

  -- resume instructions
  print("o or x to resume",35,66,7)
 end

 -- reset camera after screen shake
 camera(0,0)
end

function update_gameover()
 -- stop background music when game ends
 music(-1)
 if test_input(4)>0 or test_input(5)>0 then
  state="menu"
  _log("state:menu")
 end
end

function draw_gameover()
 cls(0)

 if is_endless then
  -- endless mode gameover
  print("endless mode",40,15,11)
  local diff_col=7
  if difficulty=="easy" then diff_col=3
  elseif difficulty=="hard" then diff_col=8 end
  print(difficulty.." difficulty",32,25,diff_col)

  print("waves survived:"..wave,28,40,11)
  local survival_time=flr((frames-level_start_frame)/60)
  print("survival:"..survival_time.."s",36,50,7)
  print("score:"..score,48,60,7)
  if score>best_endless_score then
   best_endless_score=score
   print("new record!",44,70,11)
   _log("endless_new_record:"..score)
  else
   print("best:"..best_endless_score,44,70,7)
  end
 else
  -- standard mode gameover
  local final_score=score
  if level>4 then
   final_score+=level_score+500
   print("victory!",44,20,11)
   print("escaped all five",28,35,11)
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
 -- global state updates
 update_anim()  -- update animation frame every frame
 if dash_flash_frames>0 then dash_flash_frames-=1 end

 if state=="menu" then update_menu()
 elseif state=="tutorial_mode_select" then update_tutorial_mode_select()
 elseif state=="difficulty_select" then update_difficulty_select()
 elseif state=="endless_difficulty_select" then update_endless_difficulty_select()
 elseif state=="tutorial_intro" then update_tutorial_intro()
 elseif state=="tutorial_dash" then update_tutorial_dash()
 elseif state=="play" then update_play()
 elseif state=="gameover" then update_gameover()
 end
 if state~="play" then frames+=1 end
end

function _draw()
 if state=="menu" then draw_menu()
 elseif state=="tutorial_mode_select" then draw_tutorial_mode_select()
 elseif state=="difficulty_select" then draw_difficulty_select()
 elseif state=="endless_difficulty_select" then draw_endless_difficulty_select()
 elseif state=="tutorial_intro" then draw_tutorial_intro()
 elseif state=="tutorial_dash" then draw_tutorial_dash()
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
00bbbb0000888800000cccc000bbbb0000bbbb0000bbbb000088880000888800000cccc0000ccccc000000000000000000000000000000000000000000000000000
0b7777b0088888800ceeeec00b7777b00b7777b00b7777b008888880088888800ceeeec00ceeeecc000000000000000000000000000000000000000000000000000
0b7ff7b008ff888000ceeeec0b7ff7b00b7ff7b00b7ff7b008ff888008ff888000ceeeec00ceeeecc000000000000000000000000000000000000000000000000000
0b7777b0088888800ceeeec00b7777b00b7777b00b7777b008888880088888800ceeeec00ceeeecc000000000000000000000000000000000000000000000000000
00777700088888800ceeeec000777700007777000077770008888880088888800ceeeec00ceeeecc000000000000000000000000000000000000000000000000000
00777700008888000ceeeec000777700007777000077770000888800008888000ceeeec00ceeeecc000000000000000000000000000000000000000000000000000
07700770088008800000cccc07700770077007700770077008800880088008800000cccc0000ccccc000000000000000000000000000000000000000000000000000
00700700008008000000000000700700007007000070070000800800008008000000000000000000c000000000000000000000000000000000000000000000000000
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
001004,255,000,000,2002,3003,4004,5005,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000
001004,255,000,000,5005,5005,6006,6006,7007,7007,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000,0000

