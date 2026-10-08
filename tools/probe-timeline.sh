#!/usr/bin/env bash
#
# Check the timeline without starting plasmashell.
#
#   tools/probe-timeline.sh    render contents/ui/Timeline.qml off-screen and
#                              verify cells, axis labels and peak colours
#
# Needs the Qt 6 QML runtime (qml6) and the Kirigami QML module, both part of a
# Plasma 6 install; that is why this check is not part of the CI. It runs
# against a throwaway copy of contents/, so the working tree stays untouched.
set -euo pipefail
# shellcheck source=tools/lib.sh
source "$(dirname "$0")/lib.sh"

ROOT="$(tracker_root)"
FIXTURE="$ROOT/tests/fixtures/timeline-probe.qml"

for arg in "$@"; do
    case "$arg" in
        -h|--help) tracker_usage "$0"; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
    esac
done

if ! command -v qml6 >/dev/null 2>&1; then
    printf 'qml6 missing (package qt6-declarative-dev-tools).\n' >&2
    exit 2
fi

if [ ! -f "$FIXTURE" ]; then
    printf 'Probe fixture missing: %s\n' "$FIXTURE" >&2
    exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# The fixture sits in the stage under tests/fixtures/, so its relative imports
# point at the contents/ next to it.
mkdir -p "$STAGE/tests/fixtures"
cp -r "$ROOT/contents" "$STAGE/"
cp "$FIXTURE" "$STAGE/tests/fixtures/"

# The Plasma applet engine provides i18n(); outside plasmashell the staged copy
# imports the stub from tests/fixtures instead.
tracker_stub_i18n "$STAGE" "$ROOT/tests/fixtures/i18n-stub.js"

STATUS=0
OUTPUT="$(cd "$STAGE" && QT_QPA_PLATFORM=offscreen timeout 60 qml6 tests/fixtures/timeline-probe.qml 2>&1)" || STATUS=$?
printf '%s\n' "$OUTPUT" | sed 's/^qml: //'

if [ "$STATUS" -ne 0 ]; then
    printf '\nqml6 exited with status %s (abort instead of a result).\n' "$STATUS" >&2
    exit 1
fi

if ! printf '%s\n' "$OUTPUT" | grep -q 'PROBE OK'; then
    printf '\nTimeline probe failed.\n' >&2
    exit 1
fi

printf '\nTimeline OK.\n'
