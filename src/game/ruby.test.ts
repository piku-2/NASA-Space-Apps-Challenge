import assert from "node:assert/strict"
import { describe, it } from "node:test"
import en from "../../i18n/en.json" with { type: "json" }
import ja from "../../i18n/ja.json" with { type: "json" }
import { rubyHtml } from "./ruby.ts"

describe("ruby", () => {
  it("puts a reading on every kanji in the Japanese copy", () => {
    for (const [key, value] of [...Object.entries(ja), ...Object.entries(en)]) {
      const text = value.replace(/\{(\d+)\}/g, "1")
      const html = rubyHtml(text)
      const visible = html.replace(/<rt>.*?<\/rt>/g, "").replace(/<\/?ruby>/g, "")
      assert.equal(visible, text.replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[char] ?? char), key)
      const bare = html.replace(/<ruby>[\s\S]*?<\/ruby>/g, "")
      assert.equal(bare.match(/[\u3400-\u9FFF\uF900-\uFAFF]/u), null, key)
    }
  })

  it("reads counters and words the way they are spoken", () => {
    assert.match(rubyHtml("準備"), /<ruby>準<rt>じゅん<\/rt><\/ruby><ruby>備<rt>び<\/rt><\/ruby>/)
    assert.match(rubyHtml("今日"), /<ruby>今日<rt>きょう<\/rt><\/ruby>/)
    assert.match(rubyHtml("1日目"), /<ruby>日<rt>にち<\/rt><\/ruby><ruby>目<rt>め<\/rt><\/ruby>/)
    assert.match(rubyHtml("次の日"), /<ruby>日<rt>ひ<\/rt><\/ruby>/)
    assert.match(rubyHtml("5月"), /<ruby>月<rt>がつ<\/rt><\/ruby>/)
    assert.match(rubyHtml("何とか"), /<ruby>何<rt>なん<\/rt><\/ruby>/)
    assert.match(rubyHtml("何を"), /<ruby>何<rt>なに<\/rt><\/ruby>/)
    assert.match(rubyHtml("働く"), /<ruby>働<rt>はたら<\/rt><\/ruby>く/)
    assert.match(rubyHtml("活動"), /<ruby>活<rt>かつ<\/rt><\/ruby><ruby>動<rt>どう<\/rt><\/ruby>/)
    assert.match(rubyHtml("活動結果"), /<ruby>活<rt>かつ<\/rt><\/ruby><ruby>動<rt>どう<\/rt><\/ruby><ruby>結<rt>けっ<\/rt><\/ruby><ruby>果<rt>か<\/rt><\/ruby>/)
  })
})
