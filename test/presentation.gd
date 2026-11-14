extends SceneTree
var game: Control
var frame: int = 0
func _initialize() -> void:
 game = load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
func _process(_delta: float) -> bool:
 frame+=1
 if frame==1:
  game.state = game.Sim.initial()
  game.selected=4
  game.state = game.Sim.place(game.state, "mio", 4)
  game.state = game.Sim.place(game.state, "sora", 7)
  game.state = game.Sim.place(game.state, "aoi", -1)
  game.refresh()

 if frame==3:
  var shot: ViewportTexture=root.get_viewport().get_texture()
  if shot!=null:
   var img: Image=shot.get_image()
   if img!=null: img.save_png("res://screenshots/gameplay.png")
 if frame in [18,38,58,78,98,118,138]:
  game.finish_day()
  game.close_modal()
 if frame==27: game.select_cell(7)
 if frame==48:
  game.selected=12
  game.build("mine")
  game.assign(1)
 if frame==68:
  game.selected=1
  game.upgrade()
 if frame==88: game.toggle_shelter()
 if frame==108: game.selected=4;game.refresh()
 if frame==140: quit()
 return false
