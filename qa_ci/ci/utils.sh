#!/usr/bin/env bash

# shellcheck disable=SC1091
[ ! -f .env ] || { set -a; . .env; set +a; }

# common regexes
export HASH_RE='[0-9a-f]{8,}$'
export MAJOR_RE="([0-9]+)"
export MINOR_RE="([0-9]+)\.([0-9]+)"
export BUGFIX_RE="([0-9]+)\.([0-9]+)\.([0-9]+)"
export VERSION_RE="[0-9]+(\.[0-9]+){1,2}"
export IMAGE_RE='[[:alnum:]]+[[:alnum:]/:.-]+[[:alnum:]]'

# logging and formatting utilities
log() { printf "\e[32mINFO\e[0m %s\n" "$*" >&2; }
err() { printf "\e[31mERRO\e[0m %s\n" "$*" >&2; }
die() { err "$@"; exit 1; }
quiet() { "$@" >/dev/null 2>&1; }
strip() { sed -E 's/^([[:space:]]*)//;s/([[:space:]]*)$//'; }

# gitlab repo cloning helper
git_clone() {
    test -z "${CI_JOB_ID:-}" || export GIT_TERMINAL_PROMPT=0
    test -n "${GITLAB_CI_BOT_READ_TOKEN:-}" \
        && URL="https://oauth2:$GITLAB_CI_BOT_READ_TOKEN@gitlab.com/$1" \
        || URL="https://gitlab.com/$1"
    CLONE="/tmp/$1"
    test -d "$CLONE" || git clone -q --depth 1 --branch master "$URL" "$CLONE"
    echo "$CLONE"
}

# helpers for getting latest docker/apk/apt/pip/github versions
latest_version() {
    log "Getting latest ${1} version for ${*:2}..."
    "_latest_${1}_version" "${@:2}"
}

_latest_pip_version() {
    _curl "https://pypi.org/pypi/$1/json" | jq -r .info.version
}

_latest_npm_version() {
    _curl "https://registry.npmjs.org/-/package/$1/dist-tags" | jq -r .latest
}

_latest_git_version() {
    for PAGE in $(seq 3); do
        TAG=$(_curl "https://api.github.com/repos/$1/tags?page=$PAGE" \
            | jq -r '.[].name' | grep -Ev 'alpha|beta|dev|rc|stable|latest' \
            | grep -E "${2:-.*}" | sed -E 's/^v//' | sort -rV | head -n1)
        test -z "$TAG" || break
    done
    test -n "$TAG" || die "Could not find latest tag for $1"
    echo "$TAG"
}

_latest_img_version() {
    # get qualified repo name (eg. library/python) and tag
    echo "$1" | grep -q / && REPO=${1/:*/} || REPO=library/${1/:*/}
    echo "$1" | grep -q : && OLD_TAG=${1/*:/} || OLD_TAG=latest
    TAGS_URL=https://registry.hub.docker.com/v2/repositories/$REPO/tags
    REPO=$(echo "$REPO" | sed -E "s|^library/||")
    # get the floating tag from the current tag
    if [ "${REPO:0:8}" = "flywheel" ]; then
        # flywheel image floating tags: branch.d34db33f => branch
        FLOATING_TAG=$(echo "$OLD_TAG" | sed -E "s/(.*)\.$HASH_RE/\1/")
    elif echo "$OLD_TAG" | grep -Eq "$BUGFIX_RE"; then
        # bugfix versioned image floating tags: 3.8.7 => 3.8
        FLOATING_TAG=$(echo "$OLD_TAG" | sed -E "s/^$BUGFIX_RE(.*)/\1.\2\4/")
    elif echo "$OLD_TAG" | grep -Eq "$MINOR_RE" && [ "$REPO" != ubuntu ]; then
        # minor versioned image floating tags: 3.8 => 3
        FLOATING_TAG=$(echo "$OLD_TAG" | sed -E "s/^$MINOR_RE(.*)/\1\3/")
    else
        # could not identify a floating tag - use the old tag for searching
        FLOATING_TAG=$OLD_TAG
    fi
    if echo "$FLOATING_TAG" | grep -Eq "[^0-9.]$VERSION_RE\$"; then
        # remove image variant version suffix: alpine3.12 => alpine
        FLOATING_TAG=$(echo "$FLOATING_TAG" | sed -E "s/(.*?)-?$VERSION_RE\$/\1/")
    fi
    # get most recent digest for the floating tag
    if [ "$FLOATING_TAG" != "$OLD_TAG" ]; then
        # use the old tag when the floating we trimmed doesn't exist
        quiet _curl "$TAGS_URL/$FLOATING_TAG" || FLOATING_TAG=$OLD_TAG
    fi
    FILT='.images[] | select(.os == "linux" and .architecture == "amd64") | .digest'
    NEW_DIGEST=$(_curl "$TAGS_URL/$FLOATING_TAG" | jq -r "$FILT" | head -n1)
    test -n "$NEW_DIGEST" || die "No digest found for $REPO:$FLOATING_TAG"
    # find the most specific tag with the same digest
    for PAGE in $(seq 3); do
        NEW_TAG=$(_curl "$TAGS_URL?ordering=last_updated&page_size=100&page=$PAGE" \
            | jq -r ".results[] | select(.images[].digest == \"$NEW_DIGEST\") | .name" \
            | grep -v latest | _sort_img | head -n1)
        test -z "$NEW_TAG" || break
    done
    if test -z "$NEW_TAG"; then
        err "Cannot find new docker tag for $REPO:$OLD_TAG"
        echo "$REPO:$OLD_TAG"
    else
        echo "$REPO:$NEW_TAG"
    fi
}

_sort_img() { awk '{print length,$0}' | sort -nrsu | cut -d" " -f2; }

_curl() {
    local CURL_STATUS=0
    local PARAM_HASH
    PARAM_HASH=$(echo "$*" | md5sum | awk '{print $1}')
    if [ ! -f "/tmp/curl/$PARAM_HASH" ]; then
        mkdir -p /tmp/curl
        set -- "$@" -fLSs --retry 3 --retry-delay 1 --retry-connrefused
        curl "$@" >"/tmp/curl/$PARAM_HASH" || CURL_STATUS="$?"
    fi
    cat "/tmp/curl/$PARAM_HASH"
    return "$CURL_STATUS"
}
