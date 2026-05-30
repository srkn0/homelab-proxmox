#!/usr/bin/env bash
#
# Build a Markdown section describing what changed in an external Ansible role
# between two versions, for posting as a PR comment on a Renovate bump.
#
# It reports:
#   1. which of the variables WE set (overriding a role default) are removed,
#      renamed, or have a changed default in the new version;
#   2. best-effort GitHub release notes for the versions in between;
#   3. the full defaults/main.yml diff (collapsible).
#
# Usage: role-bump-comment.sh <role_name> <repo> <old> <new> <vars_file> <prefix>
#   e.g. role-bump-comment.sh lae.proxmox lae/ansible-role-proxmox \
#          v1.10.0 v1.10.1 playbooks/install_proxmox.yml pve_
# Honors GH_TOKEN / GITHUB_TOKEN for the releases API rate limit.
#
# Backticks in printf format strings below are literal Markdown, not command
# substitution.
# shellcheck disable=SC2016
set -euo pipefail

NAME="${1:?role name}"
REPO="${2:?owner/repo}"
OLD="${3:?old version}"
NEW="${4:?new version}"
VARS_FILE="${5:?vars file}"
PREFIX="${6:?var prefix}"

auth=()
token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
[ -n "$token" ] && auth=(-H "Authorization: Bearer $token")

raw_defaults() { # repo tag -> file contents (empty on miss)
  curl -fsSL "https://raw.githubusercontent.com/$1/$2/defaults/main.yml" 2>/dev/null || true
}

old_def="$(mktemp)"; new_def="$(mktemp)"
trap 'rm -f "$old_def" "$new_def"' EXIT
raw_defaults "$REPO" "$OLD" >"$old_def"
raw_defaults "$REPO" "$NEW" >"$new_def"

printf '## %s: %s to %s\n\n' "$NAME" "$OLD" "$NEW"
printf '[Compare](https://github.com/%s/compare/%s...%s)\n\n' "$REPO" "$OLD" "$NEW"

# ---- 1. Impact on the variables we set -------------------------------------
# Keys we set in the playbook (active lines only, comments excluded).
mapfile -t our_keys < <(grep -oE "^[[:space:]]+${PREFIX}[a-z0-9_]+" "$VARS_FILE" | tr -d '[:space:]' | sort -u)

def_line() { grep -m1 "^$1:" "$2" 2>/dev/null || true; }
def_val() { def_line "$1" "$2" | sed "s/^$1:[[:space:]]*//; s/[[:space:]]*#.*//"; }

removed=(); changed=(); skipped=0
for k in "${our_keys[@]}"; do
  ol="$(def_line "$k" "$old_def")"
  nl="$(def_line "$k" "$new_def")"
  if [ -z "$ol" ]; then
    skipped=$((skipped + 1))            # we set it, but it is not a role default
  elif [ -z "$nl" ]; then
    removed+=("$k")
  elif [ "$ol" != "$nl" ]; then
    changed+=("$k|$(def_val "$k" "$old_def")|$(def_val "$k" "$new_def")")
  fi
done

printf '### Impact on variables you set\n\n'
if [ "${#removed[@]}" -eq 0 ] && [ "${#changed[@]}" -eq 0 ]; then
  printf 'None of the role defaults you override changed.\n\n'
else
  for k in "${removed[@]}"; do
    printf -- '- `%s`: **removed or renamed upstream** (your override may no longer apply)\n' "$k"
  done
  for c in "${changed[@]}"; do
    IFS='|' read -r k ov nv <<<"$c"
    printf -- '- `%s`: upstream default changed `%s` to `%s`\n' "$k" "$ov" "$nv"
  done
  printf '\n'
fi
[ "$skipped" -gt 0 ] && printf '_%d of your variables are inputs, not role defaults; skipped._\n\n' "$skipped"

# ---- 2. Release notes (best effort) ----------------------------------------
notes="$(mktemp)"; : >"$notes"
if releases="$(curl -fsSL "${auth[@]}" -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/$REPO/releases?per_page=100" 2>/dev/null)"; then
  printf '%s' "$releases" | jq -c '.[]' >"$notes" 2>/dev/null || : >"$notes"
fi
mapfile -t rel_tags < <(
  { jq -r 'select(.prerelease | not) | .tag_name' "$notes" 2>/dev/null; printf '%s\n%s\n' "$OLD" "$NEW"; } \
  | sort -V -u | awk -v old="$OLD" -v new="$NEW" '
      $0==old{seen=1;next} !seen{next} {print} $0==new{exit}' | tac
)
have_notes=0
for t in "${rel_tags[@]}"; do
  [ -n "$t" ] || continue
  body="$(jq -rs --arg t "$t" '(map(select(.tag_name==$t)) | .[0]) | .body // ""' "$notes" 2>/dev/null)"
  [ -n "$body" ] || continue
  if [ "$have_notes" -eq 0 ]; then printf '### Release notes\n\n'; have_notes=1; fi
  url="$(jq -rs --arg t "$t" '(map(select(.tag_name==$t)) | .[0]) | .html_url // ""' "$notes" 2>/dev/null)"
  printf '<details>\n<summary><b>%s</b> | <a href="%s">release</a></summary>\n\n%s\n\n</details>\n\n' \
    "$t" "$url" "$(printf '%s' "$body" | tr -d '\r')"
done
rm -f "$notes"

# ---- 3. Full defaults diff -------------------------------------------------
printf '### defaults/main.yml diff\n\n'
if diff_out="$(diff -u --label "defaults @ $OLD" "$old_def" --label "defaults @ $NEW" "$new_def")"; then
  printf '_No changes in defaults/main.yml._\n\n'
else
  printf '<details>\n<summary>defaults/main.yml %s to %s</summary>\n\n```diff\n%s\n```\n\n</details>\n\n' \
    "$OLD" "$NEW" "$diff_out"
fi
