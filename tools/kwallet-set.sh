#!/usr/bin/env bash
#
# Store the DeepSeek API key in KWallet.
#
#   printf %s "$DEEPSEEK_API_KEY" | tools/kwallet-set.sh
#   tools/kwallet-set.sh --key sk-... [--wallet kdewallet] [--folder DeepSeek] [--entry api_key]
#   tools/kwallet-set.sh --check
#
# Non-interactive: the key comes from --key or from stdin, never from a prompt.
# A locked wallet would let kwallet-query wait for the password dialog, so both
# calls run under `timeout` (KEY_TIMEOUT below) and give up after 20 seconds
# instead of blocking the caller. The widget reads the same entry back with
# kwallet-query, see contents/code/balance.js.
set -euo pipefail
# shellcheck source=tools/lib.sh
source "$(dirname "$0")/lib.sh"

WALLET="kdewallet"
FOLDER="DeepSeek"
ENTRY="api_key"
KEY=""
CHECK_ONLY=0
# Keep in sync with walletTimeoutMs (contents/ui/main.qml) and keyTimeoutMs
# (contents/ui/configGeneral.qml).
KEY_TIMEOUT=20

while [ "$#" -gt 0 ]; do
    case "$1" in
        --wallet) WALLET="$2"; shift 2 ;;
        --folder) FOLDER="$2"; shift 2 ;;
        --entry)  ENTRY="$2"; shift 2 ;;
        --key)    KEY="$2"; shift 2 ;;
        --check)  CHECK_ONLY=1; shift ;;
        -h|--help) tracker_usage "$0"; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
done

if ! command -v kwallet-query >/dev/null 2>&1; then
    printf 'kwallet-query not found - please install the kwallet6 or kwalletmanager package.\n' >&2
    exit 1
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
    printf 'Wallet : %s\n' "$WALLET"
    printf 'Folder : %s\n' "$FOLDER"
    printf 'Entry  : %s\n' "$ENTRY"
    if stored="$(timeout "$KEY_TIMEOUT" kwallet-query -r "$ENTRY" -f "$FOLDER" "$WALLET" 2>/dev/null)"; then
        if [ -n "$stored" ]; then
            printf 'Status : key present\n'
        else
            printf 'Status : entry present, but empty\n'
        fi
    else
        printf 'Status : no key found (or wallet locked: aborted after %s s)\n' "$KEY_TIMEOUT"
    fi
    exit 0
fi

# No key as an argument: read it from stdin. There is deliberately no prompt, so
# the script stays usable inside scripts and pipelines.
if [ -z "$KEY" ] && [ ! -t 0 ]; then
    KEY="$(cat)"
fi

# Same normalisation as contents/code/balance.js (normalizeKey), shared with the
# other tools via tools/lib.sh: line breaks and surrounding whitespace, one pair
# of surrounding quotes and a leading "Bearer " are removed, so script and widget
# store identically.
KEY="$(printf '%s' "$KEY" | tracker_normalize_key)"

if [ -z "$KEY" ]; then
    printf 'No key received. Usage: printf %%s "$DEEPSEEK_API_KEY" | %s\n' "$0" >&2
    exit 2
fi

# printf without a line break, so the key lands in KWallet exactly as given.
if ! printf '%s' "$KEY" | timeout "$KEY_TIMEOUT" kwallet-query -w "$ENTRY" -f "$FOLDER" "$WALLET"; then
    printf 'Saving failed or aborted after %s s (wallet locked?).\n' "$KEY_TIMEOUT" >&2
    exit 1
fi
printf 'Key stored in %s/%s/%s.\n' "$WALLET" "$FOLDER" "$ENTRY"
