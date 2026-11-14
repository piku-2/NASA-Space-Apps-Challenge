import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import {
  R,
  beginDay,
  buildAt,
  calculate,
  crewCell,
  eventOf,
  expertBonus,
  flareHarm,
  forecastChange,
  idle,
  initial as currentInitial,
  morningAhead,
  move,
  place,
  project,
  resolveDay,
  restore,
  setFlareCover,
  setShelter,
  shownDay,
  shownEvent,
  specialtyMatches,
  upgradeAt,
  wake,
  type GameState,
} from './simulation.ts'

// Existing saves must continue to obey their original resource rules.
function initial(): GameState {
  return { ...currentInitial(), rules_version: 3 }
}

function park(state: GameState): GameState {
  for (const id of ['aoi', 'ren', 'mio', 'sora', 'haru']) state = place(state, id, -1)
  return state
}

function sameResources(left: GameState, right: GameState): void {
  for (const key of ['survival', 'power', 'material', 'science', 'health', 'day'] as const) {
    assert.equal(left[key], right[key], key)
  }
}

describe('legacy simulation and save compatibility', () => {
  it('starts six crew and forecasts without mutating', () => {
    const state = initial()
    assert.equal(idle(state), 4)
    assert.equal(state.crew, 6)
    assert.equal(state.roster.length, 6)
    assert.equal(state.roster.some((person) => person.id === 'rikuto'), true)
    assert.equal('water' in state, false)
    assert.equal(crewCell(state, 'ren'), 1)
    assert.equal(crewCell(state, 'aoi'), 10)
    const copy = structuredClone(state)
    const next = calculate(state)
    assert.deepEqual(state, copy)
    assert.equal(next.survival, state.survival)
    assert.equal(next.power, 22)
    assert.equal(next.phase, 'morning')
  })

  it('harvests on the fifth staffed day and pauses without power or shelter', () => {
    let state = place(initial(), 'mio', 4)
    for (let day = 0; day < 4; day++) {
      const next = calculate(state)
      assert.equal(next.survival, state.survival)
      assert.equal(next.cells[4].progress, day + 1)
      state = next
    }
    let next = calculate(state)
    assert.equal(next.survival - state.survival, 9)
    assert.equal(next.cells[4].progress, 0)
    assert.equal(next.report?.harvest, 9)
    assert.equal(next.report?.harvest_cells.includes(4), true)

    state = place(state, 'mio', -1)
    next = calculate(state)
    assert.equal(next.cells[4].progress, 4)
    state = place(state, 'mio', 4)
    state.shelter = true
    next = calculate(state)
    assert.equal(next.cells[4].progress, 4)
    assert.equal(next.survival, state.survival - 2)
    state.shelter = false
    state.cells[0].kind = ''
    state.power = 0
    next = calculate(state)
    assert.equal(next.shortage, true)
    assert.equal(next.cells[4].progress, 4)
    assert.equal(next.survival, state.survival - 2)
  })

  it('scales harvest and applies flare, shield, and shelter', () => {
    let state = place(initial(), 'mio', 4)
    state.cells[5] = structuredClone(state.cells[4])
    state = place(state, 'haru', 5)
    let next = calculate(state)
    assert.equal(next.cells[4].progress, 1)
    assert.equal(next.cells[5].progress, 1)
    state.cells[4].progress = 4
    state.cells[4].level = 2
    state = place(state, 'mio', 4)
    state = place(state, 'haru', 4)
    next = calculate(state)
    assert.equal(next.survival - state.survival, 27)

    state = park(initial())
    state.day = 5
    next = calculate(state)
    assert.equal(next.health, 82)
    state.shield = true
    state.science = 9
    next = calculate(state)
    assert.equal(next.health, 94)
    assert.equal(next.science, 9)
    state.science = 10
    next = calculate(state)
    assert.equal(next.health, 96)
    assert.equal(next.science, 10)
    state.shield = false
    next = calculate(state)
    assert.equal(next.health, 82)
    state.shield = true
    state.shelter = true
    next = calculate(state)
    assert.equal(next.health, 100)
    assert.equal(next.power, 18)

    state = park(initial())
    state.survival = 1
    next = calculate(state)
    assert.equal(next.over, true)
    state.survival = 2
    next = calculate(state)
    assert.equal(next.over, false)
    assert.equal(next.survival, 0)
    state = initial()
    state.day = 15
    state.science = 30
    next = calculate(state)
    assert.equal(next.won, true)
    state.science = 29
    next = calculate(state)
    assert.equal(next.won, false)
    assert.equal(next.science, 29)
  })

  it('gives a specialty bonus only on the matching building', () => {
    let state = park(initial())
    state.power = 0
    state = place(state, 'aoi', 0)
    assert.equal(calculate(state).power, 12)
    state = place(state, 'aoi', -1)
    state = place(state, 'mio', 0)
    assert.equal(calculate(state).power, 10)

    state = park(initial())
    state = place(state, 'ren', 1)
    assert.equal(calculate(state).survival - state.survival, 0)
    state = place(state, 'ren', -1)
    state = place(state, 'mio', 1)
    assert.equal(calculate(state).survival - state.survival, -1)

    state = park(initial())
    state = place(state, 'sora', 7)
    assert.equal(calculate(state).science, 5)
    state = place(state, 'sora', -1)
    state = place(state, 'mio', 7)
    assert.equal(calculate(state).science, 3)

    state = park(initial())
    state = buildAt(state, 2, 'mine')
    state = place(state, 'haru', 2)
    assert.equal(calculate(state).material - state.material, 5)
    state = place(state, 'haru', -1)
    state = place(state, 'mio', 2)
    assert.equal(calculate(state).material - state.material, 3)

    state = park(initial())
    state.cells[4].progress = 4
    state = place(state, 'mio', 4)
    assert.equal(calculate(state).report?.harvest, 9)
    state.science = 20
    assert.equal(calculate(state).report?.harvest, 12)
    assert.equal(calculate(state).science, 20)
    state.science = 19
    assert.equal(calculate(state).report?.harvest, 9)

    let once = place(park(initial()), 'sora', 7)
    once.science = 8
    const discovered = calculate(once)
    assert.equal(discovered.science, 13)
    assert.deepEqual(discovered.report?.new_discoveries, ['shielding'])
    const again = calculate(discovered)
    assert.deepEqual(again.report?.new_discoveries, [])
    again.science = 18
    const crops = calculate(again)
    assert.deepEqual(crops.report?.new_discoveries, ['crops'])
    assert.equal(crops.science, 23)
  })

  it('keeps one person in one place and charges each phase once', () => {
    let state = initial()
    let moved = move(state, 'mio', 4)
    assert.equal(crewCell(moved, 'mio'), 4)
    assert.equal(moved.cells[4].crew, 1)
    moved = move(moved, 'mio', 7)
    assert.equal(crewCell(moved, 'mio'), 7)
    assert.equal(moved.cells[4].crew, 0)
    let crowded = move(moved, 'sora', 7)
    crowded = move(crowded, 'haru', 7)
    assert.equal(crewCell(crowded, 'haru') < 0, true)
    assert.equal(crowded.cells[7].crew, 2)
    const returned = move(crowded, 'mio', -1)
    assert.equal(crewCell(returned, 'mio') < 0, true)
    const daytime = beginDay(returned)
    const blocked = move(daytime, 'mio', 4)
    assert.equal(crewCell(blocked, 'mio'), crewCell(daytime, 'mio'))
    assert.equal(buildAt(daytime, 2, 'mine').material, daytime.material)
    assert.equal(upgradeAt(daytime, 1).cells[1].level, 1)
    assert.equal(setShelter(daytime, true).shelter, false)

    const morning = initial()
    const preview = calculate(morning)
    const started = beginDay(morning)
    sameResources(started, morning)
    assert.equal(started.phase, 'day')
    assert.equal(beginDay(started).phase, 'day')
    assert.equal(resolveDay(morning).phase, 'morning')
    assert.equal(resolveDay(morning).day, morning.day)
    const night = resolveDay(started)
    assert.equal(night.phase, 'night')
    sameResources(night, preview)
    const repeated = resolveDay(night)
    sameResources(repeated, night)
    assert.equal(repeated.phase, 'night')
    const woken = wake(night)
    assert.equal(woken.phase, 'morning')
    sameResources(woken, night)

    let flareMorning = initial()
    let flareDay = 0
    for (let day = 1; day <= 4000; day++) {
      if (eventOf({ day, seed: flareMorning.seed }) === 'flare') {
        flareDay = day
        break
      }
    }
    assert.ok(flareDay > 0)
    flareMorning.day = flareDay
    flareMorning = beginDay(flareMorning)
    const flareNight = resolveDay(flareMorning)
    assert.equal(flareNight.day, flareDay + 1)
    assert.equal(shownDay(flareNight), flareDay)
    assert.equal(shownEvent(flareNight), 'flare')
    assert.equal(morningAhead(flareNight), eventOf({ day: flareDay + 1, seed: flareMorning.seed }))
    assert.equal(flareNight.report?.event, 'flare')
    const afterFlare = wake(flareNight)
    assert.equal(shownDay(afterFlare), flareDay + 1)
    assert.equal(shownEvent(afterFlare), eventOf(afterFlare))
    assert.equal(morningAhead(afterFlare), eventOf(afterFlare, 1))
    assert.equal(wake(woken).phase, 'morning')
    assert.equal(wake(woken).day, woken.day)

    const roundtrip = restore(JSON.parse(JSON.stringify(night)), 3)
    assert.ok(roundtrip)
    assert.equal(roundtrip?.phase, 'night')
    assert.equal(roundtrip?.survival, night.survival)
    assert.equal(roundtrip?.science, night.science)
    assert.equal(crewCell(roundtrip!, 'ren'), crewCell(night, 'ren'))

    const legacy = initial() as GameState & { water?: number; food?: number; delivery?: number }
    delete (legacy as { roster?: unknown }).roster
    delete (legacy as { phase?: unknown }).phase
    delete (legacy as { discoveries?: unknown }).discoveries
    delete (legacy as { survival?: unknown }).survival
    legacy.water = 12
    legacy.food = 20
    legacy.delivery = 3
    const v1 = restore(legacy, 1)
    assert.ok(v1)
    assert.equal(v1?.survival, 16)
    assert.equal('water' in v1!, false)
    assert.equal('food' in v1!, false)
    assert.equal(v1?.roster.length, 6)
    assert.equal(v1?.phase, 'morning')
    assert.equal(idle(v1!), 4)
    assert.equal(v1?.cells[1].crew, 1)
    assert.equal(v1?.cells[10].crew, 1)

    const v2Source = initial()
    delete (v2Source as { roster?: unknown }).roster
    delete (v2Source as { phase?: unknown }).phase
    delete (v2Source as { discoveries?: unknown }).discoveries
    const v2 = restore(v2Source, 2)
    assert.equal(v2?.survival, 10)
    assert.equal(v2?.roster.length, 6)
    assert.equal(v2?.phase, 'morning')
    assert.equal(restore({}, 4), null)
    assert.equal(restore(initial(), 9), null)
  })

  it('marks about 35 of every 1000 days as a particle day', () => {
    let hits = 0
    const days = 2000
    const seeds = 20
    for (let seed = 1; seed <= seeds; seed++) {
      for (let day = 1; day <= days; day++) {
        if (eventOf({ day, seed }) === 'flare') hits++
      }
    }
    const fraction = hits / (days * seeds)
    assert.ok(fraction > 0.025 && fraction < 0.045, String(fraction))
  })

  it('survives 15 days with research still in hand', () => {
    for (const usePlant of [false, true]) {
      let state = initial()
      state = place(state, 'mio', usePlant ? 4 : 1)
      state = place(state, 'sora', 7)
      let previous = state.science
      for (let day = 0; day < 15; day++) {
        assert.equal(state.phase, 'morning')
        state = setShelter(state, eventOf(state) === 'flare')
        const before = structuredClone(state)
        state = beginDay(state)
        sameResources(state, before)
        state = resolveDay(state)
        assert.equal(state.day, before.day + 1)
        const second = resolveDay(state)
        assert.equal(second.day, state.day)
        assert.equal(second.survival, state.survival)
        assert.equal(state.science >= previous, true)
        previous = state.science
        assert.equal(state.over, false, 'day ' + (day + 1))
        state = wake(state)
      }
      assert.equal(state.won, true)
      assert.equal(state.science >= 30, true)
    }
  })

  it('prices flare cover without spending it until night', () => {
    assert.equal(expertBonus('solar'), 2)
    assert.equal(expertBonus('water'), 1)
    assert.equal(expertBonus('greenhouse'), 3)
    assert.equal(expertBonus('lab'), 2)
    assert.equal(expertBonus('mine'), 2)
    assert.equal(expertBonus('habitat'), 0)
    assert.equal(specialtyMatches('mio', 'greenhouse'), true)
    assert.equal(specialtyMatches('mio', 'solar'), false)
    assert.equal(flareHarm(0, false, false), 18)
    assert.equal(flareHarm(0, true, false), 6)
    assert.equal(flareHarm(10, true, false), 4)
    assert.equal(flareHarm(0, false, true), 9)
    assert.equal(flareHarm(0, true, true), 3)
    assert.equal(flareHarm(10, true, true), 2)

    let state = park(initial())
    state.day = 5
    state.power = 40
    state = place(state, 'sora', 7)
    const untouched = structuredClone(state)
    const keep = project(state, false)
    const braced = project(state, true)
    assert.deepEqual(state, untouched)
    assert.equal(keep.science, 5)
    assert.equal(keep.health, 82)
    assert.equal(keep.report?.damage, 18)
    assert.equal(braced.science, 0)
    assert.equal(braced.health, 91)
    assert.equal(braced.report?.damage, 9)
    assert.equal(braced.report?.research_paused, 5)
    assert.equal(braced.report?.cover_committed, true)
    assert.equal(keep.power - braced.power, intRule(R.flare_cover_power))
    assert.equal(braced.science < keep.science && braced.health > keep.health, true)
    assert.equal(braced.shield, false)
    assert.equal(braced.shelter, false)

    state.power = 100
    const keepRich = project(state, false)
    const bracedRich = project(state, true)
    assert.equal(bracedRich.power > 50, true)
    assert.equal(bracedRich.science, keepRich.science - 5)

    const empty = park(initial())
    empty.day = 5
    empty.flare_cover = true
    const bare = calculate(empty)
    assert.equal(bare.health, 82)
    assert.equal(bare.report?.research_paused, 0)
    assert.equal(bare.report?.cover_committed, false)

    let poor = park(initial())
    poor.day = 5
    poor.power = 0
    poor = place(poor, 'sora', 7)
    poor.flare_cover = true
    const broke = calculate(poor)
    assert.equal(broke.report?.cover_committed, false)
    assert.equal(broke.science, 5)
    assert.equal(broke.health, 82)

    let low = park(initial())
    low.day = 5
    low.health = 12
    low.power = 40
    low = place(low, 'sora', 7)
    assert.equal(project(low, false).over, true)
    assert.equal(project(low, false).health <= 0, true)
    const lived = project(low, true)
    assert.equal(lived.over, false)
    assert.equal(lived.health, 3)
    assert.equal(lived.science, low.science)

    const locked = beginDay(park(initial()))
    assert.equal(setFlareCover(locked, true).flare_cover, false)
    let plan = park(initial())
    plan.day = 5
    plan.power = 40
    plan = place(plan, 'sora', 7)
    plan = setFlareCover(plan, true)
    assert.equal(plan.flare_cover, true)
    assert.equal(plan.power, 40)
    assert.equal(plan.science, 0)
    const chosen = beginDay(plan)
    assert.equal(chosen.flare_cover, true)
    sameResources(chosen, plan)
    const resolved = resolveDay(chosen)
    const projected = calculate(plan)
    sameResources(resolved, projected)
    assert.equal(resolved.report?.damage, projected.report?.damage)
    assert.equal(resolved.report?.research_paused, 5)
    sameResources(resolveDay(resolved), resolved)
    const after = wake(resolved)
    assert.equal(after.flare_cover, false)
    sameResources(after, resolved)

    const legacyChoice = initial()
    delete (legacyChoice as { flare_cover?: unknown }).flare_cover
    const restoredChoice = restore(legacyChoice, 3)
    assert.equal(restoredChoice?.flare_cover, false)

    let plated = park(initial())
    plated.day = 5
    plated.shield = true
    plated.science = 10
    plated.power = 40
    plated = place(plated, 'sora', 7)
    const platedKeep = project(plated, false)
    const platedCover = project(plated, true)
    assert.equal(platedKeep.report?.damage, 4)
    assert.equal(platedKeep.science, 15)
    assert.equal(platedCover.report?.damage, 2)
    assert.equal(platedCover.science, 10)
  })

  it('wins a full mission either by keeping research or covering', () => {
    for (const mode of ['keep', 'cover']) {
      let state = place(initial(), 'sora', 7)
      for (let day = 0; day < 15; day++) {
        assert.equal(state.phase, 'morning')
        state = setShelter(state, false)
        state = setFlareCover(state, mode === 'cover' && eventOf(state) === 'flare')
        const morning = structuredClone(state)
        state = beginDay(state)
        sameResources(state, morning)
        state = resolveDay(state)
        assert.equal(state.over, false, mode + ' ' + (day + 1))
        sameResources(resolveDay(state), state)
        state = wake(state)
      }
      assert.equal(state.won, true)
      assert.equal(state.science >= 30, true)
    }
  })

  it('previews the same delta the night will apply', () => {
    const state = initial()
    const copy = structuredClone(state)
    const lab = place(state, 'sora', 7)
    const gain = forecastChange(state, lab)
    assert.deepEqual(state, copy)
    assert.equal(gain.science, intRule(R.lab) + intRule(R.lab_expert))
    assert.equal(gain.power, -intRule(R.lab_power))
    const back = forecastChange(lab, state)
    for (const key of ['survival', 'power', 'material', 'science', 'health'] as const) {
      assert.equal(back[key] + 0, -gain[key] + 0, key)
      assert.equal(gain[key] + 0, calculate(lab)[key] - calculate(state)[key] + 0, key)
    }
    const plain = forecastChange(state, place(state, 'haru', 7))
    assert.equal(plain.science, intRule(R.lab))
  })
})

function intRule(value: number): number {
  return Math.trunc(value)
}

describe('mission power budget', () => {
  it('normalizes an interrupted night report for safe rendering of old saves', () => {
    const state = currentInitial()
    state.phase = 'night'
    const source = { ...state, report: { science: 'broken', new_discoveries: null, harvest_cells: [-1, 20, 4] } }
    const loaded = restore(source, 3)!
    assert.deepEqual(loaded.report?.new_discoveries, [])
    assert.deepEqual(loaded.report?.harvest_cells, [4])
    assert.equal(loaded.report?.science, 0)
    assert.equal(loaded.report?.event, 'sun')
    assert.equal(loaded.phase, 'night')
  })
  it('charges base power once and preserves old saves without this rule', () => {
    const state = currentInitial()
    assert.equal(calculate(state).power, 17)
    assert.equal(calculate(state).report?.upkeep_power, 5)
    const night = resolveDay(beginDay(state))
    assert.deepEqual(resolveDay(night), night)
    assert.equal(calculate(restore(state, 3)!).power, 17)
    delete state.rules_version
    const legacy = restore(state, 3)!
    assert.equal(legacy.rules_version, 3)
    assert.equal(calculate(legacy).power, 22)
  })
  it('makes solar staffing prevent a forecast power failure without mutating the plan', () => {
    let state = currentInitial()
    state.day = 3
    state.power = 1
    const copy = structuredClone(state)
    assert.equal(calculate(state).over, true)
    const staffed = move(state, 'aoi', 0)
    assert.equal(calculate(staffed).over, false)
    assert.deepEqual(state, copy)
  })
})
