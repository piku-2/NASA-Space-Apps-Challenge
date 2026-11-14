import logo from '../../ui_assets/logo.png'
import solarIcon from '../../ui_assets/solar.svg'
import waterIcon from '../../ui_assets/water.svg'
import greenhouseIcon from '../../ui_assets/greenhouse.svg'
import labIcon from '../../ui_assets/lab.svg'
import habitatIcon from '../../ui_assets/habitat.svg'
import mineIcon from '../../ui_assets/mine.svg'
import shieldIcon from '../../ui_assets/shield.svg'
import powerIcon from '../../ui_assets/power.svg'
import materialIcon from '../../ui_assets/material.svg'
import survivalIcon from '../../ui_assets/survival.svg'
import starIcon from '../../ui_assets/star.svg'
import crewIcon from '../../ui_assets/crew.svg'
import placeSfx from '../../assets/sfx/place.ogg'
import expertSfx from '../../assets/sfx/expert.ogg'
import alarmSfx from '../../assets/sfx/flare_alert.ogg'

export const LOGO = logo

export const ICONS: Record<string, string> = {
  solar: solarIcon,
  water: waterIcon,
  greenhouse: greenhouseIcon,
  lab: labIcon,
  habitat: habitatIcon,
  mine: mineIcon,
  shield: shieldIcon,
  power: powerIcon,
  material: materialIcon,
  survival: survivalIcon,
  star: starIcon,
  crew: crewIcon,
}

const SFX = { place: placeSfx, expert: expertSfx, alarm: alarmSfx }
const audioCache: Partial<Record<keyof typeof SFX, HTMLAudioElement>> = {}

export function playSfx(name: keyof typeof SFX): void {
  const audio = audioCache[name] ?? new Audio(SFX[name])
  audioCache[name] = audio
  audio.currentTime = 0
  void audio.play().catch(() => undefined)
}
