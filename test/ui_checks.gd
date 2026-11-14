extends SceneTree
var game: Control
var frame: int=0
func _initialize() -> void:
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
func _process(_delta: float) -> bool:
 frame+=1
 if frame!=2:return false
 game.state=game.Sim.initial()
 game.selected=4
 game.assign(1)
 assert(int(game.state.cells[4].crew)==1)
 game.assign(-1)
 assert(int(game.state.cells[4].crew)==0)
 game.selected=2
 game.build("mine")
 assert(game.state.cells[2].kind=="mine")
 assert(int(game.state.material)==8)
 game.upgrade()
 assert(int(game.state.cells[2].level)==2)
 assert(int(game.state.material)==5)
 game.request_supply()
 assert(int(game.state.delivery)==3)
 assert(int(game.state.material)==1)
 game.build("shield")
 assert(game.state.cells[2].kind=="mine")
 game.set_language("en")
 assert(game.trk("title")=="Mars Outpost")
 game.set_language("ja")
 game.save_game()
 var original: Dictionary=game.state.duplicate(true)
 game.state=game.Sim.initial()
 game.load_game()
 assert(game.state==original)
 game.modal="help"
 game.refresh()
 print("PASS: UI commands, costs, localization, save and restore")
 game.state=game.Sim.initial()
 game.save_game()
 quit()
 return false
