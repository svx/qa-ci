#!/usr/bin/env bash
test -z "$TRACE" || set -x
set -eu
USAGE="Usage:
  $0 [IMAGE]...

Run basic smoke tests in a docker container to verify image functionality.
"


main() {
    echo "$*" | grep -Eqvw -- "-h|--help|help" || { echo "$USAGE"; exit; }
    if [ "${CONT_MAIN:-false}" = false ]; then
        host_main "$@"
    else
        cont_main "$@"
    fi
}


host_main() {
    test $# -gt 0 || set -- flywheel/template
    STATUS=0
    for IMG in "$@"; do
        docker run --rm \
            -e "TRACE=${TRACE:-}" \
            -e "CONT_MAIN=true" \
            -v "$(pwd):/src" \
            "$IMG" tests/test_docker.sh "$IMG" || STATUS=1
    done
    exit "$STATUS"
}


cont_main() {
    log "Running $0 $1..."
    for BIN in bash gosu tini; do
        quiet command -v "$BIN" || die "Command not found: $BIN"
    done
    test "$(id -un)" = nobody || die "Not running as nobody"
}


# logging and formatting utilities
log() { printf "\e[32mINFO\e[0m %s\n" "$*" >&2; }
err() { printf "\e[31mERRO\e[0m %s\n" "$*" >&2; }
die() { err "$@"; exit 1; }
quiet() { "$@" >/dev/null 2>&1; }


main "$@"
