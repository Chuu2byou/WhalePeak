#!/usr/bin/env bash
#
# Build a distributable .plasmoid archive from the sources.
#
#   tools/package.sh              -> dist/whalepeak.plasmoid
#                                    dist/whalepeak-<version>.plasmoid
#
# The archive only contains metadata.json and contents/, so keep it clean of
# docs, tests and tooling.
set -euo pipefail
# shellcheck source=tools/lib.sh
source "$(dirname "$0")/lib.sh"

ROOT="$(tracker_root)"
cd "$ROOT"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    tracker_usage "$0"
    exit 0
fi

VERSION="$(tracker_version "$ROOT/metadata.json")"
DIST="$ROOT/dist"
if ! STAGE="$(tracker_stage "$ROOT")"; then
    printf 'Staging failed - is %s writable? Aborting.\n' "$DIST/stage" >&2
    exit 1
fi

python3 - "$STAGE" "$DIST/whalepeak.plasmoid" "$DIST/whalepeak-$VERSION.plasmoid" <<'PY'
import os
import shutil
import sys
import zipfile

stage, primary, versioned = sys.argv[1], sys.argv[2], sys.argv[3]

for path in (primary, versioned):
    if os.path.exists(path):
        os.remove(path)

with zipfile.ZipFile(primary, "w", zipfile.ZIP_DEFLATED) as archive:
    for dirpath, dirnames, filenames in os.walk(stage):
        dirnames.sort()
        for name in sorted(filenames):
            full = os.path.join(dirpath, name)
            archive.write(full, os.path.relpath(full, stage))

shutil.copyfile(primary, versioned)
PY

printf 'Package built: %s\n' "dist/whalepeak.plasmoid"
printf 'Package built: %s\n' "dist/whalepeak-$VERSION.plasmoid"
