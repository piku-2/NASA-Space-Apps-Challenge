# 開発手順

1. Node.js 24 と npm、Python 3 を用意します。
2. `npm ci` で依存を入れます。バージョンは `package.json` に固定しています。
3. 変更後に `npm run check` を実行します。型、シミュレーション、文字と翻訳を確認します。
4. 表示に関わる変更は `npm run dev` で日本語・英語の両方を確認します。
5. 公開用のビルドは `npm run build` と `npm run preview` で確認します。
6. 戦略ボットの比較は `npm run evaluate` です。人間のプレイテストではありません。変更前の固定結果は `docs/strategy-baseline.json`、今回の再実行は `docs/strategy-current.json` です。
7. ブラウザ検証は `npm run dev` で `http://127.0.0.1:5173` を起動してから行います。Playwright は `package.json` の依存ではないので、次のどちらかで `index.mjs` を渡します。`PLAYWRIGHT_MODULE=/path/to/playwright/index.mjs node scripts/playtest.mjs` または `node scripts/playtest.mjs --playwright /path/to/playwright/index.mjs`。`npm run playtest` だけではモジュールパスを渡さないため、未導入の環境では失敗します。

新しい基地だけ `rules_version` 4 で、生命維持に電力5/日（ゲーム用の値）を使います。`rules_version` が 4 でない保存は version 3 として読み、生命維持電力は引きません。

## 文字・翻訳

テキストは UTF-8（BOM なし）、改行は LF に統一します。翻訳は `i18n/ja.json` と `i18n/en.json` を同時に編集し、キーとプレースホルダーを揃えてください。表示フォントは `ui_assets/fonts/` に同梱しています。フォント更新時にはライセンスの保持と日本語表示の確認も必要です。

## 変更とレビュー

変更目的に必要な範囲を編集し、無関係な一括整形を避けてください。PR には変更目的・確認結果・画面変更がある場合の画像を添えます。GitHub Pages への公開は `main` への push で実行されます。

秘密情報や個人設定はコミットしないでください。現在のゲームは静的データで動作するため、API キーや `.env` の用意は不要です。NASA の参考資料とゲーム内の調整値は区別して説明してください。
