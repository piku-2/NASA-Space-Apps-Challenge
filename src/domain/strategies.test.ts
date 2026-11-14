import assert from 'node:assert/strict'
import { it } from 'node:test'
import { evaluate } from '../../scripts/evaluate-strategies.ts'

it('supports four distinct deliberate policies but no longer wins with one lab placement', () => {
  const stationary = evaluate('stationary')
  assert.equal(stationary.won, false)
  assert.ok(stationary.power < 0)
  for (const strategy of ['power', 'research', 'safety', 'frugal'] as const) {
    const result = evaluate(strategy)
    assert.equal(result.won, true, strategy)
    assert.equal(result.survived, 15, strategy)
  }
  assert.ok(evaluate('research').science > evaluate('power').science)
  assert.ok(evaluate('research').power < evaluate('power').power)
  assert.ok(evaluate('safety').health > evaluate('research').health)
  assert.ok(evaluate('safety').science < evaluate('research').science)
})

it('replays deterministic random legal policies and reports their failures as well as wins', () => {
  let wins = 0
  for (let seed = 1; seed <= 20; seed++) {
    const result = evaluate('random', seed)
    assert.deepEqual(result, evaluate('random', seed))
    assert.ok(Number.isFinite(result.power))
    if (result.won) wins++
  }
  assert.ok(wins > 0 && wins < 20)
})
