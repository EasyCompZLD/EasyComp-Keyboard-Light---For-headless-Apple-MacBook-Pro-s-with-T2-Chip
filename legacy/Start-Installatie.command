#!/bin/bash
# Compatibility launcher; all setup uses the same GUI.
set -euo pipefail
PROJECT="$(cd "$(dirname "$0")/.." && pwd -P)"
exec /bin/bash "$PROJECT/Start.command"
