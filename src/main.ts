import './style.css'
import { LOGO, playSfx } from './game/assets.ts'
import { mountBoard } from './game/board.ts'
import { Session } from './game/session.ts'
import { bind, boardView, fitNotebook, render, renderShell } from './game/ui.ts'

const session = new Session()
const root = document.getElementById('app')
if (!root) throw new Error('missing #app')
renderShell(root)
fitNotebook()
window.addEventListener('resize', fitNotebook)

const icon = document.createElement('link')
icon.rel = 'icon'
icon.href = LOGO
document.head.appendChild(icon)

const boardHost = document.getElementById('board')
if (!boardHost) throw new Error('missing #board')
const board = mountBoard(boardHost, (index) => {
  session.selectCell(index)
  paint()
})

bind(session, paint)

async function boot(): Promise<void> {
  try {
    await document.fonts.load('16px "Source Han Sans JP"')
    await document.fonts.ready
  } catch {
    // The bundled font is still declared in CSS; drawing continues either way.
  }
  paint()
}

function paint(): void {
  render(session)
  board.refresh(boardView(session))
  if (session.pendingSfx === 'place' || session.pendingSfx === 'expert' || session.pendingSfx === 'alarm') {
    playSfx(session.pendingSfx)
  }
  session.pendingSfx = ''
}

void boot()
