#!/bin/bash
# EasyComp Keyboard Light 1.2.0-beta6 — Deutsch
# Localized launcher: the technical implementation is kept in one place.
set -euo pipefail
PROJECT="$(cd "$(dirname "$0")/../.." && pwd -P)"
export ECZ_INSTALL_LANGUAGE="de"
exec /bin/bash "$PROJECT/Start-Installatie.command"
