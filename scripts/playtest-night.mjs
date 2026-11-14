// Night results panel only. PLAYWRIGHT_MODULE or --playwright path, same as playtest.mjs.
import assert from 'node:assert/strict'
import { mkdir } from 'node:fs/promises'
const moduleArg = process.argv.indexOf('--playwright')
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || (moduleArg >= 0 ? process.argv[moduleArg + 1] : 'playwright'))
const browser = await chromium.launch({ headless: true })
const base = process.env.PLAYTEST_URL || 'http://127.0.0.1:5173'
await mkdir('screenshots', { recursive: true })
const errors = []

function signed(value) {
  return value >= 0 ? `+${value}` : `−${Math.abs(value)}`
}

async function openNight(page) {
  await page.goto(base)
  await page.evaluate(() => localStorage.removeItem('mars_notebook_v1'))
  await page.reload()
  await page.locator('[data-act=start]').click()
  await page.locator('[data-act=advance]').click()
  await page.waitForFunction(() => {
    const raw = localStorage.getItem('mars_notebook_v1')
    return raw && JSON.parse(raw).state.phase === 'night'
  })
}

async function assertNight(page, { width, lang, healthZero }) {
  const report = await page.evaluate(() => JSON.parse(localStorage.getItem('mars_notebook_v1')).state)
  assert.equal(report.phase, 'night')
  const night = report.report
  for (const key of ['survival', 'power', 'material', 'science']) {
    const text = (await page.locator(`#event .night-res[data-res=${key}] strong`).innerText()).trim()
    assert.equal(text, signed(night[key]), key)
  }
  const health = (await page.locator('#event .night-health').innerText()).replace(/\s+/g, ' ')
  assert.match(health, new RegExp(`${report.health}%`))
  if (healthZero || night.health === 0) {
    assert.equal(night.health, 0)
    assert.doesNotMatch(health, /[+\u2212-]0/)
  } else {
    assert.notEqual(night.health, 0)
    assert.match(health, new RegExp(signed(night.health).replace('+', '\\+')))
    assert.doesNotMatch(health, /[+\u2212-]0/)
  }
  assert.equal(await page.locator('.sheet-forecast .delta').count(), 0)
  assert.equal(await page.locator('.build-btn').count(), 0)
  assert.equal(await page.locator('#build').count(), 0)
  const fit = await page.locator('#event').evaluate((el) => {
    const box = el.getBoundingClientRect()
    const kids = [...el.querySelectorAll('h2, .night-health, .night-grid, p')].map((node) => {
      const r = node.getBoundingClientRect()
      return { top: r.top, bottom: r.bottom, h: r.height }
    })
    return {
      h: Math.round(box.height),
      scroll: el.scrollHeight,
      client: el.clientHeight,
      overflowY: getComputedStyle(el).overflowY,
      kids,
      panelTop: box.top,
      panelBottom: box.bottom,
      ruby: el.querySelectorAll('rt').length,
    }
  })
  assert.ok(fit.scroll <= fit.client + 1, JSON.stringify(fit))
  for (const kid of fit.kids) {
    assert.ok(kid.h > 0, 'empty night row')
    assert.ok(kid.top >= fit.panelTop - 1 && kid.bottom <= fit.panelBottom + 1, JSON.stringify({ kid, fit }))
  }
  const rows = fit.kids.slice().sort((a, b) => a.top - b.top)
  for (let i = 1; i < rows.length; i++) assert.ok(rows[i].top >= rows[i - 1].bottom - 1, 'night rows overlap')
  if (width >= 900) {
    assert.equal(fit.h, 430)
    assert.equal(fit.overflowY, 'hidden')
  } else {
    assert.equal(fit.overflowY, 'visible')
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1))
  }
  if (lang === 'ja') assert.ok(fit.ruby > 0)
  const heading = await page.locator('#event h2').evaluate((el) => {
    const clone = el.cloneNode(true)
    clone.querySelectorAll('rt').forEach((node) => node.remove())
    return (clone.textContent || '').replace(/\s+/g, '')
  })
  assert.equal(heading, lang === 'ja' ? '活動結果' : 'Activityresults')
  assert.equal(await page.locator('#event .night-res[tabindex="0"]').count(), 4)
  assert.equal(await page.locator('#event .next-result').count(), 1)
  return { fit, night }
}

async function assertPhaseCopy(page, width, lang) {
  await page.locator('[data-act=help]').click()
  await page.locator('.modal .pre').waitFor()
  const copy = await page.evaluate(() => {
    const parts = []
    const event = document.querySelector('#event')
    if (event) parts.push(event.innerText)
    const modal = document.querySelector('.modal')
    if (modal) parts.push(modal.innerText)
    const tip = document.querySelector('#tip')
    if (tip) parts.push(tip.innerText)
    for (const el of document.querySelectorAll('[data-tip]')) parts.push(el.getAttribute('data-tip') || '')
    return parts.join('\n')
  })
  assert.doesNotMatch(copy, /[朝昼夜]/)
  assert.doesNotMatch(copy, /morning|daytime|\bnight\b/i)
  await page.screenshot({ path: `screenshots/moon-help-${width}-${lang}.png`, fullPage: true })
  await page.locator('[data-act=close-overlay]').click()
  await page.locator('.modal').waitFor({ state: 'detached' })
}

async function shot(page, path) {
  const day = page.locator('.sheet-header .day')
  const box = await day.boundingBox()
  await page.mouse.move((box?.x ?? 20) + 8, (box?.y ?? 20) + 8)
  await page.screenshot({ path, fullPage: true })
}

async function visibleNote(page, selector, parts) {
  const note = page.locator(`#event ${selector}`)
  assert.equal(await note.count(), 1)
  const box = await note.boundingBox()
  assert.ok(box && box.height > 8 && box.width > 8, selector)
  const text = (await note.innerText()).replace(/\s+/g, '')
  for (const part of parts) assert.ok(text.includes(String(part)), `${selector} missing ${part} in ${text}`)
}

try {
  for (const width of [1360, 390]) {
    const context = await browser.newContext({ viewport: { width, height: width === 390 ? 844 : 800 }, locale: 'ja-JP' })
    await context.route('**/*', route => {
      const url = route.request().url()
      return url.startsWith(base + '/') || url.startsWith('data:') || url.startsWith('blob:') ? route.continue() : route.abort()
    })
    const page = await context.newPage()
    page.on('pageerror', error => errors.push(error.message))
    await openNight(page)
    const natural = await assertNight(page, { width, lang: 'ja', healthZero: true })
    assert.equal(await page.locator('#event .cover').count(), 0)
    await shot(page, `screenshots/moon-night-${width}-ja.png`)
    await assertPhaseCopy(page, width, 'ja')
    await page.locator('[data-act=lang]').click()
    assert.equal(await page.locator('html').getAttribute('lang'), 'en')
    await assertNight(page, { width, lang: 'en', healthZero: true })
    await shot(page, `screenshots/moon-night-${width}-en.png`)
    await assertPhaseCopy(page, width, 'en')
    await page.evaluate(() => {
      const save = JSON.parse(localStorage.getItem('mars_notebook_v1'))
      save.language = 'ja'
      save.state.health = 64
      save.state.report = {
        ...save.state.report,
        harvest: 12,
        survival: 3,
        power: -4,
        material: 2,
        science: 5,
        health: -8,
        damage: 8,
        shortage: true,
        sheltered: false,
        event: 'flare',
        cover_committed: true,
        cover_power: 6,
        new_discoveries: ['shielding', 'crops'],
      }
      localStorage.setItem('mars_notebook_v1', JSON.stringify(save))
    })
    await page.reload()
    await page.locator('[data-act=start]').click()
    const restored = await page.evaluate(() => JSON.parse(localStorage.getItem('mars_notebook_v1')).state.report)
    assert.equal(restored.event, 'flare')
    assert.equal(restored.cover_committed, true)
    assert.equal(restored.health, -8)
    const stress = await assertNight(page, { width, lang: 'ja', healthZero: false })
    await visibleNote(page, '.harvest', ['12'])
    await visibleNote(page, '.shortage', [])
    await visibleNote(page, '.cover', ['6', '8'])
    assert.equal(await page.locator('#event .discovery').count(), 2)
    for (const note of await page.locator('#event .discovery').all()) {
      const box = await note.boundingBox()
      assert.ok(box && box.height > 8)
    }
    await visibleNote(page, '.next-result', [])
    await shot(page, `screenshots/moon-night-long-${width}-ja.png`)
    await assertPhaseCopy(page, width, 'ja-long')
    await page.locator('[data-act=lang]').click()
    await assertNight(page, { width, lang: 'en', healthZero: false })
    await visibleNote(page, '.cover', ['6', '8'])
    await shot(page, `screenshots/moon-night-long-${width}-en.png`)
    await assertPhaseCopy(page, width, 'en-long')
    console.log(JSON.stringify({ width, natural: natural.fit.h, stress: stress.fit.h, notes: natural.night }))
    await context.close()
  }
  assert.deepEqual(errors, [])
  console.log('playtest-night ok')
} finally {
  await browser.close()
}
