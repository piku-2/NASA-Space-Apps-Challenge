extends SceneTree
var game: Control
var frame: int=0
func _initialize() -> void:
 game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
func _process(_delta: float) -> bool:
 frame+=1
 if frame==2:game.open_modal("help")
 if frame==4:root.get_viewport().get_texture().get_image().save_png("res://screenshots/help.png")
 if frame==5:game.open_modal("sources")
 if frame==7:root.get_viewport().get_texture().get_image().save_png("res://screenshots/sources.png")
 if frame==8:game.selected=2;game.open_modal("build")
 if frame==10:root.get_viewport().get_texture().get_image().save_png("res://screenshots/build.png")
 if frame==11:game.close_modal();game.set_language("en");game.refresh()
 if frame==13:root.get_viewport().get_texture().get_image().save_png("res://screenshots/english.png")
 if frame==14:quit()
 return false
