#!/usr/bin/env bash
test -z "$TRACE" || set -x
set -euo pipefail
USAGE="Usage:
  $0

Update .gitlab-ci.yml and .pre-commit-config.yaml references and docker images.
"

# shellcheck disable=SC1091
. /ci/utils.sh

main() {
    echo "$*" | grep -Eqvw -- "-h|--help|help" || { echo "$USAGE"; exit; }

    GITLAB_CI_YAMLS=".gitlab-ci.yml ${GITLAB_CI_YAMLS:-}"
    for GITLAB_CI_YAML in $GITLAB_CI_YAMLS; do
        test "${PIN_CI_REFS:-}" = true || update_gitlabci_refs "$GITLAB_CI_YAML"
        update_gitlabci_images "$GITLAB_CI_YAML"
    done

    test "${PIN_PRECOMMIT_REFS:-}" = true || quiet pre-commit autoupdate || true
    PRECOMMIT_YAMLS_GLOB=(.pre-commit-*.yaml)
    PRECOMMIT_YAMLS="${PRECOMMIT_YAMLS_GLOB[*]} ${PRECOMMIT_YAMLS:-}"
    for PRECOMMIT_YAML in $PRECOMMIT_YAMLS; do
        update_precommit_images "$PRECOMMIT_YAML" docker_image
        update_precommit_images "$PRECOMMIT_YAML" system
    done
}

update_gitlabci_refs() {
    log "Updating $1 include refs"
    grep -q "include:" "$1" || return 0
    FILTER='.include[] | select(has("project") and has("ref")) | .project'
    for PROJECT in $(yq -r "$FILTER" "$1" | sort -u); do
        CLONE=$(git_clone "$PROJECT")
        NEW=$(cd "$CLONE" && git rev-parse --short=8 HEAD)
        grep -En "project: ['\"]?$PROJECT" "$1" | while read -r LINE; do
            LINE_NO=$(echo "$LINE" | sed -E "s|^([0-9]+).*|\1|")
            LINES="$((LINE_NO+1)),$((LINE_NO+2))"
            sed -Ei "${LINES}s|(ref: )[^[:space:]]+(.*)|\1$NEW\2|" "$1"
        done
    done
}

update_gitlabci_images() {
    log "Updating $1 image refs"
    grep -q "image:" "$1" || return 0
    FILTER='.[] | select(type=="object" and has("image")) | .image'
    IMAGES=$(yq -r "$FILTER" "$1" | _sort_img)
    for IMG in $IMAGES; do
        NEW="$(latest_version img "$IMG")"
        test "$NEW" != "$IMG" || continue
        log "$IMG -> $NEW"
        sed -Ei "s|(image: )['\"]?${IMG}['\"]?( .*)?\$|\1$NEW\2|" "$1"
    done
}

update_precommit_images() {
    log "Updating $1 image refs ($2)"
    test "$1" = .pre-commit-hooks.yaml && ROOT=".[]" || ROOT=".repos[].hooks[]"
    test "$2" = system && \
        RE="\w+_IMAGE=[\"']?($IMAGE_RE)[\"']?[; ]" || \
        RE="^[\"']?($IMAGE_RE)[\"']?"
    FILTER="$ROOT | select(type==\"object\" and .language==\"$2\") | .entry"
    IMAGES=$(yq -r "$FILTER" "$1" \
        | { grep -Eo "$RE" || true; } | sed -E "s|$RE|\1|" | _sort_img)
    for IMG in $IMAGES; do
        NEW="$(latest_version img "$IMG")"
        test "$NEW" != "$IMG" || continue
        log "$IMG -> $NEW"
        test "$2" = system && \
            SUB="(\w+_IMAGE=)[\"']?${IMG}[\"']?" || \
            SUB="(entry: )[\"']?${IMG}[\"']?"
        sed -Ei "s|$SUB(\b.*)|\1$NEW\2|" "$1"
    done
}

main "$@"
