#!/usr/bin/env bash
#
# Merge upstream Kubespray sample group_vars into this repo's customized
# inventory group_vars via a 3-way merge.
#
#   base   = kubespray inventory/sample/group_vars at <old_version>
#   ours   = the customized file in inventory/kubespray/<cluster>/group_vars
#   theirs = kubespray inventory/sample/group_vars at <new_version>
#
# Only files that already exist under each cluster's group_vars are touched.
# Conflict markers are left in place where a customization overlaps an upstream
# change; resolving them is a manual step.
#
# Usage: scripts/merge-kubespray-sample.sh <old_version> <new_version>
#        (versions are kubespray git tags, e.g. v2.29.1)
set -euo pipefail

OLD="${1:?usage: $0 <old_version> <new_version>}"
NEW="${2:?usage: $0 <old_version> <new_version>}"

REPO_ROOT="$(git rev-parse --show-toplevel)"
INV_DIR="$REPO_ROOT/inventory/kubespray"

fetch_sample() {
  # $1 = version tag, $2 = destination dir
  local version="$1" dest="$2" tmp topdir src
  tmp="$(mktemp -d)"
  curl -fsSL "https://github.com/kubernetes-sigs/kubespray/archive/refs/tags/${version}.tar.gz" \
    | tar -xz -C "$tmp"
  topdir="$(find "$tmp" -maxdepth 1 -type d -name 'kubespray-*' | head -n1)"
  src="$topdir/inventory/sample/group_vars"
  if [ ! -d "$src" ]; then
    echo "error: inventory/sample/group_vars not found in kubespray ${version}" >&2
    rm -rf "$tmp"
    return 1
  fi
  mkdir -p "$dest"
  cp -a "$src/." "$dest/"
  rm -rf "$tmp"
}

OLD_DIR="$(mktemp -d)"
NEW_DIR="$(mktemp -d)"
trap 'rm -rf "$OLD_DIR" "$NEW_DIR"' EXIT

echo "Fetching kubespray sample group_vars for $OLD and $NEW ..."
fetch_sample "$OLD" "$OLD_DIR"
fetch_sample "$NEW" "$NEW_DIR"

changed=0
conflicts=0

for gv in "$INV_DIR"/*/group_vars; do
  [ -d "$gv" ] || continue
  cluster="$(basename "$(dirname "$gv")")"

  while IFS= read -r -d '' file; do
    rel="${file#"$gv"/}"                 # e.g. all/all.yml
    old_s="$OLD_DIR/$rel"
    new_s="$NEW_DIR/$rel"
    [ -f "$old_s" ] || old_s=/dev/null
    [ -f "$new_s" ] || new_s=/dev/null

    merged="$(mktemp)"
    set +e
    git merge-file -p \
      -L "your version ($cluster/$rel)" \
      -L "kubespray $OLD" \
      -L "kubespray $NEW" \
      "$file" "$old_s" "$new_s" >"$merged"
    rc=$?
    set -e

    # git merge-file returns the conflict count (<=127); >127 means a real error.
    if [ "$rc" -gt 127 ]; then
      echo "error: git merge-file failed for $cluster/$rel" >&2
      rm -f "$merged"
      exit 1
    fi

    if ! cmp -s "$merged" "$file"; then
      cp "$merged" "$file"
      changed=$((changed + 1))
    fi
    if [ "$rc" -gt 0 ]; then
      conflicts=$((conflicts + rc))
      echo "  conflict(s) in $cluster/$rel: $rc"
    fi
    rm -f "$merged"
  done < <(find "$gv" -type f \( -name '*.yml' -o -name '*.yaml' \) -print0)
done

echo "Done. files changed: $changed, total conflicts: $conflicts"
