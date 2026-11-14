#!/usr/bin/env bash
set -euo pipefail

# Ensure the bind sources exist as files/dirs before mounting; otherwise podman
# creates missing paths as empty directories on the host (e.g. a directory at
# ~/.claude.json or ~/.gitconfig, which then breaks claude/git on the whole
# system).

mkdir -p "$HOME/.sandbox/home"
mkdir -p "$HOME/.sandbox/tmp"
mkdir -p "$HOME/src/worktree"

# --init runs catatonit as PID 1 to reap orphans. Without it the agent is PID 1
# and never reaps, so daemons that re-parent to it (Bazel servers, git's
# detached jobs) stay zombies, and `bazel shutdown`/`clean --expunge` wait ~70s
# for a server that has already exited, then fail with exit 36.
# --shm-size raises /dev/shm from podman's 64 MB so test suites can keep their
# temp files in RAM; tmpfs only uses memory for what is stored.
# --pids-limit=-1 lifts podman's default cgroup cap of 2048 tasks (threads
# count). Parallel agent lanes each run a Bazel server with hundreds of threads;
# at the cap the JVMs die with "unable to create native thread". The host's own
# limits still apply.
podman run --rm -it --init \
  --shm-size=1g \
  --pids-limit=-1 \
  -v "$PWD:/workspace" \
  -v "$HOME/.sandbox/home:/home/sandbox" \
  -v "$HOME/.sandbox/tmp:/tmp" \
  -v "$HOME/src/worktree:/worktree" \
  -w /workspace \
  --userns=keep-id \
  sandbox \
  "${@}"
