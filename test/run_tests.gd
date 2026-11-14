extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
var checks: int = 0
func verify(condition: bool, label: String) -> void:
 checks+=1
 if not condition:
  push_error("FAIL: "+label)
  quit(1)
  assert(condition,label)
func park(s: Dictionary) -> Dictionary:
 for id: String in ["aoi","ren","mio","sora","haru"]:
  s = Sim.place(s, id, -1)
 return s
func same_resources(a: Dictionary, b: Dictionary) -> bool:
 for k: String in ["survival","power","material","science","health","day"]:
  if int(a[k]) != int(b[k]): return false
 return true
func _initialize() -> void:
 var s: Dictionary=Sim.initial()
 verify(Sim.idle(s)==3,"Initial available crew")
 verify(int(s.crew)==5 and s.roster.size()==5,"Five named crew keep the headcount")
 verify(not s.has("water") and not s.has("food"),"One survival resource replaces water and food")
 var seen: Dictionary={}
 for p: Dictionary in s.roster:
  verify(not seen.has(str(p.id)),"Crew ids are unique")
  seen[str(p.id)]=true
 verify(Sim.crew_cell(s,"ren")==1 and Sim.crew_cell(s,"aoi")==10,"Ren starts on water and Aoi rests")
 var copy: Dictionary=s.duplicate(true)
 var n: Dictionary=Sim.calculate(s)
 verify(s==copy,"Forecast is pure and leaves input unchanged")
 verify(int(n.survival)==int(s.survival),"Ren's water bonus covers the daily survival use")
 verify(int(n.power)==22,"Sunny automatic power minus recycling")
 verify(str(n.phase)=="morning","Forecast does not change the phase")
 s=Sim.place(s,"mio",4)
 for day: int in range(4):
  n=Sim.calculate(s)
  verify(int(n.survival)==int(s.survival),"No early plant harvest")
  verify(int(n.cells[4].progress)==day+1,"Plant progress persists")
  s=n
 n=Sim.calculate(s)
 verify(int(n.survival)-int(s.survival)==9,"Fifth day harvests 6 plus Mio's 3")
 verify(int(n.cells[4].progress)==0,"Harvest resets progress")
 verify(int(n.report.harvest)==9,"Night report records the harvest")
 s=Sim.place(s,"mio",-1)
 n=Sim.calculate(s)
 verify(int(n.cells[4].progress)==4,"Unstaffed plant pauses")
 s=Sim.place(s,"mio",4)
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
 s=Sim.initial()
 s=Sim.place(s,"mio",4)
 s.cells[5]=s.cells[4].duplicate(true)
 s=Sim.place(s,"haru",5)
 n=Sim.calculate(s)
 verify(int(n.cells[4].progress)==1 and int(n.cells[5].progress)==1,"Identical plants each advance")
 s.cells[4].progress=4
 s.cells[4].level=2
 s=Sim.place(s,"mio",4)
 s=Sim.place(s,"haru",4)
 n=Sim.calculate(s)
 verify(int(n.survival)-int(s.survival)==27,"Harvest scales with crew, level and Mio")
 s=Sim.initial()
 s=park(s)
 s.day=5
 n=Sim.calculate(s)
 verify(int(n.health)==82,"Flare harms unprotected crew")
 s.shield=true
 s.science=9
 n=Sim.calculate(s)
 verify(int(n.health)==94,"Shield reduces flare harm")
 verify(int(n.science)==9,"Shield research is not spent")
 s.science=10
 n=Sim.calculate(s)
 verify(int(n.health)==96,"Research 10 strengthens an installed shield")
 verify(int(n.science)==10,"The stronger shield does not spend research")
 s.shield=false
 n=Sim.calculate(s)
 verify(int(n.health)==82,"Shield research does nothing until the shield is built")
 s.shield=true
 s.shelter=true
 n=Sim.calculate(s)
 verify(int(n.health)==100,"Shelter avoids flare damage")
 verify(int(n.power)==18,"Shelter uses power")
 s=Sim.initial()
 s=park(s)
 s.survival=1
 n=Sim.calculate(s)
 verify(bool(n.over),"Negative survival ends the mission")
 s.survival=2
 n=Sim.calculate(s)
 verify(not bool(n.over) and int(n.survival)==0,"Exactly zero survival is allowed")
 s=Sim.initial()
 s.day=15
 s.science=30
 n=Sim.calculate(s)
 verify(bool(n.won),"15 completed days and 30 research win")
 s.science=29
 n=Sim.calculate(s)
 verify(not bool(n.won),"Survival alone is not victory")
 verify(int(n.science)==29,"Victory check does not spend or grant research")
 # Specialists add a bonus only on their own facility, and one person has one place.
 s=park(Sim.initial())
 s.power=0
 s=Sim.place(s,"aoi",0)
 n=Sim.calculate(s)
 verify(int(n.power)==12,"Aoi adds 2 power on the solar array")
 s=Sim.place(s,"aoi",-1)
 s=Sim.place(s,"mio",0)
 n=Sim.calculate(s)
 verify(int(n.power)==10,"A non-specialist does not get the solar bonus")
 s=park(Sim.initial())
 s=Sim.place(s,"ren",1)
 n=Sim.calculate(s)
 verify(int(n.survival)-int(s.survival)==0,"Ren adds 1 survival on the water recycler")
 s=Sim.place(s,"ren",-1)
 s=Sim.place(s,"mio",1)
 n=Sim.calculate(s)
 verify(int(n.survival)-int(s.survival)==-1,"Water without Ren is only +1")
 s=park(Sim.initial())
 s=Sim.place(s,"sora",7)
 n=Sim.calculate(s)
 verify(int(n.science)==5,"Sora adds 2 research in the lab")
 s=Sim.place(s,"sora",-1)
 s=Sim.place(s,"mio",7)
 n=Sim.calculate(s)
 verify(int(n.science)==3,"Lab without Sora is only 3")
 s=park(Sim.initial())
 s=Sim.build_at(s,2,"mine")
 s=Sim.place(s,"haru",2)
 n=Sim.calculate(s)
 verify(int(n.material)-int(s.material)==5,"Haru adds 2 parts at the mine")
 s=Sim.place(s,"haru",-1)
 s=Sim.place(s,"mio",2)
 n=Sim.calculate(s)
 verify(int(n.material)-int(s.material)==3,"Mine without Haru is only 3")
 s=park(Sim.initial())
 s.cells[4].progress=4
 s=Sim.place(s,"mio",4)
 n=Sim.calculate(s)
 verify(int(n.report.harvest)==9,"Mio adds 3 to a level-1 harvest")
 s.science=20
 n=Sim.calculate(s)
 verify(int(n.report.harvest)==12,"Research 20 raises harvest on the next morning")
 verify(int(n.science)==20,"Plant research is not spent")
 s.science=19
 n=Sim.calculate(s)
 verify(int(n.report.harvest)==9,"Research 19 does not unlock the richer harvest yet")
 var once: Dictionary=Sim.place(park(Sim.initial()),"sora",7)
 once.science=8
 var discovered: Dictionary=Sim.calculate(once)
 verify(int(discovered.science)==13,"Crossing a threshold keeps the new research")
 verify(discovered.report.new_discoveries.size()==1 and str(discovered.report.new_discoveries[0])=="shielding","Research 10 announces the shield idea once")
 var again: Dictionary=Sim.calculate(discovered)
 verify(again.report.new_discoveries.is_empty(),"The same idea is not announced twice")
 again.science=18
 var crops: Dictionary=Sim.calculate(again)
 verify(crops.report.new_discoveries.size()==1 and str(crops.report.new_discoveries[0])=="crops","Research 20 announces the plant idea")
 verify(int(crops.science)==23,"Discoveries do not spend the victory target")
 # One person cannot be in two places, and morning rules close after the day starts.
 s=Sim.initial()
 var moved: Dictionary=Sim.move(s,"mio",4)
 verify(Sim.crew_cell(moved,"mio")==4 and int(moved.cells[4].crew)==1,"Mio can be assigned to the plant")
 moved=Sim.move(moved,"mio",7)
 verify(Sim.crew_cell(moved,"mio")==7 and int(moved.cells[4].crew)==0,"Moving Mio leaves the previous building")
 var crowded: Dictionary=Sim.move(moved,"sora",7)
 crowded=Sim.move(crowded,"haru",7)
 verify(Sim.crew_cell(crowded,"haru")<0 and int(crowded.cells[7].crew)==2,"A full building rejects a third crew member")
 var returned: Dictionary=Sim.move(crowded,"mio",-1)
 verify(Sim.crew_cell(returned,"mio")<0,"Mio can return to standby")
 var daytime: Dictionary=Sim.begin_day(returned)
 var blocked: Dictionary=Sim.move(daytime,"mio",4)
 verify(Sim.crew_cell(blocked,"mio")==Sim.crew_cell(daytime,"mio"),"Crew cannot move during the day")
 verify(int(Sim.build_at(daytime,2,"mine").material)==int(daytime.material),"Building waits for morning")
 verify(int(Sim.upgrade_at(daytime,1).cells[1].level)==1,"Upgrades wait for morning")
 verify(not bool(Sim.set_shelter(daytime,true).shelter),"Shelter waits for morning")
 # Phases charge production exactly once and can be saved at every step.
 var morning: Dictionary=Sim.initial()
 var preview: Dictionary=Sim.calculate(morning)
 var started: Dictionary=Sim.begin_day(morning)
 verify(same_resources(started,morning) and str(started.phase)=="day","Daytime keeps the morning resources")
 verify(str(Sim.begin_day(started).phase)=="day","Starting the day twice does not skip ahead")
 verify(str(Sim.resolve_day(morning).phase)=="morning" and int(Sim.resolve_day(morning).day)==int(morning.day),"Night cannot resolve before daytime")
 var night: Dictionary=Sim.resolve_day(started)
 verify(str(night.phase)=="night","Resolve moves to night")
 verify(same_resources(night,preview),"Night matches the pure morning forecast")
 var repeated: Dictionary=Sim.resolve_day(night)
 verify(same_resources(repeated,night) and str(repeated.phase)=="night","Resolving night does not charge another day")
 var woken: Dictionary=Sim.wake(night)
 verify(str(woken.phase)=="morning" and same_resources(woken,night),"Next morning keeps the night result")
 var flare_morning: Dictionary=Sim.initial()
 flare_morning.day=5
 flare_morning=Sim.begin_day(flare_morning)
 var flare_night: Dictionary=Sim.resolve_day(flare_morning)
 verify(int(flare_night.day)==6,"Internal day advances to the next morning")
 verify(Sim.shown_day(flare_night)==5,"Night displays the completed flare day")
 verify(Sim.shown_event(flare_night)=="flare","Night shows the resolved flare")
 verify(Sim.morning_ahead(flare_night)=="calm","Night names the actual next morning")
 verify(str(flare_night.report.event)=="flare","The report keeps tonight's event")
 var after_flare: Dictionary=Sim.wake(flare_night)
 verify(Sim.shown_day(after_flare)==6 and Sim.shown_event(after_flare)=="calm","Morning shows the new day and its weather")
 verify(Sim.morning_ahead(after_flare)=="sun","The following morning is one day later")
 verify(str(Sim.wake(woken).phase)=="morning" and int(Sim.wake(woken).day)==int(woken.day),"Waking twice does not skip a day")
 var packed: String=JSON.stringify(night)
 var roundtrip: Dictionary=Sim.restore(JSON.parse_string(packed),3)
 verify(not roundtrip.is_empty() and str(roundtrip.phase)=="night","A night save restores the night phase")
 verify(int(roundtrip.survival)==int(night.survival) and int(roundtrip.science)==int(night.science),"A night save keeps the charged resources")
 verify(Sim.crew_cell(roundtrip,"ren")==Sim.crew_cell(night,"ren"),"A night save keeps crew places")
 var legacy: Dictionary=Sim.initial()
 legacy.erase("roster")
 legacy.erase("phase")
 legacy.erase("discoveries")
 legacy.erase("survival")
 legacy.water=12
 legacy.food=20
 legacy.delivery=3
 var v1: Dictionary=Sim.restore(legacy,1)
 verify(int(v1.survival)==16 and not v1.has("water") and not v1.has("food") and not v1.has("delivery"),"Version 1 save migrates into survival")
 verify(v1.roster.size()==5 and str(v1.phase)=="morning" and Sim.idle(v1)==3,"Version 1 save gains five crew and a morning")
 verify(int(v1.cells[1].crew)==1 and int(v1.cells[10].crew)==1,"Version 1 assignments are kept")
 var v2_source: Dictionary=Sim.initial()
 v2_source.erase("roster")
 v2_source.erase("phase")
 v2_source.erase("discoveries")
 var v2: Dictionary=Sim.restore(v2_source,2)
 verify(int(v2.survival)==10 and v2.roster.size()==5 and str(v2.phase)=="morning","Version 2 save gains roster and morning")
 verify(Sim.restore({},4).is_empty() and Sim.restore(Sim.initial(),9).is_empty(),"Unknown save versions are rejected")
 for use_plant: bool in [false,true]:
  s=Sim.initial()
  if use_plant: s=Sim.place(s,"mio",4)
  else: s=Sim.place(s,"mio",1)
  s=Sim.place(s,"sora",7)
  var previous_science: int=int(s.science)
  for day: int in range(15):
   verify(str(s.phase)=="morning","Mission planning starts each morning")
   s=Sim.set_shelter(s, Sim.event(s)=="flare")
   var before: Dictionary=s.duplicate(true)
   s=Sim.begin_day(s)
   verify(same_resources(s,before),"Daytime does not produce early")
   s=Sim.resolve_day(s)
   verify(int(s.day)==int(before.day)+1,"Each day resolves once")
   var second: Dictionary=Sim.resolve_day(s)
   verify(int(second.day)==int(s.day) and int(second.survival)==int(s.survival),"A second night click does not charge again")
   verify(int(s.science)>=previous_science,"Research never decreases")
   previous_science=int(s.science)
   verify(not bool(s.over),"Full mission survival day "+str(day+1))
   s=Sim.wake(s)
  verify(bool(s.won),"Full mission reaches victory without resupply")
  verify(int(s.science)>=30,"Victory research is still on hand")
 print("PASS: ",checks," simulation checks")
 quit()
