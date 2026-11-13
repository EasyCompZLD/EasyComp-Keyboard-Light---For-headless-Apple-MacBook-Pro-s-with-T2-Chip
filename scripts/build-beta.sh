#!/bin/bash
# Compatibility entry point for the single package builder.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
exec bash "$HERE/build-release.sh" "$@"
