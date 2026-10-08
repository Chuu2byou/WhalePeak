#!/usr/bin/env bash
#
# Install or update the WhalePeak applet for the current user.
#
#   tools/install.sh              install, or update if already installed
#   tools/install.sh --restart    also restart plasmashell afterwards
#   tools/install.sh --check      only report source/installed versions
#   tools/install.sh --icon-only  only (re)install the icon theme artwork
#   tools/install.sh --no-icon    skip the icon theme step
#
# The applet is installed from a clean staging directory, so only metadata.json
# and contents/ end up in your Plasma config.
set -euo pipefail
# shellcheck source=tools/lib.sh
source "$(dirname "$0")/lib.sh"

ROOT="$(tracker_root)"
cd "$ROOT"

DO_INSTALL=1
DO_ICON=1
RESTART=0
CHECK_ONLY=0

for arg in "$@"; do
    case "$arg" in
        --restart)   RESTART=1 ;;
        --check)     CHECK_ONLY=1 ;;
        --icon-only) DO_INSTALL=0 ;;
        --no-icon)   DO_ICON=0 ;;
        -h|--help)   tracker_usage "$0"; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

APP_ID="$(tracker_plugin_id "$ROOT/metadata.json")"
SRC_VERSION="$(tracker_version "$ROOT/metadata.json")"
INSTALLED_VERSION="$(tracker_installed_version "$APP_ID")"
INSTALLED_DIR="$(dirname "$(tracker_installed_metadata "$APP_ID")")"

if [ "$CHECK_ONLY" -eq 1 ]; then
    printf 'Applet        : %s\n' "$APP_ID"
    printf 'Source        : %s\n' "$SRC_VERSION"
    if [ -n "$INSTALLED_VERSION" ]; then
        printf 'Installed     : %s\n' "$INSTALLED_VERSION"
        if [ "$INSTALLED_VERSION" = "$SRC_VERSION" ]; then
            printf 'Status        : up to date\n'
        else
            printf 'Status        : update available\n'
        fi
        # The version alone says nothing about the installed files: a staging
        # step that failed silently used to leave an old build behind while the
        # version still matched. So compare the contents as well.
        if [ -d "$INSTALLED_DIR/contents" ]; then
            if diff -rq "$ROOT/contents" "$INSTALLED_DIR/contents" >/dev/null 2>&1; then
                printf 'Contents      : identical\n'
            else
                printf 'Contents      : differs from source (run tools/install.sh)\n'
                # diff exits 1 on differences, which pipefail would turn into an
                # abort - the listing is only informational.
                diff -rq "$ROOT/contents" "$INSTALLED_DIR/contents" 2>/dev/null | head -n 20 | sed 's/^/  /' || true
            fi
        fi
    else
        printf 'Installed     : no\n'
        printf 'Status        : not installed\n'
    fi
    if tracker_icon_is_installed "$ROOT"; then
        printf 'Icon          : installed\n'
    else
        printf 'Icon          : missing (tools/install.sh --icon-only)\n'
    fi
    exit 0
fi

if [ "$DO_INSTALL" -eq 1 ]; then
    if ! command -v kpackagetool6 >/dev/null 2>&1; then
        printf 'kpackagetool6 not found - is Plasma 6 installed?\n' >&2
        exit 1
    fi

    if ! command -v kwallet-query >/dev/null 2>&1; then
        printf 'Note: kwallet-query is missing - the remaining balance stays unavailable (package kwallet6 or kwalletmanager).\n' >&2
    fi

    if ! STAGE="$(tracker_stage "$ROOT")"; then
        printf 'Staging failed - is %s writable? Aborting instead of installing a stale build.\n' "$ROOT/dist/stage" >&2
        exit 1
    fi

    if tracker_is_installed "$APP_ID"; then
        if [ "$INSTALLED_VERSION" = "$SRC_VERSION" ]; then
            printf 'Updating %s (%s) ...\n' "$APP_ID" "$SRC_VERSION"
        else
            printf 'Updating %s: %s -> %s ...\n' "$APP_ID" "$INSTALLED_VERSION" "$SRC_VERSION"
        fi
        kpackagetool6 --type Plasma/Applet --upgrade "$STAGE"
    else
        printf 'Installing %s (%s) ...\n' "$APP_ID" "$SRC_VERSION"
        kpackagetool6 --type Plasma/Applet --install "$STAGE"
    fi
    tracker_refresh_caches
fi

if [ "$DO_ICON" -eq 1 ]; then
    tracker_install_icon "$ROOT" || true
fi

if [ "$RESTART" -eq 1 ]; then
    tracker_restart_plasma
fi

printf '\nDone.\n'
if [ "$RESTART" -eq 0 ]; then
    printf 'If the changes are not visible: tools/install.sh --restart\n'
fi
