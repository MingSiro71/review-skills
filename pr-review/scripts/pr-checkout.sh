#!/usr/bin/env bash
# PR の URL（または番号）を受け取り、現在の作業ツリーでその PR を checkout する前処理。
# 破壊的な操作を避けるため、次の場合は何もせず中断する:
#   - PR のリポジトリが現在地のリポジトリと違う
#   - 作業ツリーが汚れている
#   - 現ブランチにリモートへ push されていないコミットがある
#
# 使い方: bash pr-checkout.sh <PR-URL | owner/repo#N | N>
set -euo pipefail

ARG="${1:-}"
[ -n "$ARG" ] || { echo "ERROR=missing_pr_argument" >&2; exit 1; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "ERROR=not_in_git_worktree" >&2; exit 1;
}
command -v gh >/dev/null 2>&1 || { echo "ERROR=gh_not_found" >&2; exit 1; }

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# --- 引数の解釈: URL / owner/repo#N / 番号 ---
TARGET_REPO=""
PR_NUMBER=""
case "$ARG" in
  *github.com*)
    TARGET_REPO="$(printf '%s' "$ARG" | sed -E 's#^.*github\.com[:/]+([^/]+/[^/]+)/pull/[0-9]+.*$#\1#')"
    PR_NUMBER="$(printf '%s' "$ARG" | sed -E 's#^.*/pull/([0-9]+).*$#\1#')"
    ;;
  */*\#[0-9]*)
    TARGET_REPO="${ARG%%#*}"
    PR_NUMBER="${ARG##*#}"
    ;;
  [0-9]*)
    PR_NUMBER="$ARG"
    ;;
  *)
    echo "ERROR=unrecognized_pr_argument:$ARG" >&2; exit 1
    ;;
esac

case "$PR_NUMBER" in
  ''|*[!0-9]*) echo "ERROR=pr_number_not_parsed:$ARG" >&2; exit 1 ;;
esac

# --- リポジトリ一致の確認 ---
ORIGIN_URL="$(git remote get-url origin 2>/dev/null || true)"
[ -n "$ORIGIN_URL" ] || { echo "ERROR=no_origin_remote" >&2; exit 1; }
CUR_REPO="$(printf '%s' "$ORIGIN_URL" | sed -E 's#^.*github\.com[:/]+##; s#\.git$##; s#/+$##')"

if [ -n "$TARGET_REPO" ] && [ "$(lower "$TARGET_REPO")" != "$(lower "$CUR_REPO")" ]; then
  echo "ERROR=repo_mismatch:target=$TARGET_REPO:current=$CUR_REPO" >&2
  exit 1
fi

# --- 作業ツリーが汚れていないか ---
if [ -n "$(git status --porcelain)" ]; then
  echo "ERROR=dirty_worktree" >&2
  git status --short >&2
  exit 1
fi

PREV_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# --- リモート最新を取得（未 push 判定を正しく行うため checkout 前に実行） ---
git fetch origin >&2

# --- 現ブランチのコミットがリモートに存在するか ---
if [ "$PREV_BRANCH" != "HEAD" ]; then
  if UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
    AHEAD="$(git rev-list --count "$UPSTREAM..HEAD")"
    [ "$AHEAD" = "0" ] || {
      echo "ERROR=unpushed_commits:$PREV_BRANCH:$AHEAD" >&2; exit 1;
    }
  elif [ -z "$(git branch -r --contains HEAD 2>/dev/null | head -1)" ]; then
    echo "ERROR=local_only_commits:$PREV_BRANCH" >&2; exit 1
  fi
fi

# --- PR 情報 ---
PR_TSV="$(gh pr view "$PR_NUMBER" \
  --json state,title,baseRefName,headRefName,isCrossRepository \
  --jq '[.state, .title, .baseRefName, .headRefName, (.isCrossRepository|tostring)] | @tsv' 2>/dev/null)" || {
  echo "ERROR=pr_not_found:$CUR_REPO#$PR_NUMBER" >&2; exit 1;
}
IFS=$'\t' read -r PR_STATE PR_TITLE PR_BASE PR_HEAD PR_FORK <<<"$PR_TSV"

# --- checkout（既存ローカルブランチが PR と乖離している場合は失敗させて中断） ---
gh pr checkout "$PR_NUMBER" >&2 || {
  echo "ERROR=pr_checkout_failed:$PR_NUMBER" >&2
  echo "HINT=同名のローカルブランチが PR と乖離している可能性がある。手動で解消すること。" >&2
  exit 1
}

echo "REPO=$CUR_REPO"
echo "PR_NUMBER=$PR_NUMBER"
echo "PR_STATE=$PR_STATE"
echo "PR_TITLE=$PR_TITLE"
echo "PR_BASE=$PR_BASE"
echo "PR_HEAD=$PR_HEAD"
echo "PR_IS_FORK=$PR_FORK"
echo "PREV_BRANCH=$PREV_BRANCH"
echo "BRANCH=$(git rev-parse --abbrev-ref HEAD)"
