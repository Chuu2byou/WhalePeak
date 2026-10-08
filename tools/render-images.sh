#!/usr/bin/env bash
#
# Render the images in assets/ from the widget's own QML views.
#
#   tools/render-images.sh    write the panel/detail images and join the six
#                             palette strips into assets/themes.png
#
# Drawn off-screen by the Qt 6 QML runtime - no screen capture, no plasmashell.
# Needs qml6 + Kirigami (Plasma 6), so it runs locally only (like make probe).
# ImageMagick is optional: without it the strips stay single files.
set -euo pipefail
# shellcheck source=tools/lib.sh
source "$(dirname "$0")/lib.sh"

ROOT="$(tracker_root)"
FIXTURE="$ROOT/tests/fixtures/render-images.qml"
STUB="$ROOT/tests/fixtures/i18n-stub.js"
ASSETS="$ROOT/assets"
# Pins the timeline labels, so the images stay reproducible.
IMAGE_TZ="Europe/Berlin"

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
    printf 'Render fixture missing: %s\n' "$FIXTURE" >&2
    exit 1
fi

STAGE="$(mktemp -d)"
SHOTS="$(mktemp -d)"
trap 'rm -rf "$STAGE" "$SHOTS"' EXIT

# Fixture sits under tests/fixtures/, so its relative imports hit the staged
# contents/ next to it.
mkdir -p "$STAGE/tests/fixtures"
cp -r "$ROOT/contents" "$STAGE/"
cp "$FIXTURE" "$STAGE/tests/fixtures/"
tracker_stub_i18n "$STAGE" "$STUB"

STATUS=0
OUTPUT="$(cd "$SHOTS" && env TZ="$IMAGE_TZ" QT_QPA_PLATFORM=offscreen timeout 60 qml6 "$STAGE/tests/fixtures/render-images.qml" 2>&1)" || STATUS=$?
printf '%s\n' "$OUTPUT" | sed 's/^qml: //'

if [ "$STATUS" -ne 0 ]; then
    printf '\nqml6 exited with status %s (abort instead of a result).\n' "$STATUS" >&2
    exit 1
fi

if ! printf '%s\n' "$OUTPUT" | grep -q 'RENDER OK'; then
    printf '\nRendering failed.\n' >&2
    exit 1
fi

mkdir -p "$ASSETS"

for name in panel-off-peak panel-peak detail-combined detail-timeline; do
    if [ ! -f "$SHOTS/$name.png" ]; then
        printf 'Missing render result: %s\n' "$SHOTS/$name.png" >&2
        exit 1
    fi
    cp "$SHOTS/$name.png" "$ASSETS/$name.png"
done

shopt -s nullglob
strips=("$SHOTS"/theme-*.png)
shopt -u nullglob

if [ "${#strips[@]}" -eq 0 ]; then
    printf 'No palette strips rendered.\n' >&2
    exit 1
fi

if command -v magick >/dev/null 2>&1; then
    magick montage -background none -tile 3x2 -geometry +10+10 \
        "${strips[@]}" "$ASSETS/themes.png"
    printf 'Mosaic written: assets/themes.png (%s strips)\n' "${#strips[@]}"
elif command -v montage >/dev/null 2>&1; then
    montage -background none -tile 3x2 -geometry +10+10 \
        "${strips[@]}" "$ASSETS/themes.png"
    printf 'Mosaic written: assets/themes.png (%s strips)\n' "${#strips[@]}"
else
    for strip in "${strips[@]}"; do
        cp "$strip" "$ASSETS/"
    done
    printf 'Warning: ImageMagick missing - palette strips kept as single files, no mosaic.\n' >&2
fi

printf '\nImages in %s:\n' "$ASSETS"
ls -1 "$ASSETS" | sed 's/^/  /'
