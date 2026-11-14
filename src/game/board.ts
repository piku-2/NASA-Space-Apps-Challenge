import Phaser from 'phaser'
import { ICONS } from './assets.ts'

export interface BoardChip {
  name: string
  color: string
  selected: boolean
}

export interface BoardCell {
  kind: string
  level: number
  progress: number
  crew: BoardChip[]
  hint: '' | 'move' | 'build'
  tip: string
}

export interface BoardView {
  cells: BoardCell[]
  selected: number
  phase: string
  flare: boolean
  plantDays: number
  maxLevel: number
  harvestCells: number[]
}

interface Metrics {
  pad: number
  gap: number
  cellW: number
  cellH: number
}

let onCell: (index: number) => void = () => undefined
let latest: BoardView | null = null
let active: BoardScene | null = null
let boardParent: HTMLElement | null = null

export function mountBoard(parent: HTMLElement, select: (index: number) => void): { refresh(view: BoardView): void } {
  onCell = select
  boardParent = parent
  const game = new Phaser.Game({
    type: Phaser.AUTO,
    parent,
    backgroundColor: '#7d8188',
    banner: false,
    scale: {
      mode: Phaser.Scale.NONE,
      width: 864,
      height: 438,
    },
    scene: BoardScene,
  })
  return {
    refresh(view: BoardView) {
      latest = view
      active?.draw(view)
      void game
    },
  }
}

class BoardScene extends Phaser.Scene {
  private holdTimer = 0
  private holdIndex = -1
  private held = false
  private hoverIndex = -1

  constructor() {
    super('board')
  }

  preload(): void {
    for (const [kind, url] of Object.entries(ICONS)) this.load.image('icon-' + kind, url)
  }

  create(): void {
    active = this
    this.scale.on('resize', () => {
      if (latest) this.draw(latest)
    })
    this.input.on('pointerdown', (pointer: Phaser.Input.Pointer) => {
      this.held = false
      this.holdIndex = cellAt(pointer.x, pointer.y, this.scale.width, this.scale.height)
      window.clearTimeout(this.holdTimer)
      if (pointer.wasTouch && this.holdIndex >= 0) {
        const index = this.holdIndex
        this.holdTimer = window.setTimeout(() => {
          this.held = true
          this.emitTip(index, pointer)
        }, 480)
      }
    })
    this.input.on('pointerup', (pointer: Phaser.Input.Pointer) => {
      window.clearTimeout(this.holdTimer)
      const index = cellAt(pointer.x, pointer.y, this.scale.width, this.scale.height)
      if (!this.held && index >= 0 && index === this.holdIndex) onCell(index)
      this.held = false
    })
    this.input.on('pointermove', (pointer: Phaser.Input.Pointer) => {
      const index = cellAt(pointer.x, pointer.y, this.scale.width, this.scale.height)
      if (pointer.wasTouch) {
        if (index !== this.holdIndex) window.clearTimeout(this.holdTimer)
        return
      }
      if (index === this.hoverIndex) return
      this.hoverIndex = index
      this.emitTip(index, pointer)
    })
    this.input.on('gameout', () => {
      this.hoverIndex = -1
      this.emitTip(-1, null)
    })
    if (latest) this.draw(latest)
  }

  private emitTip(index: number, pointer: Phaser.Input.Pointer | null): void {
    const text = index >= 0 ? latest?.cells[index]?.tip ?? '' : ''
    const canvas = this.game.canvas
    const rect = canvas.getBoundingClientRect()
    const scaleX = rect.width / this.scale.width
    const scaleY = rect.height / this.scale.height
    const localX = pointer?.x ?? 0
    const localY = pointer?.y ?? 0
    boardParent?.dispatchEvent(new CustomEvent('cell-tip', {
      bubbles: true,
      detail: {
        text,
        clientX: rect.left + localX * scaleX,
        clientY: rect.top + localY * scaleY,
      },
    }))
  }

  draw(view: BoardView): void {
    this.children.removeAll(true)
    const width = this.scale.width
    const height = this.scale.height
    const metrics = gridMetrics(width, height)
    const paper = this.add.graphics()
    const marks = this.add.graphics()
    marks.setDepth(5)
    view.cells.forEach((cell, index) => {
      const rect = cellRect(metrics, index)
      const selected = index === view.selected
      paper.fillStyle(selected ? 0xb8c0c8 : 0x9aa0a8, 1)
      paper.fillRoundedRect(rect.x, rect.y, rect.w, rect.h, 8)
      const stroke = selected ? 0x0f1115 : cell.hint ? 0x0f1115 : 0x4a4e54
      paper.lineStyle(selected || cell.hint ? 3 : 2, stroke, 1)
      paper.strokeRoundedRect(rect.x, rect.y, rect.w, rect.h, 8)
      if (!cell.kind) {
        dashed(marks, rect.x + 13, rect.y + 13, rect.w - 26, rect.h - 26, 0x4a4e54)
      } else {
        if (this.textures.exists('icon-' + cell.kind)) {
          const image = this.add.image(rect.x + 72, rect.y + 62, 'icon-' + cell.kind)
          image.setDisplaySize(108, 108)
          image.setTint(0x0f1115)
          image.setDepth(2)
        }
        const steps = Math.max(1, view.maxLevel)
        const badge = this.add.graphics()
        badge.setDepth(3)
        badge.fillStyle(0x0f1115, 1)
        badge.fillRoundedRect(rect.x + 6, rect.y + 6, 18 + steps * 12, 20, 4)
        badge.lineStyle(1.5, 0xf0f0f2, 1)
        badge.strokeRoundedRect(rect.x + 6, rect.y + 6, 18 + steps * 12, 20, 4)
        for (let step = 0; step < steps; step++) {
          const cx = rect.x + 18 + step * 12
          const cy = rect.y + 16
          if (step < cell.level) {
            badge.fillStyle(0xf0f0f2, 1)
            badge.fillCircle(cx, cy, 4)
          }
          badge.lineStyle(1.5, 0xf0f0f2, 1)
          badge.strokeCircle(cx, cy, 4)
        }
        const level = this.add.text(rect.x + 8, rect.y + 28, 'Lv.' + cell.level, {
          fontFamily: FONT,
          fontSize: '12px',
          color: '#0f1115',
        })
        level.setDepth(3)
        if (cell.kind === 'greenhouse') {
          const days = Math.max(1, view.plantDays)
          const ratio = Math.max(0, Math.min(1, cell.progress / days))
          const bar = this.add.graphics()
          bar.setDepth(3)
          bar.fillStyle(0x4a4e54, 1)
          bar.fillRoundedRect(rect.x + 8, rect.y + rect.h - 18, 78, 10, 2)
          bar.fillStyle(0xf0f0f2, 1)
          bar.fillRoundedRect(rect.x + 8, rect.y + rect.h - 18, Math.max(ratio > 0 ? 4 : 0, 78 * ratio), 10, 2)
          bar.lineStyle(1.5, 0x4a4e54, 1)
          bar.strokeRoundedRect(rect.x + 8, rect.y + rect.h - 18, 78, 10, 2)
          const progress = this.add.text(rect.x + 90, rect.y + rect.h - 20, cell.progress + '/' + days, {
            fontFamily: FONT,
            fontSize: '12px',
            color: '#0f1115',
          })
          progress.setDepth(3)
        }
      }
    })
    if (view.phase === 'night') {
      marks.fillStyle(0x0f1115, 0.45)
      marks.fillRect(0, 0, width, height)
    } else if (view.phase === 'day') {
      marks.fillStyle(0xf0f0f2, 0.1)
      marks.fillRect(0, 0, width, height)
    }
    if (view.flare && view.phase !== 'night') {
      marks.lineStyle(4, 0xf0f0f2, 1)
      marks.strokeRect(3, 3, width - 6, height - 6)
    }
    view.cells.forEach((cell, index) => {
      if (!view.harvestCells.includes(index)) return
      const rect = cellRect(metrics, index)
      marks.lineStyle(4, 0x0f1115, 1)
      marks.strokeRoundedRect(rect.x + 3, rect.y + 3, rect.w - 6, rect.h - 6, 8)
      const mark = this.add.text(rect.x + rect.w - 24, rect.y + rect.h - 26, '★', {
        fontFamily: FONT,
        fontSize: '18px',
        color: '#0f1115',
      })
      mark.setDepth(6)
    })
  }
}

const FONT = '"Source Han Sans JP", sans-serif'

function gridMetrics(_width: number, _height: number): Metrics {
  return { pad: 0, gap: 0, cellW: 144, cellH: 146 }
}

function cellRect(metrics: Metrics, index: number): { x: number; y: number; w: number; h: number } {
  const col = index % 6
  const row = Math.floor(index / 6)
  return {
    x: col * metrics.cellW,
    y: row * metrics.cellH,
    w: metrics.cellW,
    h: metrics.cellH,
  }
}

function dashed(graphics: Phaser.GameObjects.Graphics, x: number, y: number, w: number, h: number, color: number): void {
  graphics.lineStyle(1.2, color, 1)
  const step = 6
  for (let i = 0; i < w; i += step * 2) graphics.lineBetween(x + i, y, x + Math.min(i + step, w), y)
  for (let i = 0; i < h; i += step * 2) graphics.lineBetween(x + w, y + i, x + w, y + Math.min(i + step, h))
  for (let i = 0; i < w; i += step * 2) graphics.lineBetween(x + w - i, y + h, x + w - Math.min(i + step, w), y + h)
  for (let i = 0; i < h; i += step * 2) graphics.lineBetween(x, y + h - i, x, y + h - Math.min(i + step, h))
}

function cellAt(x: number, y: number, width: number, height: number): number {
  const metrics = gridMetrics(width, height)
  for (let index = 0; index < 18; index++) {
    const rect = cellRect(metrics, index)
    if (x >= rect.x && y >= rect.y && x <= rect.x + rect.w && y <= rect.y + rect.h) return index
  }
  return -1
}
