---
name: pr-review
description: PR の URL を渡すと、その PR を現在の作業ディレクトリに checkout して、branch-review と同じ 3 段階プロセス（8観点の配布レビュー → 評価 → 統合）でレビューし、結果を md に書き出す。"この PR をレビューして <URL>" "pr-review <URL>" などと言われたときに使う。
---

# 概要

他人の PR を、その URL だけを起点にレビューする。branch-review が「現ブランチ」を対象にするのに対し、
こちらは PR を現在の作業ディレクトリに checkout してから同じプロセスを走らせる。

レビュー本体（配布・評価・統合）は branch-review と共通で、このスキルが追加で担うのは前処理だけ:

1. **前処理** — PR を現在の作業ディレクトリに checkout し、base を PR から確定する（このスキル固有）
2. **ルール所在の特定 / 配布レビュー / 評価 / 統合** — branch-review の手順 3〜6 をそのまま実行する

`${CLAUDE_SKILL_DIR}/../branch-review/SKILL.md` を必ず読み、手順 3〜6・出力の制約・最終 md の構成はそちらに従うこと。
観点ごとの指示とサブエージェント共通の規定（振り分け基準・指摘フォーマット・該当箇所の書式）は
`${CLAUDE_SKILL_DIR}/../branch-review/references/perspectives/` 配下にあり、各サブエージェントが直接読む。
観点や出力形式をこのファイルで再定義しない。
このファイルが上書きするのは、該当箇所の書式（後述の GitHub permalink）と md ヘッダだけ。

## 前提

- 実行場所は、対象 PR と同じリポジトリの作業ツリー（work1〜work5 のような、切り替えてよいディレクトリ）であること。
- **ブランチは戻さない。** レビュー後も PR ブランチを checkout したままにする（指摘箇所をそのまま追えるようにするため）。
  この挙動をユーザーに毎回確認しない。

## 手順

### 1. PR の checkout（前処理）

作業リポジトリのルートで実行する:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/pr-checkout.sh <PR-URL>
```

引数は PR の URL のほか `owner/repo#123` や `123`（現在地のリポジトリ）も受け付ける。

このスクリプトは、次のいずれかに当てはまる場合は**何も変更せずに中断**する。エラーを握りつぶして先に進まず、
ユーザーに状況を伝えて指示を仰ぐこと:

| エラー | 意味と対応 |
| --- | --- |
| `repo_mismatch` | PR のリポジトリが現在地と違う。対象リポジトリの作業ツリーへ移動してもらう |
| `dirty_worktree` | 未コミットの変更がある。commit / stash はこちらで勝手に行わない |
| `unpushed_commits` / `local_only_commits` | 現ブランチにリモートに無いコミットがある。切り替えると見失うため停止 |
| `pr_checkout_failed` | 同名のローカルブランチが PR と乖離している。手動解消を依頼する |

成功時は `PR_NUMBER` `PR_BASE` `PR_HEAD` `PR_STATE` `PREV_BRANCH` `BRANCH` を控える。
`PR_STATE` が `OPEN` でない場合（MERGED / CLOSED）は、その旨を伝えてから続行する。

### 2. コンテキスト算出

branch-review のスクリプトを、PR から確定した base を引数に渡して実行する:

```bash
bash ${CLAUDE_SKILL_DIR}/../branch-review/scripts/review-context.sh <PR_BASE> <PR_NUMBER>
```

`ROOT` `BASE_REF` `HEAD_SHA` `OUTDIR` `OUTFILE` `DIFF_CMD` と変更ファイル一覧を控える。
スクリプトは `REL_TO_ROOT` も出力するが、**pr-review では使わない**（該当箇所は下記の GitHub permalink にする）。

branch-review にある **base の確認ダイアログは行わない**。あれは develop 決め打ちで派生元を誤ることへの
ガードであり、PR 起点では base が PR から一意に決まるため不要。解決された base は次のように口頭で提示するだけでよい:

> PR #123 (`feature/foo` → `develop`) を checkout しました。`origin/develop...HEAD` の差分でレビューします。

### 3. ルール所在の特定 / 配布レビュー / 評価 / 統合

`${CLAUDE_SKILL_DIR}/../branch-review/SKILL.md` の手順 3〜6（手順6 のリンク検証を含む）をそのまま実行する。ルール所在エージェント、8 観点の配布、
別エージェントによる評価（閾値75）、あなた自身による統合と md 書き出しまで、内容も責務分担も変えない。

### 4. 該当箇所の書式（branch-review を上書き）

`common.md` の相対リンク形式は使わない。GitHub の permalink を使う。配布レビューの各サブエージェントの
起動プロンプトにこの形式を明記し、`HEAD_SHA` を添える（common.md は「起動プロンプトで permalink 形式を
指示された場合はそちらに従う」と規定している）。

```
https://github.com/<owner>/<repo>/blob/<HEAD_SHA>/src/foo/bar.ts#L23-L25
```

- **完全な SHA が必須。** `$(git rev-parse HEAD)` のようなコマンド埋め込みは不可（md はそのまま
  レンダリングされるため展開されない）。手順 2 で控えた `HEAD_SHA` の値を文字列として埋め込む。
- 行範囲は `#L<start>-L<end>` 形式。対象行の前後1行以上の文脈を含める。
- 表示テキストは `src/foo/bar.ts:24` のようにパスと行番号にする。

### 5. 書き出し時の追記

最終 md のヘッダには、branch-review の構成に加えて PR の情報と作業ツリーの状態を書く:

```markdown
# レビュー: PR #<番号> (<head> → <base>)

- URL: <PR-URL>
- 対象: `<BASE_REF>...HEAD`
- 日付: <today>
- 作業ツリー: `<ROOT>` は現在 `<BRANCH>` を checkout 中（レビュー前は `<PREV_BRANCH>`）
```

レビュー完了後、ブランチを元に戻す提案はしない。ユーザーが戻したいときのために
`git switch <PREV_BRANCH>` だけ最後の報告に添える。
