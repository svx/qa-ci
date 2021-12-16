#!/usr/bin/env bash
test -z "$TRACE" || set -x
set -euo pipefail
USAGE="Usage:
  $0 [--ignore PAT] FILE...

Validate links in markdown files/code comments.
URLs that match one of the ignore patterns are skipped.
Markdown files are checked with markdown-link-check tool.
See: https://github.com/tcort/markdown-link-check
"

# shellcheck disable=SC1091
. /ci/utils.sh

main() {
    test $# -ge 1 || { echo "Missing required FILE."; echo "$USAGE"; exit 1; }
    while [ "$#" -gt 0 ]; do
        case $1 in
            -i|--ignore) IGNORES+=("$2"); shift ;;
            -h|--help) echo "$USAGE"; exit ;;
            *) FILES+=("$1"); ;;
        esac
        shift
    done
    if test -n "${IGNORES[*]}"; then
        # update config file with ignore patterns came from args
        jq ".ignorePatterns += $(printf '{"pattern": "%s"}\n' "${IGNORES[@]}" \
            | jq -s '.')" .linkcheck.json >/tmp/.linkcheck.json
    else
        cp .linkcheck.json /tmp/.linkcheck.json
    fi
    # get all ignore patterns (config file and args)
    IGNORES_RE="$(jq -r '[(.ignorePatterns // [])[].pattern] | join("|")' </tmp/.linkcheck.json)"
    for FILE in "${FILES[@]}"; do
        if echo "$FILE" | grep -Eiq "\.md$"; then
            markdown-link-check -c /tmp/.linkcheck.json "$FILE" || EXIT_CODE=1
        else
            check_links "$FILE" "$IGNORES_RE" || EXIT_CODE=1
        fi
    done
    exit "${EXIT_CODE:-0}"
}

check_links() {
    log "FILE: $1"
    while read -r URL; do
        if test -n "$2"; then
            # ignore url if one of the ignore pattern matches
            echo "$URL" | grep -Evq "$2" || continue
        fi
        if echo "$URL" | grep -Eq "(gitlab|github).*blob"; then
            echo "$URL" | grep -Eq "blob.*?([0-9a-f]{8,}|[0-9]+(\.[0-9]+){1,2})" \
                || ERRORS+=("not a permalink")
        fi
            CURL_ERR=$(curl "$URL" -ILSfs --retry 3 --retry-delay 1 --retry-connrefused 2>&1 >/dev/null) \
                || ERRORS+=("$CURL_ERR")
        if test -z "${ERRORS[*]}"; then
            ok "$URL"
        else
            nok "$URL"
            for ERR in "${ERRORS[@]}"; do echo "    $ERR"; done
            RETURN_VALUE=1
        fi
    done < <(grep -Po '#.*\K((http|https)://[a-zA-Z0-9./?=#_%:-]+)' "$1")
    return "${RETURN_VALUE:-0}"
}

ok() { printf "  [\e[32m✓\e[0m] %s\n" "$*" >&2; }
nok() { printf "  [\e[31m✖\e[0m] %s\n" "$*" >&2; }

main "$@"
