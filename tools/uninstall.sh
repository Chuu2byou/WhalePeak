#!/usr/bin/env bash
#
# Remove the WhalePeak applet and its icon theme artwork.
#
#   tools/uninstall.sh            remove the applet and the icon
#   tools/uninstall.sh --restart  also restart plasmashell afterwards
#   tools/uninstall.sh --keep-icon  leave the icon theme artwork in place
set -euo pipefail
# shellcheck source=tools/lib.sh
source "$(dirname "$0")/lib.sh"

ROOT="$(tracker_root)"
cd "$ROOT"

DO_ICON=1
RESTART=0

for arg in "$@"; do
    case "$arg" in
        --restart)   RESTART=1 ;;
        --keep-icon) DO_ICON=0 ;;
        -h|--help)   tracker_usage "$0"; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

APP_ID="$(tracker_plugin_id "$ROOT/metadata.json")"

if tracker_is_installed "$APP_ID"; then
    if command -v kpackagetool6 >/dev/null 2>&1; then
        printf 'Removing %s ...\n' "$APP_ID"
        kpackagetool6 --type Plasma/Applet --remove "$APP_ID"
        tracker_refresh_caches
    else
        printf 'kpackagetool6 not found - removing the folder directly.\n' >&2
        rm -rf "$(dirname "$(tracker_installed_metadata "$APP_ID")")"
    fi
else
    printf '%s is not installed.\n' "$APP_ID"
fi

if [ "$DO_ICON" -eq 1 ]; then
    tracker_remove_icon "$ROOT"
    printf 'Icon files removed from the icon theme.\n'
fi

if [ "$RESTART" -eq 1 ]; then
    tracker_restart_plasma
fi

printf '\nDone.\n'
