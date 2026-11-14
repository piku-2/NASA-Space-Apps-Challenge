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
var build_kind: String = ""
# -2: no crew selected; -1: standby; otherwise a source cell.
var crew_source: int = -2
var selected_crew: String = ""
var message: String = ""
var saved: bool = true
var ui: Control
var font: FontFile = preload("res://ui_assets/fonts/SourceHanSansJP-Regular.otf")
var icons: Dictionary = {}
var hover_cell: int = -1
var tick: float = 0.0
var sound: AudioStreamPlayer
const SAVE_PATH: String = "user://mars_notebook_v1.json"
func _ready() -> void:
 theme = Theme.new()
 theme.default_font = font
 theme.default_font_size = 18
 for key: String in ["solar","water","greenhouse","lab","habitat","mine","shield","crew","sun","storm","power","material","star","flag","survival","upgrade","undo","help","book"]:
  icons[key] = load("res://ui_assets/"+key+".svg")
 state = Sim.initial()
 load_game()
 set_language(language)
 sound = AudioStreamPlayer.new()
 add_child(sound)
 message = phase_message()
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
 if f != null: f.store_string(JSON.stringify({"version":3,"language":language,"state":state}))
func load_game() -> void:
 if not FileAccess.file_exists(SAVE_PATH): return
 var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
 if not data is Dictionary: return
 var candidate: Variant = data.get("state")
 if not candidate is Dictionary: return
 var restored: Dictionary = Sim.restore(candidate, int(data.get("version",0)))
 if restored.is_empty(): return
 state = restored
 language = str(data.get("language","ja"))
 if not language in ["ja","en"]: language = "ja"
func phase_message() -> String:
 var phase: String = str(state.get("phase","morning"))
 if phase == "night": return outcome_message()
 if phase == "day": return trk("day_working")
 if int(state.get("day",1)) == 1: return trk("log_start")
 return trk("daily",[int(state.day)])
func outcome_message() -> String:
 var report: Dictionary = state.get("report", {}) if state.get("report") is Dictionary else {}
 var parts: PackedStringArray = PackedStringArray()
 if int(report.get("harvest",0)) > 0: parts.append(trk("outcome_harvest",[int(report.harvest)]))
 if int(report.get("produced_science",0)) > 0: parts.append(trk("outcome_science",[int(report.produced_science)]))
 if int(report.get("produced_material",0)) > 0: parts.append(trk("outcome_material",[int(report.produced_material)]))
 if int(report.get("damage",0)) > 0: parts.append(trk("outcome_damage",[int(report.damage)]))
 elif int(report.get("healed",0)) > 0: parts.append(trk("outcome_heal",[int(report.healed)]))
 var fresh: Variant = report.get("new_discoveries", [])
 if fresh is Array:
  for id: Variant in fresh:
   parts.append(trk("discovered",[trk("unlock_"+str(id)+"_name")]))
 if parts.is_empty(): parts.append(trk("outcome_none"))
 return " ".join(parts)
func unlock_label(id: String) -> String:
 var at: int = int(Sim.R.unlock_shield_at if id == "shielding" else Sim.R.unlock_plant_at)
 var have: int = int(state.science)
 if have >= at: return trk("unlock_ready")
 return trk("unlock_need",[at-have])
func idle_ids() -> Array:
 var ids: Array = []
 for d: Dictionary in Sim.CONFIG.crew:
  if Sim.crew_cell(state, str(d.id)) < 0: ids.append(str(d.id))
 return ids
func occupant_ids(cell: int) -> Array:
 var ids: Array = []
 for d: Dictionary in Sim.CONFIG.crew:
  if Sim.crew_cell(state, str(d.id)) == cell: ids.append(str(d.id))
 return ids
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
func icon_button(kind: String, rect: Rect2, hint: String, action: Callable, active: bool = false, disabled: bool = false) -> Button:
 var b: Button = button("",rect,action,active,disabled)
 if active:
  b.add_theme_stylebox_override("normal",style(Color("d4e7de"),TEAL,3))
  b.add_theme_stylebox_override("hover",style(Color("c3ded3"),TEAL,3))
 b.icon = icons[kind]
 b.expand_icon = true
 b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
 b.add_theme_constant_override("icon_max_width",42)
 b.tooltip_text = hint
 return b
func crew_hit(pos: Vector2, radius: float, id: String) -> void:
 var b: Button = Button.new()
 b.position = pos-Vector2.ONE*radius
 b.size = Vector2.ONE*radius*2
 for k: String in ["normal","hover","pressed","focus"]: b.add_theme_stylebox_override(k,StyleBoxEmpty.new())
 b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 var spec: String = Sim.specialty(id)
 b.tooltip_text = trk("crew_"+id)+"\n"+trk("spec_"+spec)+"\n"+trk("spec_bonus_"+spec)
 b.pressed.connect(func() -> void: choose_crew_id(id))
 ui.add_child(b)
func choose_crew_id(id: String) -> void:
 if not Sim.can_plan(state):
  note("plan_locked")
  return
 if id == "": return
 click_sound()
 if selected_crew == id:
  selected_crew = ""
  crew_source = -2
 else:
  selected_crew = id
  var cell: int = Sim.crew_cell(state, id)
  crew_source = -1 if cell < 0 else cell
 build_kind = ""
 refresh()
func choose_crew(source: int) -> void:
 var id: String = ""
 if source == -1: id = Sim.first_idle(state)
 elif source >= 0: id = Sim.first_in_cell(state, source)
 if id == "": return
 choose_crew_id(id)
func choose_build(kind: String) -> void:
 if not Sim.can_plan(state):
  note("plan_locked")
  return
 build_kind = "" if build_kind == kind else kind
 crew_source = -2
 selected_crew = ""
 refresh()
func return_selected() -> void:
 if selected_crew == "" or Sim.crew_cell(state, selected_crew) < 0: return
 if not Sim.can_plan(state):
  note("plan_locked")
  return
 state = Sim.move(state, selected_crew, -1)
 selected_crew = ""
 crew_source = -2
 save_game()
 note("removed")
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
 icon_button("help",Rect2(1100,84,55,42),trk("help"),func() -> void: open_modal("help"))
 button(trk("language"),Rect2(1165,84,155,38),func() -> void:
  set_language("en" if language == "ja" else "ja")
  save_game()
  refresh())
 var resource_keys: Array[String] = ["survival","power","material","science"]
 for i: int in range(resource_keys.size()):
  var tip: Control = Control.new()
  tip.position = Vector2(265+i*245,10)
  tip.size = Vector2(150,50)
  tip.tooltip_text = trk(resource_keys[i])
  if resource_keys[i]=="survival": tip.tooltip_text += "\n"+trk("consumption")
  var forecast_tip: Control = Control.new()
  forecast_tip.position = Vector2(940+i*94,616)
  forecast_tip.size = Vector2(94,34)
  forecast_tip.tooltip_text = trk(resource_keys[i])
  ui.add_child(forecast_tip)
  ui.add_child(tip)
 for i: int in range(18):
  var rect: Rect2 = cell_rect(i)
  var hit: Button = Button.new()
  hit.position = rect.position
  hit.size = rect.size
  hit.flat = true
  var kind: String = str(state.cells[i].kind)
  hit.tooltip_text = trk("empty") if kind=="" else facility_name(kind)+"\n"+trk(kind+"_desc")
  hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
  for k: String in ["normal","hover","pressed","focus"]: hit.add_theme_stylebox_override(k,StyleBoxEmpty.new())
  hit.pressed.connect(select_cell.bind(i))
  hit.mouse_entered.connect(func() -> void: hover_cell = i; queue_redraw())
  hit.mouse_exited.connect(func() -> void: hover_cell = -1; queue_redraw())
  ui.add_child(hit)
 # Named crew sit above the grid so each person can be selected and moved.
 var planning: bool = Sim.can_plan(state)
 if planning:
  for i: int in range(18):
   var occupants: Array = occupant_ids(i)
   for j: int in range(occupants.size()):
    crew_hit(cell_rect(i).position+Vector2(113-j*37,91),23,str(occupants[j]))
  var waiting: Array = idle_ids()
  for i: int in range(waiting.size()):
   crew_hit(Vector2(200+i*69,661),29,str(waiting[i]))
  var back: Button = Button.new()
  back.position = Vector2(32,648)
  back.size = Vector2(150,32)
  for k: String in ["normal","hover","pressed","focus"]: back.add_theme_stylebox_override(k,StyleBoxEmpty.new())
  back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
  back.tooltip_text = trk("crew_selected")
  back.pressed.connect(return_selected)
  ui.add_child(back)
 var c: Dictionary = state.cells[selected]
 if c.kind != "":
  icon_button("upgrade",Rect2(765,739,55,40),trk("upgrade",[int(Sim.R.upgrade)*int(c.level)]),upgrade,false,not planning or c.kind=="shield" or int(c.level)>=int(Sim.R.max_level) or int(state.material)<int(Sim.R.upgrade)*int(c.level))
  icon_button("undo",Rect2(831,739,55,40),trk("remove"),func() -> void: assign(-1),false,not planning or int(c.crew)==0)
 for i: int in range(Sim.CONFIG.facilities.size()):
  var kind: String = str(Sim.CONFIG.facilities[i])
  var cost: int = int(Sim.R.shield_cost if kind=="shield" else Sim.R.build)
  var hint: String = facility_name(kind)+"\n"+trk(kind+"_desc")+"\n"+trk("build_cost",[cost])
  icon_button(kind,Rect2(938+(i%4)*95,397+(i/4)*78,86,68),hint,func() -> void: choose_build(kind),build_kind==kind,not planning or int(state.material)<cost or (kind=="shield" and bool(state.shield)))
 var phase: String = str(state.get("phase","morning"))
 # Shelter follows the morning being planned. Night has already moved day forward.
 if phase != "night" and Sim.event(state) == "flare":
  button(trk("shelter_on") if bool(state.shelter) else trk("shelter"),Rect2(938,260,371,42),toggle_shelter,bool(state.shelter),not planning)
 var shield_tip: Control = Control.new()
 shield_tip.position = Vector2(620,718)
 shield_tip.size = Vector2(130,18)
 shield_tip.tooltip_text = trk("unlock_shield_tip")
 var crops_tip: Control = Control.new()
 crops_tip.position = Vector2(620,736)
 crops_tip.size = Vector2(130,18)
 crops_tip.tooltip_text = trk("unlock_crops_tip")
 ui.add_child(shield_tip)
 ui.add_child(crops_tip)
 var action_key: String = "start_day"
 if phase == "day": action_key = "see_results"
 elif phase == "night": action_key = "next_morning"
 button(trk(action_key),Rect2(930,659,390,69),advance_phase,true,bool(state.over))
 icon_button("book",Rect2(32,739,55,40),trk("sources"),func() -> void: open_modal("sources"))
 icon_button("undo",Rect2(99,739,55,40),trk("restart"),func() -> void: open_modal("restart"))
 if modal != "": add_modal_controls()
 queue_redraw()
func cell_rect(i: int) -> Rect2:
 return Rect2(32+(i%6)*144,180+(i/6)*146,144,146)
func select_cell(i: int) -> void:
 click_sound()
 if bool(state.over): return
 selected = i
 if not Sim.can_plan(state):
  if selected_crew != "" or build_kind != "": note("plan_locked")
  else: refresh()
  return
 var cell: Dictionary = state.cells[i]
 if selected_crew != "":
  if cell.kind == "" or cell.kind == "shield": refresh(); return
  if Sim.crew_cell(state, selected_crew) == i:
   selected_crew = ""
   crew_source = -2
   refresh()
   return
  if int(cell.crew)>=int(Sim.R.capacity): note("full"); return
  var moved: Dictionary = Sim.move(state, selected_crew, i)
  if Sim.crew_cell(moved, selected_crew) != i: refresh(); return
  state = moved
  selected_crew = ""
  crew_source = -2
  save_game()
  note("assigned")
  return
 if cell.kind == "" and build_kind != "":
  build(build_kind)
  return
 refresh()
func assign(amount: int) -> void:
 if bool(state.over): return
 if not Sim.can_plan(state): note("plan_locked"); return
 var c: Dictionary = state.cells[selected]
 if c.kind in ["", "shield"]: return
 selected_crew = ""
 crew_source = -2
 if amount > 0:
  var id: String = Sim.first_idle(state)
  if id == "": note("no_crew"); return
  if int(c.crew) >= int(Sim.R.capacity): note("full"); return
  state = Sim.move(state, id, selected)
  save_game()
  note("assigned")
  return
 var rid: String = Sim.last_in_cell(state, selected)
 if rid == "": return
 state = Sim.move(state, rid, -1)
 save_game()
 note("removed")
func upgrade() -> void:
 if bool(state.over): return
 if not Sim.can_plan(state): note("plan_locked"); return
 if state.cells[selected].kind in ["","shield"] or int(state.cells[selected].level)>=int(Sim.R.max_level): return
 var cost: int = int(Sim.R.upgrade)*int(state.cells[selected].level)
 if int(state.material)<cost: note("need_material"); return
 state = Sim.upgrade_at(state, selected)
 save_game()
 note("upgraded")
func build(kind: String) -> void:
 if bool(state.over): return
 if not Sim.can_plan(state): note("plan_locked"); return
 if not kind in Sim.CONFIG.facilities or state.cells[selected].kind!="": return
 if kind=="shield" and bool(state.shield): return
 var cost: int = int(Sim.R.shield_cost if kind == "shield" else Sim.R.build)
 if int(state.material)<cost: message = trk("need_material"); modal=""; refresh(); return
 state = Sim.build_at(state, selected, kind)
 modal=""
 build_kind=""
 save_game()
 note("built")
func toggle_shelter() -> void:
 if not Sim.can_plan(state): note("plan_locked"); return
 var active: bool = not bool(state.shelter)
 state = Sim.set_shelter(state, active)
 save_game()
 note("sheltered" if active else "unsheltered")
func advance_phase() -> void:
 if bool(state.over): return
 var phase: String = str(state.get("phase","morning"))
 selected_crew = ""
 crew_source = -2
 build_kind = ""
 if phase == "morning":
  state = Sim.begin_day(state)
  message = trk("day_started")
 elif phase == "day":
  var sheltered: bool = bool(state.shelter)
  var ev: String = Sim.event(state)
  var was_won: bool = bool(state.won)
  state = Sim.resolve_day(state)
  message = outcome_message()
  if bool(state.get("shortage", false)): message = trk("shortage")+" "+message
  if ev == "flare": message = trk("protected" if sheltered else "damaged")+" "+message
  if bool(state.over): modal = "loss"
  elif bool(state.won) and not was_won: modal = "win"
 elif phase == "night":
  state = Sim.wake(state)
  message = trk("daily",[int(state.day)])
 save_game()
 refresh()
func finish_day() -> void:
 for _step: int in range(3):
  advance_phase()
  if str(state.get("phase","morning")) == "morning": break
func open_modal(key: String) -> void:
 modal = key
 refresh()
func close_modal() -> void:
 modal = ""
 refresh()
func restart() -> void:
 state = Sim.initial()
 selected=1
 crew_source=-2
 selected_crew=""
 build_kind=""
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
 if modal=="sources":
  button(trk("source_flare"),Rect2(315,550,360,42),func() -> void: OS.shell_open("https://science.nasa.gov/blogs/solar-cycle-25/2024/05/14/strong-solar-flare-erupts-from-sun-15/"))
  button(trk("close"),Rect2(800,631,235,46),close_modal)
 elif modal in ["loss","restart"]:
  button(trk("restart_confirm"),Rect2(315,610,350,52),restart,true)
  button(trk("cancel"),Rect2(700,610,335,52),close_modal)
 else:
  button(trk("continue" if modal=="win" else "close"),Rect2(750,631,285,46),close_modal,true)
func text_at(text: String, x: float, y: float, size_px: int = 24, color: Color = INK, width: float = -1) -> void:
 draw_string(font,Vector2(x,y),text,HORIZONTAL_ALIGNMENT_LEFT,width,size_px,color)
func wrap_lines(text: String, width: float, size_px: int) -> PackedStringArray:
 var lines: PackedStringArray=PackedStringArray()
 var current: String=""
 for i: int in range(text.length()):
  var trial: String=current+text.substr(i,1)
  if current!="" and font.get_string_size(trial,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x>width:
   lines.append(current)
   current=text.substr(i,1)
  else: current=trial
 if current!="": lines.append(current)
 return lines
func centered(text: String, rect: Rect2, size_px: int = 22, color: Color = INK) -> void:
 var w: float = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x
 text_at(text,rect.position.x+(rect.size.x-w)/2,rect.position.y+rect.size.y/2+size_px*0.36,size_px,color)
func icon(kind: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
 if icons.has(kind): draw_texture_rect(icons[kind],rect,false,tint)
func draw_person(pos: Vector2, radius: float, id: String) -> void:
 coin(pos, radius)
 if selected_crew == id: draw_arc(pos, radius+3, 0, TAU, 40, TEAL, 3, true)
 var label: String = trk("crew_"+id)
 var size_px: int = 12 if radius < 26 else 14
 var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
 text_at(label, pos.x-w*0.5, pos.y+radius+size_px+1, size_px, INK)
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
 text_at(trk("day",[Sim.shown_day(state)]),32,56,37,RUST)
 text_at(trk("phase_"+str(state.get("phase","morning"))),32,168,16,TEAL)
 var keys: Array[String]=["survival","power","material","science"]
 for i: int in range(keys.size()):
  var x: float=265+i*245
  var key: String=keys[i]
  icon(key if key!="science" else "star",Rect2(x,15,37,37))
  text_at(str(int(state[key])),x+47,51,32,INK if int(state[key])>3 else RUST)

  draw_line(Vector2(x+169,21),Vector2(x+169,55),LINE,1.5,true)
 if not saved: text_at(trk("save_failed"),1080,70,14,RUST)
 draw_line(Vector2(28,74),Vector2(1326,74),LINE,2,true)
 icon("habitat",Rect2(34,91,64,64))
 text_at(trk("title"),113,145,41,RUST)
 text_at(trk("mission"),391,151,20)
 var phase_now: String=str(state.get("phase","morning"))
 var predicted: Dictionary=state if phase_now=="night" else Sim.calculate(state)
 for i: int in range(18):
  var rect: Rect2=cell_rect(i)
  var c: Dictionary=state.cells[i]
  if crew_source!=-2 and c.kind not in ["","shield"] and int(c.crew)<int(Sim.R.capacity):
   draw_style_box(style(Color("e1ebdc"),TEAL,2,9),rect.grow(-4))
  if build_kind!="" and c.kind=="":
   draw_style_box(style(Color("eef0dc"),TEAL,1,9),rect.grow(-4))
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
   if c.kind=="greenhouse":
    text_at(str(int(c.get("progress",0)))+"/"+str(int(Sim.R.plant_days)),rect.position.x+70,rect.position.y+23,13,TEAL)
   text_at(str(int(c.level)),rect.position.x+8,rect.position.y+23,14,MUTED)
   var people: Array=occupant_ids(i)
   for j: int in range(people.size()):
    draw_person(rect.position+Vector2(113-j*37,91),23,str(people[j]))
 draw_style_box(style(Color.TRANSPARENT,RUST,2,12),Rect2(31,179,866,440))
 text_at(trk("waiting"),38,675,24)
 var waiting_ids: Array=idle_ids()
 for i: int in range(waiting_ids.size()):
  draw_person(Vector2(200+i*69,661),29,str(waiting_ids[i]))
 if selected_crew != "":
  var spec: String = Sim.specialty(selected_crew)
  text_at(trk("crew_detail",[trk("crew_"+selected_crew), trk("spec_"+spec), trk("spec_bonus_"+spec)]),168,730,14,TEAL,440)
 else:
  text_at(trk("crew_hint"),168,730,14,TEAL,440)
 # Health stays separate from the resource decisions.
 text_at(trk("health")+" "+str(int(state.health))+"%",650,659,18,TEAL)
 draw_style_box(style(Color("e9ddc8"),Color.TRANSPARENT,0,5),Rect2(649,674,225,10))
 draw_style_box(style(TEAL,Color.TRANSPARENT,0,5),Rect2(649,674,225*clampf(float(state.health)/100,0,1),10))
 text_at(trk("goal",[int(state.science),mini(int(state.day)-1,15)]),630,712,16,MUTED)
 draw_style_box(style(Color.TRANSPARENT,LINE,2,16),Rect2(920,143,410,189))
 draw_style_box(style(Color("f1d7b7"),Color.TRANSPARENT,0,5),Rect2(960,156,331,32))
 centered(trk("event"),Rect2(960,154,331,34),23)
 var ev: String=Sim.shown_event(state)
 icon("sun" if ev in ["sun","calm"] else ("storm" if ev=="dust" else "shield"),Rect2(941,194,56,56))
 text_at(trk(ev),1006,221,24,RUST if ev=="flare" else INK)
 text_at(trk(ev+"_desc"),941,251,15,INK,360)
 if phase_now=="night":
  draw_line(Vector2(942,267),Vector2(1309,267),LINE,1.5)
  text_at(trk("next_morning_weather")+trk(Sim.morning_ahead(state)),944,292,18,INK,360)
  if ev=="flare": text_at(trk("archive"),944,318,12,MUTED,360)
 elif ev!="flare":
  draw_line(Vector2(942,267),Vector2(1309,267),LINE,1.5)
  text_at(trk("tomorrow")+trk(Sim.morning_ahead(state)),944,299,19,INK,360)
 else: text_at(trk("archive"),942,320,12,MUTED,360)
 draw_style_box(style(Color.TRANSPARENT,LINE,2,16),Rect2(920,350,410,225))
 text_at(trk("build_title"),940,383,23)
 text_at(trk("build_hint"),940,571,16,TEAL)
 var cell: Dictionary=state.cells[selected]
 if cell.kind!="":
  icon(str(cell.kind),Rect2(180,741,37,37))
  var detail: String=facility_name(str(cell.kind))+"  "+trk("level",[int(cell.level)])
  if cell.kind=="greenhouse":
   detail += "  "+trk("plant_progress",[int(Sim.R.plant_days)-int(cell.get("progress",0))])
  text_at(detail,228,766,16,INK,390)
 # Morning and daytime show the same pure forecast that night will apply once.
 var report: Dictionary=state.report if phase_now=="night" and state.get("report") is Dictionary else {}
 text_at(trk("outcome" if phase_now=="night" else "forecast"),940,606,17,MUTED)
 for i: int in range(keys.size()):
  var k: String=keys[i]
  var delta: int=int(report.get(k,0)) if phase_now=="night" else int(predicted[k])-int(state[k])
  var x: float=940+i*94
  icon(k if k!="science" else "star",Rect2(x,619,27,27))
  text_at(("+" if delta>=0 else "")+str(delta),x+33,642,23,TEAL if delta>=0 else RUST)
 text_at(trk("unlock_shield_line",[unlock_label("shielding")]),624,732,12,MUTED,130)
 text_at(trk("unlock_crops_line",[unlock_label("crops")]),624,750,12,MUTED,130)
 if phase_now=="night":
  var story: PackedStringArray=wrap_lines(outcome_message(),380,14)
  for line_i: int in range(mini(story.size(),3)):
   text_at(story[line_i],940,748+line_i*16,14,RUST,380)
 elif bool(predicted.shortage): text_at("! "+trk("shortage"),940,746,14,RUST,380)
 elif bool(predicted.over): text_at("! "+trk("loss_title"),940,746,14,RUST,380)
 if phase_now!="night": text_at(message,32,794,14,RUST,880)
func draw_modal() -> void:
 # This signal belongs to the top canvas, so draw using that canvas.
 var canvas: Control=ui.get_child(ui.get_child_count()-1) as Control
 for child: Node in ui.get_children():
  if child is Control and child.has_signal("draw") and child.mouse_filter==Control.MOUSE_FILTER_IGNORE and not child is ColorRect: canvas=child
 if not is_instance_valid(canvas): return
 var title_key: String=modal+"_title"
 var body_key: String=modal+"_body"
 canvas.draw_string(font,Vector2(315,154),trk(title_key),HORIZONTAL_ALIGNMENT_LEFT,730,30,RUST)
 var lines: PackedStringArray=trk(body_key).split("\n")
 for i: int in range(lines.size()):
  canvas.draw_string(font,Vector2(315,211+i*26),lines[i],HORIZONTAL_ALIGNMENT_LEFT,730,19,INK)
