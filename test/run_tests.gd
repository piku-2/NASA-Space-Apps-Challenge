extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
var checks: int = 0
func verify(condition: bool, label: String) -> void:
 checks+=1
 if not condition:
  push_error("FAIL: "+label)
  quit(1)
  assert(condition,label)
func _initialize() -> void:
 var s: Dictionary=Sim.initial()
 verify(Sim.idle(s)==3,"Initial available crew")
 verify(not s.has("water") and not s.has("food"),"One survival resource replaces water and food")
 var copy: Dictionary=s.duplicate(true)
 var n: Dictionary=Sim.calculate(s)
 verify(s==copy,"Forecast is pure and leaves input unchanged")
 verify(int(n.survival)==9,"Water makes one and crew consume two")
 verify(int(n.power)==22,"Sunny automatic power minus recycling")
 s.cells[4].crew=1
 for day: int in range(4):
  n=Sim.calculate(s)
  verify(int(n.survival)==int(s.survival)-1,"No early plant harvest")
  verify(int(n.cells[4].progress)==day+1,"Plant progress persists")
  s=n
 n=Sim.calculate(s)
 verify(int(n.survival)-int(s.survival)==5,"Fifth working day yields six minus daily net consumption")
 verify(int(n.cells[4].progress)==0,"Harvest resets progress")
 s.cells[4].crew=0
 n=Sim.calculate(s)
 verify(int(n.cells[4].progress)==4,"Unstaffed plant pauses")
 s.cells[4].crew=1
 s.shelter=true
 n=Sim.calculate(s)
 verify(int(n.cells[4].progress)==4,"Shelter pauses harvest")
 verify(int(n.survival)==int(s.survival)-2,"Shelter still consumes survival resources")
 s.shelter=false
 s.cells[0].kind=""
 s.power=0
 n=Sim.calculate(s)
 verify(bool(n.shortage),"Power shortage is surfaced")
 verify(int(n.cells[4].progress)==4,"No-power plant pauses harvest")
 verify(int(n.survival)==int(s.survival)-2,"Unpowered production stops")
 # Identical plants must advance independently, rather than updating the first matching dictionary.
 s=Sim.initial()
 s.cells[4].crew=1
 s.cells[5]=s.cells[4].duplicate(true)
 n=Sim.calculate(s)
 verify(int(n.cells[4].progress)==1 and int(n.cells[5].progress)==1,"Identical plants each advance")
 s.cells[4].progress=4
 s.cells[4].crew=2
 s.cells[4].level=2
 n=Sim.calculate(s)
 verify(int(n.survival)-int(s.survival)==23,"Harvest scales with crew and level")
 s=Sim.initial()
 s.day=5
 s.cells[10].crew=0
 n=Sim.calculate(s)
 verify(int(n.health)==82,"Flare harms unprotected crew")
 s.shield=true
 n=Sim.calculate(s)
 verify(int(n.health)==94,"Shield reduces flare harm")
 s.shelter=true
 n=Sim.calculate(s)
 verify(int(n.health)==100,"Shelter avoids flare damage")
 verify(int(n.power)==18,"Shelter uses power")
 s=Sim.initial()
 s.survival=0
 n=Sim.calculate(s)
 verify(bool(n.over),"Resource exhaustion ends mission")
 s.survival=1
 n=Sim.calculate(s)
 verify(not bool(n.over),"Exactly zero survival is allowed")
 s=Sim.initial();s.day=15;s.science=30
 n=Sim.calculate(s)
 verify(bool(n.won),"15 completed days and 30 research win")
 s.science=29
 n=Sim.calculate(s)
 verify(not bool(n.won),"Survival alone is not victory")
 # Both steady recycling and cyclic harvesting support a complete mission without resupply.
 for use_plant: bool in [false,true]:
  s=Sim.initial()
  s.cells[1].crew=2 if not use_plant else 1
  s.cells[4].crew=1 if use_plant else 0
  s.cells[7].crew=1
  for day: int in range(15):
   if Sim.event(s)=="flare": s.shelter=true
   s=Sim.calculate(s)
   verify(not bool(s.over),"Full mission survival day "+str(day+1))
  verify(bool(s.won),"Full mission reaches victory without resupply")
 print("PASS: ",checks," simulation checks")
 quit()
