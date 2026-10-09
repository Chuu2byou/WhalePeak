#!/usr/bin/env bash
#
# Tag the current commit with the version from metadata.json and push the tag.
#
#   tools/release.sh              create tag v<version> and push it
#   tools/release.sh --dry-run    only print the commands that would run
#
# The push triggers .github/workflows/release.yml, which runs the tests, builds
# dist/whalepeak.plasmoid and attaches it to a GitHub release. The working tree
# must be clean and the tag must not exist yet - run tools/bump-version.sh first
# if the version still needs to change.
set -euo pipefail
# shellcheck source=tools/lib.sh
source "$(dirname "$0")/lib.sh"

ROOT="$(tracker_root)"
cd "$ROOT"

DRY_RUN=0
case "${1:-}" in
    -h|--help) tracker_usage "$0"; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    "") ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
esac

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'Not a git repository.\n' >&2
    exit 1
fi

VERSION="$(tracker_version "$ROOT/metadata.json")"
TAG="v$VERSION"

if [ -n "$(git status --porcelain)" ]; then
    printf 'Uncommitted changes - commit or stash them first.\n' >&2
    exit 1
fi

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    printf 'Tag %s already exists - bump the version first.\n' "$TAG" >&2
    exit 1
fi

COMMIT="$(git rev-parse --short HEAD)"
printf 'Tagging %s as %s ...\n' "$COMMIT" "$TAG"

if [ "$DRY_RUN" -eq 1 ]; then
    printf 'Dry run: git tag -a %s -m "WhalePeak %s" && git push origin %s\n' \
        "$TAG" "$VERSION" "$TAG"
    exit 0
fi

git tag -a "$TAG" -m "WhalePeak $VERSION"
git push origin "$TAG"

printf 'Pushed %s - the release workflow will publish the package.\n' "$TAG"
