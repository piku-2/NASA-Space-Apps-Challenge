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
 assert(game.Sim.idle(game.state)==2)
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
 assert(int(game.state.material)==int(locked.material))
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
 assert(game.state.roster.size()==5 and str(game.state.phase)=="morning")
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
