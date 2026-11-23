#!/usr/bin/env bash
# Install the garmin-watchface skill for the agent tools found on this machine.
# Re-run after pulling updates.  Usage: ./install.sh [--link]   (--link symlinks instead of copying)
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)/skills/garmin-watchface"
MODE="${1:-}"
installed=0
put() {
  local dir="$1"
  mkdir -p "$dir"
  rm -rf "$dir/garmin-watchface"
  if [ "$MODE" = "--link" ]; then ln -s "$SRC" "$dir/garmin-watchface"; else cp -r "$SRC" "$dir/garmin-watchface"; fi
  echo "  -> $dir/garmin-watchface"
  installed=1
}
echo "Installing garmin-watchface skill:"
[ -d "$HOME/.claude" ]           && put "$HOME/.claude/skills"            # Claude Code
[ -d "$HOME/.config/opencode" ]  && put "$HOME/.config/opencode/skills"   # OpenCode
[ -d "$HOME/.hermes" ]           && put "$HOME/.hermes/skills"            # Hermes Agent
[ -d "$HOME/.codex" ]            && put "$HOME/.codex/skills"             # Codex CLI
put "$HOME/.agents/skills"                                                 # shared Agent Skills folder
[ "$installed" = 1 ] || true
echo "Done. Other agents: point them at AGENTS.md in this repo, or at skills/garmin-watchface/SKILL.md."
