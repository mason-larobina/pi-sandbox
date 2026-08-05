#!/usr/bin/env bash
set -euo pipefail
podman build -t sandbox -f Containerfile . --no-cache
