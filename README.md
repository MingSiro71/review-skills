# review-skills

ブランチ・PR の変更を 8 観点のサブエージェントでレビューし、評価・統合して md に書き出す Claude Code プラグイン。

## 2つのインターフェース
ユースケースによって使い分け可能な2つのスキル (branch-review, pr-review) が利用可能。

### branch-review
Claude code CLI が実行されているプロジェクトディレクトリのカレントブランチを対象にレビューを行う。`/branch-review` または「このブランチをレビューして」などの指示で起動。

### pr-review
PRのURLを渡し、それを対象にレビューを行う。`/pr-review <URL>` または「<URL> をレビューして」などの指示で起動。

## レビュー結果の置き場所

レビュー対象のリポジトリの `.claude-scratchpad/review/review-<PR 番号>-<連番>.md` に書き出す。

レビューするリポジトリごとに、`.claude-scratchpad/` を git の除外設定に入れておく。
この設定がないと出力した md が未追跡ファイルとして残り、次の pr-review が「未コミットの変更がある」と判定して正しく動作しない（止まる）。

以下は `.git/info/exclude` を使った方法（推奨）。
```bash
echo '/.claude-scratchpad/' >> "$(git rev-parse --git-path info/exclude)"
```

# 開発者向け情報

## eval

変更を入れた場合、`claude plugin eval` で、スキルが指示通りに動作するかチェックすること。ケースは `evals/` にある。観点が eval にない場合は適切な eval を追加する。

### 動作環境

| 必要なもの | 用途 |
| --- | --- |
| Claude Code 2.1.269 以上 | `claude plugin eval` の要件 |
| git 2.31 以上 | `claude plugin eval` の要件 |
| Claude のサブスクリプションのログイン、または API キー | モデルの呼び出し。普段の Claude Code と同じ認証で動く |
| `bubblewrap`、`socat`（Linux / WSL2） | 同上。`sudo apt-get install bubblewrap socat` |

### 実行

プラグインのルートで:

```bash
claude plugin eval . --ablation none --no-publish --runs 3
```

- `--ablation none`: プラグイン無しで比べる回を省く（このスキルなしで実行した結果が欲しい場合は外すが、基本は常に省いてよい）
- `--no-publish`: レポートを claude.ai に公開せず、手元に置く
- `--runs <N>` 1 ケースにつき N 回動かす。試しに 1 回だけ動かすなら `--runs 1`、正式なコミットの前提は 3 で実行されているものとする。
- `--case <名前>` 検証するケースを絞る場合

### 結果の保存
- 結果は `evals/results/<日時>/report.html`（`.gitignore` 対象）に記録される
