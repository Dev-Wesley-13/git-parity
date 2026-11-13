#!/usr/bin/env bash
# git-parity: report (and safely fast-forward) the state of many git repositories.
#
# Usage: git-parity.sh <status|remote|local|full|cleanup|prs|whats-new> [--no-fetch] [repo-path|group ...]
#        git-parity.sh feature <branch-pattern> [--no-fetch] [repo-path|group ...]
#        git-parity.sh hook
#
#   status   read-only report (only runs `git fetch`)
#   remote   status + fast-forward local branches that are strictly behind
#   local    status, with push candidates listed under "Push candidates"
#   full     remote + local
#   feature  where the branches of one feature stand in every repository
#   cleanup  list branches and worktrees that are safe to delete (deletes nothing)
#   prs      my open pull/merge requests and the ones waiting for my review
#   whats-new  commits that came into the base branch, and what they touch on my branch
#   hook     one line for a session-start hook; silent unless session_hook=on in the config file
#
# Never pushes, forces, resets, stashes, commits, deletes or checks out anything.
# Bash 3.2 compatible (macOS): no associative arrays, no mapfile.

set -u
export GIT_TERMINAL_PROMPT=0
export LC_ALL=C

CONFIG_DIR="${GIT_PARITY_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/git-parity}"
FETCH_TIMEOUT="${GIT_PARITY_FETCH_TIMEOUT:-30}"
JOBS="${GIT_PARITY_JOBS:-8}"
MAX_BRANCH_LINES=8
MAX_NEWS=12
SEP=$'\037'   # unit separator: never appears in branch names or paths

die() { echo "git-parity: $*" >&2; exit 2; }

qpath() { # shell-quoted path, with $HOME shown as ~ so commands stay short
  local q; q=$(printf '%q' "$1")
  case $q in "$HOME"/*) q="~${q#"$HOME"}" ;; esac
  printf '%s' "$q"
}

# --- worker: one repo -> record lines on stdout ------------------------------
# Record format (fields separated by \037):
#   R <rank> <name> <branch> <state> <detail>
#   N <name> <next step text>
#   P <name> <path> <branch> <ahead> <upstream|->       (push candidate)
#   C <name>                                             (clean repo)
#   U <name> <count> <newest names>                      (remote branches not merged into base, no local copy)

run_fetch() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$FETCH_TIMEOUT" git -C "$1" fetch --prune --quiet ${2:+"$2"} 2>/dev/null
  else
    git -C "$1" fetch --prune --quiet ${2:+"$2"} 2>/dev/null
  fi
}

detect_base() { # prints short base branch name, or nothing
  local repo=$1 ref
  ref=$(git -C "$repo" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  if [ -n "$ref" ]; then echo "${ref#origin/}"; return; fi
  for ref in main master; do
    if git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$ref"; then echo "$ref"; return; fi
  done
}

foreign_upstream() { # branch upstream base -> 0 if the branch tracks the base, not its own remote branch
  [ -n "$2" ] && [ -n "$3" ] && [ "$1" != "$3" ] && [ "$2" = "origin/$3" ]
}

unpushed_count() { # repo ref base -> commits on ref that exist on no remote branch
  git -C "$1" rev-list --count "$2" --not --remotes 2>/dev/null || echo 0
}

never_push() { # branch base -> 0 if this branch must never be offered for push
  [ "$1" = "$2" ] && return 0
  [ -f "$CONFIG_DIR/never-push" ] && grep -qxF -- "$1" "$CONFIG_DIR/never-push" && return 0
  return 1
}

worker() {
  local mode=$1 do_fetch=$2 repo=$3
  local do_ff=0 want_push=0
  case $mode in remote|full) do_ff=1 ;; esac
  case $mode in local|full) want_push=1 ;; esac

  local name; name=$(basename "$repo")
  local q; q=$(qpath "$repo")
  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    printf 'R%s1%s%s%s-%sERROR%snot a git repository: %s\n' "$SEP" "$SEP" "$name" "$SEP" "$SEP" "$SEP" "$repo"
    return
  fi

  local stale=""
  if [ "$do_fetch" = 1 ] && [ -n "$(git -C "$repo" remote)" ]; then
    run_fetch "$repo" || stale=1
    if git -C "$repo" remote | grep -qx upstream; then run_fetch "$repo" upstream || stale=1; fi
  fi

  local gitdir; gitdir=$(git -C "$repo" rev-parse --absolute-git-dir)
  local branch; branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null)
  local base; base=$(detect_base "$repo")
  local dirty; dirty=$(git -C "$repo" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  local inprog=""
  if [ -d "$gitdir/rebase-merge" ] || [ -d "$gitdir/rebase-apply" ]; then inprog="rebase"
  elif [ -f "$gitdir/MERGE_HEAD" ]; then inprog="merge"
  elif [ -f "$gitdir/CHERRY_PICK_HEAD" ]; then inprog="cherry-pick"
  fi

  local notes="" updated=""
  local n_ahead=0 n_div=0 n_gone=0 n_behind=0

  # --- every local branch with an upstream --------------------------------
  local b up upref track ahead behind
  while IFS="$SEP" read -r b up upref track; do
    [ -n "$b" ] || continue
    [ "$b" = "$branch" ] && continue             # current branch handled below
    foreign_upstream "$b" "$up" "$base" && up=""
    if [ -z "$up" ]; then
      ahead=$(unpushed_count "$repo" "refs/heads/$b" "$base")
      if [ "$ahead" != 0 ]; then
        n_ahead=$((n_ahead + 1))
        notes="$notes; $b never pushed ($ahead commit(s))"
        if [ "$want_push" = 1 ] && ! never_push "$b" "$base"; then
          printf 'P%s%s%s%s%s%s%s%s%s-\n' "$SEP" "$name" "$SEP" "$repo" "$SEP" "$b" "$SEP" "$ahead" "$SEP"
        fi
      fi
      continue
    fi
    if [ "$track" = "[gone]" ]; then n_gone=$((n_gone + 1)); continue; fi
    ahead=$(git -C "$repo" rev-list --count "$up..refs/heads/$b" 2>/dev/null || echo 0)
    behind=$(git -C "$repo" rev-list --count "refs/heads/$b..$up" 2>/dev/null || echo 0)

    if [ "$behind" -gt 0 ] && [ "$ahead" -eq 0 ]; then
      if [ "$do_ff" = 1 ] && git -C "$repo" fetch --quiet . "$upref:refs/heads/$b" 2>/dev/null; then
        updated="$updated; $b updated +$behind"
      else
        n_behind=$((n_behind + 1))
        notes="$notes; $b behind $behind"
      fi
    elif [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
      n_div=$((n_div + 1))
      notes="$notes; $b diverged (+$ahead/-$behind)"
    elif [ "$ahead" -gt 0 ]; then
      n_ahead=$((n_ahead + 1))
      notes="$notes; $b ahead $ahead (not pushed)"
      if [ "$want_push" = 1 ] && ! never_push "$b" "$base"; then
        printf 'P%s%s%s%s%s%s%s%s%s%s\n' "$SEP" "$name" "$SEP" "$repo" "$SEP" "$b" "$SEP" "$ahead" "$SEP" "$up"
      fi
    fi
  done <<EOF
$(git -C "$repo" for-each-ref --format="%(refname:short)$SEP%(upstream:short)$SEP%(upstream)$SEP%(upstream:track)" refs/heads 2>/dev/null)
EOF

  # --- current branch -------------------------------------------------------
  local state rank detail="" next=""
  local cur_up="" cur_ahead=0 cur_behind=0 cur_gone="" tracks_base="" base_behind=0 unpushed=0
  if [ -n "$branch" ]; then
    cur_up=$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name "$branch@{upstream}" 2>/dev/null)
    if foreign_upstream "$branch" "$cur_up" "$base"; then tracks_base=$cur_up; cur_up=""; fi
    if [ -n "$base" ] && [ "$branch" != "$base" ]; then
      base_behind=$(git -C "$repo" rev-list --count "HEAD..refs/remotes/origin/$base" 2>/dev/null || echo 0)
    fi
    if [ -n "$cur_up" ]; then
      if git -C "$repo" rev-parse --verify --quiet "$cur_up" >/dev/null; then
        cur_ahead=$(git -C "$repo" rev-list --count "$cur_up..HEAD")
        cur_behind=$(git -C "$repo" rev-list --count "HEAD..$cur_up")
      else
        cur_gone=1
      fi
    fi
  fi

  # fast-forward the current branch when it is safe
  if [ "$do_ff" = 1 ] && [ -n "$branch" ] && [ -z "$inprog" ] && [ "$dirty" = 0 ] \
     && [ "$cur_behind" -gt 0 ] && [ "$cur_ahead" -eq 0 ]; then
    if git -C "$repo" merge --ff-only --quiet "$cur_up" >/dev/null 2>&1; then
      updated="; $branch updated +$cur_behind$updated"
      cur_behind=0
    fi
  fi

  if [ -n "$inprog" ]; then
    state="IN-PROGRESS"; rank=2; detail="$inprog in progress; skipped"
    next="finish or abort the $inprog: git -C $q status"
  elif [ -z "$branch" ]; then
    state="DETACHED"; rank=6; detail="HEAD detached at $(git -C "$repo" rev-parse --short HEAD 2>/dev/null); skipped"
    next="check out a branch: git -C $q switch ${base:-<branch>}"
  elif [ "$cur_ahead" -gt 0 ] && [ "$cur_behind" -gt 0 ]; then
    state="DIVERGED"; rank=0; detail="$cur_ahead local / $cur_behind remote commits differ; not touched"
    next="diverged from $cur_up; inspect both sides: git -C $q log --oneline --left-right $branch...$cur_up"
  elif [ "$dirty" -gt 0 ]; then
    state="DIRTY $dirty"; rank=4; detail="uncommitted changes"
    [ "$cur_behind" -gt 0 ] && detail="$detail; behind $cur_behind, not pulled"
    [ "$cur_ahead" -gt 0 ] && detail="$detail; ahead $cur_ahead"
    next="commit or stash $dirty file(s): git -C $q status --short"
  elif [ -n "$cur_gone" ]; then
    state="GONE"; rank=7; detail="remote branch deleted (likely merged)"
    next="branch $branch looks finished; switch back: git -C $q switch ${base:-<branch>}"
  elif [ -z "$cur_up" ]; then
    unpushed=$(unpushed_count "$repo" HEAD "$base")
    state="NO-UPSTREAM"; rank=7; detail="never pushed, $unpushed commit(s)"
    [ -n "$tracks_base" ] && detail="$detail; tracks $tracks_base instead of its own remote branch"
    if [ "$unpushed" = 0 ]; then
      state="CLEAN"; rank=9; detail="new branch, no commits yet"
    elif ! never_push "$branch" "$base"; then
      next="publish the branch: git -C $q push -u origin $branch"
      [ "$want_push" = 1 ] && printf 'P%s%s%s%s%s%s%s%s%s-\n' "$SEP" "$name" "$SEP" "$repo" "$SEP" "$branch" "$SEP" "$unpushed" "$SEP"
    fi
  elif [ "$cur_ahead" -gt 0 ]; then
    state="AHEAD $cur_ahead"; rank=5; detail="not pushed"
    if never_push "$branch" "$base"; then
      detail="not pushed (protected: open a PR from a feature branch)"
    else
      next="push $cur_ahead commit(s): git -C $q push"
      [ "$want_push" = 1 ] && printf 'P%s%s%s%s%s%s%s%s%s%s\n' "$SEP" "$name" "$SEP" "$repo" "$SEP" "$branch" "$SEP" "$cur_ahead" "$SEP" "$cur_up"
    fi
  elif [ "$cur_behind" -gt 0 ]; then
    state="BEHIND $cur_behind"; rank=6; detail="can fast-forward"
    next="fast-forward: /git-parity:remote  (or: git -C $q merge --ff-only $cur_up)"
  else
    state="CLEAN"; rank=9
  fi

  [ "$base_behind" -gt 0 ] && detail="$detail; $base_behind behind $base"
  [ "$n_gone" -gt 0 ] && notes="$notes; $n_gone branch(es) with remote gone (likely merged)"
  if [ -n "$stale" ]; then
    notes="; fetch failed, data may be stale$notes"
    [ "$rank" -gt 3 ] && rank=3
    [ "$state" = "CLEAN" ] && state="STALE"
    [ -z "$next" ] && next="fetch failed; check network/credentials: git -C $q fetch"
  fi
  if [ -z "$base" ] && [ -n "$(git -C "$repo" remote)" ]; then
    notes="$notes; base branch unknown (run: git -C $q remote set-head origin -a)"
  fi

  # other branches needing attention keep a clean repo out of the "Clean" line
  if [ "$state" = "CLEAN" ] && [ $((n_ahead + n_div + n_behind)) -gt 0 ]; then
    state="BRANCHES"; rank=8
  fi

  # fork: compare the base with the repository it was forked from (remote "upstream")
  if [ -n "$base" ] && git -C "$repo" show-ref --verify --quiet "refs/remotes/upstream/$base"; then
    local fork_behind local_behind up_ref="refs/remotes/upstream/$base"
    local_behind=$(git -C "$repo" rev-list --count "refs/heads/$base..$up_ref" 2>/dev/null || echo 0)
    if [ "$do_ff" = 1 ] && [ "$local_behind" -gt 0 ] \
       && [ "$(git -C "$repo" rev-list --count "$up_ref..refs/heads/$base" 2>/dev/null)" = 0 ]; then
      if [ "$base" = "$branch" ]; then
        if [ "$dirty" = 0 ] && [ -z "$inprog" ] && git -C "$repo" merge --ff-only --quiet "$up_ref" >/dev/null 2>&1; then
          updated="$updated; $base updated +$local_behind from upstream"
        fi
      elif git -C "$repo" fetch --quiet . "$up_ref:refs/heads/$base" 2>/dev/null; then
        updated="$updated; $base updated +$local_behind from upstream"
      fi
    fi
    fork_behind=$(git -C "$repo" rev-list --count "refs/remotes/origin/$base..$up_ref" 2>/dev/null || echo 0)
    if [ "$fork_behind" -gt 0 ]; then
      notes="$notes; fork: origin/$base is $fork_behind behind upstream/$base"
      if [ "$state" = "CLEAN" ]; then state="FORK-BEHIND $fork_behind"; rank=6; fi
      [ -z "$next" ] && next="sync your fork: run /git-parity:remote, then git -C $q push origin $base"
    fi
  fi

  # remote branches not merged into the base that have no local branch (someone else's work, or yours from another machine)
  if [ -n "$base" ]; then
    local remote_only count
    remote_only=$(git -C "$repo" for-each-ref --no-merged="refs/remotes/origin/$base" --sort=-committerdate \
        --format='%(refname:lstrip=3)' refs/remotes/origin 2>/dev/null | grep -vx HEAD | while IFS= read -r b; do
      git -C "$repo" show-ref --verify --quiet "refs/heads/$b" || printf '%s\n' "$b"
    done)
    if [ -n "$remote_only" ]; then
      count=$(printf '%s\n' "$remote_only" | grep -c .)
      printf 'U%s%s%s%s%s%s\n' "$SEP" "$name" "$SEP" "$count" "$SEP" "$(printf '%s\n' "$remote_only" | head -3 | tr '\n' ',' | sed 's/,$//; s/,/, /g')"
    fi
  fi

  detail="$detail$updated$notes"
  detail="${detail#; }"

  if [ "$state" = "CLEAN" ]; then
    if [ -n "$detail" ]; then
      printf 'R%s%s%s%s%s%s%sOK%s%s\n' "$SEP" "$rank" "$SEP" "$name" "$SEP" "${branch:-}" "$SEP" "$SEP" "$detail"
    else
      printf 'C%s%s\n' "$SEP" "$name"
    fi
  else
    printf 'R%s%s%s%s%s%s%s%s%s%s\n' "$SEP" "$rank" "$SEP" "$name" "$SEP" "${branch:--}" "$SEP" "$state" "$SEP" "$detail"
  fi
  [ -n "$next" ] && printf 'N%s%s%s%s\n' "$SEP" "$name" "$SEP" "$next"
  return 0
}

# --- repo discovery -----------------------------------------------------------
repos_file() { # [group] -> paths from the repos file; no group = every path
  local want=${1:-} section="" line
  [ -f "$CONFIG_DIR/repos" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line=$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -n "$line" ] || continue
    case $line in "["*"]") section=${line#[}; section=${section%]}; continue ;; esac
    if [ -n "$want" ] && [ "$section" != "$want" ]; then continue; fi
    case $line in "~"*) line="$HOME${line#\~}" ;; esac
    printf '%s\n' "$line"
  done < "$CONFIG_DIR/repos"
}

discover() { # each argument is a path, or the name of a [group] in the repos file
  local a
  if [ "$#" -gt 0 ]; then
    for a in "$@"; do
      if [ ! -d "$a" ] && [ -n "$(repos_file "$a")" ]; then repos_file "$a"; else printf '%s\n' "$a"; fi
    done
    return
  fi
  if [ -n "$(repos_file)" ]; then repos_file; return; fi
  local top; top=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$top" ]; then printf '%s\n' "$top"; return; fi
  find . -mindepth 2 -maxdepth 3 -name .git -prune 2>/dev/null | sed 's|/\.git$||; s|^\./||' | sort
}

# --- report -------------------------------------------------------------------
render() {
  local mode=$1 tmp=$2 total=$3 secs=$4
  local attention; attention=$(grep -c "^R${SEP}[0-8]${SEP}" "$tmp")
  local fetched="fetched in ${secs}s"; [ "$DO_FETCH" = 1 ] || fetched="no fetch"
  echo "git-parity $mode · $total repo(s) · $attention need attention · $fetched"
  echo
  if grep -q "^R$SEP" "$tmp"; then
    echo "| Repo | Branch | State | Detail |"
    echo "|---|---|---|---|"
    grep "^R$SEP" "$tmp" | sort -t "$SEP" -k2,2n -k3,3 | while IFS="$SEP" read -r _ _ name branch state detail; do
      echo "| $name | $branch | $state | $(clip_detail "$detail") |"
    done
    echo
  fi
  local clean; clean=$(grep "^C$SEP" "$tmp" | cut -d "$SEP" -f2 | sort | tr '\n' ',' | sed 's/,$//; s/,/, /g')
  if [ -n "$clean" ]; then
    echo "Clean ($(grep -c "^C$SEP" "$tmp")): $clean"
    echo
  fi
  if grep -q "^P$SEP" "$tmp"; then
    echo "Push candidates (ask before each push)"
    grep "^P$SEP" "$tmp" | sort -t "$SEP" -k2,2 -k4,4 | while IFS="$SEP" read -r _ name path branch ahead up; do
      if [ "$up" = "-" ]; then echo "- $name · $branch · never pushed, $ahead commit(s) · git -C $(qpath "$path") push -u origin $branch"
      else echo "- $name · $branch · $ahead commit(s) ahead of $up · git -C $(qpath "$path") push origin $branch"
      fi
    done
    echo
  fi
  if grep -q "^U$SEP" "$tmp"; then
    echo "Remote branches not merged into base (no local copy)"
    grep "^U$SEP" "$tmp" | sort -t "$SEP" -k2,2 | while IFS="$SEP" read -r _ name count names; do
      if [ "$count" -gt 3 ]; then echo "- $name: $count, newest: $names"; else echo "- $name: $names"; fi
    done
    echo
  fi
  if grep -q "^N$SEP" "$tmp"; then
    echo "Next steps"
    # order next steps like the table: join on repo rank
    grep "^R$SEP" "$tmp" | sort -t "$SEP" -k2,2n -k3,3 | cut -d "$SEP" -f3 | while IFS= read -r name; do
      grep "^N$SEP$name$SEP" "$tmp" | while IFS="$SEP" read -r _ n text; do
        echo "- $n: $text"
      done
    done
  else
    echo "Nothing to do."
  fi
}

clip_detail() { # keep at most MAX_BRANCH_LINES "; " separated items
  printf '%s' "$1" | awk -v max="$MAX_BRANCH_LINES" 'BEGIN{RS="; "; ORS=""} {n++; if (n<=max) printf "%s%s", (n>1?"; ":""), $0} END{if (n>max) printf "; +%d more", n-max}' | tr -d '\n'
}

# --- feature: where do the branches of one feature stand ---------------------------
# Records: F <name> <order> <branch> <vs base> <remote> <pr> <note> | X <name> | N <name> <text>

forge() { # repo -> github | gitlab | other, from the origin URL (GIT_PARITY_FORGE overrides, e.g. for self-hosted servers)
  if [ -n "${GIT_PARITY_FORGE:-}" ]; then echo "$GIT_PARITY_FORGE"; return; fi
  case $(git -C "$1" remote get-url origin 2>/dev/null) in
    *github.com*) echo github ;;
    *gitlab*) echo gitlab ;;
    *) echo other ;;
  esac
}

pr_lookup() { # repo branch <all|merged> -> "#12 OPEN" / "!12 merged" (empty when the CLI is missing or nothing is found)
  case $(forge "$1") in
    github)
      command -v gh >/dev/null 2>&1 || return 0
      (cd "$1" && gh pr list --head "$2" --state "$3" --limit 1 --json number,state,isDraft \
         -q '.[0] | select(.) | "#\(.number) \(if .isDraft then "DRAFT" else .state end)"' 2>/dev/null) ;;
    gitlab)
      command -v glab >/dev/null 2>&1 || return 0
      local flag=--all; [ "$3" = merged ] && flag=--merged
      (cd "$1" && glab mr list --source-branch "$2" "$flag" -F json \
         --jq '.[0] | select(.) | "!\(.iid) \(.state)"' 2>/dev/null) ;;
  esac
}

branch_ref() { # repo branch -> local ref if it exists, else the remote-tracking ref
  if git -C "$1" show-ref --verify --quiet "refs/heads/$2"; then echo "refs/heads/$2"; else echo "refs/remotes/origin/$2"; fi
}

feature_worker() {
  local pattern=$1 do_fetch=$2 repo=$3
  local name q base b; name=$(basename "$repo"); q=$(qpath "$repo")
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { printf 'X%s%s\n' "$SEP" "$name"; return 0; }
  [ "$do_fetch" = 1 ] && [ -n "$(git -C "$repo" remote)" ] && run_fetch "$repo"
  base=$(detect_base "$repo")
  case $pattern in *[*?[]*) ;; *) pattern="*$pattern*" ;; esac

  local matched=""
  while IFS= read -r b; do
    [ -n "$b" ] && [ "$b" != "$base" ] && [ "$b" != HEAD ] || continue
    # shellcheck disable=SC2254
    case $b in $pattern) matched="$matched$b"$'\n' ;; esac
  done < <( { git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads
              git -C "$repo" for-each-ref --format='%(refname:lstrip=3)' refs/remotes/origin; } 2>/dev/null | sort -u)
  [ -n "$matched" ] || { printf 'X%s%s\n' "$SEP" "$name"; return 0; }

  local ref has_local has_remote ahead behind vs remote pr note other parent parent_ahead oa n
  while IFS= read -r b; do
    [ -n "$b" ] || continue
    has_local=""; has_remote=""
    git -C "$repo" show-ref --verify --quiet "refs/heads/$b" && has_local=1
    git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$b" && has_remote=1
    ref=$(branch_ref "$repo" "$b")
    ahead=0; behind=0
    if [ -n "$base" ]; then
      ahead=$(git -C "$repo" rev-list --count "refs/remotes/origin/$base..$ref" 2>/dev/null || echo 0)
      behind=$(git -C "$repo" rev-list --count "$ref..refs/remotes/origin/$base" 2>/dev/null || echo 0)
    fi
    if [ "$ahead" = 0 ]; then vs="merged"; else vs="+$ahead"; [ "$behind" -gt 0 ] && vs="$vs / -$behind"; fi

    if [ -n "$has_local" ] && [ -n "$has_remote" ]; then
      n=$(git -C "$repo" rev-list --count "refs/remotes/origin/$b..refs/heads/$b")
      if [ "$n" -gt 0 ]; then
        remote="$n unpushed"
        printf 'N%s%s%s%s%s%s\n' "$SEP" "$name" "$SEP" "$ahead" "$SEP" "push $b: git -C $q push origin $b"
      elif [ "$(git -C "$repo" rev-list --count "refs/heads/$b..refs/remotes/origin/$b")" -gt 0 ]; then
        remote="behind remote"
      else
        remote="pushed"
      fi
    elif [ -n "$has_local" ]; then
      remote="never pushed"
      [ "$ahead" != 0 ] && printf 'N%s%s%s%s%s%s\n' "$SEP" "$name" "$SEP" "$ahead" "$SEP" "publish $b: git -C $q push -u origin $b"
    else
      remote="remote only"
    fi

    pr="-"
    if [ -n "$has_remote" ]; then
      pr=$(pr_lookup "$repo" "$b" all); [ -n "$pr" ] || pr="none"
      if [ "$pr" = "none" ] && [ "$ahead" != 0 ] && [ "$remote" = "pushed" ]; then
        printf 'N%s%s%s%s%s%s\n' "$SEP" "$name" "$SEP" "$ahead" "$SEP" "open a pull/merge request for $b"
      fi
    fi

    # stacked: the closest other matched branch that is an ancestor of this one
    parent=""; parent_ahead=0; note=""
    while IFS= read -r other; do
      [ -n "$other" ] && [ "$other" != "$b" ] || continue
      oa=$(branch_ref "$repo" "$other")
      if git -C "$repo" merge-base --is-ancestor "$oa" "$ref" 2>/dev/null; then
        n=$(git -C "$repo" rev-list --count "refs/remotes/origin/${base:-HEAD}..$oa" 2>/dev/null || echo 0)
        if [ "$n" -gt "$parent_ahead" ] && [ "$n" -lt "$ahead" ]; then parent=$other; parent_ahead=$n; fi
      fi
    done <<<"$matched"
    [ -n "$parent" ] && note="stacked on $parent: merge that one first"
    printf 'F%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n' "$SEP" "$name" "$SEP" "$ahead" "$SEP" "$b" "$SEP" "$vs" "$SEP" "$remote" "$SEP" "$pr" "$SEP" "$note"
  done <<<"$matched"
  return 0
}

render_feature() {
  local pattern=$1 tmp=$2 total=$3
  echo "git-parity feature '$pattern' · $total repo(s) · $(grep -c "^F$SEP" "$tmp") branch(es)"
  echo
  if grep -q "^F$SEP" "$tmp"; then
    echo "| Repo | Branch | vs base | Remote | PR | Note |"
    echo "|---|---|---|---|---|---|"
    grep "^F$SEP" "$tmp" | sort -t "$SEP" -k2,2 -k3,3n | while IFS="$SEP" read -r _ name _ branch vs remote pr note; do
      echo "| $name | $branch | $vs | $remote | $pr | $note |"
    done
    echo
    echo "Rows are in merge order inside each repository. 'vs base' = commits ahead / behind the base branch."
    echo
  fi
  local missing; missing=$(grep "^X$SEP" "$tmp" | cut -d "$SEP" -f2 | sort | tr '\n' ',' | sed 's/,$//; s/,/, /g')
  if [ -n "$missing" ]; then echo "No matching branch in: $missing"; echo; fi
  if grep -q "^N$SEP" "$tmp"; then
    echo "Next steps"
    grep "^N$SEP" "$tmp" | sort -t "$SEP" -k2,2 -k3,3n | while IFS="$SEP" read -r _ n _ text; do echo "- $n: $text"; done
  else
    echo "Nothing to do."
  fi
}

# --- cleanup: what is safe to delete (this script deletes nothing) -----------------
# Records: D <name> <kind> <branch> <evidence> <command>

cleanup_worker() {
  local do_fetch=$1 repo=$2
  local name q base branch b track pr in_worktrees; name=$(basename "$repo"); q=$(qpath "$repo")
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || return 0
  [ "$do_fetch" = 1 ] && [ -n "$(git -C "$repo" remote)" ] && run_fetch "$repo"
  base=$(detect_base "$repo"); [ -n "$base" ] || return 0
  branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null)
  in_worktrees=$(git -C "$repo" worktree list --porcelain 2>/dev/null | sed -n 's|^branch refs/heads/||p')
  while IFS="$SEP" read -r b track; do
    [ -n "$b" ] && [ "$b" != "$base" ] && [ "$b" != "$branch" ] || continue
    printf '%s\n' "$in_worktrees" | grep -qxF -- "$b" && continue
    never_push "$b" "$base" && continue
    if git -C "$repo" merge-base --is-ancestor "refs/heads/$b" "refs/remotes/origin/$base" 2>/dev/null; then
      printf 'D%s%s%smerged%s%s%s%s%s%s\n' "$SEP" "$name" "$SEP" "$SEP" "$b" "$SEP" "fully contained in origin/$base" "$SEP" "git -C $q branch -D $b"
    elif [ "$track" = "[gone]" ]; then
      pr=$(pr_lookup "$repo" "$b" merged)
      if [ -n "$pr" ]; then
        printf 'D%s%s%ssquashed%s%s%s%s%s%s\n' "$SEP" "$name" "$SEP" "$SEP" "$b" "$SEP" "remote branch deleted, PR $pr" "$SEP" "git -C $q branch -D $b"
      else
        printf 'D%s%s%sunverified%s%s%s%s%s-\n' "$SEP" "$name" "$SEP" "$SEP" "$b" "$SEP" "remote branch deleted, no merged PR found" "$SEP"
      fi
    fi
  done < <(git -C "$repo" for-each-ref --format="%(refname:short)$SEP%(upstream:track)" refs/heads 2>/dev/null)
  if [ -n "$(git -C "$repo" worktree prune --dry-run 2>&1)" ]; then
    printf 'D%s%s%sworktree%s-%s%s%s%s\n' "$SEP" "$name" "$SEP" "$SEP" "$SEP" "stale worktree records" "$SEP" "git -C $q worktree prune"
  fi
  return 0
}

render_cleanup() {
  local tmp=$1 total=$2 kind title n
  n=$(grep -c "^D$SEP" "$tmp")
  echo "git-parity cleanup · $total repo(s) · $n item(s) · nothing was deleted"
  echo
  if [ "$n" -eq 0 ]; then echo "Nothing to clean."; return; fi
  for kind in merged squashed worktree unverified; do
    grep -q "^D${SEP}[^${SEP}]*${SEP}${kind}${SEP}" "$tmp" || continue
    case $kind in
      merged) title="Merged into the base (safe to delete)" ;;
      squashed) title="Squash-merged: remote branch deleted and a merged PR exists (safe to delete)" ;;
      worktree) title="Stale worktree records" ;;
      *) title="Remote branch deleted, merge NOT verified (do not delete without checking)" ;;
    esac
    echo "$title"
    # one line per repository: every branch of that kind, and a single command for all of them
    grep "^D${SEP}[^${SEP}]*${SEP}${kind}${SEP}" "$tmp" | sort -t "$SEP" -k2,2 -k4,4 | awk -F "$SEP" -v kind="$kind" '
      function flush() {
        if (name == "") return
        if (kind == "worktree") printf "- %s · %s\n", name, cmd
        else if (kind == "unverified") printf "- %s (%d): %s\n", name, n, list
        else if (kind == "merged") printf "- %s (%d): %s %s\n", name, n, cmd, args
        else printf "- %s (%d): %s\n  %s %s\n", name, n, list, cmd, args
      }
      $2 != name { flush(); name = $2; n = 0; list = ""; args = ""; cmd = $6; sub(/ [^ ]+$/, "", cmd); if (kind == "worktree") cmd = $6 }
      { n++; list = list (n > 1 ? ", " : "") $4 ($5 ~ /PR #/ ? " (" substr($5, index($5, "PR #")) ")" : ""); args = args (n > 1 ? " " : "") $4 }
      END { flush() }'
    echo
  done
  echo "Ask before deleting. Run only the commands the user approves."
}

# --- prs: my open pull requests and the ones waiting for my review -----------------
# Records: M <name> <rank> <id> <branch> <ci> <review> <merge> <title> | V <name> <id> <author> <title>
#          S <name> <reason> | N <name> <rank> <text>

# jq program run by `gh pr list -q`: one line per pull request, fields separated by \037
# shellcheck disable=SC2016
PRS_JQ='.[]
| ([.statusCheckRollup[]? | (.conclusion // .state // .status // "PENDING")]) as $c
| (if ($c | length) == 0 then "none"
   elif ($c | map(select(. == "FAILURE" or . == "ERROR" or . == "TIMED_OUT" or . == "CANCELLED" or . == "ACTION_REQUIRED")) | length) > 0 then "failing"
   elif ($c | map(select(. == "PENDING" or . == "IN_PROGRESS" or . == "QUEUED" or . == "EXPECTED" or . == "WAITING")) | length) > 0 then "running"
   else "passing" end) as $ci
| (if .isDraft then "draft"
   elif .reviewDecision == "APPROVED" then "approved"
   elif .reviewDecision == "CHANGES_REQUESTED" then "changes requested"
   elif .reviewDecision == "REVIEW_REQUIRED" then "review pending"
   else "no review" end) as $rv
| (if .mergeable == "CONFLICTING" then "conflict" elif .mergeable == "MERGEABLE" then "ok" else "?" end) as $mg
| (if $ci == "failing" or $mg == "conflict" or $rv == "changes requested" then 0
   elif $rv == "approved" and $ci != "running" then 1
   elif $ci == "running" then 2
   else 3 end) as $rank
| [$rank, "#\(.number)", .headRefName, $ci, $rv, $mg, .title] | map(tostring) | join("\u001f")'

# shellcheck disable=SC2016
MRS_JQ='.[]
| [(if .has_conflicts then 0 else 3 end), "!\(.iid)", .source_branch, "-",
   (if .draft then "draft" else "-" end), (if .has_conflicts then "conflict" else "ok" end), .title]
| map(tostring) | join("\u001f")'

prs_worker() {
  local repo=$1 name q host rank id branch ci review merge title author why
  name=$(basename "$repo"); q=$(qpath "$repo")
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || return 0
  host=$(forge "$repo")
  case $host in
    github)
      command -v gh >/dev/null 2>&1 || { printf 'S%s%s%sgh is not installed\n' "$SEP" "$name" "$SEP"; return 0; }
      (cd "$repo" && gh pr list --author @me --state open --limit 30 \
          --json number,title,headRefName,isDraft,reviewDecision,mergeable,statusCheckRollup -q "$PRS_JQ" 2>/dev/null) > "$TMPW.mine"
      (cd "$repo" && gh pr list --search "review-requested:@me" --state open --limit 30 \
          --json number,title,author -q '.[] | ["#\(.number)", .author.login, .title] | join("\u001f")' 2>/dev/null) > "$TMPW.rev" ;;
    gitlab)
      command -v glab >/dev/null 2>&1 || { printf 'S%s%s%sglab is not installed\n' "$SEP" "$name" "$SEP"; return 0; }
      (cd "$repo" && glab mr list --author=@me -F json --jq "$MRS_JQ" 2>/dev/null) > "$TMPW.mine"
      (cd "$repo" && glab mr list --reviewer=@me -F json \
          --jq '.[] | ["!\(.iid)", .author.username, .title] | join("\u001f")' 2>/dev/null) > "$TMPW.rev" ;;
    *) printf 'S%s%s%snot a GitHub or GitLab remote\n' "$SEP" "$name" "$SEP"; return 0 ;;
  esac
  while IFS="$SEP" read -r rank id branch ci review merge title; do
    [ -n "$id" ] || continue
    printf 'M%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n' "$SEP" "$name" "$SEP" "$rank" "$SEP" "$id" "$SEP" "$branch" "$SEP" "$ci" "$SEP" "$review" "$SEP" "$merge" "$SEP" "$(printf '%s' "$title" | cut -c1-60)"
    why=""
    [ "$ci" = "failing" ] && why="checks failing"
    [ "$merge" = "conflict" ] && why="${why:+$why, }conflicts with the base"
    [ "$review" = "changes requested" ] && why="${why:+$why, }changes requested"
    if [ -n "$why" ]; then
      printf 'N%s%s%s0%s%s\n' "$SEP" "$name" "$SEP" "$SEP" "$id ($branch): $why"
    elif [ "$rank" = 1 ]; then
      printf 'N%s%s%s1%s%s\n' "$SEP" "$name" "$SEP" "$SEP" "$id ($branch): approved, ready to merge"
    fi
  done < "$TMPW.mine"
  while IFS="$SEP" read -r id author title; do
    [ -n "$id" ] || continue
    printf 'V%s%s%s%s%s%s%s%s\n' "$SEP" "$name" "$SEP" "$id" "$SEP" "$author" "$SEP" "$(printf '%s' "$title" | cut -c1-60)"
  done < "$TMPW.rev"
  rm -f "$TMPW.mine" "$TMPW.rev"
  return 0
}

render_prs() {
  local tmp=$1 total=$2
  echo "git-parity prs · $total repo(s) · $(grep -c "^M$SEP" "$tmp") open · $(grep -c "^M${SEP}[^${SEP}]*${SEP}0${SEP}" "$tmp") need action · $(grep -c "^V$SEP" "$tmp") waiting for your review"
  echo
  if grep -q "^M$SEP" "$tmp"; then
    echo "My open pull requests"
    echo "| Repo | PR | Branch | CI | Review | Merge | Title |"
    echo "|---|---|---|---|---|---|---|"
    grep "^M$SEP" "$tmp" | sort -t "$SEP" -k3,3n -k2,2 | while IFS="$SEP" read -r _ name _ id branch ci review merge title; do
      echo "| $name | $id | $branch | $ci | $review | $merge | $title |"
    done
    echo
  fi
  if grep -q "^V$SEP" "$tmp"; then
    echo "Waiting for my review"
    grep "^V$SEP" "$tmp" | sort -t "$SEP" -k2,2 | while IFS="$SEP" read -r _ name id author title; do
      echo "- $name · $id · $author · $title"
    done
    echo
  fi
  if grep -q "^S$SEP" "$tmp"; then
    echo "Skipped"
    grep "^S$SEP" "$tmp" | sort -t "$SEP" -k2,2 | while IFS="$SEP" read -r _ name reason; do echo "- $name: $reason"; done
    echo
  fi
  if grep -q "^N$SEP" "$tmp"; then
    echo "Next steps"
    grep "^N$SEP" "$tmp" | sort -t "$SEP" -k3,3n -k2,2 | while IFS="$SEP" read -r _ n _ text; do echo "- $n $text"; done
  elif ! grep -q "^[MV]$SEP" "$tmp"; then
    echo "No open pull requests and nothing waiting for your review."
  else
    echo "Nothing needs you right now."
  fi
}

# --- whats-new: what came into the base branch -------------------------------------
# Records: H <name> <base> <count> <label> | L <name> <seq> <line> | A <name> <areas> | O <name> <branch> <files> | X <name>

whats_new_worker() {
  local do_fetch=$1 repo=$2 name base branch range label count prev when overlap n
  name=$(basename "$repo")
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || return 0
  [ "$do_fetch" = 1 ] && [ -n "$(git -C "$repo" remote)" ] && run_fetch "$repo"
  base=$(detect_base "$repo")
  if [ -z "$base" ] || ! git -C "$repo" show-ref --verify --quiet "refs/heads/$base"; then printf 'X%s%s\n' "$SEP" "$name"; return 0; fi
  branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null)

  if [ "$(git -C "$repo" rev-list --count "refs/heads/$base..refs/remotes/origin/$base" 2>/dev/null || echo 0)" -gt 0 ]; then
    range="refs/heads/$base..refs/remotes/origin/$base"; label="incoming, not pulled yet"
  else
    prev=$(git -C "$repo" rev-parse --quiet --verify "$base@{1}" 2>/dev/null)
    if [ -z "$prev" ] || ! git -C "$repo" merge-base --is-ancestor "$prev" "refs/heads/$base" 2>/dev/null; then
      printf 'X%s%s\n' "$SEP" "$name"; return 0
    fi
    when=$(git -C "$repo" reflog show -1 --date=relative --format='%gd' "refs/heads/$base" 2>/dev/null | sed 's/.*{\(.*\)}/\1/')
    range="$prev..refs/heads/$base"; label="since the last update${when:+ ($when)}"
  fi
  count=$(git -C "$repo" rev-list --count --no-merges "$range" 2>/dev/null || echo 0)
  [ "$count" -gt 0 ] || { printf 'X%s%s\n' "$SEP" "$name"; return 0; }
  printf 'H%s%s%s%s%s%s%s%s\n' "$SEP" "$name" "$SEP" "$base" "$SEP" "$count" "$SEP" "$label"

  n=0
  while IFS= read -r line; do
    n=$((n + 1))
    printf 'L%s%s%s%s%s%s\n' "$SEP" "$name" "$SEP" "$n" "$SEP" "$line"
  done < <(git -C "$repo" log --no-merges -n "$MAX_NEWS" --format='%h %s (%an, %cr)' "$range" 2>/dev/null)

  printf 'A%s%s%s%s\n' "$SEP" "$name" "$SEP" "$(git -C "$repo" diff --name-only "$range" 2>/dev/null \
      | awk -F/ '{ d = (NF > 2 ? $1 "/" $2 : (NF > 1 ? $1 : ".")); c[d]++ } END { for (d in c) printf "%d %s\n", c[d], d }' \
      | sort -rn | head -5 | awk '{ printf "%s%s (%s)", (NR > 1 ? ", " : ""), $2, $1 }')"

  if [ -n "$branch" ] && [ "$branch" != "$base" ]; then
    overlap=$(comm -12 <(git -C "$repo" diff --name-only "$range" 2>/dev/null | sort) \
                       <(git -C "$repo" diff --name-only "refs/heads/$base...HEAD" 2>/dev/null | sort))
    if [ -n "$overlap" ]; then
      n=$(printf '%s\n' "$overlap" | grep -c .)
      printf 'O%s%s%s%s%s%s\n' "$SEP" "$name" "$SEP" "$branch" "$SEP" "$(printf '%s\n' "$overlap" | head -6 | tr '\n' ',' | sed 's/,$//; s/,/, /g')$( [ "$n" -gt 6 ] && echo " (+$((n - 6)) more)")"
    fi
  fi
  return 0
}

render_whats_new() {
  local tmp=$1 total=$2 name base count label
  echo "git-parity whats-new · $total repo(s) · $(grep -c "^H$SEP" "$tmp") with news"
  echo
  grep "^H$SEP" "$tmp" | sort -t "$SEP" -k2,2 | while IFS="$SEP" read -r _ name base count label; do
    echo "$name · $base · $count new commit(s) · $label"
    grep "^L$SEP$name$SEP" "$tmp" | sort -t "$SEP" -k3,3n | cut -d "$SEP" -f4 | sed 's/^/  /'
    [ "$count" -gt "$MAX_NEWS" ] && echo "  +$((count - MAX_NEWS)) more"
    grep "^A$SEP$name$SEP" "$tmp" | cut -d "$SEP" -f3 | sed 's/^/  Areas: /'
    grep "^O$SEP$name$SEP" "$tmp" | while IFS="$SEP" read -r _ _ branch files; do
      echo "  Also changed on your branch $branch (possible conflicts): $files"
    done
    echo
  done
  local quiet; quiet=$(grep "^X$SEP" "$tmp" | cut -d "$SEP" -f2 | sort | tr '\n' ',' | sed 's/,$//; s/,/, /g')
  [ -z "$quiet" ] || echo "Nothing new in: $quiet"
}

# --- hook: one line at session start, only when opted in and something needs attention
run_hook() {
  [ -f "$CONFIG_DIR/config" ] && grep -qx 'session_hook=on' "$CONFIG_DIR/config" || return 0
  local repos tmp n total
  if [ -n "$(repos_file)" ]; then repos=$(repos_file); else repos=$(git rev-parse --show-toplevel 2>/dev/null); fi
  [ -n "$repos" ] || return 0
  tmp=$(mktemp "${TMPDIR:-/tmp}/git-parity.XXXXXX") || return 0
  FETCH_TIMEOUT=5; export GIT_PARITY_FETCH_TIMEOUT=5
  printf '%s\n' "$repos" | tr '\n' '\0' | xargs -0 -n 1 -P "$JOBS" bash "$0" --worker status 1 > "$tmp" 2>/dev/null
  n=$(grep -c "^R${SEP}[0-8]${SEP}" "$tmp"); total=$(printf '%s\n' "$repos" | grep -c .)
  rm -f "$tmp"
  [ "$n" -gt 0 ] && echo "git-parity: $n of $total repositories need attention. Run /git-parity:status for details."
  return 0
}

# --- main ---------------------------------------------------------------------
if [ "${1:-}" = "--worker" ]; then shift; worker "$@"; exit 0; fi
if [ "${1:-}" = "--feature-worker" ]; then shift; feature_worker "$@"; exit 0; fi
if [ "${1:-}" = "--cleanup-worker" ]; then shift; cleanup_worker "$@"; exit 0; fi
if [ "${1:-}" = "--prs-worker" ]; then shift; TMPW=$(mktemp "${TMPDIR:-/tmp}/git-parity.XXXXXX"); prs_worker "$@"; rm -f "$TMPW" "$TMPW".*; exit 0; fi
if [ "${1:-}" = "--news-worker" ]; then shift; whats_new_worker "$@"; exit 0; fi
if [ "${1:-}" = "--print-prs-jq" ]; then printf '%s\n' "$PRS_JQ"; exit 0; fi
if [ "${1:-}" = "hook" ]; then run_hook; exit 0; fi

MODE=${1:-status}; [ "$#" -gt 0 ] && shift
case $MODE in status|remote|local|full|feature|cleanup|prs|whats-new) ;; -h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) die "unknown mode '$MODE' (use: status, remote, local, full, feature, cleanup, prs, whats-new)" ;; esac

PATTERN=""
if [ "$MODE" = feature ]; then
  PATTERN=${1:-}
  case $PATTERN in
    ""|-*) # exit 0 on purpose: a skill that injects this output must still load and ask the user
      echo "git-parity feature: a branch name or pattern is needed, for example: feature login   or   feature 'feat/login*'"
      exit 0 ;;
  esac
  shift
fi

DO_FETCH=1
ARGS=()
for a in "$@"; do
  case $a in --no-fetch) DO_FETCH=0 ;; -*) die "unknown option '$a'" ;; *) ARGS+=("$a") ;; esac
done

TMP=$(mktemp "${TMPDIR:-/tmp}/git-parity.XXXXXX") || die "mktemp failed"
trap 'rm -f "$TMP" "$TMP.repos"' EXIT

discover ${ARGS[@]+"${ARGS[@]}"} > "$TMP.repos"
TOTAL=$(grep -c . "$TMP.repos")
if [ "$TOTAL" -eq 0 ]; then
  echo "git-parity: no repositories found."
  echo "Pass paths as arguments, run inside a repository, or list one path per line in $CONFIG_DIR/repos"
  exit 0
fi

START=$(date +%s)
case $MODE in
  feature)
    tr '\n' '\0' < "$TMP.repos" | xargs -0 -n 1 -P "$JOBS" bash "$0" --feature-worker "$PATTERN" "$DO_FETCH" > "$TMP"
    render_feature "$PATTERN" "$TMP" "$TOTAL" ;;
  cleanup)
    tr '\n' '\0' < "$TMP.repos" | xargs -0 -n 1 -P "$JOBS" bash "$0" --cleanup-worker "$DO_FETCH" > "$TMP"
    render_cleanup "$TMP" "$TOTAL" ;;
  prs)
    tr '\n' '\0' < "$TMP.repos" | xargs -0 -n 1 -P "$JOBS" bash "$0" --prs-worker > "$TMP"
    render_prs "$TMP" "$TOTAL" ;;
  whats-new)
    tr '\n' '\0' < "$TMP.repos" | xargs -0 -n 1 -P "$JOBS" bash "$0" --news-worker "$DO_FETCH" > "$TMP"
    render_whats_new "$TMP" "$TOTAL" ;;
  *)
    tr '\n' '\0' < "$TMP.repos" | xargs -0 -n 1 -P "$JOBS" bash "$0" --worker "$MODE" "$DO_FETCH" > "$TMP"
    END=$(date +%s)
    render "$MODE" "$TMP" "$TOTAL" "$((END - START))" ;;
esac
