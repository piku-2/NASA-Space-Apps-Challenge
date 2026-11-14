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
 var copy: Dictionary=s.duplicate(true)
 var n: Dictionary=Sim.calculate(s)
 verify(s==copy,"Forecast is pure and leaves input unchanged")
 verify(int(n.water)==20,"Water recycling and daily drinking")
 verify(int(n.food)==15,"Daily food consumption")
 verify(int(n.power)==21,"Sunny automatic power minus recycling")
 s.cells[4].crew=1
 n=Sim.calculate(s)
 verify(int(n.food)==20,"Greenhouse produces food")
 verify(int(n.water)==18,"Greenhouse consumes water")
 verify(int(n.power)==19,"Greenhouse consumes electricity")
 s.day=5
 s.cells[0].kind=""
 s.cells[10].crew=0
 s.power=0
 n=Sim.calculate(s)
 verify(bool(n.shortage),"Power shortage is surfaced")
 verify(int(n.water)==15 and int(n.food)==15,"Unpowered production stops")
 s=Sim.initial()
 s.day=5
 s.cells[10].crew=0
 n=Sim.calculate(s)
 verify(int(n.health)==82,"Flare harms unprotected crew")
 s.shield=true
 n=Sim.calculate(s)
 verify(int(n.health)==94,"Shield reduces flare harm at material cost")
 s.shelter=true
 n=Sim.calculate(s)
 verify(int(n.health)==100,"Shelter avoids flare damage")
 verify(int(n.water)==15 and int(n.food)==15,"Shelter suspends work, life support still consumed")
 verify(int(n.power)==18,"Shelter uses power")
 s=Sim.initial()
 s.delivery=3
 n=Sim.calculate(s)
 verify(int(n.delivery)==3,"Supply does not arrive immediately")
 n=Sim.calculate(n)
 verify(int(n.delivery)==-1,"Supply arrives after two advances")
 verify(int(n.material)==16,"Supply delivers parts")
 s=Sim.initial()
 s.food=0
 n=Sim.calculate(s)
 verify(bool(n.over),"Resource exhaustion ends mission")
 s=Sim.initial();s.day=15;s.science=30
 n=Sim.calculate(s)
 verify(bool(n.won),"15 completed days and 30 research win")
 s.science=29
 n=Sim.calculate(s)
 verify(not bool(n.won),"Survival alone is not victory")
 # A sustainable strategy must be able to complete the whole mission.
 s=Sim.initial()
 s.cells[4].crew=1;s.cells[7].crew=1;s.cells[10].crew=0
 s.cells[1].level=2
 s.material-=int(Sim.R.upgrade)
 for d: int in range(15):
  if Sim.event(s)=="flare": s.shelter=true
  n=Sim.calculate(s)
  verify(not bool(n.over),"Sustainable full mission day "+str(d+1))
  s=n
 verify(bool(s.won),"Full mission reaches victory")
 print("PASS: ",checks," simulation checks")
 quit()
