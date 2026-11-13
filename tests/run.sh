#!/usr/bin/env bash
# Test suite for scripts/git-parity.sh. Builds throwaway repositories with local
# bare remotes, one scenario per state, and checks both the report and the refs.
# Usage: bash tests/run.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
GP="$HERE/../scripts/git-parity.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/git-parity-test.XXXXXX")
trap 'rm -rf "$T"' EXIT

export GIT_PARITY_CONFIG_DIR="$T/config"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkdir -p "$GIT_PARITY_CONFIG_DIR"

PASS=0; FAIL=0
ok()   { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/    /'; }
has()  { case $2 in *"$3"*) ok ;; *) fail "$1: expected to find '$3'" "$2" ;; esac; }
hasnt(){ case $2 in *"$3"*) fail "$1: did not expect '$3'" "$2" ;; *) ok ;; esac; }
eq()   { if [ "$2" = "$3" ]; then ok; else fail "$1: '$2' != '$3'"; fi; }

g() { git -C "$@"; }
commit() { # repo message [file]
  local f=${3:-file.txt}
  echo "$2" >> "$1/$f"; g "$1" add -A; g "$1" commit -q -m "$2"
}
sha() { g "$1" rev-parse "$2"; }
# everything a read-only run must not change: local branches, HEAD, working tree
snapshot() { g "$1" for-each-ref refs/heads; g "$1" rev-parse HEAD; g "$1" status --porcelain; g "$1" stash list; }

# new <name>: bare remote + clone "<name>" with one commit on main, origin/HEAD set
new() {
  local d="$T/$1"
  git init -q --bare -b main "$T/$1.git"
  git clone -q "$T/$1.git" "$d" 2>/dev/null
  g "$d" checkout -q -b main 2>/dev/null
  commit "$d" init
  g "$d" push -q -u origin main
  g "$d" remote set-head origin main
  echo "$d"
}
# someone else pushes N commits to <branch> of <name>
remote_commit() { # name branch [n] [file]
  local w="$T/$1.other" n=${3:-1} i=0
  [ -d "$w" ] || git clone -q "$T/$1.git" "$w"
  g "$w" checkout -q "$2" 2>/dev/null || g "$w" checkout -q -b "$2"
  g "$w" pull -q origin "$2" 2>/dev/null
  while [ $i -lt "$n" ]; do commit "$w" "remote $i" "${4:-remote.txt}"; i=$((i + 1)); done
  g "$w" push -q origin "$2"
}

# --- scenarios ---------------------------------------------------------------

# 1. clean
R=$(new clean)
out=$(bash "$GP" status "$R")
has "clean" "$out" "Clean (1): clean"
has "clean" "$out" "0 need attention"
has "clean" "$out" "Nothing to do."

# 2. behind: status is read-only, remote fast-forwards
R=$(new behind); remote_commit behind main 2
before=$(snapshot "$R")
out=$(bash "$GP" status "$R")
has "behind/status" "$out" "| behind | main | BEHIND 2 |"
eq  "behind/status is read-only" "$(snapshot "$R")" "$before"
out=$(bash "$GP" remote "$R")
has "behind/remote" "$out" "main updated +2"
eq  "behind/remote ff" "$(sha "$R" main)" "$(sha "$R" origin/main)"

# 3. ahead: reported, never pushed; protected base gets no push step
R=$(new ahead); g "$R" checkout -q -b feat; g "$R" push -q -u origin feat; commit "$R" a; commit "$R" b
remote_before=$(g "$T/ahead.git" for-each-ref)
out=$(bash "$GP" full "$R")
has "ahead" "$out" "| ahead | feat | AHEAD 2 |"
has "ahead/candidate" "$out" "ahead · feat · 2 commit(s) ahead of origin/feat"
eq  "ahead/never pushes" "$(g "$T/ahead.git" for-each-ref)" "$remote_before"
R=$(new aheadbase); commit "$R" a
out=$(bash "$GP" local "$R")
has   "ahead on base" "$out" "protected"
hasnt "ahead on base" "$out" "Push candidates"

# 4. diverged: untouched in every mode
R=$(new diverged); remote_commit diverged main 1; commit "$R" mine
before=$(snapshot "$R")
out=$(bash "$GP" full "$R")
has "diverged" "$out" "| diverged | main | DIVERGED |"
has "diverged" "$out" "1 local / 1 remote"
eq  "diverged/untouched" "$(snapshot "$R")" "$before"

# 5. dirty: never pulled over
R=$(new dirty); remote_commit dirty main 1; echo wip >> "$R/file.txt"; echo new > "$R/untracked.txt"
before=$(snapshot "$R")
out=$(bash "$GP" remote "$R")
has "dirty" "$out" "| dirty | main | DIRTY 2 |"
has "dirty" "$out" "behind 1, not pulled"
eq  "dirty/untouched" "$(snapshot "$R")" "$before"

# 6. no upstream
R=$(new noup); g "$R" checkout -q -b feat/new; commit "$R" x
out=$(bash "$GP" local "$R")
has "no-upstream" "$out" "| noup | feat/new | NO-UPSTREAM | never pushed, 1 commit(s)"
has "no-upstream" "$out" "noup · feat/new · never pushed, 1 commit(s)"
has "no-upstream" "$out" "push -u origin feat/new"

# 7. detached HEAD
R=$(new detached); g "$R" checkout -q --detach
out=$(bash "$GP" remote "$R")
has "detached" "$out" "| detached | - | DETACHED |"

# 8. gone: remote branch deleted after merge
R=$(new gone); g "$R" checkout -q -b feat; g "$R" push -q -u origin feat
g "$T/gone.git" branch -D feat >/dev/null
out=$(bash "$GP" status "$R")
has "gone/current" "$out" "| gone | feat | GONE |"
g "$R" checkout -q main
out=$(bash "$GP" status "$R")
has "gone/other" "$out" "1 branch(es) with remote gone"
eq  "gone/branch kept" "$(g "$R" branch --list feat | tr -d ' *')" "feat"

# 9. rebase in progress
R=$(new rebase); remote_commit rebase main 1 file.txt; commit "$R" conflict
g "$R" fetch -q; g "$R" rebase -q origin/main >/dev/null 2>&1
before=$(snapshot "$R")
out=$(bash "$GP" remote "$R")
has "in-progress" "$out" "IN-PROGRESS"
has "in-progress" "$out" "rebase in progress"
eq  "in-progress/untouched" "$(snapshot "$R")" "$before"

# 10. base behind while on a feature branch: base updated without checkout
R=$(new basebehind); g "$R" checkout -q -b feat; g "$R" push -q -u origin feat; remote_commit basebehind main 3
out=$(bash "$GP" remote "$R")
has "base ff" "$out" "main updated +3"
eq  "base ff/sha" "$(sha "$R" main)" "$(sha "$R" origin/main)"
eq  "base ff/still on feat" "$(g "$R" symbolic-ref --short HEAD)" "feat"
has "base ff/row" "$out" "| basebehind | feat | OK |"

# 11. no origin/HEAD: base falls back to origin/main
R=$(new nohead); g "$R" remote set-head origin -d; commit "$R" a
out=$(bash "$GP" local "$R")
has   "no origin/HEAD" "$out" "protected"
hasnt "no origin/HEAD" "$out" "base branch unknown"

# 12. unreachable remote: flagged stale, run continues
R=$(new stale); g "$R" remote set-url origin "$T/does-not-exist.git"
R2=$(new stale-ok)
out=$(bash "$GP" status "$R" "$R2")
has "stale" "$out" "| stale | main | STALE |"
has "stale" "$out" "fetch failed"
has "stale/others still run" "$out" "Clean (1): stale-ok"

# 13. path with spaces
mkdir "$T/with space"; git init -q --bare -b main "$T/with space/sp.git"
git clone -q "$T/with space/sp.git" "$T/with space/sp" 2>/dev/null
R="$T/with space/sp"; g "$R" checkout -q -b main 2>/dev/null; commit "$R" init; g "$R" push -q -u origin main; commit "$R" more
out=$(bash "$GP" status "$R")
has "spaces" "$out" "| sp | main | AHEAD 1 |"

# 14. branch checked out in another worktree is not force-updated
R=$(new wt); g "$R" checkout -q -b feat; g "$R" push -q -u origin feat
g "$R" worktree add -q "$T/wt-main" main; remote_commit wt main 1
old=$(sha "$R" main)
out=$(bash "$GP" remote "$R")
eq  "worktree/main untouched" "$(sha "$R" main)" "$old"
has "worktree/reported" "$out" "main behind 1"

# 15. never-push file
R=$(new never); g "$R" checkout -q -b release; g "$R" push -q -u origin release; commit "$R" a
echo release > "$GIT_PARITY_CONFIG_DIR/never-push"
out=$(bash "$GP" local "$R")
hasnt "never-push" "$out" "Push candidates"
rm "$GIT_PARITY_CONFIG_DIR/never-push"

# 16. other branch ahead becomes a push candidate and keeps the repo out of "Clean"
R=$(new other); g "$R" checkout -q -b feat; g "$R" push -q -u origin feat; commit "$R" a; g "$R" checkout -q main
out=$(bash "$GP" local "$R")
has "other branch" "$out" "| other | main | BRANCHES |"
has "other branch" "$out" "other · feat · 1 commit(s) ahead"

# 16b. feature branch created from origin/main tracks the base: not "diverged", never fast-forwarded to base
R=$(new tracks); g "$R" checkout -q -b feat origin/main; commit "$R" a; remote_commit tracks main 2
g "$R" branch -q idle origin/main
old=$(sha "$R" idle)
out=$(bash "$GP" full "$R")
has   "tracks base" "$out" "| tracks | feat | NO-UPSTREAM | never pushed, 1 commit(s); tracks origin/main"
has   "tracks base" "$out" "2 behind main"
hasnt "tracks base" "$out" "DIVERGED"
has   "tracks base/candidate" "$out" "push -u origin feat"
eq    "tracks base/idle branch not moved" "$(sha "$R" idle)" "$old"
hasnt "tracks base/empty branch is not a candidate" "$out" "idle"
g "$R" checkout -q idle
out=$(bash "$GP" status "$R")
has   "new empty branch" "$out" "new branch, no commits yet"

# 16c. branch never pushed shows up in read-only status too
R=$(new hidden); g "$R" checkout -q -b wip; commit "$R" a; g "$R" checkout -q main
out=$(bash "$GP" status "$R")
has "hidden work" "$out" "wip never pushed (1 commit(s))"

# 16d. remote branches not merged into base, without a local copy
R=$(new unmerged); for b in t1 t2 t3 t4; do remote_commit unmerged "$b" 1 "$b.txt"; done
out=$(bash "$GP" status "$R")
has "remote unmerged" "$out" "- unmerged: 4, newest:"
has "remote unmerged/still clean" "$out" "Clean (1): unmerged"

# 17. discovery: repos file, cwd repo, scan, urgency ordering
A=$(new d-a); B=$(new d-b); commit "$B" x; g "$B" checkout -q -b f; commit "$B" y
printf '# comment\n%s\n\n%s\n' "$A" "$B" > "$GIT_PARITY_CONFIG_DIR/repos"
out=$(bash "$GP" status)
has "repos file" "$out" "2 repo(s)"
rm "$GIT_PARITY_CONFIG_DIR/repos"
out=$(cd "$A" && bash "$GP" status --no-fetch)
has "cwd repo" "$out" "1 repo(s)"
has "no-fetch" "$out" "no fetch"
mkdir -p "$T/scan/x" "$T/scan/grp/y"; git init -q "$T/scan/x"; git init -q "$T/scan/grp/y"; mkdir -p "$T/scan/a/b/c/z"; git init -q "$T/scan/a/b/c/z"
out=$(cd "$T/scan" && bash "$GP" status)
has "scan depth 2" "$out" "2 repo(s)"
R1=$(new o-div); remote_commit o-div main 1; commit "$R1" m
R2=$(new o-ahead); g "$R2" checkout -q -b f; g "$R2" push -q -u origin f; commit "$R2" a
out=$(bash "$GP" status "$R2" "$R1")
eq "ordering" "$(printf '%s\n' "$out" | grep '^| o-' | head -1 | cut -d'|' -f2 | tr -d ' ')" "o-div"

# 18. errors
out=$(bash "$GP" status "$T/nope" 2>&1)
has "not a repo" "$out" "ERROR"
out=$(bash "$GP" bogus 2>&1); eq "bad mode exit" "$?" "2"
out=$(cd "$T/scan/a" && bash "$GP" status)
has "no repos" "$out" "no repositories found"

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
