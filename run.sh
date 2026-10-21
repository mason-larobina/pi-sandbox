#!/usr/bin/env bash
set -euo pipefail

# Ensure the bind sources exist as files/dirs before mounting; otherwise podman
# creates missing paths as empty directories on the host (e.g. a directory at
# ~/.claude.json or ~/.gitconfig, which then breaks claude/git on the whole
# system).

# Mount a per-day tmp directory (not the shared parent) so it's easy to tell
# what scratch state is fresh and what's stale. Override with TMP_DATE=... .
TMP_DATE="${TMP_DATE:-$(date +%Y-%m-%d)}"
TMP_DIR="$HOME/src/tmp/$TMP_DATE"
mkdir -p "$TMP_DIR"
mkdir -p "$HOME/src/worktree"
mkdir -p "$HOME/.pi"
mkdir -p "$HOME/.claude"
mkdir -p "$HOME/.cargo"
touch "$HOME/.claude.json"
touch "$HOME/.gitconfig"

# --init runs catatonit as PID 1 to reap orphans. Without it the agent is PID 1
# and never reaps, so daemons that re-parent to it (Bazel servers, git's
# detached jobs) stay zombies, and `bazel shutdown`/`clean --expunge` wait ~70s
# for a server that has already exited, then fail with exit 36.
podman run --rm -it --init \
  -v "$PWD:/workspace" \
  -v "$TMP_DIR:/tmp" \
  -v "$HOME/src/worktree:/worktree" \
  -v "$HOME/.pi:/home/sandbox/.pi" \
  -v "$HOME/.claude:/home/sandbox/.claude" \
  -v "$HOME/.cargo:/home/sandbox/.cargo" \
  -v "$HOME/.claude.json:/home/sandbox/.claude.json" \
  -v "$HOME/.gitconfig:/home/sandbox/.gitconfig:ro" \
  -w /workspace \
  --userns=keep-id \
  sandbox \
  "${@}"
