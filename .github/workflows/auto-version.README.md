# 自動バージョニング (auto-version.yml)

`main` へ PR がマージされると、変更のあったプラグインのバージョンを自動で上げ、その変更を `main` へ自動マージするワークフローです。

## 挙動

- `main` 宛ての PR がマージされると発火（`pull_request: closed` かつ `merged == true`）。
- `.claude-plugin/marketplace.json` に登録された各プラグインを走査し、その PR で `source` 配下に変更があったプラグインのバージョンを上げる。
  - このリポジトリは `source` がルート（`./`）なので、`.github/` 以外の変更があれば上げる。
- `.claude-plugin/plugin.json` と `marketplace.json` の両方の `version` を同期して更新する。
- 更新は `auto-version/pr-<番号>` ブランチを作り、PR を立てて `main` へ自動マージする。

## バージョンを上げないケース

- PR に `bump:skip` ラベルが付いている。
- PR 内で `plugin.json` の `version` を手動で変更済み（その差分があるプラグインは自動では上げない）。
- PR の変更が `.github/` 配下だけ。
- 自動バージョン用ブランチ（`auto-version/*`）のマージ（無限ループ防止）。

## 上げ幅の指定

- 既定の上げ幅は `auto-version.yml` 先頭の `DEFAULT_BUMP_LEVEL`（`patch`）
- PR ごとに上書きしたい場合はラベルを付ける: `bump:major` / `bump:minor` / `bump:patch`

## 前提となるリポジトリ設定

- `main` のルールセット `protect-main`: PR 必須（承認 0 件）、強制 push と削除の禁止。
  承認が 0 件なので、`GITHUB_TOKEN` のままバージョン更新の PR を作ってマージできる。
  承認を 1 件以上必須にする場合は、bot（GitHub App）を作ってルールセットの bypass list に入れ、そのトークンでマージするように変える必要がある
  （参考: [logix-claude-plugins の auto-version.README.md](https://github.com/kurando-inc/logix-claude-plugins/blob/main/.github/workflows/auto-version.README.md)）。
- Settings → Actions → General の「Allow GitHub Actions to create and approve pull requests」: 有効。
  `GITHUB_TOKEN` で PR を作るため。
