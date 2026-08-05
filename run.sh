#!/usr/bin/env bash
set -euo pipefail

# Ensure the bind sources exist as files/dirs before mounting; otherwise podman
# creates missing paths as empty directories on the host (e.g. a directory at
# ~/.claude.json or ~/.gitconfig, which then breaks claude/git on the whole
# system).
[ -f "$HOME/.gitconfig" ] || touch "$HOME/.gitconfig"
mkdir -p "$HOME/.claude"
touch "$HOME/.claude.json"

podman run --rm -it \
  -v "$PWD:/workspace" \
  -v "$HOME/.pi:/home/sandbox/.pi" \
  -v "$HOME/.claude:/home/sandbox/.claude" \
  -v "$HOME/.claude.json:/home/sandbox/.claude.json" \
  -v "$HOME/.gitconfig:/home/sandbox/.gitconfig:ro" \
  -w /workspace \
  --userns=keep-id \
  sandbox \
  "${@}"
