# 小さな火星基地 · Mars Notebook

NASA Space Apps Challenge の Junior Astronaut Mission Trainer に向けた、Godot 製の基地運営ゲームです。隊員を配置し、生存資源・電力・資材をやりくりして、15日間の生存と研究30を目指します。日本語・英語に対応しています。

## 起動

Godot **4.6.3** で `project.godot` を開き、F5（プロジェクト実行）で起動します。

```sh
make run
# Godot が PATH にない場合
make run GODOT=/path/to/godot
```

日本語表示には同梱の Source Han Sans JP を使用します。OS へのフォント追加は不要です。

## 開発・確認

Python 3 と GNU Make を使います。変更手順は [CONTRIBUTING.md](CONTRIBUTING.md)、エージェント向けの指針は [AGENTS.md](AGENTS.md) にあります。

```sh
make check-text  # UTF-8・JSON・翻訳の整合性
make test        # インポート、シミュレーション、UI のチェック
make export-web  # dist/index.html に Web 版を書き出す
make serve       # http://localhost:8000 で確認
```

Web 書き出しには Godot 4.6.3 の export templates が必要です。エディターの「エディター → エクスポートテンプレートの管理」から用意してください。`make test` は専用のデータ保存先を使い、通常プレイのセーブを保護します。

`main` への push 時には既存の GitHub Actions が Web 版を GitHub Pages に公開します。公開先リポジトリでは Pages のソースを GitHub Actions に設定してください。

## 構成・データ

- `scripts/`: UI とシミュレーション
- `data/values.json`: ゲームバランス
- `i18n/`: 日本語・英語の文言
- `scenes/`, `ui_assets/`: 起動シーン、SVG、日本語フォント
- `test/`: 動作チェックとキャプチャ用スクリプト
- `docs/API.md`: チャレンジの背景と参考資料

フレア警報は NASA の2024年5月14日の X8.7 フレア観測を参考にしています。ライブ情報ではありません。資源量・生産量・消費量・体力はゲーム用の調整値です。

## ライセンス

コードは [MIT License](LICENSE)。外部素材・ツールの条件は [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) を参照してください。
