#!/usr/bin/env bash
test -z "$TRACE" || set -x
set -euo pipefail
USAGE="Usage:
  $0 [CHART]...

test:helm-check entrypoint running helm lint, helm dep up, helm-docs and kubeval
dockerized. Charts.yaml is searched under the helm/ if no args are specified.
Files matching test*.yaml and test*/*.yaml will be used as values files if
present.
"


main() {
    echo "$*" | grep -Eqvw -- "-h|--help|help" || { echo "$USAGE"; exit; }
    test $# -gt 0 || set -- helm/*/Chart.yaml
    test $# -gt 0 || { log "No Chart.yaml to check - exiting $0"; exit; }
    REPO=$(pwd)
    HASH=$(get_helm_hash "$REPO/helm")
    VERSION=$(get_repo_version)
    check_chart "${1/\/Chart.yaml/}"
    if [ "$(get_helm_hash "$REPO/helm")" != "$HASH" ]; then
        log "Helm files updated"
        exit 1
    fi
}


get_helm_hash() {
    find "$1" -type f -not -path "$1/render/*" -not -path "$1/*/charts/*" -exec md5sum {} \; \
        | sort -k2 | md5sum
}

get_repo_version() {
    grep -E "^version = " pyproject.toml 2>/dev/null | sed -E 's/.*"(.*)"/\1/' ||
        cat VERSION 2>/dev/null ||
        git describe --abbrev=0 --tags ||
        echo 0.1.0
}

check_chart() {
    log "Checking chart $1..."
    cd "$1" || die "Cannot cd into $1"
    log "Updating chart version and image tag to $VERSION"
    sed -Ei "s/version:.*/version: '$VERSION'/" Chart.yaml
    sed -Ei "s/tag:.*/tag: '$VERSION'/" values.yaml
    log "Running helm dependency update"
    helm dependency list | (! grep -iq missing) || helm dependency update .
    log "Running helm-docs"
    helm-docs --sort-values-order file
    TEST_VALUES=$(find . -name '*.yaml' | sed -E "s|^\./||" | grep -E "^test" || true)
    test -n "$TEST_VALUES" || echo "{}" >"${TEST_VALUES:=/tmp/empty.yaml}"
    mkdir -p "$REPO/helm/render"
    test -f .yamllint.yml && YAMLLINT_CFG=.yamllint.yml || YAMLLINT_CFG=/helm/.yamllint.yml
    for VALUES in $TEST_VALUES; do
        log "Using --values $VALUES"
        log "Running helm lint"
        helm lint . --strict --values "$VALUES"
        log "Running helm template"
        RENDERED_FILE="$REPO/helm/render/$(basename $VALUES)"
        helm template flywheel . --values "$VALUES" >"$RENDERED_FILE"
        log "Running kubeval"
        kubeval -v "$KUBERNETES" --strict --force-color "$RENDERED_FILE"
        yamllint -c "$YAMLLINT_CFG" -f colored "$RENDERED_FILE"
    done
}


# logging and formatting utilities
log() { printf "\e[32mINFO\e[0m %s\n" "$*" >&2; }
err() { printf "\e[31mERRO\e[0m %s\n" "$*" >&2; }
die() { err "$@"; exit 1; }


main "$@"
