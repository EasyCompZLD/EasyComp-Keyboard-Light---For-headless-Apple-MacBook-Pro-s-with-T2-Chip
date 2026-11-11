#!/bin/bash
# EasyComp Keyboard Light 1.2.0-beta — Polski
# Localized launcher: the technical implementation is kept in one place.
set -euo pipefail
PROJECT="$(cd "$(dirname "$0")/../../.." && pwd -P)"
export ECZ_INSTALL_LANGUAGE="pl"
exec /bin/bash "$PROJECT/Diagnoseer-T2-Mac.command"
