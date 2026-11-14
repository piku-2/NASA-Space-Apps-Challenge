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
var at_title: bool = true
var title_canvas: Control
var build_kind: String = ""
# -2: no crew selected; -1: standby; otherwise a source cell.
var crew_source: int = -2
var selected_crew: String = ""
var message: String = ""
var saved: bool = true
var ui: Control
var font: FontFile = preload("res://ui_assets/fonts/SourceHanSansJP-Regular.otf")
var icons: Dictionary = {}
var facility_cards: Dictionary = {}
var hover_cell: int = -1
var tick: float = 0.0
var fx_t: float = 1.0
var fx_playing: bool = false
var motion_frozen: bool = false
var quip_badge: Dictionary = {}
var keep_preview: Dictionary = {}
var cover_preview: Dictionary = {}
var sound: AudioStreamPlayer
# Juice layer. Everything below is presentation only and never touches the rules.
var sfx: AudioStreamPlayer
var sfx_cache: Dictionary = {}
var floaters: Array = []
var sparks: Array = []
var hop: Dictionary = {}
var forecast_roll: Dictionary = {}
var banner_t: float = 1.0
var banner_ids: Array = []
var streak: int = 0
var streak_chip_t: float = 1.0
var flare_alert_t: float = 1.0
const STAGE_SECONDS: float = 0.5
const BANNER_SECONDS: float = 2.8
const STREAK_CHIP_SECONDS: float = 2.2
const FLARE_ALERT_SECONDS: float = 2.4
const GOLD: Color = Color("c9892a")
# Kenney CC0 sounds (see assets/sfx/CREDITS.md). [path, volume offset dB]
const SFX_FILES: Dictionary = {
 "place": ["res://assets/sfx/place.ogg", 0.0],
 "expert": ["res://assets/sfx/expert.ogg", -2.0],
 "power": ["res://assets/sfx/reveal_power.ogg", 0.0],
 "material": ["res://assets/sfx/reveal_material.ogg", -7.0],
 "survival": ["res://assets/sfx/reveal_survival.ogg", 0.0],
 "science": ["res://assets/sfx/reveal_science.ogg", 0.0],
 "heal": ["res://assets/sfx/reveal_heal.ogg", -6.0],
 "damage": ["res://assets/sfx/reveal_damage.ogg", -3.0],
 "protect": ["res://assets/sfx/protect.ogg", -5.0],
 "page": ["res://assets/sfx/reveal_discovery.ogg", 8.0],
 "discovery": ["res://assets/sfx/milestone.ogg", -2.0],
 "streak": ["res://assets/sfx/streak.ogg", -2.0],
 "alarm": ["res://assets/sfx/flare_alert.ogg", -3.0]
}
var fx_rng: RandomNumberGenerator = RandomNumberGenerator.new()
const SAVE_PATH: String = "user://mars_notebook_v1.json"
func _ready() -> void:
 theme = Theme.new()
 theme.default_font = font
 theme.default_font_size = 18
 for key: String in ["solar","water","greenhouse","lab","habitat","mine","shield","crew","sun","storm","power","material","star","flag","survival","upgrade","undo","help","book"]:
  icons[key] = load("res://ui_assets/"+key+".svg")
 if ResourceLoader.exists("res://ui_assets/logo.png"):
  icons["logo"] = load("res://ui_assets/logo.png")
 for fkey: String in ["solar","water","greenhouse","lab","habitat","mine","shield"]:
  var jpg_path: String = "res://ui_assets/facilities/facility_" + fkey + ".jpg"
  var png_path: String = "res://ui_assets/facilities/facility_" + fkey + ".png"
  if ResourceLoader.exists(jpg_path): facility_cards[fkey] = load(jpg_path)
  elif ResourceLoader.exists(png_path): facility_cards[fkey] = load(png_path)
 state = Sim.initial()
 load_game()
 set_language(language)
 sound = AudioStreamPlayer.new()
 add_child(sound)
 sfx = AudioStreamPlayer.new()
 sfx.volume_db = -4.0
 add_child(sfx)
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
 if f != null: f.store_string(JSON.stringify({"version":3,"language":language,"state":state,"streak":streak}))
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
 streak = maxi(0, int(data.get("streak", 0)))
 reset_feedback()
 # A loaded night is already settled. Do not replay the reveal.
 fx_t = 1.0
 fx_playing = false
 quip_badge = {}
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
 if bool(report.get("cover_committed", false)):
  parts.append(trk("night_cover",[int(report.get("cover_power",0)), int(report.get("damage",0))]))
 elif bool(report.get("sheltered", false)) and str(report.get("event","")) == "flare":
  parts.append(trk("night_shelter"))
 elif int(report.get("damage",0)) > 0:
  var harm_key: String = "night_keep_hit" if str(report.get("event","")) == "flare" else "outcome_damage"
  parts.append(trk(harm_key,[int(report.damage)]))
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
func button(text: String, rect: Rect2, action: Callable, primary: bool = false, disabled: bool = false, font_px: int = 20) -> Button:
 var b: Button = Button.new()
 b.text = text
 b.position = rect.position
 b.size = rect.size
 b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 b.add_theme_font_override("font",font)
 b.add_theme_font_size_override("font_size",font_px)
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
 if facility_cards.has(kind):
  b.icon = facility_cards[kind]
  b.add_theme_constant_override("icon_max_width",44)
 elif icons.has(kind):
  b.icon = icons[kind]
  b.add_theme_constant_override("icon_max_width",42)
 b.expand_icon = true
 b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
 var from_cell: int = Sim.crew_cell(state, selected_crew)
 var before: Dictionary = state
 state = Sim.move(state, selected_crew, -1)
 selected_crew = ""
 crew_source = -2
 save_game()
 show_plan_change(before, from_cell)
 note("removed")
func click_sound() -> void:
 if DisplayServer.get_name() == "headless": return
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
  icon_button(kind,Rect2(938+(i%4)*95,390+(i/4)*80,86,52),hint,func() -> void: choose_build(kind),build_kind==kind,not planning or int(state.material)<cost or (kind=="shield" and bool(state.shield)))
 var phase: String = str(state.get("phase","morning"))
 # Shelter follows the morning being planned. Night has already moved day forward.
 if phase != "night" and Sim.event(state) == "flare":
  add_flare_controls(planning)
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
 button(trk(action_key),Rect2(930,659,390,69),on_primary,true,bool(state.over))
 icon_button("book",Rect2(32,739,55,40),trk("sources"),func() -> void: open_modal("sources"))
 icon_button("undo",Rect2(99,739,55,40),trk("restart"),func() -> void: open_modal("restart"))
 if at_title: add_title_controls()
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
  var who: String = selected_crew
  var before: Dictionary = state
  state = moved
  selected_crew = ""
  crew_source = -2
  save_game()
  announce_assignment(who, i, before)
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
  var before_add: Dictionary = state
  state = Sim.move(state, id, selected)
  save_game()
  announce_assignment(id, selected, before_add)
  return
 var rid: String = Sim.last_in_cell(state, selected)
 if rid == "": return
 var before_remove: Dictionary = state
 state = Sim.move(state, rid, -1)
 save_game()
 quip_badge = {}
 show_plan_change(before_remove, selected)
 note("removed")
func upgrade() -> void:
 if bool(state.over): return
 if not Sim.can_plan(state): note("plan_locked"); return
 if state.cells[selected].kind in ["","shield"] or int(state.cells[selected].level)>=int(Sim.R.max_level): return
 var cost: int = int(Sim.R.upgrade)*int(state.cells[selected].level)
 if int(state.material)<cost: note("need_material"); return
 var before: Dictionary = state
 state = Sim.upgrade_at(state, selected)
 save_game()
 show_plan_change(before, selected)
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
  quip_badge = {}
 elif phase == "day":
  var sheltered: bool = bool(state.shelter)
  var ev: String = Sim.event(state)
  var was_won: bool = bool(state.won)
  state = Sim.resolve_day(state)
  message = outcome_message()
  if bool(state.get("shortage", false)): message = trk("shortage")+" "+message
  if ev == "flare": message = trk("protected" if sheltered else "damaged")+" "+message
  if str(state.get("phase","")) == "night":
   fx_t = 0.0
   fx_playing = true
   update_streak()
  if bool(state.over): modal = "loss"
  elif bool(state.won) and not was_won: modal = "win"
 elif phase == "night":
  state = Sim.wake(state)
  fx_playing = false
  fx_t = 1.0
  reset_feedback()
  message = trk("daily",[int(state.day)])
  if Sim.event(state) == "flare":
   flare_alert_t = 0.0
   play_sfx("alarm")
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
 quip_badge = {}
 fx_t = 1.0
 fx_playing = false
 streak = 0
 reset_feedback()
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
func add_title_controls() -> void:
 var shade: ColorRect = ColorRect.new()
 shade.color = PAPER
 shade.size = Vector2(1360,800)
 ui.add_child(shade)
 title_canvas = Control.new()
 title_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
 title_canvas.draw.connect(draw_title)
 ui.add_child(title_canvas)
 button(trk("language"),Rect2(1165,84,155,38),func() -> void:
  set_language("en" if language == "ja" else "ja")
  save_game()
  refresh())
 button(trk("start_game"),Rect2(505,536,350,64),func() -> void:
  at_title = false
  refresh(),true,false,26)
func draw_title() -> void:
 if not is_instance_valid(title_canvas): return
 title_canvas.draw_texture_rect(icons["habitat"],Rect2(618,140,124,124),false)
 title_text(trk("title"),356,64,RUST)
 title_text(trk("subtitle"),404,20,MUTED)
 title_text(trk("mission"),486,22,INK)
 title_text(trk("footer"),762,13,MUTED)
func title_text(text: String, y: float, size_px: int, color: Color) -> void:
 var w: float = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x
 title_canvas.draw_string(font,Vector2((1360-w)/2,y),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)
func announce_assignment(id: String, cell: int, before: Dictionary = {}) -> void:
 if id == "" or cell < 0 or cell >= state.cells.size():
  refresh()
  return
 var kind: String = str(state.cells[cell].kind)
 var matched: bool = Sim.specialty_matches(id, kind)
 var bonus: int = Sim.expert_bonus(kind) if matched else 0
 quip_badge = {"cell": cell, "matched": matched, "bonus": bonus, "id": id}
 if not before.is_empty(): show_plan_change(before, cell)
 hop[id] = 0.0
 if matched: celebrate_expert(id, cell, bonus)
 else: play_sfx("place")
 if matched: message = trk("quip_"+id)+"  "+trk("bonus_words",[bonus])
 else: message = trk("quip_other",[trk("crew_"+id), facility_name(kind)])
 refresh()
func choose_cover(active: bool) -> void:
 if not Sim.can_plan(state):
  note("plan_locked")
  return
 if bool(state.shelter):
  note("choice_while_shelter")
  return
 var preview: Dictionary = Sim.project(state, active)
 state = Sim.set_flare_cover(state, active)
 save_game()
 if active and not bool(preview.get("report", {}).get("cover_committed", false)):
  message = trk("choice_cover_unready",[int(Sim.R.flare_cover_power)])
  refresh()
  return
 note("choice_cover_set" if active else "choice_keep_set")
func add_flare_controls(planning: bool) -> void:
 var lines: Dictionary = flare_choice_lines()
 var sheltered: bool = bool(state.shelter)
 var keep_on: bool = not sheltered and not bool(state.get("flare_cover", false))
 var cover_on: bool = not sheltered and bool(state.get("flare_cover", false))
 var keep_b: Button = button(trk("choice_keep_btn"), Rect2(932,308,124,36), func() -> void: choose_cover(false), keep_on, not planning or sheltered, 15)
 var cover_b: Button = button(trk("choice_cover_btn"), Rect2(1062,308,140,36), func() -> void: choose_cover(true), cover_on, not planning or sheltered, 15)
 var shelter_b: Button = button(trk("shelter_short_on") if sheltered else trk("shelter_short"), Rect2(1208,308,112,36), toggle_shelter, sheltered, not planning, 15)
 keep_b.tooltip_text = str(lines.get("keep_tip",""))
 cover_b.tooltip_text = str(lines.get("cover_tip",""))
 shelter_b.tooltip_text = trk("shelter_info")
func ensure_previews() -> void:
 if state.is_empty() or str(state.get("phase","")) == "night" or Sim.event(state) != "flare":
  keep_preview = {}
  cover_preview = {}
  return
 keep_preview = Sim.project(state, false)
 cover_preview = Sim.project(state, true)
func signed(n: int) -> String:
 if n >= 0: return "+"+str(n)
 return "−"+str(absi(n))
func flare_choice_lines() -> Dictionary:
 ensure_previews()
 if keep_preview.is_empty() or cover_preview.is_empty(): return {}
 var keep_sci: int = int(keep_preview.science)-int(state.science)
 var keep_hp: int = int(keep_preview.health)-int(state.health)
 var cover_sci: int = int(cover_preview.science)-int(state.science)
 var cover_hp: int = int(cover_preview.health)-int(state.health)
 var ready: bool = bool(cover_preview.report.get("cover_committed", false))
 var extra: int = int(cover_preview.report.get("cover_power", 0)) if ready else int(Sim.R.flare_cover_power)
 var cover_line: String = trk("choice_cover_stat",[extra, signed(cover_sci), signed(cover_hp)]) if ready else trk("choice_cover_blocked",[int(Sim.R.flare_cover_power)])
 return {
  "keep": trk("choice_keep_stat",[signed(keep_sci), signed(keep_hp)]),
  "cover": cover_line,
  "ready": ready,
  "keep_tip": trk("choice_keep_tip",[signed(keep_sci), signed(keep_hp)]),
  "cover_tip": trk("choice_cover_tip",[int(Sim.R.flare_cover_power), signed(cover_sci), signed(cover_hp)])
 }
func shown_amount(key: String) -> int:
 var settled: int = int(state.get(key, 0))
 if str(state.get("phase","")) != "night": return settled
 var report: Dictionary = state.report if state.get("report") is Dictionary else {}
 if not report.has(key): return settled
 var fade: float = stage_progress(key)
 return int(round(lerpf(float(settled-int(report[key])), float(settled), fade)))
# Visual only. This never calls calculate, resolve, or save.
func presentation_step(delta: float) -> void:
 if motion_frozen or not fx_playing: return
 var stages: Array = reveal_stages()
 var before_stage: int = int(fx_t*stages.size()) if fx_t > 0.0 else -1
 fx_t = minf(1.0, fx_t+delta/reveal_seconds())
 var now_stage: int = mini(int(fx_t*stages.size()), stages.size()-1)
 # Each step enters its own row once, even when a long frame skips ahead.
 for i: int in range(maxi(before_stage+1, 0), now_stage+1):
  on_stage_enter(str(stages[i]))
 if fx_t >= 1.0:
  fx_playing = false
  finish_reveal()
 queue_redraw()
func pose_feedback(anim: float, motion: float) -> void:
 motion_frozen = true
 tick = motion
 fx_t = clampf(anim, 0.0, 1.0)
 fx_playing = false
 queue_redraw()
func _process(delta: float) -> void:
 presentation_step(delta)
 feedback_step(delta)
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
func crew_color(id: String) -> Color:
 match id:
  "rikuto": return Color("d97724")
 match Sim.specialty(id):
  "solar": return Color("e0a030")
  "water": return Color("3e7c78")
  "greenhouse": return Color("5c8a3e")
  "lab": return Color("5d6eae")
  "mine": return Color("8a5a3a")
  _: return MUTED
func draw_person(base: Vector2, radius: float, id: String) -> void:
 var pos: Vector2 = base - Vector2(0, hop_offset(id))
 coin(pos, radius)
 draw_circle(pos+Vector2(radius*0.55, -radius*0.55), maxf(4.0, radius*0.22), crew_color(id))
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
  var amount: int = shown_amount(key)
  icon(key if key!="science" else "star",Rect2(x,15,37,37))
  text_at(str(amount),x+47,51,32,INK if amount>3 else RUST)

  draw_line(Vector2(x+169,21),Vector2(x+169,55),LINE,1.5,true)
 if not saved: text_at(trk("save_failed"),1080,70,14,RUST)
 draw_line(Vector2(28,74),Vector2(1326,74),LINE,2,true)
 icon("logo" if icons.has("logo") else "habitat",Rect2(34,91,64,64))
 text_at(trk("title"),113,145,41,RUST)
 text_at(trk("mission"),391,151,20)
 var phase_now: String=str(state.get("phase","morning"))
 var predicted: Dictionary=state if phase_now=="night" else Sim.calculate(state)
 draw_base()
 for i: int in range(18):
  var rect: Rect2=cell_rect(i)
  var c: Dictionary=state.cells[i]
  draw_rect(rect.grow(-7), Color("f7e0d0"))
  if i%2==0:
   var crater: Vector2=rect.position+Vector2(118, 36)
   draw_circle(crater, 5, Color(0.62, 0.34, 0.22, 0.16))
   draw_arc(crater, 5, 0, TAU, 12, Color(0.45, 0.22, 0.14, 0.28), 1, true)
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
   var kind_str: String = str(c.kind)
   if facility_cards.has(kind_str):
    var cw: float = 90.0
    var ch: float = 134.0
    var cpos: Vector2 = Vector2(rect.position.x + (rect.size.x - cw) * 0.5, rect.position.y + 6.0)
    draw_texture_rect(facility_cards[kind_str], Rect2(cpos, Vector2(cw, ch)), false)
   else:
    draw_facility_mark(kind_str, rect, int(c.crew))
    icon(kind_str, Rect2(rect.position+Vector2(27,13), Vector2(90,90)))
   if c.kind=="greenhouse":
    var prog_text: String = str(int(c.get("progress",0)))+"/"+str(int(Sim.R.plant_days))
    var prog_pill: Rect2 = Rect2(rect.position.x+82, rect.position.y+6, 38, 18)
    draw_style_box(style(Color(0.98,0.96,0.9,0.9), TEAL, 1, 4), prog_pill)
    centered(prog_text, prog_pill, 11, TEAL)
   var lvl_pill: Rect2 = Rect2(rect.position.x+6, rect.position.y+6, 24, 18)
   draw_style_box(style(Color(0.98,0.96,0.9,0.9), LINE, 1, 4), lvl_pill)
   centered("L"+str(int(c.level)), lvl_pill, 11, INK)
   draw_assignment_chip(i, rect)
   draw_harvest_pulse(i, rect)
   var people: Array=occupant_ids(i)
   for j: int in range(people.size()):
    draw_person(rect.position+Vector2(113-j*37,91),23,str(people[j]))
 draw_night_tint()
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
 var health_now: int = shown_amount("health")
 text_at(trk("health")+" "+str(health_now)+"%",650,659,18,TEAL)
 draw_style_box(style(Color("e9ddc8"),Color.TRANSPARENT,0,5),Rect2(649,674,225,10))
 draw_style_box(style(TEAL,Color.TRANSPARENT,0,5),Rect2(649,674,225*clampf(float(health_now)/100,0,1),10))
 text_at(trk("goal",[shown_amount("science"),mini(Sim.shown_day(state),15)]),630,712,16,MUTED)
 var ev: String=Sim.shown_event(state)
 var flare_choice: bool = phase_now!="night" and ev=="flare"
 draw_style_box(style(Color.TRANSPARENT,LINE,2,16),Rect2(920,143,410,220 if flare_choice else 189))
 draw_style_box(style(Color("f1d7b7"),Color.TRANSPARENT,0,5),Rect2(960,156,331,32))
 centered(trk("event"),Rect2(960,154,331,34),23)
 var event_icon: float = 40.0 if flare_choice else 56.0
 icon("sun" if ev in ["sun","calm"] else ("storm" if ev=="dust" else "shield"),Rect2(941,192,event_icon,event_icon))
 text_at(trk(ev),990 if flare_choice else 1006,216 if flare_choice else 221,22 if flare_choice else 24,RUST if ev=="flare" else INK)
 if flare_choice: draw_flare_choice()
 else:
  text_at(trk(ev+"_desc"),941,251,15,INK,360)
  if phase_now=="night":
   draw_line(Vector2(942,267),Vector2(1309,267),LINE,1.5)
   text_at(trk("next_morning_weather")+trk(Sim.morning_ahead(state)),944,292,18,INK,360)
   if ev=="flare": text_at(trk("archive"),944,318,12,MUTED,360)
  elif ev!="flare":
   draw_line(Vector2(942,267),Vector2(1309,267),LINE,1.5)
   text_at(trk("tomorrow")+trk(Sim.morning_ahead(state)),944,299,19,INK,360)
  else: text_at(trk("archive"),942,320,12,MUTED,360)
 draw_style_box(style(Color.TRANSPARENT,LINE,2,16),Rect2(920,366 if flare_choice else 350,410,206 if flare_choice else 225))
 text_at(trk("build_title"),940,383,23)
 for i: int in range(Sim.CONFIG.facilities.size()):
  var bkind: String = str(Sim.CONFIG.facilities[i])
  var bcost: int = int(Sim.R.shield_cost if bkind=="shield" else Sim.R.build)
  var bx: float = 938+(i%4)*95
  var by: float = 390+(i/4)*80
  var bname: String = facility_name(bkind)
  var name_w: float = font.get_string_size(bname,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
  text_at(bname,bx+(86-name_w)/2,by+65,11,INK)
  var cost_text: String = trk("material")+" "+str(bcost)
  var cost_w: float = font.get_string_size(cost_text,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
  text_at(cost_text,bx+(86-cost_w)/2,by+78,11,RUST if int(state.material)<bcost else MUTED)
 text_at(trk("build_hint"),940,571,16,TEAL)
 var cell: Dictionary=state.cells[selected]
 if cell.kind!="":
  var k_sel: String = str(cell.kind)
  if facility_cards.has(k_sel):
   draw_texture_rect(facility_cards[k_sel],Rect2(182,736,26,38),false)
  else:
   icon(k_sel,Rect2(180,741,37,37))
  var detail: String=facility_name(k_sel)+"  "+trk("level",[int(cell.level)])
  if cell.kind=="greenhouse":
   detail += "  "+trk("plant_progress",[int(Sim.R.plant_days)-int(cell.get("progress",0))])
  text_at(detail,228,766,16,INK,390)
 # Morning and daytime show the same pure forecast that night will apply once.
 var report: Dictionary=state.report if phase_now=="night" and state.get("report") is Dictionary else {}
 var fade: float = smoothstep(0.0, 1.0, clampf(fx_t, 0.0, 1.0)) if phase_now=="night" else 1.0
 var rise: float = (1.0-fade)*8.0 if phase_now=="night" else 0.0
 text_at(trk("outcome" if phase_now=="night" else "forecast"),940,606,17,MUTED)
 for i: int in range(keys.size()):
  var k: String=keys[i]
  var delta: int=int(report.get(k,0)) if phase_now=="night" else int(predicted[k])-int(state[k])
  var x: float=940+i*94
  var col_fade: float = fade
  var col_rise: float = rise
  var flash: float = 0.0
  var shown: int = delta
  if phase_now=="night":
   # Night columns wait for their own turn, then count up.
   var p: float = stage_progress(k)
   col_fade = 0.25+0.75*p
   col_rise = (1.0-p)*8.0
   shown = int(round(float(delta)*p))
  else:
   shown = rolled(k, delta)
   flash = float(forecast_roll[k].flash)
  var delta_color: Color = (TEAL if delta>=0 else RUST)
  if phase_now=="night" and delta>0 and streak>=2: delta_color = GOLD
  delta_color.a = col_fade
  if flash > 0.0: draw_style_box(style(Color(delta_color, 0.18*flash), Color.TRANSPARENT, 0, 8), Rect2(x-3, 615, 90, 34))
  icon(k if k!="science" else "star",Rect2(x,619-col_rise,27,27), Color(1,1,1,col_fade))
  text_at(("+" if shown>=0 else "")+str(shown),x+33,642-col_rise,23+int(round(4.0*flash)),delta_color)
 var shield_on: bool = int(state.science) >= int(Sim.R.unlock_shield_at)
 var crops_on: bool = int(state.science) >= int(Sim.R.unlock_plant_at)
 text_at(trk("unlock_shield_line",[unlock_label("shielding")]),624,732,12,TEAL if shield_on else MUTED,130)
 text_at(trk("unlock_crops_line",[unlock_label("crops")]),624,750,12,TEAL if crops_on else MUTED,130)
 if shield_on: icon("star",Rect2(606,721,14,14))
 if crops_on: icon("star",Rect2(606,739,14,14))
 if phase_now=="night": draw_night_summary(fade)
 elif bool(predicted.shortage): text_at("! "+trk("shortage"),940,746,14,RUST,380)
 elif bool(predicted.over): text_at("! "+trk("loss_title"),940,746,14,RUST,380)
 if phase_now!="night": text_at(message,32,794,14,RUST,880)
 draw_feedback_layer()
func draw_base() -> void:
 draw_rect(Rect2(32, 180, 864, 438), Color("e39b78"))
func draw_facility_mark(kind: String, rect: Rect2, staff: int) -> void:
 if staff <= 0 and kind != "solar" and kind != "habitat": return
 var origin: Vector2 = rect.position + Vector2(16, 86)
 match kind:
  "solar":
   draw_line(origin, origin+Vector2(14, -16), Color("e0a030"), 2, true)
   draw_line(origin+Vector2(8, 0), origin+Vector2(18, -10), Color("e0a030"), 2, true)
  "water":
   draw_circle(origin, 4, Color("3e7c78"))
   draw_circle(origin+Vector2(10, -8), 3, Color("7eb8b4"))
  "greenhouse":
   draw_arc(origin+Vector2(6, 0), 10, PI, TAU, 10, Color("5c8a3e"), 2, true)
  "lab":
   draw_line(origin, origin+Vector2(8, -8), Color("5d6eae"), 2, true)
   draw_line(origin+Vector2(8, -8), origin+Vector2(16, 0), Color("5d6eae"), 2, true)
  "mine":
   draw_line(origin, origin+Vector2(12, -14), Color("8a5a3a"), 2, true)
  "habitat":
   var dome_c: Vector2 = rect.position + Vector2(72, 62)
   var pts: PackedVector2Array = PackedVector2Array()
   for step: int in range(14):
    var angle: float = PI + PI * float(step) / 13.0
    pts.append(dome_c + Vector2(cos(angle), sin(angle)) * 24.0)
   draw_colored_polygon(pts, Color("fbf6ee"))
   draw_polyline(pts, Color("c47858"), 2.0, true)
   icon("flag", Rect2(dome_c + Vector2(6, -36), Vector2(16, 16)))
  "shield":
   draw_arc(origin+Vector2(8, 4), 12, PI, TAU, 12, TEAL, 2, true)
func draw_assignment_chip(index: int, rect: Rect2) -> void:
 if int(quip_badge.get("cell", -2)) != index: return
 var matched: bool = bool(quip_badge.get("matched", false))
 var label: String = trk("bonus_chip", [int(quip_badge.get("bonus", 0))]) if matched else trk("bonus_none")
 var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
 var pill: Rect2 = Rect2(rect.position + Vector2(6, 120), Vector2(width + 10, 18))
 draw_style_box(style(PAPER, TEAL if matched else LINE, 1, 6), pill)
 text_at(label, pill.position.x + 5, pill.position.y + 13, 13, TEAL if matched else MUTED)
func draw_harvest_pulse(index: int, rect: Rect2) -> void:
 if str(state.get("phase", "")) != "night" or not state.get("report") is Dictionary: return
 var cells: Variant = state.report.get("harvest_cells", [])
 if not cells is Array or not index in cells: return
 var hump: float = sin(stage_progress("survival") * PI)
 if hump <= 0.02: return
 var center: Vector2 = rect.position + Vector2(72, 58)
 draw_arc(center, 20.0 + hump * 18.0, 0, TAU, 28, Color(TEAL, 0.2 + hump * 0.55), 3, true)
 var label: String = "+"+str(int(state.report.get("harvest", 0)))
 text_at(label, center.x - 12, center.y - 24 - hump * 12, 16, Color(TEAL, hump))
func draw_night_tint() -> void:
 if str(state.get("phase", "")) != "night" or fx_t <= 0.0 or fx_t >= 1.0: return
 if Sim.shown_event(state) != "flare": return
 var hump: float = sin(stage_progress("health") * PI)
 var report: Dictionary = state.report if state.get("report") is Dictionary else {}
 var protected: bool = bool(report.get("sheltered", false)) or bool(state.get("shield", false)) or bool(report.get("cover_committed", false))
 var tint: Color = Color(0.24, 0.45, 0.42, 0.10 * hump) if protected else Color(0.72, 0.28, 0.16, 0.12 * hump)
 draw_rect(Rect2(32, 180, 864, 438), tint)
 if protected:
  draw_arc(Vector2(464, 390), 78, PI, TAU, 32, Color(TEAL, 0.45 * hump), 3, true)
  # Shield and habitat cells glow while the crew sighs with relief.
  for i: int in range(state.cells.size()):
   var kind: String = str(state.cells[i].kind)
   if kind == "shield" or (kind == "habitat" and bool(report.get("sheltered", false))):
    var c: Vector2 = cell_rect(i).get_center()
    draw_arc(c, 40.0 + hump * 14.0, 0, TAU, 32, Color(TEAL, 0.55 * hump), 4, true)
    draw_circle(c, 36.0, Color(TEAL, 0.10 * hump))
func draw_flare_choice() -> void:
 var lines: Dictionary = flare_choice_lines()
 if bool(state.get("shelter", false)):
  var note_lines: PackedStringArray = wrap_lines(trk("choice_shelter_note"), 360, 15)
  for i: int in range(mini(note_lines.size(), 2)):
   text_at(note_lines[i], 948, 252 + i * 20, 15, INK, 360)
  return
 var keep_fill: Color = Color("f6dfbc") if not bool(state.get("flare_cover", false)) else Color("f3e7d4")
 var cover_fill: Color = Color("d4e7de") if bool(state.get("flare_cover", false)) else Color("f3e7d4")
 draw_style_box(style(keep_fill, LINE, 1, 8), Rect2(940, 228, 180, 74))
 draw_style_box(style(cover_fill, LINE, 1, 8), Rect2(1130, 228, 180, 74))
 text_at(trk("choice_keep"), 948, 246, 14, INK, 164)
 text_at(trk("choice_cover"), 1138, 246, 14, INK, 164)
 var keep_lines: PackedStringArray = str(lines.get("keep", "")).split("\n")
 var cover_lines: PackedStringArray = str(lines.get("cover", "")).split("\n")
 var cover_ink: Color = TEAL if bool(lines.get("ready", false)) else RUST
 for i: int in range(mini(keep_lines.size(), 3)):
  text_at(keep_lines[i], 948, 264 + i * 14, 13, TEAL, 164)
 for i: int in range(mini(cover_lines.size(), 3)):
  text_at(cover_lines[i], 1138, 264 + i * 14, 13, cover_ink, 164)
func draw_night_summary(fade: float) -> void:
 var report: Dictionary = state.report if state.get("report") is Dictionary else {}
 var rows: Array = []
 if bool(report.get("cover_committed", false)):
  rows.append(["shield", trk("night_cover", [int(report.get("cover_power", 0)), int(report.get("damage", 0))]), "health"])
 elif bool(report.get("sheltered", false)) and str(report.get("event", "")) == "flare":
  rows.append(["habitat", trk("night_shelter"), "health"])
 elif int(report.get("damage", 0)) > 0:
  rows.append(["storm" if str(report.get("event", "")) == "flare" else "shield", trk("night_keep_hit" if str(report.get("event", "")) == "flare" else "outcome_damage", [int(report.damage)]), "health"])
 elif int(report.get("healed", 0)) > 0:
  rows.append(["habitat", trk("outcome_heal", [int(report.healed)]), "health"])
 if int(report.get("harvest", 0)) > 0:
  rows.append(["greenhouse", trk("outcome_harvest", [int(report.harvest)]), "survival"])
 var fresh: Variant = report.get("new_discoveries", [])
 if fresh is Array:
  for id: Variant in fresh:
   rows.append(["star", trk("discovered", [trk("unlock_"+str(id)+"_name")]), "discovery"])
 if rows.size() < 3 and int(report.get("produced_science", 0)) > 0:
  rows.append(["star", trk("outcome_science", [int(report.produced_science)]), "science"])
 if rows.size() < 3 and int(report.get("produced_material", 0)) > 0:
  rows.append(["material", trk("outcome_material", [int(report.produced_material)]), "material"])
 if rows.size() < 3 and bool(state.get("shortage", false)):
  rows.append(["power", trk("shortage"), "power"])
 if rows.is_empty(): rows.append(["book", trk("outcome_none"), "none"])
 for i: int in range(mini(rows.size(), 3)):
  var row: Array = rows[i]
  # Each line arrives with its own step of the reveal instead of all at once.
  var row_fade: float = minf(fade, stage_progress(str(row[2])))
  icon(str(row[0]), Rect2(936, 734 + i * 18, 16, 16), Color(1, 1, 1, row_fade))
  text_at(str(row[1]), 958, 748 + i * 18, 14, Color(RUST, row_fade), 360)
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
# ---------------------------------------------------------------------------
# Tempo and feedback layer (presentation only).
# Numbers come from Sim.calculate / Sim.forecast_change or the saved night report,
# so nothing here can drift from the rules.
# ---------------------------------------------------------------------------
func reset_feedback() -> void:
 floaters = []
 sparks = []
 hop = {}
 forecast_roll = {}
 banner_t = 1.0
 banner_ids = []
 streak_chip_t = 1.0
 flare_alert_t = 1.0
func night_report() -> Dictionary:
 if str(state.get("phase","")) != "night": return {}
 return state.report if state.get("report") is Dictionary else {}
func update_streak() -> void:
 var report: Dictionary = night_report()
 if int(report.get("survival", 0)) > 0 and not bool(state.get("over", false)): streak += 1
 else: streak = 0
func streak_tier() -> int:
 if streak >= 5: return 2
 if streak >= 2: return 1
 return 0
func is_streak_milestone(n: int) -> bool:
 return n == 3 or n == 5 or (n > 5 and n % 5 == 0)
func night_protected(report: Dictionary) -> bool:
 return bool(report.get("sheltered", false)) or bool(state.get("shield", false)) or bool(report.get("cover_committed", false))
func gain_color(v: int) -> Color:
 if v < 0: return RUST
 return GOLD if streak_tier() > 0 else TEAL
# --- Morning: instant placement feedback ---
func show_plan_change(before: Dictionary, cell: int) -> void:
 if before.is_empty() or cell < 0 or cell >= state.cells.size(): return
 var change: Dictionary = Sim.forecast_change(before, state)
 var origin: Vector2 = cell_rect(cell).position + Vector2(72, 52)
 var row: int = 0
 for k: String in ["survival","power","material","science","health"]:
  var v: int = int(change[k])
  if v == 0: continue
  var key_icon: String = str({"science":"star","health":"habitat"}.get(k, k))
  spawn_float(signed(v), origin - Vector2(0, row*24), TEAL if v > 0 else RUST, key_icon, 18, 1.2, row*0.07)
  row += 1
 var c: Dictionary = state.cells[cell]
 if str(c.kind) == "greenhouse" and int(change.harvest) == 0 and int(c.crew) > 0 and int(before.cells[cell].crew) == 0:
  var left: int = int(Sim.R.plant_days) - (int(c.get("progress", 0)) + 1)
  if left > 0:
   spawn_float(trk("float_grow", [left]), origin - Vector2(0, row*24), TEAL, "greenhouse", 14, 1.4, row*0.07)
   row += 1
 if bool(change.shortage):
  spawn_float(trk("float_shortage"), origin - Vector2(0, row*24), RUST, "power", 14, 1.5, row*0.07)
func celebrate_expert(id: String, cell: int, bonus: int) -> void:
 var center: Vector2 = cell_rect(cell).get_center()
 spawn_float(trk("expert_pop", [bonus]), center + Vector2(0, -60), TEAL, "star", 17, 1.6, 0.0, true)
 spawn_sparks(center, 14, crew_color(id), 150.0)
 play_sfx("expert")
func spawn_float(text: String, pos: Vector2, color: Color, icon_key: String = "", size_px: int = 18, life: float = 1.2, delay: float = 0.0, pop: bool = false) -> void:
 floaters.append({"text":text, "pos":pos, "color":color, "icon":icon_key, "size":size_px, "age":-delay, "life":life, "pop":pop})
 if floaters.size() > 24: floaters.pop_front()
 queue_redraw()
func spawn_sparks(pos: Vector2, count: int, color: Color, speed: float) -> void:
 for _i: int in range(count):
  var ang: float = fx_rng.randf_range(-PI, 0.0) if fx_rng.randf() < 0.8 else fx_rng.randf_range(0.0, PI)
  var vel: Vector2 = Vector2(cos(ang), sin(ang)) * fx_rng.randf_range(speed*0.4, speed)
  sparks.append({"pos":pos, "vel":vel, "age":0.0, "life":fx_rng.randf_range(0.5, 0.9), "color":color, "size":fx_rng.randf_range(2.5, 5.0), "star":fx_rng.randf() < 0.5})
 while sparks.size() > 160: sparks.pop_front()
 queue_redraw()
func hop_offset(id: String) -> float:
 var off: float = 0.0
 if hop.has(id):
  var a: float = float(hop[id])
  if a >= 0.0 and a <= 0.45: off = sin(a / 0.45 * PI) * 9.0
 if banner_t >= 0.0 and banner_t < 1.0:
  var idx: int = 0
  for i: int in range(Sim.CONFIG.crew.size()):
   if str(Sim.CONFIG.crew[i].id) == id: idx = i
  off = maxf(off, absf(sin(tick * 9.0 + float(idx))) * 6.0 * banner_alpha())
 return off
# Forecast numbers roll toward the new value and flash once whenever the plan changes.
func rolled(key: String, target: int) -> int:
 if motion_frozen or not forecast_roll.has(key):
  forecast_roll[key] = {"shown": float(target), "target": target, "flash": 0.0}
  return target
 var e: Dictionary = forecast_roll[key]
 if int(e.target) != target:
  e["target"] = target
  e["flash"] = 1.0
 return int(round(float(e.shown)))
func feedback_step(delta: float) -> void:
 if motion_frozen: return
 tick += delta
 var busy: bool = false
 for f: Dictionary in floaters: f["age"] = float(f.age) + delta
 floaters = floaters.filter(func(f: Dictionary) -> bool: return float(f.age) < float(f.life))
 busy = busy or not floaters.is_empty()
 for sp: Dictionary in sparks:
  sp["age"] = float(sp.age) + delta
  sp["vel"] = Vector2(sp.vel) * (1.0 - 2.2 * delta) + Vector2(0, 160.0 * delta)
  sp["pos"] = Vector2(sp.pos) + Vector2(sp.vel) * delta
 sparks = sparks.filter(func(sp: Dictionary) -> bool: return float(sp.age) < float(sp.life))
 busy = busy or not sparks.is_empty()
 for id: Variant in hop.keys():
  hop[id] = float(hop[id]) + delta
  if float(hop[id]) > 0.5: hop.erase(id)
  else: busy = true
 for k: Variant in forecast_roll.keys():
  var e: Dictionary = forecast_roll[k]
  var gap: float = float(e.target) - float(e.shown)
  if absf(gap) > 0.01:
   e["shown"] = float(e.target) if absf(gap) < 0.05 else float(e.shown) + gap * (1.0 - exp(-delta * 12.0))
   busy = true
  if float(e.flash) > 0.0:
   e["flash"] = maxf(0.0, float(e.flash) - delta * 1.6)
   busy = true
 if banner_t < 1.0:
  banner_t = minf(1.0, banner_t + delta / BANNER_SECONDS)
  busy = true
 if streak_chip_t < 1.0:
  var was: float = streak_chip_t
  streak_chip_t = minf(1.0, streak_chip_t + delta / STREAK_CHIP_SECONDS)
  if was < 0.0 and streak_chip_t >= 0.0: cheer_streak()
  busy = true
 if flare_alert_t < 1.0:
  flare_alert_t = minf(1.0, flare_alert_t + delta / FLARE_ALERT_SECONDS)
  busy = true
 if busy: queue_redraw()
# --- Night: one result at a time ---
func reveal_stages() -> Array:
 var report: Dictionary = night_report()
 var out: Array = []
 if report.is_empty(): return ["none"]
 if int(report.get("power", 0)) != 0: out.append("power")
 if int(report.get("material", 0)) != 0: out.append("material")
 if int(report.get("survival", 0)) != 0 or int(report.get("harvest", 0)) > 0: out.append("survival")
 if int(report.get("produced_science", 0)) > 0 or int(report.get("research_paused", 0)) > 0: out.append("science")
 if str(report.get("event", "")) == "flare" or int(report.get("damage", 0)) > 0 or int(report.get("healed", 0)) > 0: out.append("health")
 var fresh: Variant = report.get("new_discoveries", [])
 if fresh is Array and not fresh.is_empty(): out.append("discovery")
 if out.is_empty(): out.append("none")
 return out
func reveal_seconds() -> float:
 return clampf(STAGE_SECONDS * float(reveal_stages().size()), 1.4, 3.0)
func stage_progress(stage: String) -> float:
 if str(state.get("phase", "")) != "night": return 1.0
 var stages: Array = reveal_stages()
 var i: int = stages.find(stage)
 if i < 0: return smoothstep(0.0, 1.0, clampf(fx_t, 0.0, 1.0))
 return smoothstep(0.0, 1.0, clampf(fx_t * float(stages.size()) - float(i), 0.0, 1.0))
func on_stage_enter(stage: String) -> void:
 var report: Dictionary = night_report()
 var tier: int = streak_tier()
 var bar: Array = ["survival","power","material","science"]
 if stage in bar:
  var anchor: Vector2 = Vector2(265 + bar.find(stage) * 245 + 60, 46)
  var v: int = int(report.get(stage, 0))
  play_sfx(stage)
  if v != 0: spawn_float(signed(v), anchor + Vector2(0, 34), gain_color(v), "", 18, 1.0)
  spawn_sparks(anchor, 5 + tier * 5, gain_color(v), 90.0 + tier * 30.0)
  return
 match stage:
  "health":
   if str(report.get("event", "")) == "flare" and night_protected(report):
    play_sfx("protect")
    var ids: Array = []
    for d: Dictionary in Sim.CONFIG.crew: ids.append(str(d.id))
    for i: int in range(ids.size()): hop[ids[i]] = -0.07 * float(i)
    spawn_sparks(Vector2(464, 395), 12 + tier * 4, TEAL, 140.0)
   elif int(report.get("damage", 0)) > 0: play_sfx("damage")
   else: play_sfx("heal")
  "discovery":
   play_sfx("page")
   spawn_sparks(Vector2(464, 395), 10 + tier * 4, GOLD, 120.0)
func finish_reveal() -> void:
 var fresh: Variant = night_report().get("new_discoveries", [])
 banner_ids = fresh.duplicate() if fresh is Array else []
 if not banner_ids.is_empty():
  banner_t = 0.0
  play_sfx("discovery")
  spawn_sparks(Vector2(464, 395), 26, GOLD, 220.0)
 if is_streak_milestone(streak):
  if banner_ids.is_empty():
   streak_chip_t = 0.0
   cheer_streak()
  else: streak_chip_t = -BANNER_SECONDS / STREAK_CHIP_SECONDS
func cheer_streak() -> void:
 play_sfx("streak")
 spawn_sparks(Vector2(464, 218), 10 + streak_tier() * 6, GOLD, 130.0)
# The big button first finishes the show, then closes the banner, then moves on.
func on_primary() -> void:
 if str(state.get("phase", "")) == "night" and skip_presentation(): return
 advance_phase()
func skip_presentation() -> bool:
 if fx_playing:
  fx_t = 1.0
  fx_playing = false
  finish_reveal()
  queue_redraw()
  return true
 if (banner_t >= 0.0 and banner_t < 1.0) or streak_chip_t < 1.0:
  banner_t = 1.0
  streak_chip_t = 1.0
  queue_redraw()
  return true
 return false
func banner_alpha() -> float:
 if banner_t < 0.0 or banner_t >= 1.0: return 0.0
 return smoothstep(0.0, 0.1, banner_t) * (1.0 - smoothstep(0.85, 1.0, banner_t))
# --- Short synthesized sounds (no new audio files) ---
# Stop short sounds on exit so headless test runs do not report leaked playbacks.
func _exit_tree() -> void:
 for player: AudioStreamPlayer in [sound, sfx]:
  if is_instance_valid(player):
   player.stop()
   player.stream = null
 sfx_cache = {}
func play_sfx(key: String) -> void:
 # Headless checks have no speakers; skipping keeps their exit clean.
 if not is_instance_valid(sfx) or DisplayServer.get_name() == "headless": return
 if not sfx_cache.has(key): sfx_cache[key] = load_sfx(key)
 var entry: Array = SFX_FILES.get(key, ["", 0.0])
 sfx.volume_db = -4.0 + float(entry[1])
 sfx.stream = sfx_cache[key]
 sfx.play()
# Prefer the bundled CC0 file; fall back to the synthesized tone if it is missing.
func load_sfx(key: String) -> AudioStream:
 var path: String = str(SFX_FILES.get(key, [""])[0])
 if path != "" and ResourceLoader.exists(path):
  var stream: Resource = load(path)
  if stream is AudioStream: return stream
 return make_sfx(key)
func make_sfx(key: String) -> AudioStreamWAV:
 # [start Hz, end Hz, seconds, voice]
 var notes: Array = [[600.0, 600.0, 0.06, "pluck"]]
 match key:
  "place": notes = [[660.0, 660.0, 0.08, "pluck"]]
  "expert": notes = [[660.0, 660.0, 0.07, "pluck"], [990.0, 990.0, 0.16, "bell"]]
  "power": notes = [[220.0, 440.0, 0.22, "hum"]]
  "material": notes = [[0.0, 0.0, 0.035, "noise"], [330.0, 330.0, 0.08, "pluck"]]
  "survival": notes = [[523.0, 523.0, 0.07, "pluck"], [659.0, 659.0, 0.11, "pluck"]]
  "science": notes = [[784.0, 784.0, 0.07, "bell"], [1175.0, 1175.0, 0.16, "bell"]]
  "heal": notes = [[392.0, 392.0, 0.08, "pluck"], [523.0, 523.0, 0.14, "pluck"]]
  "damage": notes = [[200.0, 140.0, 0.22, "hum"]]
  "protect": notes = [[523.0, 523.0, 0.07, "bell"], [659.0, 659.0, 0.07, "bell"], [784.0, 784.0, 0.2, "bell"]]
  "discovery": notes = [[523.0, 523.0, 0.08, "bell"], [659.0, 659.0, 0.08, "bell"], [784.0, 784.0, 0.08, "bell"], [1047.0, 1047.0, 0.3, "bell"]]
  "streak": notes = [[659.0, 659.0, 0.07, "bell"], [880.0, 880.0, 0.16, "bell"]]
  "page": notes = [[0.0, 0.0, 0.05, "noise"], [880.0, 880.0, 0.12, "bell"]]
  "alarm": notes = [[392.0, 392.0, 0.12, "hum"], [0.0, 0.0, 0.05, "rest"], [392.0, 392.0, 0.12, "hum"]]
 var rate: int = 22050
 var total: int = 0
 for n: Array in notes: total += int(float(n[2]) * rate)
 var bytes: PackedByteArray = PackedByteArray()
 bytes.resize(total * 2)
 var noise: RandomNumberGenerator = RandomNumberGenerator.new()
 noise.seed = 7
 var at: int = 0
 for n: Array in notes:
  var count: int = int(float(n[2]) * rate)
  var voice: String = str(n[3])
  var decay: float = 6.0 if voice == "hum" else (12.0 if voice == "bell" else 20.0)
  var phase: float = 0.0
  for j: int in range(count):
   var t: float = float(j) / rate
   var f: float = lerpf(float(n[0]), float(n[1]), float(j) / maxf(1.0, float(count)))
   phase += TAU * f / rate
   var env: float = minf(1.0, float(j) / (0.004 * rate)) * exp(-t * decay) * minf(1.0, float(count - j) / (0.005 * rate))
   var w: float = 0.0
   match voice:
    "bell": w = sin(phase) + 0.3 * sin(phase * 2.0)
    "hum": w = sin(phase) + 0.25 * sin(phase * 3.0)
    "noise": w = noise.randf_range(-1.0, 1.0)
    "rest": w = 0.0
    _: w = sin(phase)
   bytes.encode_s16((at + j) * 2, clampi(int(w * env * 2600.0), -32768, 32767))
  at += count
 var wav: AudioStreamWAV = AudioStreamWAV.new()
 wav.format = AudioStreamWAV.FORMAT_16_BITS
 wav.mix_rate = rate
 wav.data = bytes
 return wav
# --- Drawing ---
func draw_feedback_layer() -> void:
 draw_phase_badges()
 draw_reveal_callout()
 draw_sparks()
 draw_floaters()
 draw_streak_chip()
 draw_milestone_banner()
func draw_phase_badges() -> void:
 var phase: String = str(state.get("phase", "morning"))
 var x: float = 32.0 + font.get_string_size(trk("phase_" + phase), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 14.0
 if phase != "night" and Sim.event(state) == "flare" and not bool(state.get("over", false)):
  var pulse: float = absf(sin(flare_alert_t * PI * 3.0)) if flare_alert_t < 1.0 else 0.0
  var frame_col: Color = Color(RUST, 0.55 + 0.4 * pulse)
  draw_style_box(style(Color(RUST, 0.03 + 0.06 * pulse), frame_col, 3 + int(round(2.0 * pulse)), 12), Rect2(29, 176, 872, 446))
  draw_style_box(style(Color.TRANSPARENT, frame_col, 3, 16), Rect2(920, 143, 410, 220))
  var label: String = trk("flare_alert")
  var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
  var pill: Rect2 = Rect2(x, 153, w + 38, 22).grow(pulse * 2.0)
  draw_style_box(style(RUST, RUST, 1, 10), pill)
  var o: Vector2 = pill.position + Vector2(9, 3)
  draw_colored_polygon(PackedVector2Array([o + Vector2(8, 0), o + Vector2(16, 15), o + Vector2(0, 15)]), PAPER)
  draw_line(o + Vector2(8, 5), o + Vector2(8, 10), RUST, 2.0)
  draw_circle(o + Vector2(8, 12.5), 1.2, RUST)
  text_at(label, pill.position.x + 30, pill.position.y + 16 + pulse * 2.0, 14, PAPER)
  x = pill.end.x + 10.0
 if streak >= 2:
  var label2: String = trk("streak_badge", [streak])
  var w2: float = font.get_string_size(label2, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
  var badge: Rect2 = Rect2(x, 153, w2 + 34, 22)
  draw_style_box(style(PAPER, GOLD, 2 if streak_tier() > 1 else 1, 10), badge)
  icon("star", Rect2(badge.position + Vector2(7, 3), Vector2(16, 16)))
  text_at(label2, badge.position.x + 27, badge.position.y + 16, 14, GOLD)
func callout_info(stage: String, p: float) -> Dictionary:
 var report: Dictionary = night_report()
 var info: Dictionary = {"icon":"book", "title":trk("outcome_none"), "sub":"", "color":INK}
 match stage:
  "power", "material":
   var v: int = int(report.get(stage, 0))
   info = {"icon":stage, "title":trk("reveal_"+stage, [signed(int(round(v * p)))]), "sub":"", "color":gain_color(v)}
  "survival":
   var net: int = int(report.get("survival", 0))
   var harvest: int = int(report.get("harvest", 0))
   if harvest > 0: info = {"icon":"greenhouse", "title":trk("reveal_harvest", [signed(int(round(harvest * p)))]), "sub":trk("reveal_survival", [signed(net)]), "color":gain_color(harvest)}
   else: info = {"icon":"survival", "title":trk("reveal_survival", [signed(int(round(net * p)))]), "sub":"", "color":gain_color(net)}
  "science":
   var made: int = int(report.get("produced_science", 0))
   if made > 0: info = {"icon":"star", "title":trk("reveal_science", [signed(int(round(made * p)))]), "sub":"", "color":gain_color(made)}
   else: info = {"icon":"lab", "title":trk("reveal_paused"), "sub":"", "color":MUTED}
  "health":
   var hp: int = int(report.get("health", 0))
   var flare: bool = str(report.get("event", "")) == "flare"
   if flare and night_protected(report): info = {"icon":"shield", "title":trk("reveal_protected"), "sub":trk("reveal_health", [signed(int(round(hp * p)))]), "color":TEAL}
   elif hp < 0: info = {"icon":"storm", "title":trk("reveal_health", [signed(int(round(hp * p)))]), "sub":"" if bool(state.get("over", false)) else trk("reveal_endured"), "color":RUST}
   else: info = {"icon":"habitat", "title":trk("reveal_health", [signed(int(round(hp * p)))]), "sub":"", "color":gain_color(hp)}
  "discovery":
   var names: PackedStringArray = PackedStringArray()
   var fresh: Variant = report.get("new_discoveries", [])
   if fresh is Array:
    for id: Variant in fresh: names.append(trk("unlock_" + str(id) + "_name"))
   info = {"icon":"star", "title":trk("reveal_discovery", [" / ".join(names)]), "sub":"", "color":GOLD}
 return info
func draw_reveal_callout() -> void:
 if str(state.get("phase", "")) != "night" or fx_t >= 1.0: return
 var stages: Array = reveal_stages()
 var n: int = stages.size()
 var raw: float = clampf(fx_t, 0.0, 1.0) * float(n)
 var i: int = mini(int(raw), n - 1)
 var local: float = clampf(raw - float(i), 0.0, 1.0)
 var info: Dictionary = callout_info(str(stages[i]), smoothstep(0.0, 1.0, local))
 var a: float = clampf(local * 6.0, 0.0, 1.0)
 if i == n - 1: a *= 1.0 - smoothstep(0.85, 1.0, local)
 var pop: float = 1.0 - clampf(local * 4.0, 0.0, 1.0)
 var col: Color = info.color
 var box: Rect2 = Rect2(279, 345, 370, 100)
 draw_style_box(style(Color(PAPER, 0.95 * a), Color(col, a), 2 + streak_tier(), 14), box)
 icon(str(info.icon), Rect2(box.position + Vector2(18, 22), Vector2(54, 54)), Color(1, 1, 1, a))
 var sub: String = str(info.sub)
 var title_y: float = box.position.y + (50.0 if sub != "" else 62.0)
 text_at(str(info.title), box.position.x + 86, title_y, 28 + int(round(8.0 * pop)), Color(col, a), 270)
 if sub != "": text_at(sub, box.position.x + 86, box.position.y + 80, 15, Color(INK, a), 270)
 for j: int in range(n):
  draw_circle(Vector2(box.end.x - 16 - float(n - 1 - j) * 12.0, box.end.y - 12), 3.5, Color(col if j <= i else LINE, a))
func draw_floaters() -> void:
 for f: Dictionary in floaters:
  var age: float = float(f.age)
  if age < 0.0: continue
  var k: float = age / float(f.life)
  var a: float = 1.0 - smoothstep(0.6, 1.0, k)
  var size_px: int = int(f.size)
  if bool(f.pop): size_px += int(round(6.0 * (1.0 - clampf(age * 5.0, 0.0, 1.0))))
  var lift: float = 30.0 * (1.0 - pow(1.0 - minf(k * 1.6, 1.0), 3.0))
  var text: String = str(f.text)
  var icon_key: String = str(f.icon)
  var icon_w: float = float(size_px) + 4.0 if icon_key != "" and icons.has(icon_key) else 0.0
  var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x + icon_w
  var pos: Vector2 = Vector2(f.pos) - Vector2(w * 0.5, lift)
  var col: Color = f.color
  draw_style_box(style(Color(PAPER, 0.88 * a), Color(col, 0.7 * a), 1, 8), Rect2(pos - Vector2(6, size_px + 3), Vector2(w + 12, size_px + 10)))
  if icon_w > 0.0: icon(icon_key, Rect2(pos - Vector2(0, size_px - 1), Vector2(size_px, size_px)), Color(1, 1, 1, a))
  text_at(text, pos.x + icon_w, pos.y + 1, size_px, Color(col, a))
func draw_sparks() -> void:
 for sp: Dictionary in sparks:
  var k: float = float(sp.age) / float(sp.life)
  var col: Color = Color(sp.color, 0.85 * (1.0 - k))
  var r: float = float(sp.size) * (1.0 - 0.5 * k)
  var at: Vector2 = sp.pos
  if bool(sp.star):
   draw_line(at - Vector2(r, 0), at + Vector2(r, 0), col, 1.6, true)
   draw_line(at - Vector2(0, r), at + Vector2(0, r), col, 1.6, true)
  else: draw_circle(at, r * 0.5, col)
func draw_streak_chip() -> void:
 if streak_chip_t < 0.0 or streak_chip_t >= 1.0: return
 var a: float = smoothstep(0.0, 0.12, streak_chip_t) * (1.0 - smoothstep(0.8, 1.0, streak_chip_t))
 var label: String = trk("streak_cheer", [streak])
 var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 70.0
 var box: Rect2 = Rect2(464.0 - w * 0.5, 196, w, 46)
 draw_style_box(style(Color(PAPER, 0.95 * a), Color(GOLD, a), 2, 14), box)
 icon("star", Rect2(box.position + Vector2(14, 9), Vector2(28, 28)), Color(1, 1, 1, a))
 text_at(label, box.position.x + 52, box.position.y + 31, 20, Color(GOLD, a))
func draw_milestone_banner() -> void:
 var a: float = banner_alpha()
 if a <= 0.0 or banner_ids.is_empty(): return
 var center: Vector2 = Vector2(464, 396)
 draw_rect(Rect2(32, 180, 864, 438), Color(PAPER, 0.4 * a))
 for i: int in range(16):
  var ang: float = TAU * float(i) / 16.0 + banner_t * 0.6
  var dir: Vector2 = Vector2(cos(ang), sin(ang))
  draw_line(center + dir * 120.0, center + dir * 300.0, Color(GOLD, 0.16 * a), 7.0, true)
 var count: int = mini(banner_ids.size(), 2)
 var box: Rect2 = Rect2(152, 396 - (70 + count * 56) * 0.5, 624, 70 + count * 56)
 draw_style_box(style(Color(PAPER, a), Color(RUST, a), 3, 16), box)
 draw_style_box(style(Color.TRANSPARENT, Color(GOLD, a), 1, 12), box.grow(-6))
 var at: int = int(Sim.R.unlock_plant_at) if "crops" in banner_ids else int(Sim.R.unlock_shield_at)
 centered(trk("milestone_title", [at]), Rect2(box.position.x, box.position.y + 10, box.size.x, 46), 32, Color(RUST, a))
 for j: int in range(count):
  var id: String = str(banner_ids[j])
  var y: float = box.position.y + 66 + j * 56
  var effect: String = trk("milestone_shielding_effect", [str(Sim.R.shield_factor), str(Sim.R.shield_factor_plus)]) if id == "shielding" else trk("milestone_crops_effect", [int(Sim.R.plant_yield), int(Sim.R.plant_yield) + int(Sim.R.plant_unlock_bonus)])
  var line: String = trk("milestone_unlocked", [trk("unlock_" + id + "_name")])
  var w: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 38.0
  var left: float = box.get_center().x - w * 0.5
  icon("shield" if id == "shielding" else "greenhouse", Rect2(left, y, 30, 30), Color(1, 1, 1, a))
  text_at(line, left + 38, y + 23, 20, Color(INK, a))
  centered(effect, Rect2(box.position.x, y + 30, box.size.x, 22), 16, Color(TEAL, a))
