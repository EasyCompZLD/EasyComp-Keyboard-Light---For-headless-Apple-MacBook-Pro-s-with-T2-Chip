#!/bin/bash
# EasyComp Keyboard Light 1.2.0-beta — Italiano
# Localized launcher: the technical implementation is kept in one place.
set -euo pipefail
PROJECT="$(cd "$(dirname "$0")/../../.." && pwd -P)"
export ECZ_INSTALL_LANGUAGE="it"
exec /bin/bash "$PROJECT/Start.command"
