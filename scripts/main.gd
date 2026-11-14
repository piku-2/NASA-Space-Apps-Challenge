extends Control
const Sim = preload("res://scripts/simulation.gd")
const PAPER: Color = Color("fbf2df")
const INK: Color = Color("303e52")
const RUST: Color = Color("b65030")
const LINE: Color = Color("cd805c")
const MUTED: Color = Color("827565")
const TEAL: Color = Color("3e7c78")
var state: Dictionary = {}
var words: Dictionary = {}
var language: String = "ja"
var selected: int = 1
var modal: String = ""
var build_kind: String = "solar"
var message: String = ""
var saved: bool = true
var ui: Control
var font: Font = preload("res://assets/font.otf")
var icons: Dictionary = {}
var hover_cell: int = -1
var tick: float = 0.0
var sound: AudioStreamPlayer
const SAVE_PATH: String = "user://mars_notebook_v1.json"
func _ready() -> void:
 for key: String in ["solar","water","greenhouse","lab","habitat","mine","shield","crew","sun","storm","power","food","material","star","flag"]:
  icons[key] = load("res://assets/"+key+".svg")
 state = Sim.initial()
 load_game()
 set_language(language)
 sound = AudioStreamPlayer.new()
 add_child(sound)
 message = trk("log_start")
 refresh()
func trk(key: String, args: Array = []) -> String:
 return str(words.get(key,key)).format(args)
func facility_name(kind: String) -> String:
 return trk("facility_water" if kind=="water" else kind)
func set_language(lang: String) -> void:
 language = lang
 var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/"+lang+".json"))
 words = parsed if parsed is Dictionary else {}
func save_game() -> void:
 var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
 saved = f != null
 if f != null: f.store_string(JSON.stringify({"version":1,"language":language,"state":state}))
func load_game() -> void:
 if not FileAccess.file_exists(SAVE_PATH): return
 var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
 if not data is Dictionary or data.get("version",0) != 1: return
 var candidate: Variant = data.get("state")
 if not candidate is Dictionary or not candidate.get("cells") is Array or candidate.cells.size() != 18: return
 for k: String in Sim.CONFIG.initial.keys():
  if not candidate.has(k) or typeof(candidate[k]) != typeof(Sim.CONFIG.initial[k]) and not (candidate[k] is float or candidate[k] is int): return
 for c: Variant in candidate.cells:
  if not c is Dictionary or not c.get("kind") is String or not c.has("crew") or not c.has("level"): return
  if c.kind != "" and not c.kind in Sim.CONFIG.facilities: return
  if int(c.crew)<0 or int(c.crew)>int(Sim.R.capacity) or int(c.level)<1 or int(c.level)>int(Sim.R.max_level): return
 if Sim.idle(candidate) < 0 or int(candidate.day)<1: return
 for k: String in Sim.CONFIG.initial.keys():
  if candidate[k] is float: candidate[k]=int(candidate[k])
 for c: Dictionary in candidate.cells:
  c.crew=int(c.crew)
  c.level=int(c.level)
 state = candidate
 language = str(data.get("language","ja"))
 if not language in ["ja","en"]: language = "ja"
func note(key: String) -> void:
 message = trk(key)
 refresh()
func style(fill: Color, border: Color = LINE, width: int = 2, radius: int = 14) -> StyleBoxFlat:
 var s: StyleBoxFlat = StyleBoxFlat.new()
 s.bg_color = fill
 s.border_color = border
 s.set_border_width_all(width)
 s.set_corner_radius_all(radius)
 s.content_margin_left = 12
 s.content_margin_right = 12
 return s
func button(text: String, rect: Rect2, action: Callable, primary: bool = false, disabled: bool = false) -> Button:
 var b: Button = Button.new()
 b.text = text
 b.position = rect.position
 b.size = rect.size
 b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 b.add_theme_font_override("font",font)
 b.add_theme_font_size_override("font_size",20)
 b.add_theme_color_override("font_color",PAPER if primary else INK)
 b.add_theme_color_override("font_hover_color",PAPER if primary else RUST)
 b.add_theme_color_override("font_pressed_color",PAPER if primary else RUST)
 b.add_theme_color_override("font_disabled_color", Color("9c968a"))
 b.add_theme_stylebox_override("normal",style(RUST if primary else PAPER,RUST))
 b.add_theme_stylebox_override("hover",style(Color("a94628") if primary else Color("f7e2c3"),RUST,3))
 b.add_theme_stylebox_override("pressed",style(Color("924227") if primary else Color("efd5ae"),RUST,3))
 b.add_theme_stylebox_override("disabled",style(Color("eee6d6"),Color("c7bba8")))
 b.disabled = disabled
 b.pressed.connect(func() -> void:
  click_sound()
  action.call())
 ui.add_child(b)
 return b
func click_sound() -> void:
 var wav: AudioStreamWAV = AudioStreamWAV.new()
 wav.format = AudioStreamWAV.FORMAT_16_BITS
 wav.mix_rate = 22050
 var bytes: PackedByteArray = PackedByteArray()
 bytes.resize(2205*2)
 for i: int in range(2205):
  var value: int = int(sin(float(i)*0.23)*1300.0*exp(-float(i)/350.0))
  bytes.encode_s16(i*2,value)
 wav.data = bytes
 sound.stream = wav
 sound.play()
func refresh() -> void:
 if is_instance_valid(ui):
  remove_child(ui)
  ui.queue_free()
 ui = Control.new()
 ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(ui)
 button(trk("help"),Rect2(1010,84,145,38),func() -> void: open_modal("help"))
 button(trk("language"),Rect2(1165,84,155,38),func() -> void:
  set_language("en" if language == "ja" else "ja")
  save_game()
  refresh())
 for i: int in range(18):
  var rect: Rect2 = cell_rect(i)
  var hit: Button = Button.new()
  hit.position = rect.position
  hit.size = rect.size
  hit.flat = true
  hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
  for k: String in ["normal","hover","pressed","focus"]: hit.add_theme_stylebox_override(k,StyleBoxEmpty.new())
  hit.pressed.connect(select_cell.bind(i))
  hit.mouse_entered.connect(func() -> void: hover_cell = i; queue_redraw())
  hit.mouse_exited.connect(func() -> void: hover_cell = -1; queue_redraw())
  ui.add_child(hit)
 var c: Dictionary = state.cells[selected]
 if c.kind != "":
  button(trk("assign"),Rect2(938,466,181,42),func() -> void: assign(1), false, bool(state.over) or c.kind=="shield" or int(c.crew)>=int(Sim.R.capacity) or Sim.idle(state)==0)
  button(trk("remove"),Rect2(1127,466,182,42),func() -> void: assign(-1), false, bool(state.over) or int(c.crew)==0)
  button(trk("upgrade",[int(Sim.R.upgrade)*int(c.level)]),Rect2(938,518,371,42),upgrade,false,bool(state.over) or c.kind=="shield" or int(c.level)>=int(Sim.R.max_level))
 else:
  button(trk("build_title"),Rect2(938,466,371,50),func() -> void: open_modal("build"), true, bool(state.over))
 var ev: String = Sim.event(state)
 if ev == "flare":
  button(trk("shelter_on") if bool(state.shelter) else trk("shelter"),Rect2(938,260,371,42),toggle_shelter,bool(state.shelter),bool(state.over))
 button(trk("next"),Rect2(930,659,390,69),next_day,true,bool(state.over))
 button(trk("sources"),Rect2(32,744,174,32),func() -> void: open_modal("sources"))
 button(trk("restart"),Rect2(217,744,150,32),func() -> void: open_modal("restart"))
 if int(state.delivery) < 0:
  button(trk("supply"),Rect2(930,591,390,43),request_supply,false,bool(state.over))
 if modal != "": add_modal_controls()
 queue_redraw()
func cell_rect(i: int) -> Rect2:
 return Rect2(32+(i%6)*144,180+(i/6)*146,144,146)
func select_cell(i: int) -> void:
 click_sound()
 selected = i
 if state.cells[i].kind == "": modal = "build"
 refresh()
func assign(amount: int) -> void:
 var c: Dictionary = state.cells[selected]
 if amount > 0 and Sim.idle(state) == 0: note("no_crew"); return
 c.crew = clampi(int(c.crew)+amount,0,int(Sim.R.capacity))
 save_game()
 note("assigned" if amount > 0 else "removed")
func upgrade() -> void:
 var c: Dictionary = state.cells[selected]
 var cost: int = int(Sim.R.upgrade)*int(c.level)
 if int(state.material)<cost: note("need_material"); return
 state.material -= cost
 c.level += 1
 save_game()
 note("upgraded")
func build(kind: String) -> void:
 var cost: int = int(Sim.R.shield_cost if kind == "shield" else Sim.R.build)
 if int(state.material)<cost: message = trk("need_material"); modal=""; refresh(); return
 state.material -= cost
 state.cells[selected] = {"kind":kind,"crew":0,"level":1}
 if kind=="shield": state.shield = true
 modal=""
 save_game()
 note("built")
func toggle_shelter() -> void:
 state.shelter = not bool(state.shelter)
 save_game()
 note("sheltered" if bool(state.shelter) else "unsheltered")
func request_supply() -> void:
 if int(state.material)<int(Sim.R.supply_cost): note("need_material"); return
 state.material -= int(Sim.R.supply_cost)
 state.delivery = int(state.day)+int(Sim.R.delivery_days)
 save_game()
 note("supply_sent")
func next_day() -> void:
 if bool(state.over): return
 var was_won: bool = bool(state.won)
 var was_delivery: int = int(state.delivery)
 var sheltered: bool = bool(state.shelter)
 var ev: String = Sim.event(state)
 state = Sim.calculate(state)
 message = trk("daily",[int(state.day)])
 if bool(state.shortage): message = trk("shortage")
 if ev == "flare": message = trk("protected" if sheltered else "damaged")
 if was_delivery>=0 and int(state.delivery)<0: message = trk("supply_received")
 if bool(state.over): modal = "loss"
 elif bool(state.won) and not was_won: modal = "win"
 save_game()
 refresh()
func open_modal(key: String) -> void:
 modal = key
 refresh()
func close_modal() -> void:
 modal = ""
 refresh()
func restart() -> void:
 state = Sim.initial()
 selected=1
 modal=""
 message=trk("log_start")
 save_game()
 refresh()
func add_modal_controls() -> void:
 var shade: ColorRect = ColorRect.new()
 shade.color = Color(0.18,0.2,0.23,0.42)
 shade.size = Vector2(1360,800)
 ui.add_child(shade)
 var panel: Panel = Panel.new()
 panel.position=Vector2(280,95)
 panel.size=Vector2(800,610)
 panel.add_theme_stylebox_override("panel",style(PAPER,RUST,3,20))
 ui.add_child(panel)
 # Labels are drawn by a foreground canvas above the modal shade.
 var canvas: Control = Control.new()
 canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
 canvas.draw.connect(draw_modal)
 ui.add_child(canvas)
 if modal=="build":
  var kinds: Array = Sim.CONFIG.facilities
  for i: int in range(kinds.size()):
   var kind: String = str(kinds[i])
   var b: Button = button(facility_name(kind),Rect2(315+(i%4)*186,195+(i/4)*175,170,132),func() -> void: build(kind))
   b.icon=icons[kind]
   b.expand_icon=true
   b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
   b.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
   b.add_theme_constant_override("icon_max_width",66)
   b.add_theme_font_size_override("font_size",18)
   b.tooltip_text=trk(kind+"_desc")
  button(trk("cancel"),Rect2(800,631,235,46),close_modal)
 elif modal=="sources":
  button(trk("source_flare"),Rect2(315,550,360,42),func() -> void: OS.shell_open("https://science.nasa.gov/blogs/solar-cycle-25/2024/05/14/strong-solar-flare-erupts-from-sun-15/"))
  button(trk("source_comm"),Rect2(315,601,360,42),func() -> void: OS.shell_open("https://www.nasa.gov/centers-and-facilities/goddard/space-communications-7-things-you-need-to-know/"))
  button(trk("close"),Rect2(800,631,235,46),close_modal)
 elif modal in ["loss","restart"]:
  button(trk("restart_confirm"),Rect2(315,610,350,52),restart,true)
  button(trk("cancel"),Rect2(700,610,335,52),close_modal)
 else:
  button(trk("continue" if modal=="win" else "close"),Rect2(750,631,285,46),close_modal,true)
func text_at(text: String, x: float, y: float, size_px: int = 24, color: Color = INK, width: float = -1) -> void:
 draw_string(font,Vector2(x,y),text,HORIZONTAL_ALIGNMENT_LEFT,width,size_px,color)
func centered(text: String, rect: Rect2, size_px: int = 22, color: Color = INK) -> void:
 var w: float = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x
 text_at(text,rect.position.x+(rect.size.x-w)/2,rect.position.y+rect.size.y/2+size_px*0.36,size_px,color)
func icon(kind: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
 if icons.has(kind): draw_texture_rect(icons[kind],rect,false,tint)
func coin(pos: Vector2, radius: float = 31) -> void:
 draw_circle(pos+Vector2(1,5),radius,Color(0.3,0.2,0.1,0.13))
 draw_circle(pos,radius,Color("ebc58b"))
 draw_arc(pos,radius-2,0,TAU,40,Color("c49960"),2,true)
 icon("crew",Rect2(pos-Vector2.ONE*radius*0.81,Vector2.ONE*radius*1.62))
func _draw() -> void:
 draw_rect(Rect2(0,0,1360,800),PAPER)
 # Deterministic speckling gives the same quiet paper texture on every device.
 var rng: RandomNumberGenerator = RandomNumberGenerator.new()
 rng.seed=1729
 for i: int in range(5400):
  var p: Vector2=Vector2(rng.randf_range(0,1360),rng.randf_range(0,800))
  draw_circle(p,rng.randf_range(0.25,0.75),Color(0.55,0.38,0.2,0.035))
 if state.is_empty(): return
 text_at(trk("day",[int(state.day)]),32,56,37,RUST)
 var keys: Array[String]=["water","power","food","material","science"]
 for i: int in range(keys.size()):
  var x: float=225+i*184
  var key: String=keys[i]
  icon(key if key!="science" else "star",Rect2(x,15,37,37))
  text_at(str(int(state[key])),x+47,51,32,INK if int(state[key])>3 else RUST)
  text_at(trk(key),x+91,45,15,MUTED)
  draw_line(Vector2(x+169,21),Vector2(x+169,55),LINE,1.5,true)
 text_at(trk("saved" if saved else "save_failed"),1164,45,18,TEAL if saved else RUST)
 draw_line(Vector2(28,74),Vector2(1326,74),LINE,2,true)
 icon("habitat",Rect2(34,91,64,64))
 text_at(trk("title"),113,145,41,RUST)
 text_at(trk("subtitle"),390,121,14,MUTED)
 text_at(trk("mission"),391,151,20)
 var predicted: Dictionary=Sim.calculate(state)
 for i: int in range(18):
  var rect: Rect2=cell_rect(i)
  var c: Dictionary=state.cells[i]
  if i==selected: draw_style_box(style(Color("f6dfbc"),RUST,3,9),rect.grow(-3))
  elif i==hover_cell: draw_style_box(style(Color("f8e8d0"),LINE,1,8),rect.grow(-4))
  draw_rect(rect,LINE,false,1.5)
  if c.kind=="":
   var inner: Rect2=rect.grow(-13)
   draw_dashed_line(inner.position,Vector2(inner.end.x,inner.position.y),Color("dcb697"),1.2,3)
   draw_dashed_line(Vector2(inner.end.x,inner.position.y),inner.end,Color("dcb697"),1.2,3)
   draw_dashed_line(inner.end,Vector2(inner.position.x,inner.end.y),Color("dcb697"),1.2,3)
   draw_dashed_line(Vector2(inner.position.x,inner.end.y),inner.position,Color("dcb697"),1.2,3)
   if i==hover_cell: centered("+",rect,33,LINE)
  else:
   icon(str(c.kind),Rect2(rect.position+Vector2(27,13),Vector2(90,90)))
   centered(facility_name(str(c.kind)),Rect2(rect.position+Vector2(0,101),Vector2(144,31)),17)
   text_at(str(int(c.level)),rect.position.x+8,rect.position.y+23,14,MUTED)
   for j: int in range(int(c.crew)): coin(rect.position+Vector2(113-j*37,91),23)
 draw_style_box(style(Color.TRANSPARENT,RUST,2,12),Rect2(31,179,866,440))
 text_at(trk("waiting"),38,675,24)
 for i: int in range(Sim.idle(state)): coin(Vector2(200+i*69,661),29)
 text_at(trk("crew_hint"),38,715,17,MUTED)
 # Health stays separate from the resource decisions.
 text_at(trk("health")+" "+str(int(state.health))+"%",650,659,18,TEAL)
 draw_style_box(style(Color("e9ddc8"),Color.TRANSPARENT,0,5),Rect2(649,674,225,10))
 draw_style_box(style(TEAL,Color.TRANSPARENT,0,5),Rect2(649,674,225*clampf(float(state.health)/100,0,1),10))
 text_at(trk("goal",[int(state.science),mini(int(state.day)-1,15)]),630,712,16,MUTED)
 draw_style_box(style(Color.TRANSPARENT,LINE,2,16),Rect2(920,143,410,189))
 draw_style_box(style(Color("f1d7b7"),Color.TRANSPARENT,0,5),Rect2(960,156,331,32))
 centered(trk("event"),Rect2(960,154,331,34),23)
 var ev: String=Sim.event(state)
 icon("sun" if ev in ["sun","calm"] else ("storm" if ev=="dust" else "shield"),Rect2(941,194,56,56))
 text_at(trk(ev),1006,221,24,RUST if ev=="flare" else INK)
 text_at(trk(ev+"_desc"),941,251,15)
 if ev!="flare":
  draw_line(Vector2(942,267),Vector2(1309,267),LINE,1.5)
  text_at(trk("tomorrow")+trk(Sim.event(state,1)),944,299,19)
 else: text_at(trk("archive"),942,320,12,MUTED)
 draw_style_box(style(Color.TRANSPARENT,LINE,2,16),Rect2(920,350,410,225))
 var cell: Dictionary=state.cells[selected]
 if cell.kind!="":
  icon(str(cell.kind),Rect2(940,366,73,73))
  text_at(facility_name(str(cell.kind)),1028,394,26)
  text_at(trk("level",[int(cell.level)]),1234,393,16,MUTED)
  for i: int in range(int(Sim.R.capacity)):
   if i<int(cell.crew): coin(Vector2(1055+i*71,429),22)
   else: draw_arc(Vector2(1055+i*71,429),22,0,TAU,36,LINE,1.2,true)
  text_at(trk(str(cell.kind)+"_desc"),938,459,13,MUTED)
 else:
  centered(trk("empty"),Rect2(935,366,375,80),28)
  text_at(trk("build_cost",[int(Sim.R.build)]),960,451,17,MUTED)
 if int(state.delivery)>=0: text_at(trk("supply_wait",[int(state.delivery)-int(state.day)]),943,619,21,TEAL)
 # Daily forecast is always inspectable before committing.
 text_at(trk("forecast"),390,753,15,MUTED)
 for i: int in range(keys.size()):
  var k: String=keys[i]
  var delta: int=int(predicted[k])-int(state[k])
  var x: float=390+i*101
  icon(k if k!="science" else "star",Rect2(x,762,21,21))
  text_at(("+" if delta>=0 else "")+str(delta),x+28,782,18,TEAL if delta>=0 else RUST)
 text_at(message,32,794,14,RUST)
 text_at(trk("footer"),940,763,11,MUTED)
func draw_modal() -> void:
 # This signal belongs to the top canvas, so draw using that canvas.
 var canvas: Control=ui.get_child(ui.get_child_count()-1) as Control
 for child: Node in ui.get_children():
  if child is Control and child.has_signal("draw") and child.mouse_filter==Control.MOUSE_FILTER_IGNORE and not child is ColorRect: canvas=child
 if not is_instance_valid(canvas): return
 var title_key: String=modal+"_title"
 var body_key: String=modal+"_body"
 if modal=="build": title_key="build_title"
 canvas.draw_string(font,Vector2(315,154),trk(title_key),HORIZONTAL_ALIGNMENT_LEFT,730,30,RUST)
 if modal=="build":
  canvas.draw_string(font,Vector2(315,602),trk("build_cost",[int(Sim.R.build)])+"  /  "+trk("shield_button"),HORIZONTAL_ALIGNMENT_LEFT,730,18,INK)
  return
 var lines: PackedStringArray=trk(body_key).split("\n")
 for i: int in range(lines.size()):
  canvas.draw_string(font,Vector2(315,211+i*26),lines[i],HORIZONTAL_ALIGNMENT_LEFT,730,19,INK)
