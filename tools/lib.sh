#!/usr/bin/env bash
tracker_root() {
    cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

tracker_usage() {
    awk 'NR > 2 { if (/^#/) { sub(/^# ?/, ""); print } else { exit } }' "$1"
}

tracker_field() {
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["KPlugin"][sys.argv[2]])' "$1" "$2"
}

tracker_plugin_id() { tracker_field "$1" Id; }
tracker_version()   { tracker_field "$1" Version; }
tracker_icon_name() { tracker_field "$1" Icon; }

tracker_data_home() {
    printf '%s' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

tracker_installed_metadata() {
    printf '%s/plasma/plasmoids/%s/metadata.json' "$(tracker_data_home)" "$1"
}

tracker_installed_version() {
    local metadata
    metadata="$(tracker_installed_metadata "$1")"
    [ -f "$metadata" ] || return 0
    tracker_version "$metadata"
}

# Fail rather than install a stale or partial staging tree.
tracker_stage() {
    local root="$1"
    local stage="$root/dist/stage"
    if ! rm -rf "$stage" \
        || ! mkdir -p "$stage" \
        || ! cp "$root/metadata.json" "$stage/" \
        || ! cp -r "$root/contents" "$stage/"; then
        return 1
    fi
    find "$stage" \( -name '.DS_Store' -o -name '*~' -o -name '*.swp' \) -delete 2>/dev/null || true
    printf '%s' "$stage"
}

# Replace Plasma i18n calls in the staged QML copy for off-screen tests.
tracker_stub_i18n() {
    local stage="$1" stub="$2"
    cp "$stub" "$stage/contents/code/i18n-stub.js"
    python3 - "$stage" <<'PY'
import pathlib
import re
import sys

CALL = re.compile(r"\bi18n(cp|p|c)?\(")
ui = pathlib.Path(sys.argv[1]) / "contents" / "ui"
for path in sorted(ui.glob("*.qml")):
    text = path.read_text(encoding="utf-8")
    if "i18n" not in text:
        continue
    lines = text.splitlines(keepends=True)
    last_import = max(i for i, line in enumerate(lines) if line.startswith("import "))
    lines.insert(last_import + 1, 'import "../code/i18n-stub.js" as I18n\n')
    text = CALL.sub(lambda match: "I18n.tr" + (match.group(1) or "") + "(", "".join(lines))
    if CALL.search(text):
        sys.exit("i18n() could not be replaced in %s" % path)
    path.write_text(text, encoding="utf-8")
PY
}

tracker_is_installed() {
    [ -f "$(tracker_installed_metadata "$1")" ]
}

# Keep in sync with Balance.normalizeKey; tests/test_key_normalize.js compares both.
tracker_normalize_key() {
    local key
    key="$(cat | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    case "$key" in
        \"*\"|\'*\')
            if [ "${#key}" -ge 2 ]; then
                key="${key:1:${#key}-2}"
            fi
            ;;
    esac
    printf '%s' "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^Bearer[[:space:]]\+//I'
}

tracker_install_icon() {
    local root="$1"
    local icon_name icon_src data_home tool size dir

    icon_name="$(tracker_icon_name "$root/metadata.json")"
    icon_src="$root/contents/icons/$icon_name.png"

    if [ ! -f "$icon_src" ]; then
        printf 'Warning: icon source missing: %s\n' "$icon_src" >&2
        return 1
    fi

    if command -v magick >/dev/null 2>&1; then
        tool=magick
    elif command -v convert >/dev/null 2>&1; then
        tool=convert
    else
        printf 'Warning: ImageMagick (magick/convert) missing - skipping the icon.\n' >&2
        return 1
    fi

    data_home="$(tracker_data_home)"
    for size in 32 48 64 128 256 512; do
        dir="$data_home/icons/hicolor/${size}x${size}/apps"
        mkdir -p "$dir"
        "$tool" "$icon_src" -resize "${size}x${size}" "$dir/$icon_name.png"
    done
    printf 'Icon installed to %s/icons/hicolor.\n' "$data_home"
}

tracker_remove_icon() {
    local root="$1" icon_name data_home size
    icon_name="$(tracker_icon_name "$root/metadata.json")"
    data_home="$(tracker_data_home)"
    for size in 32 48 64 128 256 512; do
        rm -f "$data_home/icons/hicolor/${size}x${size}/apps/$icon_name.png"
    done
}

tracker_icon_is_installed() {
    local root="$1" icon_name data_home
    icon_name="$(tracker_icon_name "$root/metadata.json")"
    data_home="$(tracker_data_home)"
    [ -f "$data_home/icons/hicolor/512x512/apps/$icon_name.png" ]
}

tracker_refresh_caches() {
    if command -v kbuildsycoca6 >/dev/null 2>&1; then
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    fi
}

tracker_restart_plasma() {
    if systemctl --user cat plasma-plasmashell.service >/dev/null 2>&1; then
        printf 'Restarting plasmashell via systemd ...\n'
        systemctl --user restart plasma-plasmashell.service
        return 0
    fi
    if command -v kquitapp6 >/dev/null 2>&1; then
        printf 'Restarting plasmashell ...\n'
        kquitapp6 plasmashell 2>/dev/null || true
    fi
    if command -v plasmashell >/dev/null 2>&1; then
        setsid plasmashell >/dev/null 2>&1 &
        disown 2>/dev/null || true
    fi
}
