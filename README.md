# review-skills

ブランチ・PR の変更を 8 観点のサブエージェントでレビューし、評価・統合して md に書き出す Claude Code プラグイン。

| スキル | 使い方 |
| --- | --- |
| `branch-review` | 「このブランチをレビューして」。現ブランチの変更をレビューする |
| `pr-review` | 「この PR をレビューして <URL>」。PR を checkout してからレビューする |

## レビュー結果の置き場所

レビュー対象のリポジトリの `.claude-scratchpad/review/review-<PR 番号>-<連番>.md` に書き出す。

レビューするリポジトリごとに、`.claude-scratchpad/` を git の除外設定に入れておく。
入れておかないと、出力した md が未追跡ファイルとして残り、次の pr-review が「未コミットの変更がある」と判定して止まる。

```bash
echo '/.claude-scratchpad/' >> "$(git rev-parse --git-path info/exclude)"
```

`.git/info/exclude` は手元だけの除外設定で、コミットされない。worktree では `.git` がファイルなので、パスは `git rev-parse --git-path` で求める。
除外されていない状態でレビューすると、branch-review / pr-review が最後にその旨を知らせる。

## eval

`claude plugin eval` で、スキルが指示どおりに動くかを確かめる。ケースは `evals/` にある。

### 必要な環境

| 必要なもの | 用途 |
| --- | --- |
| Claude Code 2.1.269 以上 | `claude plugin eval` |
| git 2.31 以上 | `claude plugin eval` の要件 |
| Claude のサブスクリプションのログイン、または API キー | モデルの呼び出し。普段の Claude Code と同じ認証で動く |
| Linux / macOS / WSL2（Windows ネイティブは不可） | Bash を許可したケースは OS のサンドボックス内で動くため |
| `bubblewrap`、`socat`（Linux / WSL2） | 同上。`sudo apt-get install bubblewrap socat` |
| AppArmor の設定（Ubuntu 24.04 以降で、`sysctl kernel.apparmor_restrict_unprivileged_userns` が `1` の場合のみ） | `bubblewrap` を動かすため。手順は [Sandboxing](https://code.claude.com/docs/en/sandboxing) の「Set up Linux and WSL2」 |

### 実行

プラグインのルートで:

```bash
claude plugin eval . --ablation none --no-publish
```

- `--ablation none`: プラグイン無しで比べる回を省く。今あるケースは「スキルが呼ばれるか」なので、比べる意味が無い
- `--no-publish`: レポートを claude.ai に公開せず、手元に置く
- 1 ケースにつき 3 回動かす。試しに 1 回だけ動かすなら `--runs 1`、ケースを絞るなら `--case <名前>`
- 結果は `evals/results/<日時>/report.html`（`.gitignore` 済み）

### ケース

| ケース | 確かめること |
| --- | --- |
| `triggers-branch-review` | ブランチのレビュー依頼で branch-review が呼ばれる |
| `triggers-pr-review` | PR の URL を渡したレビュー依頼で pr-review が呼ばれる |
| `ignores-bug-fix` | レビューではない依頼では、どちらのスキルも呼ばれない |
