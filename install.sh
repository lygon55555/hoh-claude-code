#!/usr/bin/env bash
# Project-local install: symlink the HoH skill and agents into a workspace's .claude/
# directory, and optionally copy a project profile into <workspace>/hoh/.
#
# This is the alternative to installing HoH as a Claude Code plugin. Use it when you
# want the harness to live inside one workspace (for example, committed to the repo
# for a team) instead of in the plugin cache.
#
# Usage: ./install.sh <workspace> [--profile <name>]
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "usage: $0 <workspace> [--profile <name>]" >&2
  echo >&2
  echo "profiles:" >&2
  for p in "$REPO"/skills/hoh/profiles/*/; do
    [ -d "$p" ] && echo "  $(basename "$p")" >&2
  done
  exit 1
}

[ $# -ge 1 ] || usage
WS="$1"; shift
PROFILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; [ -n "$PROFILE" ] || usage; shift 2 ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
done

if [ ! -d "$WS" ]; then
  echo "workspace not found: $WS" >&2
  exit 1
fi

# Link one target. An existing symlink is replaced; a real file or directory is left alone.
link() {
  local src="$1" target="$2" label="$3"
  if [ -L "$target" ]; then
    rm "$target"
    echo "update: $label (replaced existing symlink)"
  elif [ -e "$target" ]; then
    echo "skip:   $label — a real file/directory already exists. Move it away and rerun: $target" >&2
    return
  fi
  ln -s "$src" "$target"
  echo "link:   $target -> $src"
}

echo "== skills"
mkdir -p "$WS/.claude/skills"
for skill in "$REPO"/skills/*/; do
  name="$(basename "$skill")"
  link "${skill%/}" "$WS/.claude/skills/$name" "$name"
done

echo
echo "== agents"
mkdir -p "$WS/.claude/agents"
for agent in "$REPO"/agents/*.md; do
  name="$(basename "$agent")"
  link "$agent" "$WS/.claude/agents/$name" "$name"
done
chmod +x "$REPO/skills/hoh/scripts/gate.sh"

echo
echo "== project profile"
if [ -n "$PROFILE" ]; then
  SRC="$REPO/skills/hoh/profiles/$PROFILE"
  if [ ! -d "$SRC" ]; then
    echo "no such profile: $PROFILE" >&2
    usage
  fi
  mkdir -p "$WS/hoh"
  for f in project.sh project.md; do
    # Profiles other than `generic` ship only project.sh; project.md comes from generic.
    src="$SRC/$f"; [ -f "$src" ] || src="$REPO/skills/hoh/profiles/generic/$f"
    if [ -e "$WS/hoh/$f" ]; then
      echo "skip:   hoh/$f already exists (left unchanged)"
    else
      cp "$src" "$WS/hoh/$f"
      echo "copy:   $WS/hoh/$f  (from ${src#"$REPO"/skills/hoh/})"
    fi
  done
  chmod +x "$WS/hoh/project.sh"
  echo "Edit hoh/project.sh and hoh/project.md for this project, then run '/hoh init' in Claude Code to self-check."
else
  if [ -f "$WS/hoh/project.sh" ]; then
    echo "hoh/project.sh already present (left unchanged)"
  else
    echo "none. Run '/hoh init <profile>' in Claude Code, or rerun with --profile <name>."
    echo "See skills/hoh/references/setup.md."
  fi
fi

echo
echo "Done. Restart Claude Code in the workspace; /hoh should appear in the skill list."
