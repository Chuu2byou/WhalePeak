#!/usr/bin/env bash
#
# Change the applet version in metadata.json.
#
#   tools/bump-version.sh 0.2.0      set an explicit version
#   tools/bump-version.sh patch      bump the last part   (0.1.0 -> 0.1.1)
#   tools/bump-version.sh minor      bump the middle part (0.1.0 -> 0.2.0)
#   tools/bump-version.sh major      bump the first part  (0.1.0 -> 1.0.0)
#
# Afterwards: git commit, then make package and make install.
set -euo pipefail
# shellcheck source=tools/lib.sh
source "$(dirname "$0")/lib.sh"

ROOT="$(tracker_root)"
cd "$ROOT"

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ -z "${1:-}" ]; then
    tracker_usage "$0"
    [ -n "${1:-}" ] || exit 2
    exit 0
fi

CURRENT="$(tracker_version "$ROOT/metadata.json")"

python3 - "$ROOT/metadata.json" "$CURRENT" "$1" <<'PY'
import json
import re
import sys

path, current, request = sys.argv[1], sys.argv[2], sys.argv[3]

parts = current.split(".")


def bump(index):
    numbers = [int(part) for part in (parts + ["0", "0", "0"])[:3]]
    numbers[index] += 1
    for position in range(index + 1, 3):
        numbers[position] = 0
    return ".".join(str(number) for number in numbers)


if request in ("major", "minor", "patch"):
    new_version = bump({"major": 0, "minor": 1, "patch": 2}[request])
elif re.fullmatch(r"\d+\.\d+\.\d+", request):
    new_version = request
else:
    sys.exit(f"Invalid version: {request} (expected: major|minor|patch or X.Y.Z)")


def read_version():
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)["KPlugin"]["Version"]


# Before replacing, check that the file is readable and matches the expected version.
if read_version() != current:
    sys.exit("metadata.json differs from the expected version")

text = open(path, encoding="utf-8").read()
updated, count = re.subn(r'("Version"\s*:\s*")[^"]*(")', rf"\g<1>{new_version}\g<2>", text, count=1)
if count != 1:
    sys.exit('Could not find "Version" in metadata.json')

open(path, "w", encoding="utf-8").write(updated)

# After replacing, make sure the file stays valid and matches.
if read_version() != new_version:
    sys.exit("Could not set the version in metadata.json")

print(new_version)
PY

NEW="$(tracker_version "$ROOT/metadata.json")"
printf 'Version: %s -> %s\n' "$CURRENT" "$NEW"
