// Deterministic bots, not human playtests. No browser, network, or save access.
import { initial, place, move, buildAt, upgradeAt, beginDay, resolveDay, wake, eventOf, type GameState } from '../src/domain/simulation.ts'

const strategies = ['stationary', 'power', 'research', 'safety', 'frugal', 'random'] as const
export function evaluate(strategy: typeof strategies[number], seed = 1) {
  let s = initial()
  let decisions = 0
  let shortages = 0
  let survived = 0
  let random = seed >>> 0
  const pick = (n: number) => { random = (Math.imul(random, 1664525) + 1013904223) >>> 0; return Math.floor(random / 4294967296 * n) }
  const assign = (id: string, dest: number) => {
    const before = s.roster.find(p => p.id === id)?.cell
    s = move(s, id, dest)
    if (s.roster.find(p => p.id === id)?.cell !== before) decisions++
  }
  if (strategy === 'stationary') assign('sora', 7)
  if (strategy !== 'stationary' && strategy !== 'random') {
    assign('aoi', 0); assign('sora', 7); assign('mio', 4)
    if (strategy === 'power') assign('rikuto', 0)
    if (strategy === 'research') assign('rikuto', 7)
    if (strategy === 'safety') { s = buildAt(s, 2, 'shield'); decisions++ }
    if (strategy === 'frugal') { s = upgradeAt(s, 0); decisions++ }
  }
  while (s.day <= 15 && !s.over) {
    if (strategy === 'safety') s.shelter = eventOf(s) === 'flare'
    if (strategy === 'random') {
      for (const p of s.roster) assign(p.id, [-1, 0, 1, 4, 7, 10][pick(6)])
      if (eventOf(s) === 'flare') s.shelter = pick(2) === 1
    }
    s = resolveDay(beginDay(s))
    if (s.report?.shortage) shortages++
    if (!s.over) survived++
    s = wake(s)
  }
  return { strategy, seed, won: s.won, survived, science: s.science, shortages, decisions, power: s.power, survival: s.survival, health: s.health }
}
export function allStrategies() {
  return strategies.flatMap(strategy => strategy === 'random'
    ? Array.from({ length: 20 }, (_, i) => evaluate(strategy, i + 1)) : [evaluate(strategy)])
}
if (process.argv[1]?.endsWith('evaluate-strategies.ts')) console.log(JSON.stringify(allStrategies(), null, 2))
