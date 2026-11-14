extends RefCounted
const CONFIG: Dictionary = preload("res://data/values.json").data
const R: Dictionary = CONFIG.rules
static func initial() -> Dictionary:
 var s: Dictionary = CONFIG.initial.duplicate(true)
 for k: String in s.keys():
  if s[k] is float: s[k]=int(s[k])
 s["cells"] = []
 for i: int in range(18):
  var k: String = {0:"solar",1:"water",4:"greenhouse",7:"lab",10:"habitat"}.get(i, "")
  s.cells.append({"kind":k,"level":1,"crew":0,"progress":0})
 # Aoi rests in the habitat and Ren runs water. The other three wait for the morning plan.
 s["roster"] = [{"id":"aoi","cell":10},{"id":"ren","cell":1},{"id":"mio","cell":-1},{"id":"sora","cell":-1},{"id":"haru","cell":-1}]
 s["phase"] = "morning"
 s["discoveries"] = []
 _sync_counts(s)
 return s
static func event(s: Dictionary, offset: int = 0) -> String:
 var events: Array = CONFIG.events
 return events[(int(s.day) - 1 + offset) % events.size()]
# Night stores the next morning in day, so the notebook shows the day that just finished.
static func shown_day(s: Dictionary) -> int:
 var day: int = int(s.get("day",1))
 if str(s.get("phase","")) == "night": return maxi(1, day-1)
 return day
static func shown_event(s: Dictionary) -> String:
 if str(s.get("phase","")) == "night" and s.get("report") is Dictionary:
  var ev: String = str(s.report.get("event",""))
  if ev != "": return ev
 return event(s)
static func morning_ahead(s: Dictionary) -> String:
 if str(s.get("phase","")) == "night": return event(s)
 return event(s, 1)
static func specialty(id: String) -> String:
 for d: Dictionary in CONFIG.crew:
  if str(d.id) == id: return str(d.specialty)
 return ""
static func can_plan(s: Dictionary) -> bool:
 return str(s.get("phase","morning")) == "morning" and not bool(s.get("over", false))
static func idle(s: Dictionary) -> int:
 if s.get("roster") is Array:
  var waiting: int = 0
  for p: Dictionary in s.roster:
   if int(p.get("cell",-1)) < 0: waiting += 1
  return waiting
 var used: int = 0
 for c: Dictionary in s.cells: used += int(c.crew)
 return int(s.get("crew",0)) - used
static func crew_cell(s: Dictionary, id: String) -> int:
 return _cell_of(s, id)
static func first_idle(s: Dictionary) -> String:
 for d: Dictionary in CONFIG.crew:
  if _cell_of(s, str(d.id)) < 0: return str(d.id)
 return ""
static func first_in_cell(s: Dictionary, cell: int) -> String:
 for d: Dictionary in CONFIG.crew:
  if _cell_of(s, str(d.id)) == cell: return str(d.id)
 return ""
static func last_in_cell(s: Dictionary, cell: int) -> String:
 var found: String = ""
 for d: Dictionary in CONFIG.crew:
  if _cell_of(s, str(d.id)) == cell: found = str(d.id)
 return found
static func move(s: Dictionary, id: String, dest: int) -> Dictionary:
 if not can_plan(s): return s.duplicate(true)
 return place(s, id, dest)
static func place(s: Dictionary, id: String, dest: int) -> Dictionary:
 var n: Dictionary = s.duplicate(true)
 var index: int = _index(n, id)
 if index < 0: return s.duplicate(true)
 if int(n.roster[index].cell) == dest: return n
 if dest < -1 or dest >= n.cells.size(): return s.duplicate(true)
 if dest >= 0:
  var kind: String = str(n.cells[dest].kind)
  if kind == "" or kind == "shield": return s.duplicate(true)
  if _count_cell(n, dest) >= int(R.capacity): return s.duplicate(true)
 n.roster[index]["cell"] = dest
 _sync_counts(n)
 return n
static func build_at(s: Dictionary, index: int, kind: String) -> Dictionary:
 if not can_plan(s): return s.duplicate(true)
 if index < 0 or index >= s.cells.size() or not kind in CONFIG.facilities: return s.duplicate(true)
 if str(s.cells[index].kind) != "": return s.duplicate(true)
 if kind == "shield" and bool(s.shield): return s.duplicate(true)
 var cost: int = int(R.shield_cost if kind == "shield" else R.build)
 if int(s.material) < cost: return s.duplicate(true)
 var n: Dictionary = s.duplicate(true)
 n.material = int(n.material) - cost
 n.cells[index] = {"kind":kind,"crew":0,"level":1,"progress":0}
 if kind == "shield": n.shield = true
 _sync_counts(n)
 return n
static func upgrade_at(s: Dictionary, index: int) -> Dictionary:
 if not can_plan(s): return s.duplicate(true)
 if index < 0 or index >= s.cells.size(): return s.duplicate(true)
 var kind: String = str(s.cells[index].kind)
 if kind == "" or kind == "shield" or int(s.cells[index].level) >= int(R.max_level): return s.duplicate(true)
 var cost: int = int(R.upgrade) * int(s.cells[index].level)
 if int(s.material) < cost: return s.duplicate(true)
 var n: Dictionary = s.duplicate(true)
 n.material = int(n.material) - cost
 n.cells[index].level = int(n.cells[index].level) + 1
 return n
static func set_shelter(s: Dictionary, active: bool) -> Dictionary:
 if not can_plan(s): return s.duplicate(true)
 var n: Dictionary = s.duplicate(true)
 n.shelter = active
 return n
static func begin_day(s: Dictionary) -> Dictionary:
 if str(s.get("phase","morning")) != "morning" or bool(s.get("over", false)): return s.duplicate(true)
 var n: Dictionary = s.duplicate(true)
 n.phase = "day"
 return n
static func resolve_day(s: Dictionary) -> Dictionary:
 # Production runs only when leaving daytime, so continuing again cannot charge the same day.
 if str(s.get("phase","")) != "day" or bool(s.get("over", false)): return s.duplicate(true)
 var n: Dictionary = calculate(s)
 n.phase = "night"
 return n
static func wake(s: Dictionary) -> Dictionary:
 if str(s.get("phase","")) != "night" or bool(s.get("over", false)): return s.duplicate(true)
 var n: Dictionary = s.duplicate(true)
 n.phase = "morning"
 return n
static func calculate(s: Dictionary) -> Dictionary:
 var n: Dictionary = s.duplicate(true)
 if n.get("roster") is Array: _sync_counts(n)
 var ev: String = event(s)
 var science_before: int = int(s.science)
 var survival_before: int = int(s.survival)
 var power_before: int = int(s.power)
 var material_before: int = int(s.material)
 var health_before: int = int(s.health)
 var harvest: int = 0
 var survival_made: int = 0
 var power_made: int = 0
 var material_made: int = 0
 var science_made: int = 0
 var healed: int = 0
 n["shortage"] = false
 for index: int in range(n.cells.size()):
  var c: Dictionary = n.cells[index]
  if c.kind != "solar": continue
  var output: int = int(R.solar) * int(c.level) + int(c.crew) * int(R.solar_staff)
  if ev == "sun": output += int(R.solar_bonus)
  if ev == "dust": output = int(output / 2.0)
  if _specialist_at(n, index, "solar"): output += int(R.solar_expert)
  power_made += output
  n.power += output
 if bool(s.shelter):
  n.power -= int(R.shelter_power)
 else:
  for index: int in range(n.cells.size()):
   var c: Dictionary = n.cells[index]
   var staff: int = int(c.crew)
   if staff == 0: continue
   var level: int = int(c.level)
   var cost: int = int(R.get(("plant" if c.kind=="greenhouse" else str(c.kind)) + "_power", 0)) * staff
   if int(n.power) < cost:
    n.shortage = true
    continue
   n.power -= cost
   match str(c.kind):
    "water":
     var made: int = int(R.water)*staff*level
     if _specialist_at(n, index, "water"): made += int(R.water_expert)
     survival_made += made
     n.survival += made
    "greenhouse":
     var progress: int = int(c.get("progress",0))+1
     if progress >= int(R.plant_days):
      var per: int = int(R.plant_yield)
      # Unlocks follow the science owned this morning, so the forecast matches the day.
      if science_before >= int(R.unlock_plant_at): per += int(R.plant_unlock_bonus)
      var amount: int = per*staff*level
      if _specialist_at(n, index, "greenhouse"): amount += int(R.plant_expert)
      harvest += amount
      survival_made += amount
      n.survival += amount
      progress = 0
     n.cells[index]["progress"] = progress
    "lab":
     var learned: int = int(R.lab)*staff*level
     if _specialist_at(n, index, "lab"): learned += int(R.lab_expert)
     science_made += learned
     n.science += learned
    "mine":
     var mined: int = int(R.mine)*staff*level
     if _specialist_at(n, index, "mine"): mined += int(R.mine_expert)
     material_made += mined
     n.material += mined
    "habitat":
     var gain: int = int(R.habitat_heal)*staff
     var before_health: int = int(n.health)
     n.health = mini(100, before_health+gain)
     healed += int(n.health)-before_health
 n.survival -= int(R.daily_survival)
 var damage: int = 0
 if ev == "flare" and not bool(s.shelter):
  var factor: float = float(R.shield_factor)
  if bool(s.shield) and science_before >= int(R.unlock_shield_at): factor = float(R.shield_factor_plus)
  damage = int(round(float(R.flare_damage) * (factor if bool(s.shield) else 1.0)))
  n.health -= damage
 var owned: Array = []
 if s.get("discoveries") is Array:
  for item: Variant in s.discoveries:
   var known: String = str(item)
   if known in ["shielding","crops"] and not known in owned: owned.append(known)
 var fresh: Array = []
 if science_before < int(R.unlock_shield_at) and int(n.science) >= int(R.unlock_shield_at) and not "shielding" in owned:
  owned.append("shielding")
  fresh.append("shielding")
 if science_before < int(R.unlock_plant_at) and int(n.science) >= int(R.unlock_plant_at) and not "crops" in owned:
  owned.append("crops")
  fresh.append("crops")
 n.discoveries = owned
 n.shelter = false
 n.day += 1
 n.over = int(n.survival) < 0 or int(n.power) < 0 or int(n.health) <= 0
 n.won = bool(s.won) or (int(n.day) > int(R.days) and int(n.science) >= int(R.target) and not bool(n.over))
 n.report = {
  "harvest": harvest,
  "survival": int(n.survival)-survival_before,
  "power": int(n.power)-power_before,
  "material": int(n.material)-material_before,
  "science": science_made,
  "health": int(n.health)-health_before,
  "damage": damage,
  "produced_survival": survival_made,
  "produced_power": power_made,
  "produced_material": material_made,
  "produced_science": science_made,
  "healed": healed,
  "shortage": bool(n.shortage),
  "sheltered": bool(s.shelter),
  "event": ev,
  "new_discoveries": fresh
 }
 return n
static func restore(candidate: Dictionary, version: int) -> Dictionary:
 if not version in [1,2,3] or not candidate.get("cells") is Array or candidate.cells.size() != 18: return {}
 var s: Dictionary = candidate.duplicate(true)
 if version == 1:
  s["survival"] = int((int(s.get("water",18)) + int(s.get("food",18))) / 2.0)
 for legacy: String in ["water","food","delivery"]: s.erase(legacy)
 for k: String in CONFIG.initial.keys():
  if not s.has(k) or typeof(s[k]) != typeof(CONFIG.initial[k]) and not (s[k] is float or s[k] is int): return {}
  if s[k] is float: s[k] = int(s[k])
 for c: Variant in s.cells:
  if not c is Dictionary or not c.get("kind") is String or not c.has("crew") or not c.has("level"): return {}
  if c.kind != "" and not c.kind in CONFIG.facilities: return {}
  if int(c.crew) < 0 or int(c.crew) > int(R.capacity) or int(c.level) < 1 or int(c.level) > int(R.max_level): return {}
 if int(s.day) < 1: return {}
 for c: Dictionary in s.cells:
  c.crew = int(c.crew)
  c.level = int(c.level)
  c.progress = clampi(int(c.get("progress",0)),0,int(R.plant_days)-1)
 if not _install_roster(s): return {}
 if idle(s) < 0: return {}
 var phase: String = str(s.get("phase","morning"))
 s.phase = phase if phase in ["morning","day","night"] else "morning"
 var kept: Array = []
 if s.get("discoveries") is Array:
  for item: Variant in s.discoveries:
   var id: String = str(item)
   if id in ["shielding","crops"] and not id in kept: kept.append(id)
 s.discoveries = kept
 if not s.get("report") is Dictionary: s.erase("report")
 s.over = bool(s.over)
 s.won = bool(s.won)
 s.shield = bool(s.shield)
 s.shelter = bool(s.shelter)
 s.crew = int(s.crew)
 return s
static func _install_roster(s: Dictionary) -> bool:
 var ids: Array = []
 for d: Dictionary in CONFIG.crew: ids.append(str(d.id))
 var by_id: Dictionary = {}
 var incoming: Variant = s.get("roster")
 if incoming is Array and incoming.size() == ids.size():
  for p: Variant in incoming:
   if not p is Dictionary:
    by_id = {}
    break
   var id: String = str(p.get("id",""))
   if not id in ids or by_id.has(id):
    by_id = {}
    break
   by_id[id] = int(p.get("cell",-1))
 if by_id.size() != ids.size():
  var slots: Array = []
  for i: int in range(s.cells.size()):
   for _j: int in range(int(s.cells[i].crew)): slots.append(i)
  if slots.size() > ids.size(): return false
  by_id = {}
  for i: int in range(ids.size()):
   by_id[str(ids[i])] = int(slots[i]) if i < slots.size() else -1
 var placed: Dictionary = {}
 var roster: Array = []
 for id: Variant in ids:
  var cell: int = int(by_id[str(id)])
  if cell < -1 or cell >= s.cells.size(): cell = -1
  if cell >= 0:
   var kind: String = str(s.cells[cell].kind)
   if kind == "" or kind == "shield" or int(placed.get(cell,0)) >= int(R.capacity): cell = -1
   else: placed[cell] = int(placed.get(cell,0))+1
  roster.append({"id":str(id),"cell":cell})
 s.roster = roster
 _sync_counts(s)
 return true
static func _sync_counts(s: Dictionary) -> void:
 for c: Dictionary in s.cells: c.crew = 0
 if not s.get("roster") is Array: return
 for p: Dictionary in s.roster:
  var cell: int = int(p.get("cell",-1))
  if cell >= 0 and cell < s.cells.size(): s.cells[cell].crew = int(s.cells[cell].crew)+1
static func _index(s: Dictionary, id: String) -> int:
 if not s.get("roster") is Array: return -1
 for i: int in range(s.roster.size()):
  if str(s.roster[i].get("id","")) == id: return i
 return -1
static func _cell_of(s: Dictionary, id: String) -> int:
 var index: int = _index(s, id)
 if index < 0: return -2
 return int(s.roster[index].get("cell",-1))
static func _count_cell(s: Dictionary, cell: int) -> int:
 var count: int = 0
 if not s.get("roster") is Array: return 0
 for p: Dictionary in s.roster:
  if int(p.cell) == cell: count += 1
 return count
static func _specialist_at(s: Dictionary, cell: int, kind: String) -> bool:
 if not s.get("roster") is Array: return false
 for p: Dictionary in s.roster:
  if int(p.cell) == cell and specialty(str(p.id)) == kind: return true
 return false
