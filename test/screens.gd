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
 if frame==27:quit()
 return false
