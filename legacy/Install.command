#!/bin/bash
# Automatically detects the macOS language and opens the installer once.
set -euo pipefail
PROJECT="$(cd "$(dirname "$0")/.." && pwd -P)"
unset ECZ_INSTALL_LANGUAGE
exec /bin/bash "$PROJECT/Start.command"
