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
  s.cells.append({"kind":k,"level":1,"crew":1 if i in [1,10] else 0,"progress":0})
 return s
static func event(s: Dictionary, offset: int = 0) -> String:
 var events: Array = CONFIG.events
 return events[(int(s.day) - 1 + offset) % events.size()]
static func idle(s: Dictionary) -> int:
 var used: int = 0
 for c: Dictionary in s.cells: used += int(c.crew)
 return int(s.crew) - used
static func calculate(s: Dictionary) -> Dictionary:
 var n: Dictionary = s.duplicate(true)
 var ev: String = event(s)
 n["shortage"] = false
 for c: Dictionary in s.cells:
  if c.kind != "solar": continue
  var output: int = int(R.solar) * int(c.level) + int(c.crew) * int(R.solar_staff)
  if ev == "sun": output += int(R.solar_bonus)
  if ev == "dust": output = int(output / 2.0)
  n.power += output
 if bool(s.shelter):
  n.power -= int(R.shelter_power)
 else:
  for index: int in range(s.cells.size()):
   var c: Dictionary = s.cells[index]
   var staff: int = int(c.crew)
   if staff == 0: continue
   var level: int = int(c.level)
   var cost: int = int(R.get(("plant" if c.kind=="greenhouse" else str(c.kind)) + "_power", 0)) * staff
   if int(n.power) < cost:
    n.shortage = true
    continue
   n.power -= cost
   match str(c.kind):
    "water": n.survival += int(R.water)*staff*level
    "greenhouse":
     var progress: int = int(c.get("progress",0))+1
     if progress >= int(R.plant_days):
      n.survival += int(R.plant_yield)*staff*level
      progress = 0
     n.cells[index]["progress"] = progress
    "lab": n.science += int(R.lab)*staff*level
    "mine": n.material += int(R.mine)*staff*level
    "habitat": n.health = mini(100, int(n.health)+int(R.habitat_heal)*staff)
 n.survival -= int(R.daily_survival)
 if ev == "flare" and not bool(s.shelter):
  n.health -= int(round(float(R.flare_damage) * (float(R.shield_factor) if bool(s.shield) else 1.0)))
 n.shelter = false
 n.day += 1
 n.over = int(n.survival) < 0 or int(n.power) < 0 or int(n.health) <= 0
 n.won = bool(s.won) or (int(n.day) > int(R.days) and int(n.science) >= int(R.target) and not bool(n.over))
 return n
