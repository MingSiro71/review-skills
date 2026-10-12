#!/usr/bin/env bash
# レビュー対象と出力先を決定論的に算出して KEY=VALUE 形式で出力する。
# 副作用なし（PR は作らない・ファイルも作らない）。読み取りのみ。
#
# 使い方: bash review-context.sh [base-branch]
#   base 省略時: PR があればその baseRefName、無ければ develop。
set -euo pipefail

BASE_ARG="${1:-}"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "ERROR=not_in_git_worktree" >&2; exit 1;
}

ROOT="$(git rev-parse --show-toplevel)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# --- PR 情報（gh があれば現ブランチの PR を引く） ---
PR_NUMBER=""
PR_BASE=""
if command -v gh >/dev/null 2>&1; then
  if PR_NUMBER="$(gh pr view --json number -q .number 2>/dev/null)"; then
    PR_BASE="$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null || true)"
  else
    PR_NUMBER=""
  fi
fi

# --- base 解決: 引数 > PR の base > develop ---
BASE="${BASE_ARG:-${PR_BASE:-develop}}"

# 比較対象の ref（origin/<base> があれば優先、無ければローカル <base>）
if git rev-parse --verify --quiet "origin/$BASE" >/dev/null; then
  BASE_REF="origin/$BASE"
elif git rev-parse --verify --quiet "$BASE" >/dev/null; then
  BASE_REF="$BASE"
else
  echo "ERROR=base_not_found:$BASE" >&2; exit 1
fi

MERGE_BASE="$(git merge-base "$BASE_REF" HEAD)"

# --- 出力先: ~/.claude/projects/<slug>/docs (slug = worktree root の / を - に置換) ---
SLUG="$(printf '%s' "$ROOT" | sed 's#/#-#g')"
OUTDIR="$HOME/.claude/projects/$SLUG/docs"

# --- 出力先の md から見たリポジトリルートへの相対パス（該当箇所リンク用） ---
# md はリポジトリ外に置かれるので `../` で遡る。段数は環境で変わるため決め打ちしない。
# OUTDIR はまだ存在しないことがあるので、実在を要求しない -m を使う。
if ! REL_TO_ROOT="$(realpath -m --relative-to="$OUTDIR" "$ROOT" 2>/dev/null)"; then
  REL_TO_ROOT="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$ROOT" "$OUTDIR")"
fi

# --- ファイル名タグと連番 ---
if [ -n "$PR_NUMBER" ]; then
  TAG="$PR_NUMBER"
else
  TAG="nopr-$(printf '%s' "$BRANCH" | tr '/ ' '__')"
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
