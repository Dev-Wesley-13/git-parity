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

# --- 1.1.0: groups, feature, cleanup, forks ----------------------------------

# 19. groups in the repos file
GA=$(new g-a); GB=$(new g-b); GC=$(new g-c)
printf '%s\n[web]\n%s\n\n[mobile]\n%s\n' "$GA" "$GB" "$GC" > "$GIT_PARITY_CONFIG_DIR/repos"
out=$(bash "$GP" status --no-fetch);        has "groups/all" "$out" "3 repo(s)"
out=$(bash "$GP" status --no-fetch web);    has "groups/one" "$out" "Clean (1): g-b"
out=$(bash "$GP" status --no-fetch web mobile "$GA"); has "groups/mixed with path" "$out" "3 repo(s)"
out=$(bash "$GP" status --no-fetch nope 2>&1); has "groups/unknown name is a path" "$out" "ERROR"
rm "$GIT_PARITY_CONFIG_DIR/repos"

# gh stub: prints a PR only for the branch/state named in GH_STUB ("branch:state=text")
mkdir -p "$T/bin"
cat > "$T/bin/gh" <<'STUB'
#!/usr/bin/env bash
head=""; state=""
while [ "$#" -gt 0 ]; do
  case $1 in --head) head=$2; shift ;; --state) state=$2; shift ;; --author) head=mine; shift ;; --search) head=reviews; shift ;; esac
  shift
done
printf '%s\n' "${GH_STUB:-}" | tr ';' '\n' | while IFS='=' read -r key text; do
  [ "$key" = "$head:$state" ] && echo "$text"
done
exit 0
STUB
chmod +x "$T/bin/gh"

# 20. feature across repositories, with a stacked branch and PR lookup
F1=$(new f-api); g "$F1" checkout -q -b feat/pay-core; commit "$F1" a; g "$F1" push -q -u origin feat/pay-core
g "$F1" checkout -q -b feat/pay-ui; commit "$F1" b; commit "$F1" c
F2=$(new f-web); g "$F2" checkout -q -b feat/pay-page; commit "$F2" a; g "$F2" push -q -u origin feat/pay-page; commit "$F2" more
F3=$(new f-docs)
before=$(snapshot "$F1")
out=$(PATH="$T/bin:$PATH" GIT_PARITY_FORGE=github GH_STUB="feat/pay-core:all=#7 OPEN" bash "$GP" feature pay "$F1" "$F2" "$F3")
has "feature/header" "$out" "3 repo(s) · 3 branch(es)"
has "feature/pushed with PR" "$out" "| f-api | feat/pay-core | +1 | pushed | #7 OPEN |"
has "feature/stacked" "$out" "| f-api | feat/pay-ui | +3 | never pushed | - | stacked on feat/pay-core: merge that one first |"
has "feature/unpushed" "$out" "| f-web | feat/pay-page | +2 | 1 unpushed | none |"
has "feature/missing" "$out" "No matching branch in: f-docs"
has "feature/next" "$out" "publish feat/pay-ui: git -C"
eq  "feature/merge order" "$(printf '%s\n' "$out" | grep '^| f-api' | head -1 | cut -d'|' -f3 | tr -d ' ')" "feat/pay-core"
eq  "feature/read-only" "$(snapshot "$F1")" "$before"
out=$(bash "$GP" feature 'feat/pay-u*' --no-fetch "$F1"); has "feature/glob" "$out" "1 branch(es)"
out=$(bash "$GP" feature 2>&1); eq "feature/no pattern still exits 0" "$?" "0"
has "feature/no pattern asks for one" "$out" "a branch name or pattern is needed"

# 21. cleanup lists, never deletes
C1=$(new c-one)
g "$C1" checkout -q -b done-ff; commit "$C1" a; g "$C1" push -q -u origin done-ff
g "$C1" checkout -q main; g "$C1" merge -q --ff-only done-ff; g "$C1" push -q origin main
g "$C1" checkout -q -b squashed; commit "$C1" s; g "$C1" push -q -u origin squashed
g "$C1" checkout -q -b mystery; commit "$C1" m; g "$C1" push -q -u origin mystery
g "$C1" checkout -q -b wip; commit "$C1" w
g "$C1" checkout -q main
g "$T/c-one.git" branch -D squashed mystery >/dev/null
before=$(snapshot "$C1")
out=$(PATH="$T/bin:$PATH" GIT_PARITY_FORGE=github GH_STUB="squashed:merged=#12 MERGED" bash "$GP" cleanup "$C1")
has   "cleanup/merged" "$out" "- c-one (1): git -C"
has   "cleanup/merged cmd" "$out" "branch -D done-ff"
has   "cleanup/squashed evidence" "$out" "squashed (PR #12 MERGED)"
has   "cleanup/unverified" "$out" "- c-one (1): mystery"
hasnt "cleanup/unverified has no command" "$out" "branch -D mystery"
hasnt "cleanup/keeps unmerged work" "$out" "wip"
has   "cleanup/says so" "$out" "nothing was deleted"
eq    "cleanup/read-only" "$(snapshot "$C1")" "$before"
out=$(bash "$GP" cleanup "$(new c-empty)"); has "cleanup/nothing" "$out" "Nothing to clean."

# 22. fork: base follows the "upstream" remote
git init -q --bare -b main "$T/up.git"; git clone -q "$T/up.git" "$T/up-w" 2>/dev/null
g "$T/up-w" checkout -q -b main 2>/dev/null; commit "$T/up-w" init; g "$T/up-w" push -q -u origin main
git clone -q --bare "$T/up.git" "$T/fork.git"; git clone -q "$T/fork.git" "$T/fork"
K="$T/fork"; g "$K" remote add upstream "$T/up.git"; g "$K" remote set-head origin main
commit "$T/up-w" u1; commit "$T/up-w" u2; g "$T/up-w" push -q origin main
old=$(sha "$K" main)
out=$(bash "$GP" status "$K")
has "fork/status" "$out" "| fork | main | FORK-BEHIND 2 |"
eq  "fork/status read-only" "$(sha "$K" main)" "$old"
out=$(bash "$GP" remote "$K")
has "fork/remote" "$out" "main updated +2 from upstream"
eq  "fork/remote sha" "$(sha "$K" main)" "$(sha "$K" upstream/main)"
has "fork/next" "$out" "push origin main"

# --- 1.2.0: prs, whats-new, GitLab, session hook ------------------------------

US=$(printf '\037')

# glab stub, same idea as the gh stub: GLAB_STUB="key=text;key=text"
cat > "$T/bin/glab" <<'STUB'
#!/usr/bin/env bash
key=""; state=all
for a in "$@"; do
  case $a in --author=@me) key=mine ;; --reviewer=@me) key=reviews ;; --merged) state=merged ;; esac
done
while [ "$#" -gt 0 ]; do
  case $1 in --source-branch) key=$2; shift ;; esac
  shift
done
printf '%s\n' "${GLAB_STUB:-}" | tr ';' '\n' | while IFS='=' read -r k text; do
  [ "$k" = "$key:$state" ] && echo "$text"
done
exit 0
STUB
chmod +x "$T/bin/glab"

# 23. prs: table, ordering by urgency, review queue, next steps
P1=$(new p-api); P2=$(new p-web)
mine="3${US}#11${US}feat/a${US}passing${US}review pending${US}ok${US}Add A"
bad="0${US}#12${US}feat/b${US}failing${US}changes requested${US}conflict${US}Fix B"
ready="1${US}#13${US}feat/c${US}passing${US}approved${US}ok${US}Ship C"
rev="#20${US}ana${US}Please review"
out=$(PATH="$T/bin:$PATH" GIT_PARITY_FORGE=github GH_STUB="mine:open=$mine;mine:open=$bad;mine:open=$ready;reviews:open=$rev" bash "$GP" prs "$P1")
has "prs/header" "$out" "3 open · 1 need action · 1 waiting for your review"
has "prs/row" "$out" "| p-api | #11 | feat/a | passing | review pending | ok | Add A |"
eq  "prs/urgent first" "$(printf '%s\n' "$out" | grep '^| p-api' | head -1 | cut -d'|' -f3 | tr -d ' ')" "#12"
has "prs/review queue" "$out" "- p-api · #20 · ana · Please review"
has "prs/next action" "$out" "#12 (feat/b): checks failing, conflicts with the base, changes requested"
has "prs/next ready" "$out" "#13 (feat/c): approved, ready to merge"
out=$(PATH="$T/bin:$PATH" GIT_PARITY_FORGE=github GH_STUB="" bash "$GP" prs "$P1" "$P2")
has "prs/empty" "$out" "No open pull requests"
out=$(bash "$GP" prs "$P1"); has "prs/unknown host skipped" "$out" "p-api: not a GitHub or GitLab remote"
if command -v jq >/dev/null 2>&1; then
  fixture='[{"number":5,"title":"T","headRefName":"f","isDraft":false,"reviewDecision":"APPROVED","mergeable":"MERGEABLE","statusCheckRollup":[{"conclusion":"SUCCESS"}]},{"number":6,"title":"U","headRefName":"g","isDraft":false,"reviewDecision":"","mergeable":"CONFLICTING","statusCheckRollup":[{"conclusion":"FAILURE"}]},{"number":7,"title":"V","headRefName":"h","isDraft":true,"reviewDecision":null,"mergeable":"UNKNOWN","statusCheckRollup":[{"status":"IN_PROGRESS","conclusion":null}]},{"number":8,"title":"W","headRefName":"i","isDraft":false,"reviewDecision":"REVIEW_REQUIRED","mergeable":"MERGEABLE","statusCheckRollup":[]}]'
  got=$(printf '%s' "$fixture" | jq -r "$(bash "$GP" --print-prs-jq)" | tr '\037' '|')
  has "prs/jq approved" "$got" "1|#5|f|passing|approved|ok|T"
  has "prs/jq failing" "$got" "0|#6|g|failing|no review|conflict|U"
  has "prs/jq running draft" "$got" "2|#7|h|running|draft|?|V"
  has "prs/jq no checks" "$got" "3|#8|i|none|review pending|ok|W"
fi

# 24. GitLab: merge requests through glab
out=$(PATH="$T/bin:$PATH" GIT_PARITY_FORGE=gitlab GLAB_STUB="mine:all=3${US}!4${US}feat/a${US}-${US}-${US}ok${US}MR A;reviews:all=!9${US}bob${US}Look" bash "$GP" prs "$P1")
has "gitlab/prs" "$out" "| p-api | !4 | feat/a | - | - | ok | MR A |"
has "gitlab/reviews" "$out" "- p-api · !9 · bob · Look"
L1=$(new l-api); g "$L1" checkout -q -b feat/x; commit "$L1" a; g "$L1" push -q -u origin feat/x
out=$(PATH="$T/bin:$PATH" GIT_PARITY_FORGE=gitlab GLAB_STUB="feat/x:all=!7 opened" bash "$GP" feature x "$L1")
has "gitlab/feature" "$out" "| l-api | feat/x | +1 | pushed | !7 opened |"
out=$(GIT_PARITY_FORGE=gitlab PATH="$(dirname "$(command -v git)"):/usr/bin:/bin" bash "$GP" prs "$P1")
has "gitlab/no glab" "$out" "glab is not installed"

# 25. whats-new: incoming commits, then the last update, with overlap on my branch
W1=$(new w-api); commit "$W1" base shared.txt; g "$W1" push -q origin main
g "$W1" checkout -q -b feat/mine; commit "$W1" mine shared.txt
remote_commit w-api main 2 shared.txt
before=$(snapshot "$W1")
out=$(bash "$GP" whats-new "$W1")
has "news/incoming" "$out" "w-api · main · 2 new commit(s) · incoming, not pulled yet"
has "news/commit line" "$out" "remote 1 (t,"
has "news/overlap" "$out" "Also changed on your branch feat/mine (possible conflicts): shared.txt"
eq  "news/read-only" "$(snapshot "$W1")" "$before"
bash "$GP" remote "$W1" >/dev/null
out=$(bash "$GP" whats-new --no-fetch "$W1")
has "news/after sync" "$out" "2 new commit(s) · since the last update"
has "news/areas" "$out" "Areas: . (1)"
out=$(bash "$GP" whats-new --no-fetch "$(new w-quiet)")
has "news/quiet" "$out" "Nothing new in: w-quiet"

# 26. session hook: silent unless opted in, one line when something needs attention
H1=$(new h-ok); H2=$(new h-dirty); echo x >> "$H2/file.txt"
printf '%s\n%s\n' "$H1" "$H2" > "$GIT_PARITY_CONFIG_DIR/repos"
eq  "hook/off by default" "$(bash "$GP" hook)" ""
echo "session_hook=on" > "$GIT_PARITY_CONFIG_DIR/config"
has "hook/on" "$(bash "$GP" hook)" "git-parity: 1 of 2 repositories need attention."
before=$(snapshot "$H2"); bash "$GP" hook >/dev/null; eq "hook/read-only" "$(snapshot "$H2")" "$before"
printf '%s\n' "$H1" > "$GIT_PARITY_CONFIG_DIR/repos"
eq  "hook/silent when clean" "$(bash "$GP" hook)" ""
rm "$GIT_PARITY_CONFIG_DIR/repos" "$GIT_PARITY_CONFIG_DIR/config"

# 27. arguments from agents that pass one quoted string, or an empty one
Q1=$(new q-a); Q2=$(new q-b)
out=$(bash "$GP" status "");                    has "args/empty string ignored" "$out" "repo(s)"
hasnt "args/empty string is not a path" "$out" "ERROR"
out=$(bash "$GP" status "$Q1 $Q2 --no-fetch");  has "args/one string split" "$out" "2 repo(s)"
has "args/flag inside the string" "$out" "no fetch"
g "$Q1" checkout -q -b feat/zed; commit "$Q1" z
out=$(bash "$GP" feature "zed $Q1 --no-fetch"); has "args/feature pattern from one string" "$out" "| q-a | feat/zed |"
out=$(bash "$GP" feature "");                   has "args/feature empty string" "$out" "a branch name or pattern is needed"
out=$(bash "$GP" status --no-fetch "$T/with space/sp"); has "args/real path with spaces kept" "$out" "| sp | main |"

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
