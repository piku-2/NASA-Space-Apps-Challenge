// Resource rules for the base. No rendering, storage, or browser APIs.
import raw from '../../data/values.json' with { type: 'json' }

export interface Cell {
  kind: string
  level: number
  crew: number
  progress: number
}

export interface CrewPlace {
  id: string
  cell: number
}

export interface Report {
  upkeep_power?: number
  harvest: number
  survival: number
  power: number
  material: number
  science: number
  health: number
  damage: number
  produced_survival: number
  produced_power: number
  produced_material: number
  produced_science: number
  healed: number
  shortage: boolean
  sheltered: boolean
  event: string
  new_discoveries: string[]
  research_paused: number
  cover_power: number
  cover_committed: boolean
  harvest_cells: number[]
}

export interface GameState {
  // Missing means legacy rules, so existing saves keep their original budget.
  rules_version?: number
  day: number
  power: number
  material: number
  science: number
  health: number
  crew: number
  seed: number
  shield: boolean
  shelter: boolean
  won: boolean
  over: boolean
  survival: number
  flare_cover: boolean
  cells: Cell[]
  roster: CrewPlace[]
  phase: string
  discoveries: string[]
  shortage?: boolean
  report?: Report
}

interface ConfigFile {
  initial: {
    day: number
    power: number
    material: number
    science: number
    health: number
    crew: number
    seed: number
    shield: boolean
    shelter: boolean
    won: boolean
    over: boolean
    survival: number
    flare_cover: boolean
  }
  rules: Record<string, number>
  crew: { id: string; specialty: string }[]
  facilities: string[]
  events: string[]
}

export const CONFIG = raw as ConfigFile
export const R = CONFIG.rules

const START_KIND: Record<number, string> = {
  0: 'solar',
  1: 'water',
  4: 'greenhouse',
  7: 'lab',
  10: 'habitat',
}

function clone<T>(value: T): T {
  return structuredClone(value)
}

function int(value: number): number {
  return Math.trunc(value)
}

function isNum(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value)
}

function isDict(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function rule(name: string, fallback = 0): number {
  const value = R[name]
  return typeof value === 'number' ? value : fallback
}

export function initial(): GameState {
  const start = CONFIG.initial
  const state: GameState = {
    rules_version: 4,
    day: int(start.day),
    power: int(start.power),
    material: int(start.material),
    science: int(start.science),
    health: int(start.health),
    crew: int(start.crew),
    seed: int(start.seed),
    shield: start.shield,
    shelter: start.shelter,
    won: start.won,
    over: start.over,
    survival: int(start.survival),
    flare_cover: start.flare_cover,
    cells: [],
    roster: [
      { id: 'aoi', cell: 10 },
      { id: 'ren', cell: 1 },
      { id: 'mio', cell: -1 },
      { id: 'sora', cell: -1 },
      { id: 'haru', cell: -1 },
      { id: 'rikuto', cell: -1 },
    ],
    phase: 'morning',
    discoveries: [],
  }
  for (let i = 0; i < 18; i++) {
    state.cells.push({ kind: START_KIND[i] ?? '', level: 1, crew: 0, progress: 0 })
  }
  syncCounts(state)
  return state
}

function mix(seed: number, index: number): number {
  let x = (int(seed) >>> 0) ^ Math.imul(index + 1, 0x9e3779b1)
  x = Math.imul(x ^ (x >>> 16), 0x7feb352d)
  x = Math.imul(x ^ (x >>> 15), 0x846ca68b)
  return (x ^ (x >>> 16)) >>> 0
}

export function eventOf(state: { day: number; seed?: number }, offset = 0): string {
  const events = CONFIG.events
  const index = int(state.day) - 1 + offset
  const base = events[((index % events.length) + events.length) % events.length]
  const permille = Math.max(0, Math.min(1000, int(rule('sep_day_permille'))))
  if (permille > 0 && mix(state.seed ?? 1, index) % 1000 < permille) return 'flare'
  return base === 'flare' ? 'calm' : base
}

export function shownDay(state: GameState): number {
  const day = int(state.day ?? 1)
  if (String(state.phase ?? '') === 'night') return Math.max(1, day - 1)
  return day
}

export function shownEvent(state: GameState): string {
  if (state.phase === 'night' && state.report && state.report.event) return state.report.event
  return eventOf(state)
}

export function morningAhead(state: GameState): string {
  if (state.phase === 'night') return eventOf(state)
  return eventOf(state, 1)
}

export function specialty(id: string): string {
  return CONFIG.crew.find((entry) => entry.id === id)?.specialty ?? ''
}

export function expertBonus(kind: string): number {
  switch (kind) {
    case 'solar': return int(rule('solar_expert'))
    case 'water': return int(rule('water_expert'))
    case 'greenhouse': return int(rule('plant_expert'))
    case 'lab': return int(rule('lab_expert'))
    case 'mine': return int(rule('mine_expert'))
    default: return 0
  }
}

export function specialtyMatches(id: string, kind: string): boolean {
  return specialty(id) === kind && expertBonus(kind) > 0
}

export function flareHarm(scienceBefore: number, shielded: boolean, covered: boolean): number {
  let factor = 1
  if (shielded) {
    factor = scienceBefore >= int(rule('unlock_shield_at')) ? rule('shield_factor_plus') : rule('shield_factor')
  }
  let damage = Math.round(rule('flare_damage') * factor)
  if (covered) damage = Math.round(damage * rule('flare_cover_factor'))
  return damage
}

export function canPlan(state: GameState): boolean {
  return String(state.phase ?? 'morning') === 'morning' && !state.over
}

export function idle(state: GameState): number {
  if (Array.isArray(state.roster)) {
    return state.roster.filter((person) => int(person.cell) < 0).length
  }
  const used = state.cells.reduce((sum, cell) => sum + int(cell.crew), 0)
  return int(state.crew) - used
}

export function crewCell(state: GameState, id: string): number {
  const index = indexOf(state, id)
  if (index < 0) return -2
  return int(state.roster[index].cell)
}

export function idleIds(state: GameState): string[] {
  return CONFIG.crew.map((entry) => entry.id).filter((id) => crewCell(state, id) < 0)
}

export function occupants(state: GameState, cell: number): string[] {
  return CONFIG.crew.map((entry) => entry.id).filter((id) => crewCell(state, id) === cell)
}

export function firstIdle(state: GameState): string {
  return idleIds(state)[0] ?? ''
}

export function firstInCell(state: GameState, cell: number): string {
  return occupants(state, cell)[0] ?? ''
}

export function lastInCell(state: GameState, cell: number): string {
  const people = occupants(state, cell)
  return people[people.length - 1] ?? ''
}

export function move(state: GameState, id: string, dest: number): GameState {
  if (!canPlan(state)) return clone(state)
  return place(state, id, dest)
}

export function place(state: GameState, id: string, dest: number): GameState {
  const next = clone(state)
  const index = indexOf(next, id)
  if (index < 0) return clone(state)
  if (int(next.roster[index].cell) === dest) return next
  if (dest < -1 || dest >= next.cells.length) return clone(state)
  if (dest >= 0) {
    const kind = next.cells[dest].kind
    if (kind === '' || kind === 'shield') return clone(state)
    if (countCell(next, dest) >= int(rule('capacity'))) return clone(state)
  }
  next.roster[index].cell = dest
  syncCounts(next)
  return next
}

export function buildAt(state: GameState, index: number, kind: string): GameState {
  if (!canPlan(state)) return clone(state)
  if (index < 0 || index >= state.cells.length || !CONFIG.facilities.includes(kind)) return clone(state)
  if (state.cells[index].kind !== '') return clone(state)
  if (kind === 'shield' && state.shield) return clone(state)
  const cost = int(kind === 'shield' ? rule('shield_cost') : rule('build'))
  if (int(state.material) < cost) return clone(state)
  const next = clone(state)
  next.material = int(next.material) - cost
  next.cells[index] = { kind, crew: 0, level: 1, progress: 0 }
  if (kind === 'shield') next.shield = true
  syncCounts(next)
  return next
}

export function upgradeAt(state: GameState, index: number): GameState {
  if (!canPlan(state)) return clone(state)
  if (index < 0 || index >= state.cells.length) return clone(state)
  const cell = state.cells[index]
  if (cell.kind === '' || cell.kind === 'shield' || int(cell.level) >= int(rule('max_level'))) return clone(state)
  const cost = int(rule('upgrade')) * int(cell.level)
  if (int(state.material) < cost) return clone(state)
  const next = clone(state)
  next.material = int(next.material) - cost
  next.cells[index].level = int(next.cells[index].level) + 1
  return next
}

export function setShelter(state: GameState, active: boolean): GameState {
  if (!canPlan(state)) return clone(state)
  const next = clone(state)
  next.shelter = active
  return next
}

export function setFlareCover(state: GameState, active: boolean): GameState {
  if (!canPlan(state)) return clone(state)
  const next = clone(state)
  next.flare_cover = active && eventOf(next) === 'flare'
  return next
}

export function project(state: GameState, cover: boolean): GameState {
  const next = clone(state)
  next.flare_cover = cover
  return calculate(next)
}

export interface ForecastDelta {
  survival: number
  power: number
  material: number
  science: number
  health: number
  harvest: number
  shortage: boolean
}

export function forecastChange(before: GameState, after: GameState): ForecastDelta {
  const left = calculate(before)
  const right = calculate(after)
  return {
    survival: zero((int(right.survival) - int(after.survival)) - (int(left.survival) - int(before.survival))),
    power: zero((int(right.power) - int(after.power)) - (int(left.power) - int(before.power))),
    material: zero((int(right.material) - int(after.material)) - (int(left.material) - int(before.material))),
    science: zero((int(right.science) - int(after.science)) - (int(left.science) - int(before.science))),
    health: zero((int(right.health) - int(after.health)) - (int(left.health) - int(before.health))),
    harvest: zero(int(right.report?.harvest ?? 0) - int(left.report?.harvest ?? 0)),
    shortage: Boolean(right.shortage) && !left.shortage,
  }
}

function zero(value: number): number {
  return value === 0 ? 0 : value
}

export function beginDay(state: GameState): GameState {
  if (String(state.phase ?? 'morning') !== 'morning' || state.over) return clone(state)
  const next = clone(state)
  next.phase = 'day'
  return next
}

export function resolveDay(state: GameState): GameState {
  if (state.phase !== 'day' || state.over) return clone(state)
  const next = calculate(state)
  next.phase = 'night'
  return next
}

export function wake(state: GameState): GameState {
  if (state.phase !== 'night' || state.over) return clone(state)
  const next = clone(state)
  next.phase = 'morning'
  next.flare_cover = false
  return next
}

export function calculate(state: GameState): GameState {
  const next = clone(state)
  if (Array.isArray(next.roster)) syncCounts(next)
  const ev = eventOf(state)
  const scienceBefore = int(state.science)
  const survivalBefore = int(state.survival)
  const powerBefore = int(state.power)
  const materialBefore = int(state.material)
  const healthBefore = int(state.health)
  let harvest = 0
  let survivalMade = 0
  let powerMade = 0
  let materialMade = 0
  let scienceMade = 0
  let healed = 0
  let researchPaused = 0
  let coverPower = 0
  let coverCommitted = false
  const harvestCells: number[] = []
  const wantCover = ev === 'flare' && Boolean(state.flare_cover) && !state.shelter
  next.shortage = false

  for (let index = 0; index < next.cells.length; index++) {
    const cell = next.cells[index]
    if (cell.kind !== 'solar') continue
    let output = int(rule('solar')) * int(cell.level) + int(cell.crew) * int(rule('solar_staff'))
    if (ev === 'sun') output += int(rule('solar_bonus'))
    if (ev === 'dust') output = int(output / 2)
    if (specialistAt(next, index, 'solar')) output += int(rule('solar_expert'))
    powerMade += output
    next.power += output
  }

  const upkeep = state.rules_version === 4 ? int(rule('life_support_power')) : 0
  next.power -= upkeep

  if (state.shelter) {
    next.power -= int(rule('shelter_power'))
  } else {
    for (let index = 0; index < next.cells.length; index++) {
      const cell = next.cells[index]
      const staff = int(cell.crew)
      if (staff === 0) continue
      const level = int(cell.level)
      const powerName = (cell.kind === 'greenhouse' ? 'plant' : cell.kind) + '_power'
      const cost = int(rule(powerName)) * staff
      if (int(next.power) < cost) {
        next.shortage = true
        continue
      }
      next.power -= cost
      if (cell.kind === 'water') {
        let made = int(rule('water')) * staff * level
        if (specialistAt(next, index, 'water')) made += int(rule('water_expert'))
        survivalMade += made
        next.survival += made
      } else if (cell.kind === 'greenhouse') {
        let progress = int(cell.progress ?? 0) + 1
        if (progress >= int(rule('plant_days'))) {
          let per = int(rule('plant_yield'))
          if (scienceBefore >= int(rule('unlock_plant_at'))) per += int(rule('plant_unlock_bonus'))
          let amount = per * staff * level
          if (specialistAt(next, index, 'greenhouse')) amount += int(rule('plant_expert'))
          harvest += amount
          survivalMade += amount
          next.survival += amount
          harvestCells.push(index)
          progress = 0
        }
        next.cells[index].progress = progress
      } else if (cell.kind === 'lab') {
        let learned = int(rule('lab')) * staff * level
        if (specialistAt(next, index, 'lab')) learned += int(rule('lab_expert'))
        const extra = int(rule('flare_cover_power'))
        if (wantCover && int(next.power) >= extra) {
          next.power -= extra
          researchPaused += learned
          coverPower += extra
          coverCommitted = true
        } else {
          scienceMade += learned
          next.science += learned
        }
      } else if (cell.kind === 'mine') {
        let mined = int(rule('mine')) * staff * level
        if (specialistAt(next, index, 'mine')) mined += int(rule('mine_expert'))
        materialMade += mined
        next.material += mined
      } else if (cell.kind === 'habitat') {
        const gain = int(rule('habitat_heal')) * staff
        const beforeHealth = int(next.health)
        next.health = Math.min(100, beforeHealth + gain)
        healed += int(next.health) - beforeHealth
      }
    }
  }

  next.survival -= int(rule('daily_survival'))
  let damage = 0
  if (ev === 'flare' && !state.shelter) {
    damage = flareHarm(scienceBefore, Boolean(state.shield), coverCommitted)
    next.health -= damage
  }

  const owned: string[] = []
  if (Array.isArray(state.discoveries)) {
    for (const item of state.discoveries) {
      const known = String(item)
      if ((known === 'shielding' || known === 'crops') && !owned.includes(known)) owned.push(known)
    }
  }
  const fresh: string[] = []
  if (scienceBefore < int(rule('unlock_shield_at')) && int(next.science) >= int(rule('unlock_shield_at')) && !owned.includes('shielding')) {
    owned.push('shielding')
    fresh.push('shielding')
  }
  if (scienceBefore < int(rule('unlock_plant_at')) && int(next.science) >= int(rule('unlock_plant_at')) && !owned.includes('crops')) {
    owned.push('crops')
    fresh.push('crops')
  }
  next.discoveries = owned
  next.shelter = false
  next.day = int(next.day) + 1
  next.over = int(next.survival) < 0 || int(next.power) < 0 || int(next.health) <= 0
  next.won = Boolean(state.won) || (int(next.day) > int(rule('days')) && int(next.science) >= int(rule('target')) && !next.over)
  next.report = {
    upkeep_power: upkeep,
    harvest,
    survival: int(next.survival) - survivalBefore,
    power: int(next.power) - powerBefore,
    material: int(next.material) - materialBefore,
    science: scienceMade,
    health: int(next.health) - healthBefore,
    damage,
    produced_survival: survivalMade,
    produced_power: powerMade,
    produced_material: materialMade,
    produced_science: scienceMade,
    healed,
    shortage: Boolean(next.shortage),
    sheltered: Boolean(state.shelter),
    event: ev,
    new_discoveries: fresh,
    research_paused: researchPaused,
    cover_power: coverPower,
    cover_committed: coverCommitted,
    harvest_cells: harvestCells,
  }
  return next
}

export function restore(candidate: unknown, version: number): GameState | null {
  if (version !== 1 && version !== 2 && version !== 3) return null
  if (!isDict(candidate) || !Array.isArray(candidate.cells) || candidate.cells.length !== 18) return null
  const state = clone(candidate)
  if (version === 1) {
    const water = isNum(state.water) ? int(state.water) : 18
    const food = isNum(state.food) ? int(state.food) : 18
    state.survival = int((water + food) / 2)
  }
  delete state.water
  delete state.food
  delete state.delivery
  if (typeof state.flare_cover !== 'boolean') state.flare_cover = false

  for (const key of Object.keys(CONFIG.initial) as (keyof ConfigFile['initial'])[]) {
    if (!(key in state)) return null
    const expected = CONFIG.initial[key]
    const got = state[key]
    if (typeof expected === 'number') {
      if (!isNum(got)) return null
      state[key] = int(got)
    } else if (typeof expected === 'boolean') {
      if (typeof got !== 'boolean' && !isNum(got)) return null
    } else {
      return null
    }
  }

  const cells = state.cells as unknown[]
  for (const entry of cells) {
    if (!isDict(entry) || typeof entry.kind !== 'string' || !('crew' in entry) || !('level' in entry)) return null
    if (!isNum(entry.crew) || !isNum(entry.level)) return null
    if (entry.kind !== '' && !CONFIG.facilities.includes(entry.kind)) return null
    if (int(entry.crew) < 0 || int(entry.crew) > int(rule('capacity'))) return null
    if (int(entry.level) < 1 || int(entry.level) > int(rule('max_level'))) return null
  }
  if (int(state.day as number) < 1) return null

  const maxProgress = int(rule('plant_days')) - 1
  for (const entry of cells) {
    if (!isDict(entry)) return null
    entry.crew = int(entry.crew as number)
    entry.level = int(entry.level as number)
    const progress = isNum(entry.progress) ? int(entry.progress) : 0
    entry.progress = Math.min(maxProgress, Math.max(0, progress))
  }

  const normalized = state as unknown as GameState
  normalized.rules_version = state.rules_version === 4 ? 4 : 3
  normalized.cells = cells as Cell[]
  if (!installRoster(normalized)) return null
  if (idle(normalized) < 0) return null
  const phase = String(normalized.phase ?? 'morning')
  normalized.phase = phase === 'morning' || phase === 'day' || phase === 'night' ? phase : 'morning'
  const kept: string[] = []
  if (Array.isArray(normalized.discoveries)) {
    for (const item of normalized.discoveries) {
      const id = String(item)
      if ((id === 'shielding' || id === 'crops') && !kept.includes(id)) kept.push(id)
    }
  }
  normalized.discoveries = kept
  if (!isDict(normalized.report)) delete normalized.report
  else {
    // Older or interrupted saves may contain a partial night report.
    const report = normalized.report as unknown as Record<string, unknown>
    const numeric = ['harvest', 'survival', 'power', 'material', 'science', 'health', 'damage', 'produced_survival', 'produced_power', 'produced_material', 'produced_science', 'healed', 'research_paused', 'cover_power', 'upkeep_power']
    for (const key of numeric) report[key] = isNum(report[key]) ? int(report[key]) : 0
    for (const key of ['shortage', 'sheltered', 'cover_committed']) report[key] = report[key] === true
    report.event = typeof report.event === 'string' && CONFIG.events.includes(report.event) ? report.event : eventOf({ day: Math.max(1, normalized.day - 1), seed: normalized.seed })
    report.new_discoveries = Array.isArray(report.new_discoveries) ? report.new_discoveries.filter(id => id === 'shielding' || id === 'crops') : []
    report.harvest_cells = Array.isArray(report.harvest_cells) ? report.harvest_cells.filter(index => isNum(index) && Number.isInteger(index) && index >= 0 && index < 18) : []
  }
  normalized.over = Boolean(normalized.over)
  normalized.won = Boolean(normalized.won)
  normalized.shield = Boolean(normalized.shield)
  normalized.shelter = Boolean(normalized.shelter)
  normalized.crew = int(normalized.crew)
  normalized.flare_cover = Boolean(normalized.flare_cover)
  return normalized
}

function installRoster(state: GameState): boolean {
  const ids = CONFIG.crew.map((entry) => entry.id)
  let byId: Record<string, number> | null = null
  const incoming = state.roster as unknown
  if (Array.isArray(incoming) && incoming.length === ids.length) {
    byId = {}
    for (const entry of incoming) {
      if (!isDict(entry)) {
        byId = null
        break
      }
      const id = String(entry.id ?? '')
      if (!ids.includes(id) || Object.prototype.hasOwnProperty.call(byId, id)) {
        byId = null
        break
      }
      byId[id] = isNum(entry.cell) ? int(entry.cell) : -1
    }
    if (byId && Object.keys(byId).length !== ids.length) byId = null
  }
  if (!byId) {
    const slots: number[] = []
    for (let i = 0; i < state.cells.length; i++) {
      for (let n = 0; n < int(state.cells[i].crew); n++) slots.push(i)
    }
    if (slots.length > ids.length) return false
    byId = {}
    for (let i = 0; i < ids.length; i++) byId[ids[i]] = i < slots.length ? slots[i] : -1
  }
  const placed: Record<number, number> = {}
  const roster: CrewPlace[] = []
  for (const id of ids) {
    let cell = byId[id]
    if (cell < -1 || cell >= state.cells.length) cell = -1
    if (cell >= 0) {
      const kind = String(state.cells[cell].kind)
      if (kind === '' || kind === 'shield' || (placed[cell] ?? 0) >= int(rule('capacity'))) cell = -1
      else placed[cell] = (placed[cell] ?? 0) + 1
    }
    roster.push({ id, cell })
  }
  state.roster = roster
  syncCounts(state)
  return true
}

function syncCounts(state: { cells: Cell[]; roster?: CrewPlace[] }): void {
  for (const cell of state.cells) cell.crew = 0
  if (!Array.isArray(state.roster)) return
  for (const person of state.roster) {
    const cell = int(person.cell)
    if (cell >= 0 && cell < state.cells.length) state.cells[cell].crew += 1
  }
}

function indexOf(state: GameState, id: string): number {
  if (!Array.isArray(state.roster)) return -1
  return state.roster.findIndex((person) => person.id === id)
}

function countCell(state: GameState, cell: number): number {
  if (!Array.isArray(state.roster)) return 0
  return state.roster.filter((person) => int(person.cell) === cell).length
}

function specialistAt(state: GameState, cell: number, kind: string): boolean {
  if (!Array.isArray(state.roster)) return false
  return state.roster.some((person) => int(person.cell) === cell && specialty(person.id) === kind)
}
