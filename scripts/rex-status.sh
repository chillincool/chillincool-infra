# shellcheck shell=bash
# Rex Program Status Protocol (OSC 7501) helpers for just recipes.
# https://www.superlogical.com/rex/docs/build/program-status
#
# Source it, then call `rex_track "<message>"` at the start of a recipe line:
# the tab shows `working` while the line runs, then `done` or `error` from an
# EXIT trap. Ctrl-C reports `idle`. Writes to /dev/tty so piped or captured
# stdout is untouched, and does nothing outside Rex.

rex_status() {
    [[ -n "${REX_BLOCK:-}" ]] || return 0
    # shellcheck disable=SC1003 # '\\' is the ST terminator, not an escaped quote
    { printf '\033]7501;state=%s:msg=%s\033\\' "$1" \
        "$(printf '%s' "${2:-}" | base64 | tr -d '\n')" >/dev/tty; } 2>/dev/null || true
}

_rex_finish() {
    local rc=$?
    case $rc in
        0) rex_status "done" "$_rex_msg" ;;
        130 | 143) rex_status idle "$_rex_msg (cancelled)" ;;
        *) rex_status error "$_rex_msg (exit $rc)" ;;
    esac
    exit "$rc"
}

rex_track() {
    _rex_msg="$1"
    rex_status working "$_rex_msg"
    trap _rex_finish EXIT
}
