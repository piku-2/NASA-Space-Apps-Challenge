// Local-only browser checks. Supply PLAYWRIGHT_MODULE if Playwright is not installed globally.
import assert from 'node:assert/strict'
import { mkdir } from 'node:fs/promises'
const moduleArg = process.argv.indexOf('--playwright')
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || (moduleArg >= 0 ? process.argv[moduleArg + 1] : 'playwright'))
const browser = await chromium.launch({ headless: true })
const base = process.env.PLAYTEST_URL || 'http://127.0.0.1:5173'
const label = process.env.PLAYTEST_LABEL || 'current'
await mkdir('screenshots', { recursive: true })
const errors = []
async function waitPhase(page, phase) {
  await page.waitForFunction((expected) => {
    try {
      return JSON.parse(localStorage.getItem('mars_notebook_v1')).state.phase === expected
    } catch {
      return false
    }
  }, phase, { timeout: 3000 })
}
async function readState(page) {
  return page.evaluate(() => JSON.parse(localStorage.getItem('mars_notebook_v1')).state)
}
try {
  for (const width of [1360, 390]) {
    let advances = 0
    const context = await browser.newContext({ viewport: { width, height: width === 390 ? 844 : 800 } })
    await context.route('**/*', route => {
      const url = route.request().url()
      return url.startsWith(base + '/') || url.startsWith('data:') || url.startsWith('blob:') ? route.continue() : route.abort()
    })
    const page = await context.newPage()
    page.on('pageerror', error => errors.push(error.message))
    await page.goto(base)
    await page.locator('[data-act=start]').click()
    await page.screenshot({ path: `screenshots/${label}-${width}-morning.png`, fullPage: true })
    if (width === 390) assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth))
    await page.locator('[data-act=crew][data-id=mio]:visible').click()
    await page.locator('[data-act=cell][data-cell="4"]').click()
    assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem('mars_notebook_v1')).state.roster.find(p => p.id === 'mio').cell), 4)
    await page.locator('[data-act=crew][data-id=mio]:visible').click()
    await page.locator('[data-act=wait]').click()
    assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem('mars_notebook_v1')).state.roster.find(p => p.id === 'mio').cell), -1)
    await page.locator('[data-act=crew][data-id=sora]:visible').click()
    await page.locator('[data-act=cell][data-cell="7"]').click()
    for (const [id, cell] of [['aoi', 0], ['rikuto', 0], ['mio', 4]]) {
      await page.locator(`[data-act=crew][data-id=${id}]:visible`).click()
      await page.locator(`[data-act=cell][data-cell="${cell}"]`).click()
    }
    await page.locator('[data-act=build][data-kind=mine]').click()
    await page.locator('[data-act=cell][data-cell="2"]').click()
    await page.locator('[data-act=crew][data-id=haru]:visible').click()
    await page.locator('[data-act=cell][data-cell="2"]').click()
    await page.locator('[data-act=build][data-kind=shield]').click()
    await page.locator('[data-act=cell][data-cell="3"]').click()
    await page.locator('[data-act=advance]').click()
    advances += 1
    await waitPhase(page, 'night')
    await page.screenshot({ path: `screenshots/${label}-${width}-night.png`, fullPage: true })
    const metrics = await page.locator('[data-act=crew]:visible').first().boundingBox()
    assert.ok(metrics.width >= 44 && metrics.height >= 44)
    console.log(JSON.stringify({ width, crewTarget: metrics, phase: await page.evaluate(() => JSON.parse(localStorage.getItem('mars_notebook_v1')).state.phase) }))
    await page.reload()
    await page.locator('[data-act=start]').click()
    await page.locator('[data-act=lang]').click()
    assert.equal(await page.locator('html').getAttribute('lang'), 'en')
    await page.locator('[data-act=help]').click()
    await page.locator('[data-act=close-overlay]').click()
    await page.screenshot({ path: `screenshots/${label}-${width}-en.png`, fullPage: true })
    for (let day = 2; day <= 15; day++) {
      await page.locator('[data-act=advance]').click()
      advances += 1
      await waitPhase(page, 'morning')
      if (day === 5) await page.screenshot({ path: `screenshots/${label}-${width}-flare.png`, fullPage: true })
      await page.locator('[data-act=advance]').click()
      advances += 1
      await waitPhase(page, 'night')
    }
    const won = await readState(page)
    assert.equal(won.won, true)
    assert.ok(won.survival > 0 && won.health > 0)
    await page.screenshot({ path: `screenshots/${label}-${width}-win.png`, fullPage: true })
    await page.locator('[data-act=dismiss]').click()
    await page.locator('[data-act=advance]').click()
    advances += 1
    await waitPhase(page, 'morning')
    assert.equal(advances, 30)
    await page.locator('[data-act=restart]').click()
    await page.locator('[data-act=restart-yes]').click()
    await page.locator('[data-act=crew][data-id=ren]:visible').click()
    await page.locator('[data-act=cell][data-cell="0"]').click()
    for (let day = 1; day <= 6; day++) {
      await page.locator('[data-act=advance]').click()
      await waitPhase(page, 'night')
      if (day < 6) {
        await page.locator('[data-act=advance]').click()
        await waitPhase(page, 'morning')
      }
    }
    const lost = await readState(page)
    assert.equal(lost.over, true)
    assert.ok(lost.survival < 0)
    await page.screenshot({ path: `screenshots/${label}-${width}-loss.png`, fullPage: true })
    assert.ok(await page.locator('.modal').innerText().then(text => text.includes('Water and food')))
    console.log(JSON.stringify({ width, won: won.won, research: won.science, harvested: won.survival, lossCause: 'survival', survivedLossDays: lost.day - 2 }))
    await context.close()
  }
  const extra = await browser.newContext({ viewport: { width: 1360, height: 800 } })
  await extra.route('**/*', route => {
    const url = route.request().url()
    return url.startsWith(base + '/') || url.startsWith('data:') || url.startsWith('blob:') ? route.continue() : route.abort()
  })
  const page = await extra.newPage()
  page.on('pageerror', error => errors.push(error.message))
  await page.goto(base)
  await page.locator('[data-act=start]').click()
  await page.locator('[data-act=help]').click()
  const focusedInModal = await page.evaluate(() => document.querySelector('.modal')?.contains(document.activeElement))
  assert.equal(focusedInModal, true)
  const first = page.locator('.modal button').first()
  const last = page.locator('.modal button').last()
  await last.focus()
  await page.keyboard.press('Tab')
  assert.equal(await page.evaluate(() => document.activeElement === document.querySelector('.modal button')), true)
  await first.focus()
  await page.keyboard.press('Shift+Tab')
  const onLast = await page.evaluate(() => {
    const buttons = [...document.querySelectorAll('.modal button')]
    return document.activeElement === buttons[buttons.length - 1]
  })
  assert.equal(onLast, true)
  await page.keyboard.press('Escape')
  assert.equal(await page.locator('#shade').getAttribute('hidden'), '')
  assert.equal(await page.evaluate(() => document.activeElement?.getAttribute('data-act')), 'help')
  await page.locator('[data-act=cell][data-cell="10"]').click()
  await page.locator('[data-act=upgrade]').click()
  assert.equal(await page.locator('[data-act=cell][data-cell="10"]').getAttribute('data-level'), '2')
  const greenhouse = page.locator('[data-act=cell][data-cell="4"]')
  assert.match(await greenhouse.locator('.cell-mobile-meta').innerText(), /Lv\.1 · 0\/2 · 0\/5/)
  assert.equal(await greenhouse.locator('.cell-pips i.on').count(), 1)
  await page.evaluate(() => {
    const save = JSON.parse(localStorage.getItem('mars_notebook_v1'))
    save.state.cells[4].progress = 4
    const mio = save.state.roster.find(person => person.id === 'mio')
    mio.cell = 4
    save.state.cells[4].crew = save.state.roster.filter(person => person.cell === 4).length
    localStorage.setItem('mars_notebook_v1', JSON.stringify(save))
  })
  await page.reload()
  await page.locator('[data-act=start]').click()
  await page.locator('[data-act=advance]').click()
  await waitPhase(page, 'night')
  assert.equal(await page.locator('[data-act=cell][data-cell="4"]').getAttribute('class').then(value => value.includes('harvest')), true)
  assert.match(await page.locator('.night-summary').innerText(), /✓/)
  await page.screenshot({ path: `screenshots/${label}-1360-harvest.png`, fullPage: true })
  await page.evaluate(() => {
    const save = JSON.parse(localStorage.getItem('mars_notebook_v1'))
    save.state.phase = 'morning'
    save.state.science = 8
    save.state.roster.find(person => person.id === 'sora').cell = 7
    save.state.cells[7].crew = 1
    localStorage.setItem('mars_notebook_v1', JSON.stringify(save))
  })
  await page.reload()
  await page.locator('[data-act=start]').click()
  await page.locator('[data-act=advance]').click()
  await waitPhase(page, 'night')
  assert.ok(await page.locator('.discovery').count() > 0)
  await page.evaluate(() => localStorage.setItem('mars_notebook_v1', '{'))
  await page.reload()
  await page.locator('[data-act=start]').click()
  assert.match(await page.locator('.day').innerText(), /1/)
  assert.equal(await page.evaluate(() => localStorage.getItem('mars_notebook_v1')), '{')
  assert.ok(await page.locator('.save-failed').count() > 0)
  await page.evaluate(() => { Storage.prototype.setItem = function () { throw new Error('full') } })
  await page.locator('[data-act=lang]').click()
  assert.ok(await page.locator('.save-failed').count() > 0)
  await extra.close()
  const denied = await browser.newContext({ viewport: { width: 390, height: 844 } })
  await denied.route('**/*', route => {
    const url = route.request().url()
    return url.startsWith(base + '/') || url.startsWith('data:') || url.startsWith('blob:') ? route.continue() : route.abort()
  })
  await denied.addInitScript(() => {
    const read = Storage.prototype.getItem
    Storage.prototype.getItem = function (key) {
      if (key === 'mars_notebook_v1') throw new Error('denied')
      return read.call(this, key)
    }
  })
  const phone = await denied.newPage()
  phone.on('pageerror', error => errors.push(error.message))
  await phone.goto(base)
  await phone.locator('[data-act=start]').click()
  assert.equal(await phone.locator('[data-act=cell][data-cell="4"] .cell-pips').evaluate(el => getComputedStyle(el).display), 'flex')
  assert.notEqual(await phone.locator('[data-act=cell][data-cell="4"] .cell-mobile-meta').evaluate(el => getComputedStyle(el).display), 'none')
  const titleBox = await phone.locator('.title-name').boundingBox()
  const failedBox = await phone.locator('.save-failed').boundingBox()
  assert.ok(titleBox.width >= 100 && titleBox.width > titleBox.height * 2)
  assert.ok(failedBox.width >= 300)
  await phone.screenshot({ path: `screenshots/${label}-390-growth.png`, fullPage: true })
  await phone.screenshot({ path: `screenshots/${label}-390-save-title.png`, fullPage: true })
  await denied.close()
  const pace = await browser.newContext({ viewport: { width: 1360, height: 800 } })
  await pace.route('**/*', route => {
    const url = route.request().url()
    return url.startsWith(base + '/') || url.startsWith('data:') || url.startsWith('blob:') ? route.continue() : route.abort()
  })
  const paced = await pace.newPage()
  paced.on('pageerror', error => errors.push(error.message))
  await paced.goto(base)
  await paced.locator('[data-act=start]').click()
  await paced.locator('[data-act=advance]').click()
  await paced.locator('[data-act=advance]').click()
  await waitPhase(paced, 'night')
  const skipped = await readState(paced)
  await paced.waitForTimeout(800)
  const skippedLater = await readState(paced)
  assert.equal(skippedLater.phase, 'night')
  assert.equal(skippedLater.day, skipped.day)
  assert.equal(skippedLater.science, skipped.science)
  await paced.evaluate(() => {
    const save = JSON.parse(localStorage.getItem('mars_notebook_v1'))
    save.state.phase = 'day'
    localStorage.setItem('mars_notebook_v1', JSON.stringify(save))
  })
  await paced.reload()
  await paced.waitForTimeout(700)
  assert.equal((await readState(paced)).phase, 'day')
  await paced.locator('[data-act=start]').click()
  await waitPhase(paced, 'night')
  const resumed = await readState(paced)
  await paced.waitForTimeout(800)
  const resumedLater = await readState(paced)
  assert.equal(resumed.phase, 'night')
  assert.equal(resumedLater.phase, 'night')
  assert.equal(resumedLater.day, resumed.day)
  assert.equal(resumedLater.science, resumed.science)
  const nightStamp = { day: resumedLater.day, science: resumedLater.science }
  await paced.reload()
  await paced.locator('[data-act=start]').click()
  await paced.waitForTimeout(800)
  const reloadedNight = await readState(paced)
  assert.equal(reloadedNight.phase, 'night')
  assert.equal(reloadedNight.day, nightStamp.day)
  assert.equal(reloadedNight.science, nightStamp.science)
  await paced.evaluate(() => {
    const save = JSON.parse(localStorage.getItem('mars_notebook_v1'))
    delete save.state.rules_version
    save.state.phase = 'morning'
    localStorage.setItem('mars_notebook_v1', JSON.stringify(save))
  })
  await paced.reload()
  await paced.locator('[data-act=start]').click()
  assert.equal(await paced.locator('.forecast-label').innerText().then(text => text.includes('基地の電力')), false)
  await pace.close()
  const reduced = await browser.newContext({ viewport: { width: 1360, height: 800 }, reducedMotion: 'reduce' })
  await reduced.route('**/*', route => {
    const url = route.request().url()
    return url.startsWith(base + '/') || url.startsWith('data:') || url.startsWith('blob:') ? route.continue() : route.abort()
  })
  const quiet = await reduced.newPage()
  quiet.on('pageerror', error => errors.push(error.message))
  await quiet.goto(base)
  await quiet.locator('[data-act=start]').click()
  const started = Date.now()
  await quiet.locator('[data-act=advance]').click()
  await waitPhase(quiet, 'night')
  assert.ok(Date.now() - started < 1500)
  await reduced.close()
  assert.deepEqual(errors, [])
  console.log('PASS: placement, standby, construction, 30-advance 15-day win, 6-day loss, save/load, language, help, 44px targets, modal focus, upgrade, harvest, discovery, save failure, corrupt save, growth UI, day skip, resume, reduced motion; no page errors')
} finally { await browser.close() }
