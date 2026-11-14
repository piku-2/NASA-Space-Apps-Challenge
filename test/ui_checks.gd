extends SceneTree
var game: Control
func _initialize() -> void:
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 run_checks.call_deferred()
func run_checks() -> void:
 await process_frame
 await process_frame
 game.state=game.Sim.initial()
 game.selected=1
 game.modal=""
 game.at_title=false
 game.build_kind=""
 game.crew_source=-2
 game.refresh()
 await process_frame
 # Real pointer events verify that transparent crew targets and palette buttons receive clicks.
 pointer_click(Vector2(200,661))
 await process_frame
 assert(game.crew_source==-1)
 pointer_click(Vector2(650,220))
 await process_frame
 assert(int(game.state.cells[4].crew)==1)
 pointer_click(Vector2(721,271))
 await process_frame
 assert(game.crew_source==4)
 pointer_click(Vector2(240,350))
 await process_frame
 assert(int(game.state.cells[4].crew)==0 and int(game.state.cells[7].crew)==1)
 pointer_click(Vector2(981,431))
 await process_frame
 assert(game.build_kind=="solar")
 pointer_click(Vector2(390,220))
 await process_frame
 assert(game.state.cells[2].kind=="solar" and game.modal=="")
 game.state=game.Sim.initial()
 game.build_kind=""
 game.selected=4
 game.choose_crew(-1)
 game.select_cell(4)
 assert(int(game.state.cells[4].crew)==1)
 assert(game.crew_source==-2)
 game.choose_crew(4)
 game.select_cell(7)
 assert(int(game.state.cells[4].crew)==0 and int(game.state.cells[7].crew)==1)
 assert(game.Sim.idle(game.state)==3)
 game.choose_crew(-1)
 game.select_cell(7)
 game.choose_crew(1)
 game.select_cell(7)
 assert(int(game.state.cells[1].crew)==1 and int(game.state.cells[7].crew)==2)
 assert(game.crew_source==1)
 game.select_cell(2)
 assert(game.state.cells[2].kind=="" and game.modal=="")
 game.choose_build("mine")
 assert(game.crew_source==-2)
 game.select_cell(2)
 assert(game.state.cells[2].kind=="mine")
 assert(int(game.state.material)==8)
 game.build("shield")
 assert(game.state.cells[2].kind=="mine" and int(game.state.material)==8)
 game.assign(1)
 assert(int(game.state.cells[2].crew)>=1 and game.selected==2)
 assert(int(game.state.material)>=int(game.Sim.R.upgrade))
 pointer_click(Vector2(790,745))
 await process_frame
 assert(int(game.state.cells[2].level)==2 and int(game.state.material)==5)
 game.set_language("en")
 assert(game.trk("title")=="Mars Outpost")
 assert(game.trk("survival")=="Survival")
 game.set_language("ja")
 # Every localized glyph must be bundled, without OS font fallback.
 assert(game.font is FontFile)
 for lang: String in ["ja", "en"]:
  game.set_language(lang)
  for value: String in game.words.values():
   for index: int in range(value.length()):
    var code: int = value.unicode_at(index)
    if code > 32:
     assert(game.font.has_char(code), "Missing glyph: " + value[index])
 game.set_language("ja")
 game.save_game()
 var original: Dictionary=game.state.duplicate(true)
 game.state=game.Sim.initial()
 game.load_game()
 assert(game.state==original)
 var before: Dictionary=game.state.duplicate(true)
 game.advance_phase()
 assert(str(game.state.phase)=="day")
 assert(int(game.state.survival)==int(before.survival) and int(game.state.science)==int(before.science))
 var preview: Dictionary=game.Sim.calculate(before)
 game.advance_phase()
 assert(str(game.state.phase)=="night")
 assert(int(game.state.survival)==int(preview.survival) and int(game.state.day)==int(preview.day))
 assert(int(game.state.power)==int(preview.power) and int(game.state.science)==int(preview.science))
 var night: Dictionary=game.state.duplicate(true)
 game.advance_phase()
 assert(str(game.state.phase)=="morning")
 assert(int(game.state.survival)==int(night.survival) and int(game.state.day)==int(night.day))
 game.state.phase="day"
 var locked: Dictionary=game.state.duplicate(true)
 game.choose_build("solar")
 game.upgrade()
 game.toggle_shelter()
 game.choose_crew(-1)
 game.select_cell(5)
 game.assign(1)
 game.choose_cover(true)
 assert(int(game.state.material)==int(locked.material))
 assert(not bool(game.state.get("flare_cover", false)))
 assert(int(game.state.cells[5].crew)==int(locked.cells[5].crew))
 assert(bool(game.state.shelter)==bool(locked.shelter))
 game.state.phase="morning"
 # Existing saves migrate into one survival resource without losing the base.
 var legacy: Dictionary=game.Sim.initial()
 legacy.erase("survival")
 legacy.erase("roster")
 legacy.erase("phase")
 legacy.erase("discoveries")
 legacy.erase("report")
 legacy.water=12;legacy.food=20;legacy.delivery=3
 for c: Dictionary in legacy.cells: c.erase("progress")
 var file: FileAccess=FileAccess.open(game.SAVE_PATH,FileAccess.WRITE)
 file.store_string(JSON.stringify({"version":1,"language":"ja","state":legacy}))
 file.close()
 game.load_game()
 assert(int(game.state.survival)==16)
 assert(not game.state.has("water") and not game.state.has("food") and not game.state.has("delivery"))
 assert(int(game.state.cells[4].progress)==0)
 assert(game.state.roster.size()==6 and str(game.state.phase)=="morning")
 game.state.phase="night"
 game.state.report={"harvest":6,"science":0,"new_discoveries":[]}
 game.save_game()
 var night_state: Dictionary=game.state.duplicate(true)
 game.state=game.Sim.initial()
 game.load_game()
 assert(str(game.state.phase)=="night")
 assert(int(game.state.report.harvest)==int(night_state.report.harvest))
 assert(game.Sim.crew_cell(game.state,"ren")==game.Sim.crew_cell(night_state,"ren"))
 game.modal="help"
 game.refresh()
 game.motion_frozen=true
 game.state=game.Sim.initial()
 game.selected_crew=""
 game.crew_source=-2
 game.set_language("ja")
 var quips: Dictionary={}
 for id: String in ["aoi","ren","mio","sora","haru","rikuto"]:
  var line: String=game.trk("quip_"+id)
  assert(not quips.has(line))
  quips[line]=true
 game.set_language("en")
 quips={}
 for id: String in ["aoi","ren","mio","sora","haru","rikuto"]:
  var line: String=game.trk("quip_"+id)
  assert(not quips.has(line))
  quips[line]=true
 game.set_language("ja")
 game.selected_crew="mio"
 game.select_cell(4)
 assert(game.Sim.crew_cell(game.state,"mio")==4)
 assert(bool(game.quip_badge.matched) and int(game.quip_badge.bonus)==int(game.Sim.expert_bonus("greenhouse")))
 assert(game.trk("quip_mio") in game.message and str(game.Sim.expert_bonus("greenhouse")) in game.message)
 game.selected_crew="aoi"
 game.select_cell(4)
 assert(game.Sim.crew_cell(game.state,"aoi")==4)
 assert(not bool(game.quip_badge.matched))
 assert(game.trk("crew_aoi") in game.message and game.trk("greenhouse") in game.message)
 game.state=game.Sim.initial()
 game.state.day=5
 game.state.power=40
 game.state=game.Sim.place(game.state,"sora",7)
 var before_choice: Dictionary=game.state.duplicate(true)
 game.refresh()
 var choice_lines: Dictionary=game.flare_choice_lines()
 assert(str(int(game.Sim.project(game.state,false).science)-int(game.state.science)) in str(choice_lines.keep))
 assert(str(absi(int(game.Sim.project(game.state,false).health)-int(game.state.health))) in str(choice_lines.keep))
 assert(str(int(game.Sim.R.flare_cover_power)) in str(choice_lines.cover))
 assert(str(int(game.Sim.project(game.state,true).report.damage)) in str(choice_lines.cover))
 assert(bool(choice_lines.ready))
 assert(game.state==before_choice)
 game.choose_cover(true)
 assert(bool(game.state.flare_cover))
 assert(int(game.state.power)==int(before_choice.power) and int(game.state.science)==int(before_choice.science))
 game.state.phase="day"
 var day_snapshot: Dictionary=game.state.duplicate(true)
 game.choose_cover(false)
 assert(game.state==day_snapshot)
 var covered_night: Dictionary=game.Sim.resolve_day(game.state)
 game.state=covered_night
 var settled: Dictionary=game.state.duplicate(true)
 game.motion_frozen=false
 game.fx_t=0.0
 game.fx_playing=true
 game.presentation_step(0.35)
 assert(game.state==settled)
 assert(str(game.state.phase)=="night" and int(game.state.day)==int(settled.day))
 assert(game.shown_amount("health")!=int(settled.health))
 game.presentation_step(3.0)
 assert(not game.fx_playing)
 assert(game.fx_t==1.0)
 assert(game.shown_amount("health")==int(settled.health))
 assert(game.shown_amount("science")==int(settled.science))
 assert(game.state==settled)
 game.save_game()
 game.fx_t=0.2
 game.fx_playing=true
 game.load_game()
 assert(game.fx_t==1.0 and not game.fx_playing)
 assert(int(game.state.health)==int(settled.health) and bool(game.state.flare_cover)==bool(settled.flare_cover))
 # Tempo layer: instant placement feedback, staged night reveal, milestone banner and streak.
 game.motion_frozen=false
 game.set_language("ja")
 game.state=game.Sim.initial()
 game.reset_feedback()
 game.streak=0
 game.refresh()
 game.selected_crew="sora"
 game.select_cell(7)
 assert(game.Sim.crew_cell(game.state,"sora")==7)
 assert(game.floaters.size()>=2)
 var expert_seen: bool=false
 for f: Dictionary in game.floaters:
  if str(f.text)==game.trk("expert_pop",[int(game.Sim.expert_bonus("lab"))]): expert_seen=true
 assert(expert_seen and not game.sparks.is_empty() and game.hop.has("sora"))
 var plain_state: Dictionary=game.state.duplicate(true)
 game.feedback_step(0.2)
 assert(game.state==plain_state)
 game.forecast_roll={}
 assert(game.rolled("science",3)==3)
 assert(game.rolled("science",5)==3 and float(game.forecast_roll.science.flash)==1.0)
 game.feedback_step(2.0)
 assert(game.rolled("science",5)==5)
 # The night reveal follows power, material, harvest, research, health, discovery.
 game.state=game.Sim.initial()
 game.state.science=8
 game.state=game.Sim.place(game.state,"sora",7)
 game.state=game.Sim.place(game.state,"haru",4)
 game.state=game.Sim.begin_day(game.state)
 game.streak=2
 game.advance_phase()
 assert(str(game.state.phase)=="night" and game.fx_playing)
 assert(game.streak==3 or int(game.state.report.survival)<=0)
 var stages: Array=game.reveal_stages()
 var order: Array=["power","material","survival","science","health","discovery"]
 var last: int=-1
 for st: Variant in stages:
  var at: int=order.find(str(st))
  assert(at>last)
  last=at
 assert("discovery" in stages and stages.find("power")<stages.find("science"))
 var settled_night: Dictionary=game.state.duplicate(true)
 game.presentation_step(0.01)
 assert(game.stage_progress("science")==0.0)
 assert(game.shown_amount("science")==int(settled_night.science)-int(settled_night.report.science))
 game.presentation_step(5.0)
 assert(not game.fx_playing and game.fx_t==1.0)
 assert(game.banner_t==0.0 and "shielding" in game.banner_ids)
 assert(game.state==settled_night)
 assert(game.skip_presentation() and game.banner_t==1.0)
 assert(str(game.state.phase)=="night")
 game.on_primary()
 assert(str(game.state.phase)=="morning")
 # Every effect uses its bundled CC0 file instead of the synthesized fallback.
 for key: Variant in game.SFX_FILES.keys():
  assert(ResourceLoader.exists(str(game.SFX_FILES[key][0])))
  assert(game.load_sfx(str(key)) is AudioStreamOggVorbis)
 # The streak lives beside the save state and survives a reload.
 game.streak=4
 game.save_game()
 game.streak=0
 game.load_game()
 assert(game.streak==4)
 game.restart()
 assert(game.streak==0)
 game.motion_frozen=true
 print("PASS: direct crew assignment, movement, capacity, palette building, forecast, localization and save migration")
 game.state=game.Sim.initial()
 game.save_game()
 quit()
 return

func pointer_click(pos: Vector2) -> void:
 var motion: InputEventMouseMotion=InputEventMouseMotion.new()
 motion.position=pos
 root.push_input(motion,true)
 var press: InputEventMouseButton=InputEventMouseButton.new()
 press.position=pos
 press.button_index=MOUSE_BUTTON_LEFT
 press.pressed=true
 root.push_input(press,true)
 var release: InputEventMouseButton=press.duplicate()
 release.pressed=false
 root.push_input(release,true)
