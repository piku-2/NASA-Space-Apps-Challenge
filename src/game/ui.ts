import {
  CONFIG,
  R,
  calculate,
  canPlan,
  idleIds,
  morningAhead,
  occupants,
  project,
  shownDay,
  shownEvent,
  specialty,
} from '../domain/simulation.ts'
import { ICONS, LOGO } from './assets.ts'
import type { BoardView } from './board.ts'
import { translate, type Lang } from './i18n.ts'
import { Session, type DayNote } from './session.ts'
import { facilityName, outcomeNotices, renderNotices, type Notice } from './text.ts'

let overlay: '' | 'help' | 'sources' = ''

export function renderShell(root: HTMLElement): void {
  const frame = document.createElement('div')
  frame.id = 'frame'
  root.replaceWith(frame)
  frame.appendChild(root)
  root.innerHTML = `
    <div id="sheet"></div>
    <div id="board"></div>
    <div id="tip" role="tooltip" hidden></div>
    <div id="shade" hidden></div>
    <div id="title" hidden></div>
  `
}

export function fitNotebook(): void {
  const frame = document.getElementById('frame')
  const app = document.getElementById('app')
  if (!frame || !app) return
  const scale = Math.min(window.innerWidth / 1360, window.innerHeight / 800)
  frame.style.width = `${Math.floor(1360 * scale)}px`
  frame.style.height = `${Math.floor(800 * scale)}px`
  app.style.transform = `scale(${scale})`
}

let tipTimer = 0
let tipHold = false
let tipAnchor: HTMLElement | null = null

export function bind(session: Session, onChange: () => void): void {
  const app = document.getElementById('app')
  app?.addEventListener('pointerover', (event) => {
    if (event.pointerType === 'touch') return
    const el = tipHost(event.target)
    if (el) showTipOn(el)
  })
  app?.addEventListener('pointerout', (event) => {
    const el = tipHost(event.target)
    if (!el || tipHold) return
    const next = event.relatedTarget
    if (next instanceof Node && el.contains(next)) return
    if (tipAnchor === el) hideTip()
  })
  app?.addEventListener('focusin', (event) => {
    const el = tipHost(event.target)
    if (el) showTipOn(el)
  })
  app?.addEventListener('focusout', () => {
    if (!tipHold) hideTip()
  })
  app?.addEventListener('pointerdown', (event) => {
    if (event.pointerType === 'mouse') return
    window.clearTimeout(tipTimer)
    tipHold = false
    const el = tipHost(event.target)
    if (!el) {
      hideTip()
      return
    }
    tipTimer = window.setTimeout(() => {
      tipHold = true
      showTipOn(el)
    }, 480)
  })
  const endPress = () => window.clearTimeout(tipTimer)
  app?.addEventListener('pointerup', endPress)
  app?.addEventListener('pointercancel', () => {
    endPress()
    tipHold = false
    hideTip()
  })
  document.addEventListener('cell-tip', (event) => {
    const detail = (event as CustomEvent<{ text: string, clientX: number, clientY: number }>).detail
    if (!detail?.text) {
      if (!tipHold) hideTip()
      return
    }
    showTipText(detail.text, detail.clientX, detail.clientY, 28)
  })
  app?.addEventListener('click', (event) => {
    if (tipHold) {
      tipHold = false
      event.preventDefault()
      event.stopPropagation()
      return
    }
    const target = (event.target as HTMLElement).closest<HTMLElement>('[data-act]')
    if (!target || target.getAttribute('aria-disabled') === 'true') return
    const act = target.dataset.act
    if (act === 'start') session.start()
    else if (act === 'lang') session.toggleLanguage()
    else if (act === 'advance') session.advance()
    else if (act === 'crew') session.selectCrew(target.dataset.id ?? '')
    else if (act === 'build') session.chooseBuild(target.dataset.kind ?? '')
    else if (act === 'upgrade') session.upgrade()
    else if (act === 'assign') session.assignIdle()
    else if (act === 'remove') session.removeOne()
    else if (act === 'shelter') session.toggleShelter()
    else if (act === 'keep') session.chooseCover(false)
    else if (act === 'cover') session.chooseCover(true)
    else if (act === 'restart') session.confirmRestart = true
    else if (act === 'restart-no') session.confirmRestart = false
    else if (act === 'restart-yes') session.restart()
    else if (act === 'dismiss') session.ended = ''
    else if (act === 'help') overlay = 'help'
    else if (act === 'sources') overlay = 'sources'
    else if (act === 'close-overlay') overlay = ''
    else return
    onChange()
  })
}

export function render(session: Session): void {
  const lang = session.language
  const tr = (key: string, args: Array<string | number> = []) => translate(lang, key, args)
  const sheet = document.getElementById('sheet')
  const shade = document.getElementById('shade')
  const title = document.getElementById('title')
  const flare = session.state.phase !== 'night' && shownEvent(session.state) === 'flare'
  if (sheet) {
    sheet.className = flare ? 'flare' : ''
    sheet.innerHTML = sheetHtml(session, tr)
  }
  if (shade) {
    const modal = modalHtml(session, tr)
    shade.hidden = modal === ''
    shade.innerHTML = modal
  }
  if (title) {
    title.hidden = !session.atTitle
    title.innerHTML = session.atTitle ? titleHtml(tr) : ''
  }
  document.documentElement.lang = lang
  document.title = tr('title')
}

export function boardView(session: Session): BoardView {
  const planning = canPlan(session.state)
  return {
    selected: session.selected,
    phase: session.state.phase,
    flare: shownEvent(session.state) === 'flare',
    plantDays: Math.trunc(R.plant_days),
    cells: session.state.cells.map((cell, index) => ({
      kind: cell.kind,
      level: cell.level,
      progress: cell.progress,
      hint: !planning ? ''
        : session.buildKind && cell.kind === '' ? 'build'
          : session.selectedCrew && cell.kind !== '' && cell.kind !== 'shield' && cell.crew < Math.trunc(R.capacity) ? 'move'
            : '',
      tip: cellTip(session, index),
      crew: occupants(session.state, index).map((id) => ({
        name: translate(session.language, 'crew_' + id),
        color: crewColor(id),
        selected: session.selectedCrew === id,
      })),
    })),
  }
}

function cellTip(session: Session, index: number): string {
  const tr = (key: string, args: Array<string | number> = []) => translate(session.language, key, args)
  const cell = session.state.cells[index]
  if (!cell) return ''
  const people = occupants(session.state, index).map((id) => tr('crew_detail', [
    tr('crew_' + id),
    tr('spec_' + specialty(id)),
    tr('spec_bonus_' + specialty(id)),
  ]))
  if (!cell.kind) {
    const build = session.buildKind ? facilityName(session.language, session.buildKind) : ''
    return [tr('empty'), build, tr('build_hint'), ...people].filter(Boolean).join('\n')
  }
  const lines = [
    facilityName(session.language, cell.kind),
    tr('level', [cell.level]),
    tr(cell.kind + '_desc'),
  ]
  if (cell.kind === 'greenhouse') lines.push(tr('plant_progress', [Math.max(0, Math.trunc(R.plant_days) - cell.progress)]))
  lines.push(...people)
  return lines.filter(Boolean).join('\n')
}

function sheetHtml(session: Session, tr: Tr): string {
  return `
    ${headerHtml(session, tr)}
    ${eventHtml(session, tr)}
    ${buildHtml(session, tr)}
    ${forecastHtml(session, tr)}
    ${crewHtml(session, tr)}
    ${footerHtml(session, tr)}
  `
}

function headerHtml(session: Session, tr: Tr): string {
  const state = session.state
  const day = shownDay(state)
  const keys = ['survival', 'power', 'material', 'science'] as const
  const chips = keys.map((key, index) => {
    const icon = ICONS[key === 'science' ? 'star' : key]
    const amount = state[key]
    return `<div class="res" tabindex="0" style="left:${250 + index * 250}px" ${tipAttr(tr(key))}><img src="${icon}" alt=""><strong class="${amount <= 3 ? 'down' : ''}">${amount}</strong><i></i></div>`
  }).join('')
  return `
    <div class="day">${esc(tr('day', [day]))}</div>
    ${chips}
    ${session.saved ? '' : `<div class="save-failed">${esc(tr('save_failed'))}</div>`}
    <div class="rule"></div>
    <img class="logo" src="${LOGO}" alt="">
    <h1 class="title-name">${esc(tr('title'))}</h1>
    <div class="phase-label" tabindex="0" ${tipAttr(tr('phase_' + state.phase))}>${esc(tr('phase_short_' + state.phase))}</div>
    ${session.streak >= 2 ? `<span class="streak" tabindex="0" ${tipAttr(tr('streak_badge', [session.streak]))}>${session.streak}</span>` : ''}
    <button type="button" class="icon-btn help-btn" data-act="help" ${tipAttr(tr('help'))}>${esc(tr('btn_help'))}</button>
    <button type="button" class="lang" data-act="lang">${esc(tr('language'))}</button>
  `
}

function eventHtml(session: Session, tr: Tr): string {
  const state = session.state
  const ev = shownEvent(state)
  const ahead = morningAhead(state)
  const night = state.phase === 'night'
  const flare = !night && ev === 'flare'
  const nowTip = [tr('event'), tr(ev), tr(ev + '_desc'), ev === 'flare' ? tr('archive') : ''].filter(Boolean).join('\n')
  const nextTip = (night ? tr('next_morning_weather') : tr('tomorrow')) + tr(ahead) + '\n' + tr(ahead + '_desc')
  return `
    <section id="event" class="panel">
      <div class="event-row ${ev === 'flare' ? 'down' : ''}" tabindex="0" ${tipAttr(nowTip)}><strong>${esc(tr('wx_' + ev))}</strong></div>
      ${flare ? flareHtml(session, tr) : ''}
      ${flare ? '' : `<div class="next-wx" tabindex="0" ${tipAttr(nextTip)}><span>${esc(tr('next_short'))}</span><strong>${esc(tr('wx_' + ahead))}</strong></div>`}
    </section>
  `
}

function forecastHtml(session: Session, tr: Tr): string {
  const state = session.state
  const night = state.phase === 'night'
  const forecast = night ? null : calculate(state)
  const deltas = {
    survival: night ? state.report?.survival ?? 0 : (forecast?.survival ?? 0) - state.survival,
    power: night ? state.report?.power ?? 0 : (forecast?.power ?? 0) - state.power,
    material: night ? state.report?.material ?? 0 : (forecast?.material ?? 0) - state.material,
    science: night ? state.report?.science ?? 0 : (forecast?.science ?? 0) - state.science,
  }
  const warning = !forecast ? '' : forecast.shortage ? tr('shortage') : forecast.over ? tr('loss_title') : ''
  const cols = (['survival', 'power', 'material', 'science'] as const).map((key, index) => {
    const value = deltas[key]
    const icon = ICONS[key === 'science' ? 'star' : key]
    return `<div class="delta ${value >= 0 ? 'up' : 'down'}" tabindex="0" style="left:${930 + index * 100}px" ${tipAttr(tr(night ? 'outcome' : 'forecast') + ' · ' + tr(key))}><img src="${icon}" alt=""><strong>${signed(value)}</strong></div>`
  }).join('')
  return `
    ${cols}
    ${warning && !night ? `<p class="warn" tabindex="0" ${tipAttr(warning)}>!</p>` : ''}
  `
}

function flareHtml(session: Session, tr: Tr): string {
  const state = session.state
  const planning = canPlan(state)
  if (state.shelter) {
    return `<button type="button" class="on shelter-on" data-act="shelter" ${off(planning)} ${tipAttr(tr('shelter_on') + '\n' + tr('choice_shelter_note'))}><img src="${ICONS.habitat}" alt=""></button>`
  }
  const keep = project(state, false)
  const cover = project(state, true)
  const ready = Boolean(cover.report?.cover_committed)
  const keepText = tr('choice_keep_stat', [signed(keep.science - state.science), signed(keep.health - state.health)])
  const coverText = ready
    ? tr('choice_cover_stat', [cover.report?.cover_power ?? Math.trunc(R.flare_cover_power), signed(cover.science - state.science), signed(cover.health - state.health)])
    : tr('choice_cover_blocked', [Math.trunc(R.flare_cover_power)])
  const keepOn = !state.flare_cover
  return `
    <div class="choice">
      <button type="button" data-act="keep" class="${keepOn ? 'on' : ''}" ${off(planning)} ${tipAttr(tr('choice_keep') + '\n' + keepText)}>
        <img src="${ICONS.lab}" alt=""><strong>${esc(signed(keep.science - state.science))}</strong>
      </button>
      <button type="button" data-act="cover" class="${state.flare_cover ? 'on' : ''}" ${off(planning)} ${tipAttr(tr('choice_cover') + '\n' + coverText)}>
        <img src="${ICONS.shield}" alt=""><strong>${esc(ready ? '−' + (cover.report?.cover_power ?? Math.trunc(R.flare_cover_power)) : '−')}</strong>
      </button>
      <button type="button" data-act="shelter" ${off(planning)} ${tipAttr(tr('shelter') + '\n' + tr('shelter_info'))}><img src="${ICONS.habitat}" alt=""></button>
    </div>
  `
}

function buildHtml(session: Session, tr: Tr): string {
  const state = session.state
  const planning = canPlan(state)
  const builds = CONFIG.facilities.map((kind, index) => {
    const cost = Math.trunc(kind === 'shield' ? R.shield_cost : R.build)
    const disabled = !planning || state.material < cost || (kind === 'shield' && state.shield)
    const flare = session.state.phase !== 'night' && shownEvent(state) === 'flare'
    const col = index % 4
    const row = Math.floor(index / 4)
    const left = 932 + col * 100
    const top = (flare ? 388 : 358) + row * 100
    const name = facilityName(session.language, kind)
    const tip = [name, tr(kind + '_desc'), tr('build_cost', [cost]), tr('build_hint')].join('\n')
    return `
      <button type="button" class="build-btn ${session.buildKind === kind ? 'on' : ''}" style="left:${left}px;top:${top}px" data-act="build" data-kind="${esc(kind)}" ${off(!disabled)} ${tipAttr(tip)}><img src="${ICONS[kind]}" alt=""><em class="${state.material < cost ? 'down' : ''}"><img src="${ICONS.material}" alt="">${cost}</em></button>
    `
  }).join('')
  return `
    <section id="build" class="panel"></section>
    ${builds}
  `
}

function crewHtml(session: Session, tr: Tr): string {
  const state = session.state
  const planning = canPlan(state)
  const waiting = idleIds(state)
  const coins = waiting.map((id, index) => coin(id, crewTip(tr, id), 188 + index * 74, 668, 32, session.selectedCrew === id, planning, tr('crew_' + id))).join('')
  const onCells = state.cells.map((_, index) => {
    const people = occupants(state, index)
    const col = index % 6
    const row = Math.floor(index / 6)
    return people.map((id, person) => {
      const cx = 32 + col * 144 + 113 - person * 37
      const cy = 180 + row * 146 + 91
      return coin(id, crewTip(tr, id), cx, cy, 26, session.selectedCrew === id, planning, tr('crew_' + id))
    }).join('')
  }).join('')
  return `
    <div class="crew-mark" tabindex="0" ${tipAttr(tr('waiting') + '\n' + tr('crew_hint'))}>${esc(tr('btn_wait'))}</div>
    ${coins}
    ${onCells}
  `
}

function crewTip(tr: Tr, id: string): string {
  const spec = specialty(id)
  return tr('crew_detail', [tr('crew_' + id), tr('spec_' + spec), tr('spec_bonus_' + spec)])
}

function coin(id: string, tip: string, cx: number, cy: number, radius: number, selected: boolean, planning: boolean, name: string): string {
  const size = radius * 2
  return `<button type="button" class="coin ${selected ? 'on' : ''}" data-act="crew" data-id="${esc(id)}" ${off(planning)} style="left:${cx - radius}px;top:${cy - radius}px;width:${size}px;height:${size}px" ${tipAttr(tip)}><img src="${ICONS.crew}" alt=""><span>${esc(name)}</span></button>`
}

function footerHtml(session: Session, tr: Tr): string {
  const state = session.state
  const planning = canPlan(state)
  const day = shownDay(state)
  const health = Math.max(0, Math.min(100, state.health))
  const selected = state.cells[session.selected]
  const upgradeCost = selected ? Math.trunc(R.upgrade) * selected.level : 0
  const canUpgrade = planning && !!selected && selected.kind !== '' && selected.kind !== 'shield' && selected.level < Math.trunc(R.max_level) && state.material >= upgradeCost
  const canRemove = planning && !!selected && selected.crew > 0
  const detail = selected?.kind
    ? facilityName(session.language, selected.kind) + '  ' + tr('level', [selected.level]) + (selected.kind === 'greenhouse' ? '  ' + tr('plant_progress', [Math.max(0, Math.trunc(R.plant_days) - selected.progress)]) : '')
    : ''
  const phase = state.phase
  const advanceLabel = phase === 'morning' ? 'start_day' : phase === 'day' ? 'see_results' : 'next_morning'
  const standing = new Set(['log_start', 'daily', 'day_working', 'day_started'])
  const spoken = phase === 'night' ? [] : session.notices().filter((notice) => !standing.has(notice.key))
  const message = spoken.length === 0 ? '' : `<p class="message">${esc(renderNotices(session.language, spoken))}</p>`
  const shieldAt = Math.trunc(R.unlock_shield_at)
  const plantAt = Math.trunc(R.unlock_plant_at)
  const shieldOn = state.science >= shieldAt
  const cropsOn = state.science >= plantAt
  const visible = selected?.kind
    ? 'Lv.' + selected.level + (selected.kind === 'greenhouse' ? '  ' + selected.progress + '/' + Math.trunc(R.plant_days) : '')
    : ''
  return `
    <div class="health-label" tabindex="0" ${tipAttr(tr('health'))}>${state.health}%</div>
    <div class="bar" tabindex="0" ${tipAttr(tr('health') + ' ' + state.health + '%')}><div style="width:${health}%"></div></div>
    <div class="goal" tabindex="0" ${tipAttr(tr('goal', [state.science, Math.min(day, 15)]))}><span>${esc(tr('goal_sci'))}</span><strong>${state.science}/30</strong><span>${esc(tr('goal_day'))}</span><strong>${Math.min(day, 15)}/15</strong></div>
    <div class="unlock shield ${shieldOn ? 'on' : ''}" tabindex="0" ${tipAttr(tr('unlock_shield_tip'))}><img src="${ICONS.shield}" alt=""><strong>${esc(unlockLabel(state.science, shieldAt, tr))}</strong></div>
    <div class="unlock crops ${cropsOn ? 'on' : ''}" tabindex="0" ${tipAttr(tr('unlock_crops_tip'))}><img src="${ICONS.greenhouse}" alt=""><strong>${esc(unlockLabel(state.science, plantAt, tr))}</strong></div>
    ${visible ? `<img class="detail-icon" src="${ICONS[selected?.kind ?? ''] ?? ''}" alt="" tabindex="0" ${tipAttr(detail)}><div class="detail">${esc(visible)}</div>` : ''}
    ${selected?.kind ? `<button type="button" class="icon-btn up-btn" data-act="upgrade" ${off(canUpgrade)} ${tipAttr(tr('upgrade', [upgradeCost]))}>${esc(tr('btn_upgrade'))}</button>` : ''}
    ${selected?.kind ? `<button type="button" class="icon-btn back-btn" data-act="remove" ${off(canRemove)} ${tipAttr(tr('remove'))}>${esc(tr('btn_back'))}</button>` : ''}
    <button type="button" class="icon-btn book-btn" data-act="sources" ${tipAttr(tr('sources'))}>${esc(tr('btn_notes'))}</button>
    <button type="button" class="icon-btn restart-btn" data-act="restart" ${tipAttr(tr('restart'))}>${esc(tr('btn_restart'))}</button>
    <button type="button" class="primary advance" data-act="advance" ${off(!state.over)} ${tipAttr(tr(advanceLabel) + '\n' + tr('crew_hint'))}>${esc(tr(advanceLabel === 'start_day' ? 'go_start' : advanceLabel === 'see_results' ? 'go_results' : 'go_morning'))}</button>
    ${message}
  `
}

function modalHtml(session: Session, tr: Tr): string {
  const state = session.state
  if (state.over) {
    return `<div class="modal"><h2>${esc(tr('loss_title'))}</h2><p class="pre">${esc(tr('loss_body'))}</p><div class="actions"><button type="button" class="primary" data-act="restart-yes">${esc(tr('restart_confirm'))}</button></div></div>`
  }
  if (session.ended === 'win') {
    return `<div class="modal"><h2>${esc(tr('win_title'))}</h2><p class="pre">${esc(tr('win_body'))}</p><div class="actions"><button type="button" class="primary" data-act="dismiss">${esc(tr('continue'))}</button></div></div>`
  }
  if (session.confirmRestart) {
    return `<div class="modal"><h2>${esc(tr('restart'))}</h2><p class="pre">${esc(tr('restart_body'))}</p><div class="actions"><button type="button" class="primary" data-act="restart-yes">${esc(tr('restart_confirm'))}</button><button type="button" data-act="restart-no">${esc(tr('cancel'))}</button></div></div>`
  }
  if (overlay === 'help') {
    return `<div class="modal"><h2>${esc(tr('help_title'))}</h2><p class="pre">${esc(tr('help_body'))}</p><div class="actions"><button type="button" class="primary" data-act="close-overlay">${esc(tr('close'))}</button></div></div>`
  }
  if (overlay === 'sources') {
    const history = session.history.length === 0
      ? `<p>${esc(tr('history_empty'))}</p>`
      : `<ul class="history">${[...session.history].reverse().map((note) => historyItem(session.language, note, tr)).join('')}</ul>`
    return `<div class="modal"><h2>${esc(tr('sources_title'))}</h2><p class="pre">${esc(tr('sources_body'))}</p><p><a href="https://science.nasa.gov/blogs/solar-cycle-25/2024/05/14/strong-solar-flare-erupts-from-sun-15/" target="_blank" rel="noopener noreferrer">${esc(tr('source_flare'))}</a></p><h3>${esc(tr('history'))}</h3>${history}<div class="actions"><button type="button" class="primary" data-act="close-overlay">${esc(tr('close'))}</button></div></div>`
  }
  return ''
}

function historyItem(lang: Lang, note: DayNote, tr: Tr): string {
  const report = {
    harvest: note.harvest,
    survival: 0,
    power: 0,
    material: 0,
    science: note.produced_science,
    health: note.healed - note.damage,
    damage: note.damage,
    produced_survival: 0,
    produced_power: 0,
    produced_material: note.produced_material,
    produced_science: note.produced_science,
    healed: note.healed,
    shortage: note.shortage,
    sheltered: note.sheltered,
    event: note.event,
    new_discoveries: note.discoveries,
    research_paused: 0,
    cover_power: note.cover_power,
    cover_committed: note.cover_committed,
    harvest_cells: [],
  }
  const parts: Notice[] = []
  if (note.shortage) parts.push({ key: 'shortage' })
  if (note.event === 'flare') parts.push({ key: note.sheltered ? 'protected' : 'damaged' })
  parts.push(...outcomeNotices(report))
  return `<li><strong>${esc(tr('day', [note.day]))}</strong> ${esc(tr(note.event))}<br>${esc(renderNotices(lang, parts))}</li>`
}

function titleHtml(tr: Tr): string {
  return `
    <img class="mark" src="${ICONS.habitat}" alt="">
    <h1>${esc(tr('title'))}</h1>
    <p class="sub">${esc(tr('subtitle'))}</p>
    <p class="mission-line">${esc(tr('mission'))}</p>
    <button type="button" class="primary start" data-act="start">${esc(tr('start_game'))}</button>
    <button type="button" class="lang" data-act="lang">${esc(tr('language'))}</button>
    <p class="foot">${esc(tr('footer'))}</p>
  `
}

function unlockLabel(science: number, at: number, tr: Tr): string {
  if (science >= at) return tr('unlock_ready')
  return tr('unlock_need', [at - science])
}

function signed(value: number): string {
  if (value >= 0) return '+' + value
  return '−' + Math.abs(value)
}

function crewColor(id: string): string {
  if (id === 'rikuto') return '#d97724'
  switch (specialty(id)) {
    case 'solar': return '#e0a030'
    case 'water': return '#3e7c78'
    case 'greenhouse': return '#5c8a3e'
    case 'lab': return '#5d6eae'
    case 'mine': return '#8a5a3a'
    default: return '#827565'
  }
}

function off(enabled: boolean): string {
  return enabled ? '' : 'aria-disabled="true"'
}

function tipAttr(text: string): string {
  return `data-tip="${esc(text)}" aria-label="${esc(text)}"`
}

function tipHost(target: EventTarget | null): HTMLElement | null {
  if (!(target instanceof Element)) return null
  return target.closest<HTMLElement>('[data-tip]')
}

function showTipOn(el: HTMLElement): void {
  const text = el.getAttribute('data-tip') ?? ''
  if (!text) return
  tipAnchor = el
  const rect = el.getBoundingClientRect()
  showTipText(text, rect.left + rect.width / 2, rect.top, rect.height + 12)
}

function showTipText(text: string, clientX: number, clientY: number, lift: number): void {
  const tip = document.getElementById('tip')
  const app = document.getElementById('app')
  if (!tip || !app) return
  tip.hidden = false
  tip.textContent = text
  const frame = app.getBoundingClientRect()
  const scale = frame.width / 1360 || 1
  const tw = tip.offsetWidth
  const th = tip.offsetHeight
  let x = (clientX - frame.left) / scale - tw / 2
  let y = (clientY - frame.top) / scale - th - 10
  if (y < 4) y = (clientY - frame.top) / scale + lift
  if (y + th > 796) y = Math.max(4, 796 - th)
  x = Math.max(4, Math.min(1356 - tw, x))
  tip.style.left = `${Math.round(x)}px`
  tip.style.top = `${Math.round(y)}px`
}

function hideTip(): void {
  tipAnchor = null
  const tip = document.getElementById('tip')
  if (tip) tip.hidden = true
}

function esc(value: string): string {
  return value.replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char] ?? char)
}

type Tr = (key: string, args?: Array<string | number>) => string
