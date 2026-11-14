const KANJI = /[\u3400-\u9FFF\uF900-\uFAFF]/

/** A pipe splits one reading per kanji. No pipe means one ruby over the whole run. */
const READINGS: Record<string, string> = {
  基地司令官: "き|ち|し|れい|かん",
  太陽光発電: "たい|よう|こう|はつ|でん",
  火星基地: "か|せい|き|ち",
  基本収穫: "き|ほん|しゅう|かく",
  研究施設: "けん|きゅう|し|せつ",
  研究目標: "けん|きゅう|もく|ひょう",
  採掘施設: "さい|くつ|し|せつ",
  資材採掘: "し|ざい|さい|くつ",
  生存資源: "せい|ぞん|し|げん",
  生命維持: "せい|めい|い|じ",
  電力不足: "でん|りょく|ふ|そく",
  任務成功: "にん|む|せい|こう",
  居住区: "きょ|じゅう|く",
  実験室: "じっ|けん|しつ",
  実測値: "じっ|そく|ち",
  収穫前: "しゅう|かく|まえ",
  出来事: "で|き|ごと",
  消費量: "しょう|ひ|りょう",
  生産量: "せい|さん|りょう",
  設置済: "せっ|ち|す",
  専門家: "せん|もん|か",
  待機中: "たい|き|ちゅう",
  退避中: "たい|ひ|ちゅう",
  調整値: "ちょう|せい|ち",
  日連続: "にち|れん|ぞく",
  放射線: "ほう|しゃ|せん",
  稼働日: "か|どう|び",
  安全: "あん|ぜん",
  以上: "い|じょう",
  以前: "い|ぜん",
  移動: "い|どう",
  一日: "いち|にち",
  一歩: "いっ|ぽ",
  右側: "みぎ|がわ",
  宇宙: "う|ちゅう",
  影響: "えい|きょう",
  科学: "か|がく",
  稼働: "か|どう",
  解除: "かい|じょ",
  回復: "かい|ふく",
  改良: "かい|りょう",
  観測: "かん|そく",
  基地: "き|ち",
  機会: "き|かい",
  規則: "き|そく",
  記録: "き|ろく",
  休止: "きゅう|し",
  強化: "きょう|か",
  計画: "けい|かく",
  警報: "けい|ほう",
  結果: "けっ|か",
  建設: "けん|せつ",
  研究: "けん|きゅう",
  見守: "み|まも",
  見通: "み|とお",
  元気: "げん|き",
  効果: "こう|か",
  工夫: "く|ふう",
  今日: "きょう",
  砂嵐: "すな|あらし",
  砂埃: "すな|ぼこり",
  再生: "さい|せい",
  最初: "さい|しょ",
  採掘: "さい|くつ",
  栽培: "さい|ばい",
  参考: "さん|こう",
  仕事: "し|ごと",
  施設: "し|せつ",
  資源: "し|げん",
  資材: "し|ざい",
  自動: "じ|どう",
  実況: "じっ|きょう",
  収穫: "しゅう|かく",
  終了: "しゅう|りょう",
  出来: "でき",
  準備: "じゅん|び",
  情報: "じょう|ほう",
  食料: "しょく|りょう",
  成功: "せい|こう",
  生産: "せい|さん",
  設置: "せっ|ち",
  設定: "せっ|てい",
  選択: "せん|たく",
  全員: "ぜん|いん",
  太陽: "たい|よう",
  体力: "たい|りょく",
  対策: "たい|さく",
  待機: "たい|き",
  退避: "たい|ひ",
  隊員: "たい|いん",
  達成: "たっ|せい",
  単位: "たん|い",
  段階: "だん|かい",
  地球: "ち|きゅう",
  挑戦: "ちょう|せん",
  追加: "つい|か",
  電力: "でん|りょく",
  到着: "とう|ちゃく",
  得意: "とく|い",
  日間: "にち|かん",
  日目: "にち|め",
  配置: "はい|ち",
  配分: "はい|ぶん",
  発見: "はっ|けん",
  発電: "はつ|でん",
  半分: "はん|ぶん",
  被害: "ひ|がい",
  必要: "ひつ|よう",
  変化: "へん|か",
  保存: "ほ|ぞん",
  方法: "ほう|ほう",
  本当: "ほん|とう",
  毎日: "まい|にち",
  満員: "まん|いん",
  明日: "あした",
  目標: "もく|ひょう",
  予測: "よ|そく",
  予報: "よ|ほう",
  立派: "りっ|ぱ",
  綺麗: "きれい",
  日本語: "に|ほん|ご",
  育: "そだ",
  延: "の",
  押: "お",
  穏: "おだ",
  過: "す",
  確: "たし",
  帰: "かえ",
  休: "やす",
  居: "い",
  強: "つよ",
  近: "ちか",
  空: "あ",
  決: "き",
  建: "た",
  見: "み",
  元: "もと",
  減: "へ",
  後: "あと",
  効: "き",
  更: "さら",
  今: "いま",
  左: "ひだり",
  作: "つく",
  残: "のこ",
  使: "つか",
  始: "はじ",
  試: "ため",
  持: "も",
  次: "つぎ",
  守: "まも",
  終: "お",
  集: "あつ",
  出: "で",
  順: "じゅん",
  初: "はじ",
  書: "か",
  助: "たす",
  小: "ちい",
  消: "け",
  乗: "の",
  新: "あたら",
  進: "すす",
  水: "みず",
  晴: "は",
  生: "い",
  青: "あお",
  石: "いし",
  赤: "あか",
  切: "き",
  選: "えら",
  前: "まえ",
  増: "ふ",
  足: "た",
  続: "つづ",
  大: "おお",
  置: "お",
  蓄: "たくわ",
  昼: "ひる",
  朝: "あさ",
  働: "はたら",
  動: "うご",
  内: "ない",
  年: "ねん",
  倍: "ばい",
  付: "つ",
  負: "ふ",
  閉: "と",
  別: "べつ",
  変: "か",
  方: "かた",
  豊: "ゆた",
  無: "な",
  目: "め",
  戻: "もど",
  夜: "よる",
  遊: "あそ",
  用: "よう",
  葉: "は",
  嵐: "あらし",
}

function esc(value: string): string {
  return value.replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[char] ?? char)
}

function isKanji(char: string): boolean {
  return KANJI.test(char)
}

function previousMeaningful(chars: string[], index: number): string {
  for (let i = index - 1; i >= 0; i--) {
    if (chars[i].trim() === "") continue
    return chars[i]
  }
  return ""
}

function readingFor(run: string, prev: string, next: string): string {
  if (run === "日") return /[0-9０-９/／]/.test(prev) ? "にち" : "ひ"
  if (run === "月") return /[0-9０-９]/.test(prev) ? "がつ" : "つき"
  if (run === "何") return next === "と" ? "なん" : "なに"
  const reading = READINGS[run]
  if (!reading) throw new Error(`missing ruby for ${run}`)
  return reading
}

function rubyFor(run: string, reading: string): string {
  const parts = reading.split("|")
  const chars = [...run]
  if (parts.length === 1) return `<ruby>${esc(run)}<rt>${esc(parts[0])}</rt></ruby>`
  if (parts.length !== chars.length) throw new Error(`ruby length mismatch for ${run}`)
  return chars.map((char, index) => `<ruby>${esc(char)}<rt>${esc(parts[index])}</rt></ruby>`).join("")
}

export function rubyHtml(text: string): string {
  const chars = [...text]
  let html = ""
  let index = 0
  while (index < chars.length) {
    if (!isKanji(chars[index])) {
      html += esc(chars[index])
      index += 1
      continue
    }
    let end = index
    while (end < chars.length && isKanji(chars[end])) end += 1
    const run = chars.slice(index, end).join("")
    const next = chars[end] ?? ""
    html += rubyFor(run, readingFor(run, previousMeaningful(chars, index), next))
    index = end
  }
  return html
}
