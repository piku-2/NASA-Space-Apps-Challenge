extends SceneTree
var game: Control
var frame: int=0
func _initialize() -> void:
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
func save_shot(path: String) -> void:
 var tex: ViewportTexture=root.get_viewport().get_texture()
 if tex==null: return
 var img: Image=tex.get_image()
 if img==null: return
 img.save_png(path)
func _process(_delta: float) -> bool:
 frame+=1
 if frame==1:
  game.state=game.Sim.initial()
  game.set_language("ja")
  game.motion_frozen=true
  game.fx_t=1.0
  game.fx_playing=false
  game.tick=0.2
  game.refresh()
 if frame==2:game.open_modal("help")
 if frame==4:save_shot("res://screenshots/help.png")
 if frame==5:game.open_modal("sources")
 if frame==7:save_shot("res://screenshots/sources.png")
 if frame==8:game.close_modal();game.selected=2;game.choose_build("water")
 if frame==10:save_shot("res://screenshots/build.png")
 if frame==11:game.close_modal();game.set_language("en");game.refresh()
 if frame==13:save_shot("res://screenshots/english.png")
 if frame==15:
  game.set_language("ja")
  game.modal=""
  game.state=game.Sim.initial()
  game.state.day=5
  game.selected_crew="mio"
  game.crew_source=-1
  game.state=game.Sim.begin_day(game.state)
  game.refresh()
 if frame==17:save_shot("res://screenshots/day.png")
 if frame==18:
  game.state=game.Sim.resolve_day(game.state)
  game.message=game.outcome_message()
  game.refresh()
 if frame==20:save_shot("res://screenshots/night.png")
 if frame==21:
  game.set_language("en")
  game.refresh()
 if frame==23:save_shot("res://screenshots/english_night.png")
 if frame==24:
  game.state.science=10
  game.state.discoveries=["shielding"]
  if game.state.get("report") is Dictionary:
   game.state.report.new_discoveries=["shielding"]
  game.message=game.outcome_message()
  game.refresh()
 if frame==26:save_shot("res://screenshots/discovery.png")
 if frame==28:
  game.set_language("ja")
  game.modal=""
  game.selected_crew=""
  game.state=game.Sim.initial()
  game.state=game.Sim.place(game.state,"mio",4)
  game.state.cells[4].progress=4
  game.state=game.Sim.begin_day(game.state)
  game.state=game.Sim.resolve_day(game.state)
  game.message=game.outcome_message()
  game.pose_feedback(0.55, 0.2)
  game.refresh()
 if frame==30:save_shot("res://screenshots/harvest_ja.png")
 if frame==31:
  game.set_language("en")
  game.message=game.outcome_message()
  game.pose_feedback(0.55, 0.2)
  game.refresh()
 if frame==33:save_shot("res://screenshots/harvest_en.png")
 if frame==34:
  game.set_language("ja")
  game.modal=""
  game.selected_crew=""
  game.quip_badge={}
  game.state=game.Sim.initial()
  game.state.day=5
  game.state.power=40
  game.state=game.Sim.place(game.state,"sora",7)
  game.fx_t=1.0
  game.fx_playing=false
  game.refresh()
 if frame==36:save_shot("res://screenshots/flare_ja.png")
 if frame==37:
  game.set_language("en")
  game.refresh()
 if frame==39:save_shot("res://screenshots/flare_en.png")
 if frame==40:
  game.set_language("ja")
  game.state=game.Sim.initial()
  game.selected_crew="mio"
  game.crew_source=-1
  game.select_cell(4)
  game.pose_feedback(1.0, 0.2)
  game.refresh()
 if frame==42:save_shot("res://screenshots/quip_ja.png")
 if frame==43:
  game.set_language("en")
  game.announce_assignment("mio", 4)
  game.pose_feedback(1.0, 0.2)
  game.refresh()
 if frame==45:save_shot("res://screenshots/quip_en.png")
 if frame==46:
  game.set_language("ja")
  game.quip_badge={}
  game.selected_crew=""
  game.state=game.Sim.initial()
  game.state=game.Sim.place(game.state,"sora",7)
  game.state.science=8
  game.state=game.Sim.begin_day(game.state)
  game.state=game.Sim.resolve_day(game.state)
  game.message=game.outcome_message()
  game.pose_feedback(1.0, 0.2)
  game.refresh()
 if frame==48:save_shot("res://screenshots/discovery_ja.png")
 if frame==49:
  game.set_language("en")
  game.message=game.outcome_message()
  game.pose_feedback(1.0, 0.2)
  game.refresh()
 if frame==51:save_shot("res://screenshots/discovery_en.png")
 if frame==52:quit()
 return false
