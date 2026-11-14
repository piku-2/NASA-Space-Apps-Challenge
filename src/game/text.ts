import { eventOf, type GameState, type Report } from '../domain/simulation.ts'
import { translate, type Lang } from './i18n.ts'

export interface Notice {
  key: string
  args?: Array<string | number>
}

export function facilityName(lang: Lang, kind: string): string {
  return translate(lang, kind === 'water' ? 'facility_water' : kind)
}

export function renderNotices(lang: Lang, notices: Notice[]): string {
  return notices.map((notice) => renderNotice(lang, notice)).join(' ')
}

export function renderNotice(lang: Lang, notice: Notice): string {
  const args = notice.args ?? []
  if (notice.key === 'discovered') {
    return translate(lang, 'discovered', [translate(lang, 'unlock_' + String(args[0]) + '_name')])
  }
  if (notice.key === 'quip_other') {
    return translate(lang, 'quip_other', [
      translate(lang, 'crew_' + String(args[0])),
      facilityName(lang, String(args[1])),
    ])
  }
  return translate(lang, notice.key, args)
}

export function outcomeNotices(report: Report): Notice[] {
  const parts: Notice[] = []
  if (report.harvest > 0) parts.push({ key: 'outcome_harvest', args: [report.harvest] })
  if (report.produced_science > 0) parts.push({ key: 'outcome_science', args: [report.produced_science] })
  if (report.produced_material > 0) parts.push({ key: 'outcome_material', args: [report.produced_material] })
  if (report.cover_committed) parts.push({ key: 'night_cover', args: [report.cover_power, report.damage] })
  else if (report.sheltered && report.event === 'flare') parts.push({ key: 'night_shelter' })
  else if (report.damage > 0) {
    parts.push({ key: report.event === 'flare' ? 'night_keep_hit' : 'outcome_damage', args: [report.damage] })
  } else if (report.healed > 0) parts.push({ key: 'outcome_heal', args: [report.healed] })
  for (const id of report.new_discoveries) parts.push({ key: 'discovered', args: [id] })
  if (parts.length === 0) parts.push({ key: 'outcome_none' })
  return parts
}

export function phaseNotices(state: GameState): Notice[] {
  if (state.phase === 'night') {
    if (!state.report) return [{ key: 'outcome_none' }]
    const parts: Notice[] = []
    if (state.report.shortage) parts.push({ key: 'shortage' })
    if (state.report.event === 'flare') parts.push({ key: state.report.sheltered ? 'protected' : 'damaged' })
    const outcome = outcomeNotices(state.report)
    if (parts.length > 0 && outcome.length === 1 && outcome[0].key === 'outcome_none') return parts.concat(outcome)
    return parts.concat(outcome)
  }
  return []
}

export function forecastEvent(state: GameState): string {
  return state.phase === 'night' ? morningLabel(state) : eventOf(state, 1)
}

function morningLabel(state: GameState): string {
  return eventOf(state)
}
