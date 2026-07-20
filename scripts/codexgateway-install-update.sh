#!/usr/bin/env bash
set -euo pipefail

# In-app update helper. Bundled as Resources/codexgateway-install-update.
# Supports:
#   - replace install: --target PATH --new-app PATH --pid PID [--remove-legacy PATH]
#   - rename in place: --rename-from PATH --rename-to PATH --pid PID
#     (used when an older updater left the new binary inside CodexBar.app)

TARGET=""
NEW_APP=""
PID=""
REMOVE_LEGACY=""
RENAME_FROM=""
RENAME_TO=""
RELAUNCH=1
RELAUNCH_ONLY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            TARGET="$2"
            shift 2
            ;;
        --new-app)
            NEW_APP="$2"
            shift 2
            ;;
        --pid)
            PID="$2"
            shift 2
            ;;
        --remove-legacy)
            REMOVE_LEGACY="$2"
            shift 2
            ;;
        --rename-from)
            RENAME_FROM="$2"
            shift 2
            ;;
        --rename-to)
            RENAME_TO="$2"
            shift 2
            ;;
        --relaunch-only)
            RELAUNCH_ONLY=1
            shift
            ;;
        --no-relaunch)
            RELAUNCH=0
            shift
            ;;
        -h|--help)
            echo "Usage:"
            echo "  $0 --target PATH (--new-app PATH | --relaunch-only) --pid PID [--remove-legacy PATH] [--no-relaunch]"
            echo "  $0 --rename-from PATH --rename-to PATH --pid PID [--no-relaunch]"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

is_app_bundle() {
    local path="$1"
    [[ -n "$path" && "$path" == *.app ]]
}

wait_for_pid_exit() {
    local pid="$1"
    for _ in $(seq 1 120); do
        if ! kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
        sleep 0.5
    done
    if kill -0 "$pid" 2>/dev/null; then
        echo "Timed out waiting for process $pid to exit." >&2
        exit 1
    fi
}

if [[ -z "$PID" ]]; then
    echo "Missing required --pid." >&2
    exit 2
fi

# --- Rename mode: CodexBar.app → CodexGateway.app after an old-updater install ---
if [[ -n "$RENAME_FROM" || -n "$RENAME_TO" ]]; then
    if [[ -z "$RENAME_FROM" || -z "$RENAME_TO" ]]; then
        echo "Rename mode requires both --rename-from and --rename-to." >&2
        exit 2
    fi
    if ! is_app_bundle "$RENAME_FROM" || ! is_app_bundle "$RENAME_TO"; then
        echo "Rename paths must be .app bundles." >&2
        exit 2
    fi
    if [[ "$RENAME_FROM" == "$RENAME_TO" ]]; then
        echo "Rename source and destination are the same." >&2
        exit 2
    fi

    wait_for_pid_exit "$PID"

    if [[ ! -d "$RENAME_FROM" ]]; then
        echo "Rename source not found: $RENAME_FROM" >&2
        exit 1
    fi

    # If destination already exists, replace it with the renamed source.
    if [[ -e "$RENAME_TO" ]]; then
        rm -rf "$RENAME_TO"
    fi
    mv "$RENAME_FROM" "$RENAME_TO"
    xattr -cr "$RENAME_TO" 2>/dev/null || true

    if [[ "$RELAUNCH" -eq 1 ]]; then
        open "$RENAME_TO"
    fi
    exit 0
fi

# --- Install / replace mode ---
if [[ -z "$TARGET" ]]; then
    echo "Missing required --target (or use --rename-from/--rename-to)." >&2
    echo "Usage: $0 --target PATH (--new-app PATH | --relaunch-only) --pid PID [--remove-legacy PATH] [--no-relaunch]" >&2
    exit 2
fi

if ! is_app_bundle "$TARGET"; then
    echo "Target must be an .app bundle path: $TARGET" >&2
    exit 2
fi

if [[ "$RELAUNCH_ONLY" -eq 0 ]]; then
    if [[ -z "$NEW_APP" ]]; then
        echo "Missing --new-app (or pass --relaunch-only)." >&2
        exit 2
    fi
    if [[ ! -d "$NEW_APP" ]]; then
        echo "New app bundle not found: $NEW_APP" >&2
        exit 1
    fi
    if ! is_app_bundle "$NEW_APP"; then
        echo "New app must be an .app bundle path: $NEW_APP" >&2
        exit 2
    fi
fi

wait_for_pid_exit "$PID"

if [[ "$RELAUNCH_ONLY" -eq 0 ]]; then
    mkdir -p "$(dirname "$TARGET")"
    rm -rf "$TARGET"
    ditto "$NEW_APP" "$TARGET"
    xattr -cr "$TARGET" 2>/dev/null || true

    if [[ -n "$REMOVE_LEGACY" && -d "$REMOVE_LEGACY" && "$REMOVE_LEGACY" != "$TARGET" ]]; then
        if ! is_app_bundle "$REMOVE_LEGACY"; then
            echo "Refusing to remove non-.app legacy path: $REMOVE_LEGACY" >&2
            exit 2
        fi
        rm -rf "$REMOVE_LEGACY"
    fi
fi

if [[ "$RELAUNCH_ONLY" -eq 1 || "$RELAUNCH" -eq 1 ]]; then
    open "$TARGET"
fi
