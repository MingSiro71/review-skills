#!/usr/bin/env bash
# レビュー対象と出力先を決定論的に算出して KEY=VALUE 形式で出力する。
#
# 使い方: bash review-context.sh [base-branch] [pr-number]
#   base 省略時: develop。
#   pr-number: pr-review 専用。渡したときだけファイル名のタグを PR 番号にする（無ければブランチ名）。
set -euo pipefail

BASE_ARG="${1:-}"
PR_NUMBER="${2:-}"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "ERROR=not_in_git_worktree" >&2; exit 1;
}

ROOT="$(git rev-parse --show-toplevel)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# --- base 解決: 引数 > develop ---
BASE="${BASE_ARG:-develop}"

# 比較対象の ref（origin/<base> があれば優先、無ければローカル <base>）
if git rev-parse --verify --quiet "origin/$BASE" >/dev/null; then
  BASE_REF="origin/$BASE"
elif git rev-parse --verify --quiet "$BASE" >/dev/null; then
  BASE_REF="$BASE"
else
  echo "ERROR=base_not_found:$BASE" >&2; exit 1
fi

MERGE_BASE="$(git merge-base "$BASE_REF" HEAD)"

# --- 出力先 ---
OUTDIR="$ROOT/.claude-scratchpad/review"
# 出力先の md から見たリポジトリルートへの相対パス（該当箇所リンク用）。OUTDIR の段数と合わせる
REL_TO_ROOT="../.."

# 出力した md が未追跡ファイルとして残ると、次の pr-review が dirty_worktree で止まる。
# 除外の設定はユーザーに任せ（README 参照）、ここでは無ければ知らせるだけにする。
if ! git -C "$ROOT" check-ignore -q .claude-scratchpad/; then
  echo "WARN=scratchpad_not_ignored" >&2
fi

# --- ファイル名タグと連番 ---
if [ -n "$PR_NUMBER" ]; then
  TAG="$PR_NUMBER"
else
  TAG="$(printf '%s' "$BRANCH" | tr '/ ' '__')"
fi

SERIAL=1
if [ -d "$OUTDIR" ]; then
  EXISTING="$(find "$OUTDIR" -maxdepth 1 -name "review-${TAG}-*.md" 2>/dev/null | wc -l | tr -d ' ')"
  SERIAL=$((EXISTING + 1))
fi

echo "ROOT=$ROOT"
echo "BRANCH=$BRANCH"
echo "BASE=$BASE"
echo "BASE_REF=$BASE_REF"
echo "MERGE_BASE=$MERGE_BASE"
echo "HEAD_SHA=$(git rev-parse HEAD)"
echo "PR_NUMBER=$PR_NUMBER"
echo "OUTDIR=$OUTDIR"
echo "REL_TO_ROOT=$REL_TO_ROOT"
echo "SERIAL=$SERIAL"
echo "OUTFILE=$OUTDIR/review-${TAG}-${SERIAL}.md"
echo "DIFF_CMD=git diff ${BASE_REF}...HEAD"
echo "---CHANGED_FILES---"
git diff --stat "${BASE_REF}...HEAD"
