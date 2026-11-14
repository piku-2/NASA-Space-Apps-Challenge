import en from '../../i18n/en.json' with { type: 'json' }
import ja from '../../i18n/ja.json' with { type: 'json' }

export type Lang = 'ja' | 'en'

const DICTS: Record<Lang, Record<string, string>> = {
  ja: ja as Record<string, string>,
  en: en as Record<string, string>,
}

export function translate(lang: Lang, key: string, args: Array<string | number> = []): string {
  const template = DICTS[lang][key] ?? key
  return template.replace(/\{(\d+)\}/g, (_, index: string) => {
    const value = args[Number(index)]
    return value === undefined ? '' : String(value)
  })
}
