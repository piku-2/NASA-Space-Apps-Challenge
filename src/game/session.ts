import {
  R,
  beginDay,
  buildAt,
  canPlan,
  crewCell,
  eventOf,
  firstIdle,
  initial,
  lastInCell,
  move,
  resolveDay,
  restore,
  setFlareCover,
  setShelter,
  shownDay,
  specialtyMatches,
  upgradeAt,
  wake,
  project,
  type GameState,
  type Report,
} from '../domain/simulation.ts'
import type { Lang } from './i18n.ts'
import { phaseNotices, type Notice } from './text.ts'

const SAVE_KEY = 'mars_notebook_v1'

export interface DayNote {
  day: number
  event: string
  harvest: number
  produced_science: number
  produced_material: number
  damage: number
  healed: number
  sheltered: boolean
  cover_committed: boolean
  cover_power: number
  discoveries: string[]
  shortage: boolean
}

export class Session {
  state: GameState = initial()
  language: Lang = 'ja'
  selected = 1
  selectedCrew = ''
  buildKind = ''
  action: Notice[] = []
  history: DayNote[] = []
  streak = 0
  atTitle = true
  saved = true
  confirmRestart = false
  ended = ''
  pendingSfx = ''

  constructor() {
    this.load()
  }

  notices(): Notice[] {
    return this.action.length > 0 ? this.action : phaseNotices(this.state)
  }

  start(): void {
    this.atTitle = false
  }

  toggleLanguage(): void {
    this.language = this.language === 'ja' ? 'en' : 'ja'
    this.save()
  }

  selectCrew(id: string): void {
    this.confirmRestart = false
    if (!id) return
    if (!canPlan(this.state)) {
      this.action = [{ key: 'plan_locked' }]
      return
    }
    if (this.selectedCrew === id) {
      this.selectedCrew = ''
      return
    }
    this.selectedCrew = id
    this.buildKind = ''
  }

  chooseBuild(kind: string): void {
    this.confirmRestart = false
    if (!canPlan(this.state)) {
      this.action = [{ key: 'plan_locked' }]
      return
    }
    this.buildKind = this.buildKind === kind ? '' : kind
    this.selectedCrew = ''
  }

  selectCell(index: number): void {
    this.confirmRestart = false
    if (this.state.over || index < 0 || index >= this.state.cells.length) return
    this.selected = index
    if (!canPlan(this.state)) {
      if (this.selectedCrew || this.buildKind) this.action = [{ key: 'plan_locked' }]
      return
    }
    const cell = this.state.cells[index]
    if (this.selectedCrew) {
      if (cell.kind === '' || cell.kind === 'shield') return
      if (crewCell(this.state, this.selectedCrew) === index) {
        this.selectedCrew = ''
        return
      }
      if (cell.crew >= Math.trunc(R.capacity)) {
        this.action = [{ key: 'full' }]
        return
      }
      const who = this.selectedCrew
      const moved = move(this.state, who, index)
      if (crewCell(moved, who) !== index) return
      this.state = moved
      this.selectedCrew = ''
      this.announce(who, index)
      this.save()
      return
    }
    if (cell.kind === '' && this.buildKind) this.buildSelected(this.buildKind)
  }

  assignIdle(): void {
    if (!this.guardPlan()) return
    const cell = this.state.cells[this.selected]
    if (!cell || cell.kind === '' || cell.kind === 'shield') return
    const id = firstIdle(this.state)
    if (!id) {
      this.action = [{ key: 'no_crew' }]
      return
    }
    if (cell.crew >= Math.trunc(R.capacity)) {
      this.action = [{ key: 'full' }]
      return
    }
    const moved = move(this.state, id, this.selected)
    if (crewCell(moved, id) !== this.selected) return
    this.state = moved
    this.selectedCrew = ''
    this.announce(id, this.selected)
    this.save()
  }

  removeOne(): void {
    if (!this.guardPlan()) return
    const id = lastInCell(this.state, this.selected)
    if (!id) return
    this.state = move(this.state, id, -1)
    this.selectedCrew = ''
    this.action = [{ key: 'removed' }]
    this.save()
  }

  returnSelected(): void {
    if (!this.guardPlan() || !this.selectedCrew) return
    this.state = move(this.state, this.selectedCrew, -1)
    this.selectedCrew = ''
    this.action = [{ key: 'removed' }]
    this.save()
  }

  upgrade(): void {
    if (!this.guardPlan()) return
    const cell = this.state.cells[this.selected]
    if (!cell || cell.kind === '' || cell.kind === 'shield' || cell.level >= Math.trunc(R.max_level)) return
    const cost = Math.trunc(R.upgrade) * cell.level
    if (this.state.material < cost) {
      this.action = [{ key: 'need_material' }]
      return
    }
    this.state = upgradeAt(this.state, this.selected)
    this.action = [{ key: 'upgraded' }]
    this.save()
  }

  toggleShelter(): void {
    if (!this.guardPlan()) return
    const active = !this.state.shelter
    this.state = setShelter(this.state, active)
    this.action = [{ key: active ? 'sheltered' : 'unsheltered' }]
    this.save()
  }

  chooseCover(active: boolean): void {
    if (!this.guardPlan()) return
    if (this.state.shelter) {
      this.action = [{ key: 'choice_while_shelter' }]
      return
    }
    const preview = project(this.state, active)
    this.state = setFlareCover(this.state, active)
    if (active && !preview.report?.cover_committed) {
      this.action = [{ key: 'choice_cover_unready', args: [Math.trunc(R.flare_cover_power)] }]
    } else {
      this.action = [{ key: active ? 'choice_cover_set' : 'choice_keep_set' }]
    }
    this.save()
  }

  advance(): void {
    if (this.state.over) return
    this.selectedCrew = ''
    this.buildKind = ''
    this.confirmRestart = false
    const phase = this.state.phase
    if (phase === 'morning' || phase === 'day') {
      const wasWon = this.state.won
      const started = phase === 'morning' ? beginDay(this.state) : this.state
      this.state = resolveDay(started)
      this.action = phaseNotices(this.state)
      if (this.state.phase === 'night' && this.state.report) {
        this.history.push(noteFrom(this.state.report, shownDay(this.state)))
        if (this.history.length > 40) this.history.shift()
        if ((this.state.report.survival ?? 0) > 0 && !this.state.over) this.streak += 1
        else this.streak = 0
        if (this.state.over) this.ended = 'loss'
        else if (this.state.won && !wasWon) this.ended = 'win'
      }
    } else if (phase === 'night') {
      this.state = wake(this.state)
      this.action = []
      if (eventOf(this.state) === 'flare') this.pendingSfx = 'alarm'
    }
    this.save()
  }

  restart(): void {
    this.state = initial()
    this.selected = 1
    this.selectedCrew = ''
    this.buildKind = ''
    this.history = []
    this.streak = 0
    this.ended = ''
    this.confirmRestart = false
    this.atTitle = false
    this.action = []
    this.save()
  }

  private buildSelected(kind: string): void {
    const cell = this.state.cells[this.selected]
    if (!cell || cell.kind !== '') return
    const cost = Math.trunc(kind === 'shield' ? R.shield_cost : R.build)
    if (this.state.material < cost) {
      this.action = [{ key: 'need_material' }]
      return
    }
    const built = buildAt(this.state, this.selected, kind)
    if (built.cells[this.selected].kind !== kind) return
    this.state = built
    this.buildKind = ''
    this.action = [{ key: 'built' }]
    this.pendingSfx = 'place'
    this.save()
  }

  private announce(id: string, cell: number): void {
    const kind = this.state.cells[cell]?.kind ?? ''
    if (specialtyMatches(id, kind)) {
      this.action = [
        { key: 'quip_' + id },
        { key: 'bonus_words', args: [Math.trunc(bonusOf(kind))] },
      ]
      this.pendingSfx = 'expert'
    } else {
      this.action = [{ key: 'quip_other', args: [id, kind] }]
      this.pendingSfx = 'place'
    }
  }

  private guardPlan(): boolean {
    this.confirmRestart = false
    if (this.state.over) return false
    if (!canPlan(this.state)) {
      this.action = [{ key: 'plan_locked' }]
      return false
    }
    return true
  }

  private load(): void {
    const store = storage()
    if (!store) return
    try {
      const raw = store.getItem(SAVE_KEY)
      if (!raw) return
      const data = JSON.parse(raw) as { version?: number; language?: string; state?: unknown; streak?: number; history?: unknown }
      const restored = restore(data.state, Number(data.version ?? 0))
      if (!restored) return
      this.state = restored
      this.language = data.language === 'en' ? 'en' : 'ja'
      this.streak = Math.max(0, Math.trunc(Number(data.streak ?? 0)) || 0)
      this.history = Array.isArray(data.history) ? data.history.slice(-40).map(asNote).filter((note): note is DayNote => note !== null) : []
      this.ended = restored.over ? 'loss' : restored.won ? 'win' : ''
    } catch {
      this.saved = false
    }
  }

  private save(): void {
    const store = storage()
    if (!store) {
      this.saved = false
      return
    }
    try {
      store.setItem(SAVE_KEY, JSON.stringify({
        version: 3,
        language: this.language,
        state: this.state,
        streak: this.streak,
        history: this.history,
      }))
      this.saved = true
    } catch {
      this.saved = false
    }
  }
}

function bonusOf(kind: string): number {
  const table: Record<string, number> = {
    solar: R.solar_expert,
    water: R.water_expert,
    greenhouse: R.plant_expert,
    lab: R.lab_expert,
    mine: R.mine_expert,
  }
  return table[kind] ?? 0
}

function noteFrom(report: Report, day: number): DayNote {
  return {
    day,
    event: report.event,
    harvest: report.harvest,
    produced_science: report.produced_science,
    produced_material: report.produced_material,
    damage: report.damage,
    healed: report.healed,
    sheltered: report.sheltered,
    cover_committed: report.cover_committed,
    cover_power: report.cover_power,
    discoveries: [...report.new_discoveries],
    shortage: report.shortage,
  }
}

function asNote(value: unknown): DayNote | null {
  if (!value || typeof value !== 'object') return null
  const note = value as Partial<DayNote>
  if (typeof note.day !== 'number' || !Number.isFinite(note.day) || typeof note.event !== 'string') return null
  return {
    day: Math.trunc(note.day),
    event: note.event,
    harvest: num(note.harvest),
    produced_science: num(note.produced_science),
    produced_material: num(note.produced_material),
    damage: num(note.damage),
    healed: num(note.healed),
    sheltered: Boolean(note.sheltered),
    cover_committed: Boolean(note.cover_committed),
    cover_power: num(note.cover_power),
    discoveries: Array.isArray(note.discoveries) ? note.discoveries.map(String) : [],
    shortage: Boolean(note.shortage),
  }
}

function num(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? Math.trunc(value) : 0
}

function storage(): Storage | null {
  try {
    const store = globalThis.localStorage
    if (!store) return null
    return store
  } catch {
    return null
  }
}
