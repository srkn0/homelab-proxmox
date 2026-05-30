#!/usr/bin/env bash
#
# Build a Markdown summary of kubespray GitHub release notes for every release
# in the range (old, new], newest first, for posting as a PR comment.
#
# Usage: scripts/kubespray-release-notes.sh <old_version> <new_version>
#        Honors GH_TOKEN / GITHUB_TOKEN for a higher API rate limit if set.
set -euo pipefail

OLD="${1:?usage: $0 <old_version> <new_version>}"
NEW="${2:?usage: $0 <old_version> <new_version>}"

REPO="kubernetes-sigs/kubespray"
MARKER="<!-- ksp-release-notes -->"
MAX_CHARS=60000   # GitHub comment limit is 65536; stay under it

auth=()
token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
[ -n "$token" ] && auth=(-H "Authorization: Bearer $token")

releases="$(mktemp)"
trap 'rm -f "$releases"' EXIT

# Fetch all releases (paginated), one compact JSON object per line.
page=1
while :; do
  resp="$(curl -fsSL "${auth[@]}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO/releases?per_page=100&page=$page")"
  [ "$(printf '%s' "$resp" | jq 'length')" -eq 0 ] && break
  printf '%s' "$resp" | jq -c '.[]' >>"$releases"
  page=$((page + 1))
  [ "$page" -gt 10 ] && break
done

# Non-prerelease tags in (OLD, NEW], ascending by semver. OLD/NEW are injected so
# they anchor the window even if one of them is not a published release.
selected_asc="$(
  {
    jq -r 'select(.prerelease | not) | .tag_name' "$releases"
    printf '%s\n%s\n' "$OLD" "$NEW"
  } | sort -V -u | awk -v old="$OLD" -v new="$NEW" '
      $0 == old { seen = 1; next }
      !seen { next }
      { print }
      $0 == new { exit }
    '
)"
mapfile -t selected < <(printf '%s\n' "$selected_asc" | tac)

field() { jq -rs --arg t "$1" "(map(select(.tag_name==\$t)) | .[0]) | $2 // \"\"" "$releases"; }

emit_full() {
  printf '%s\n\n' "$MARKER"
  printf '## Kubespray release notes: %s to %s\n\n' "$OLD" "$NEW"
  printf '[Full compare](https://github.com/%s/compare/%s...%s) | [Upgrade docs](https://github.com/%s/blob/%s/docs/operations/upgrades.md)\n\n' \
    "$REPO" "$OLD" "$NEW" "$REPO" "$NEW"
  for tag in "${selected[@]}"; do
    [ -n "$tag" ] || continue
    url="$(field "$tag" '.html_url')"
    date="$(field "$tag" '.published_at' | cut -dT -f1)"
    printf '<details>\n<summary><b>%s</b> (%s) | <a href="%s">release</a></summary>\n\n' "$tag" "$date" "$url"
    field "$tag" '.body' | tr -d '\r'
    printf '\n\n</details>\n\n'
  done
}

emit_links() {
  printf '%s\n\n' "$MARKER"
  printf '## Kubespray release notes: %s to %s\n\n' "$OLD" "$NEW"
  printf '_Too many changes to inline; linking releases instead._\n\n'
  printf '[Full compare](https://github.com/%s/compare/%s...%s) | [Upgrade docs](https://github.com/%s/blob/%s/docs/operations/upgrades.md)\n\n' \
    "$REPO" "$OLD" "$NEW" "$REPO" "$NEW"
  for tag in "${selected[@]}"; do
    [ -n "$tag" ] || continue
    url="$(field "$tag" '.html_url')"
    date="$(field "$tag" '.published_at' | cut -dT -f1)"
    printf -- '- [%s](%s) (%s)\n' "$tag" "$url" "$date"
  done
}

out="$(emit_full)"
if [ "${#out}" -gt "$MAX_CHARS" ]; then
  out="$(emit_links)"
fi
printf '%s\n' "$out"
