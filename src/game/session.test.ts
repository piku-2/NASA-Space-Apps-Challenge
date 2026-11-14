import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { crewCell, idle, initial } from '../domain/simulation.ts'
import { Session } from './session.ts'

describe('session', () => {
  it('starts safely when storage reads are denied by the browser', () => {
    const holder = globalThis as { localStorage?: Storage }
    const previous = holder.localStorage
    holder.localStorage = { getItem: () => { throw new Error('storage denied') } } as unknown as Storage
    try {
      const session = new Session()
      assert.equal(session.state.day, 1)
      assert.equal(session.saved, false)
    } finally {
      if (previous) holder.localStorage = previous
      else delete holder.localStorage
    }
  })
  it('returns the selected person to standby only in the morning', () => {
    const session = new Session()
    session.selectCrew('ren')
    session.returnSelected()
    assert.equal(crewCell(session.state, 'ren'), -1)
    session.selectCrew('aoi')
    session.advance()
    session.selectedCrew = 'aoi'
    session.returnSelected()
    assert.equal(crewCell(session.state, 'aoi'), 10)
  })
  it('places crew, steps morning day night, and records one day', () => {
    const session = new Session()
    assert.equal(session.state.roster.length, 6)
    assert.equal(idle(session.state), 4)
    session.start()
    session.selectCrew('mio')
    session.selectCell(4)
    assert.equal(crewCell(session.state, 'mio'), 4)
    session.advance()
    assert.equal(session.state.phase, 'night')
    assert.equal(session.history.length, 1)
    assert.equal(session.history[0].day, 1)
    session.advance()
    assert.equal(session.state.phase, 'morning')
    assert.equal(session.history.length, 1)
    assert.equal(session.state.day, 2)
  })

  it('refuses building after the morning ends', () => {
    const session = new Session()
    session.start()
    session.advance()
    const material = session.state.material
    session.chooseBuild('mine')
    session.selectCell(2)
    assert.equal(session.state.cells[2].kind, '')
    assert.equal(session.state.material, material)
  })

  it('restores a win or a loss and still lets the victory card close', () => {
    const memory = new Map<string, string>()
    const store = {
      getItem: (key: string) => memory.get(key) ?? null,
      setItem: (key: string, value: string) => { memory.set(key, value) },
      removeItem: (key: string) => { memory.delete(key) },
      clear: () => { memory.clear() },
      key: () => null,
      get length() { return memory.size },
    }
    const holder = globalThis as { localStorage?: Storage }
    const previous = holder.localStorage
    holder.localStorage = store as Storage
    try {
      const won = initial()
      won.won = true
      store.setItem('mars_notebook_v1', JSON.stringify({ version: 3, language: 'en', state: won, streak: 2 }))
      const loaded = new Session()
      assert.equal(loaded.ended, 'win')
      assert.equal(loaded.state.won, true)
      loaded.ended = ''
      assert.equal(loaded.ended, '')

      const lost = initial()
      lost.over = true
      store.setItem('mars_notebook_v1', JSON.stringify({ version: 3, state: lost }))
      assert.equal(new Session().ended, 'loss')

      store.setItem('mars_notebook_v1', JSON.stringify({ version: 3, state: initial() }))
      assert.equal(new Session().ended, '')
    } finally {
      if (previous) holder.localStorage = previous
      else delete holder.localStorage
    }
  })
})
