# 小さな火星基地 · Mars Notebook

NASA Space Apps Challenge の Junior Astronaut Mission Trainer に向けた、ブラウザーの基地運営ゲームです。朝に隊員・建設・改良・退避を決め、昼に仕事が一度だけ進み、夜に収穫・被害・生産・研究の結果を見てから次の朝へ進みます。15日間の生存と研究30が目標です。日本語・英語に対応しています。

6人の隊員（アオイ、レン、ミオ、ソラ、ハル、リクト）はそれぞれ発電、水、プラント、研究、採掘が得意で、その施設にいるときだけ追加の効果があります。リクトもアオイと同じく発電が得意です。別の施設でも働けますが、得意ボーナスはつきません。施設の定員は2人です。研究は消費しません。研究10でシールドが強くなり、研究20でプラントの収穫が増えます。どちらも、その研究を持った朝から効きます。

フレアの日順は固定です。その朝は、研究を続けるか、実験室の研究を休んで追加の電力と仕事をまもりに使うかを選べます。予報に、研究・元気の変化と追加の電力が見えます。電力が余っていても、まもる側は当日の研究を失います。退避は全員の仕事を止めて被害をゼロにします。シールドは資材で建てると残り、研究10でさらに強くなります。確率の天気や依頼、ストレスはありません。資源の計算は昼の終わりに一度だけです。

## 起動

Node.js と npm があれば遊べます。

```sh
npm ci
npm run dev
```

開発サーバーは `http://127.0.0.1:5173` です。日本語表示には同梱の Source Han Sans JP を使用します。OS へのフォント追加は不要です。

## 開発・確認

手順は [CONTRIBUTING.md](CONTRIBUTING.md)、エージェント向けの指針は [AGENTS.md](AGENTS.md) にあります。

```sh
npm run check      # 型検査、シミュレーションテスト、UTF-8・翻訳
npm run build      # dist/ に静的ファイルを書き出す
npm run preview    # http://127.0.0.1:8000 でビルド結果を確認
```

`make check` と `make build` も同じコマンドを呼びます。

`main` への push 時には GitHub Actions が `npm ci`、`npm run check`、`npm run build` を実行し、`dist/` を GitHub Pages に公開します。公開先リポジトリでは Pages のソースを GitHub Actions に設定してください。

## 構成・データ

- `src/domain/`: UI に依存しないシミュレーション
- `src/game/`: Phaser の基地ボードと、操作・表示の DOM
- `data/values.json`: ゲームバランス
- `i18n/`: 日本語・英語の文言
- `ui_assets/`: SVG と日本語フォント
- `assets/sfx/`: 効果音（Kenney、CC0。[クレジット](assets/sfx/CREDITS.md)）

フレア警報は NASA の2024年5月14日の X8.7 フレア観測を参考にしています。ライブ情報ではありません。資源量・生産量・消費量・体力はゲーム用の調整値です。

## ライセンス

コードは [MIT License](LICENSE)。外部素材・ツールの条件は [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) を参照してください。
