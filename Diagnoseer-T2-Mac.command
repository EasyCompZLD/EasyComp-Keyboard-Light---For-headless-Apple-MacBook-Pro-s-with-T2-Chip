#!/bin/bash
# Read-only development diagnostic with local, privacy-conscious report output.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
exec /bin/bash "$HERE/Probleemrapport.command"
