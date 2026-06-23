#!/bin/sh
# Shared shim delegator. The shim's job is to be a thin proxy that makes
# goclaw's hardcoded "install dependencies" action work without the
# goclaw binary having to know about apk or version pinning.
#
# Per-tool shims set:
#   TOOL=<name>         — the binary the shim represents
#   ADD=add-<name>      — the script to run when the tool is missing
#
# Then call shim_main "$@".
#
# Behaviour:
#   --version / -V / -v → run "$ADD --version" and print its output.
#                          The add-* script returns the version it would
#                          install (via apk policy, etc.). Single source
#                          of truth for versions.
#   anything else        →
#     1. if $TOOL is on PATH and not the shim itself → exec it
#     2. else if $ADD exists at /usr/local/bin/ → run it, then re-check
#     3. else → print a generic not-installed message, exit 127
#
# Each add-* script encodes its own strategy (currently apk; can be
# swapped to mise later without changing this shim contract) and the
# version it would install. The shim has no policy.

shim_main() {
    if [ -z "$TOOL" ]; then
        echo "shim-common.sh: TOOL must be set before calling shim_main" >&2
        exit 2
    fi
    ADD="${ADD:-add-$TOOL}"
    SELF_DIR="${SELF_DIR:-$(dirname "$0")}"
    # add-* scripts are bind-mounted at /usr/local/bin/ by +self-improve.yml.
    # That dir is already in PATH at position 4, so we could call $ADD
    # directly — but using an explicit path keeps --version output
    # consistent regardless of which PATH the shim is invoked under.
    ADD_PATH="/usr/local/bin/$ADD"

    # 1. Version probe: defer to add-* --version. The add-* script
    #    returns the version it WOULD install (no actual install).
    #    This keeps version info in one place.
    case "$1" in
        --version|-V|-v)
            if [ -x "$ADD_PATH" ]; then
                "$ADD_PATH" --version
                exit $?
            fi
            echo "$TOOL not installed. Run: $ADD_PATH" >&2
            exit 127
            ;;
    esac

    # 2. Real tool on PATH? Exec it. Use realpath to dodge recursion
    #    when the shim itself is what's at $PATH/$TOOL. The shim lives
    #    at /usr/local/sbin/<tool> which is in PATH ahead of /usr/bin,
    #    so `command -v` would return the shim path. Walk PATH manually
    #    to find a non-self match.
    SELF_REAL="$(realpath "$0" 2>/dev/null || echo "$0")"
    REAL_PATH=""
    IFS=':'
    for dir in $PATH; do
        [ -z "$dir" ] && continue
        candidate="$dir/$TOOL"
        if [ -x "$candidate" ]; then
            cand_real="$(realpath "$candidate" 2>/dev/null || echo "$candidate")"
            if [ "$cand_real" != "$SELF_REAL" ]; then
                REAL_PATH="$candidate"
                break
            fi
        fi
    done
    unset IFS
    if [ -n "$REAL_PATH" ]; then
        exec "$REAL_PATH" "$@"
    fi

    # 3. Not available — run the add- script.
    if [ -x "$ADD_PATH" ]; then
        echo "[Shim] $TOOL not found, running $ADD..." >&2
        "$ADD_PATH" || {
            echo "[Shim] $ADD failed; cannot run $TOOL." >&2
            echo "$TOOL not installed. Run: $ADD_PATH" >&2
            exit 127
        }
        # Re-walk PATH now that the add- script may have installed the tool.
        REAL_PATH=""
        IFS=':'
        for dir in $PATH; do
            [ -z "$dir" ] && continue
            candidate="$dir/$TOOL"
            if [ -x "$candidate" ]; then
                cand_real="$(realpath "$candidate" 2>/dev/null || echo "$candidate")"
                if [ "$cand_real" != "$SELF_REAL" ]; then
                    REAL_PATH="$candidate"
                    break
                fi
            fi
        done
        unset IFS
        if [ -n "$REAL_PATH" ]; then
            exec "$REAL_PATH" "$@"
        fi
    fi

    # 4. No add- script, or add- didn't put the tool on PATH.
    echo "$TOOL not installed. Run: $ADD_PATH" >&2
    exit 127
}
