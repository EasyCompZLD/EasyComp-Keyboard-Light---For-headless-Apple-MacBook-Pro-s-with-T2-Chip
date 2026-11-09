#!/bin/bash
# EasyComp Keyboard Light 1.2.0-beta6 — Polski
# Localized launcher: the technical implementation is kept in one place.
set -euo pipefail
PROJECT="$(cd "$(dirname "$0")/../.." && pwd -P)"
export ECZ_INSTALL_LANGUAGE="pl"
source "$PROJECT/scripts/cli-i18n.sh"
if [[ "$(uname -s)" != "Darwin" ]]; then echo "$(ecz_t boot.nonmac)" >&2; exit 2; fi
printf '%s ' "$(ecz_t remove.confirm)"
IFS= read -r reply || reply=''
reply="$(printf '%s' "$reply" | /usr/bin/tr '[:upper:]' '[:lower:]')"
case "$ECZ_LANGUAGE:$reply" in
  en:y|en:yes|nl:j|nl:ja|de:j|de:ja|fr:o|fr:oui|es:s|es:si|es:sí|it:s|it:si|it:sì|pt:s|pt:sim|pl:t|pl:tak)
    exec /bin/bash "$PROJECT/Verwijder.command" ;;
  *) echo "$(ecz_t remove.cancel)" ;;
esac
