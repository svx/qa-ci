#!/usr/bin/env bash

# NOTE helm / kubernetes version skew
# Each helm version supports 4 minor versions of k8s (N, N-1, N-2, N-3):
#   https://helm.sh/docs/topics/version_skew/
# Using a helm version compiled against the most recent prod deployment version:
#   https://grafana.ops.flywheel.io/d/8si-2YFGz/cluster-version

replace DOCKER_VERSION=.* DOCKER_VERSION="$(latest_version git docker/engine)"
replace DOCKER_COMPOSE_VERSION=.* DOCKER_COMPOSE_VERSION="$(latest_version git docker/compose)"
replace PUSHRM_VERSION=.* PUSHRM_VERSION="$(latest_version git christian-korneck/docker-pushrm)"
replace HELM_VERSION=.* HELM_VERSION="$(latest_version git helm/helm v3.3)"
replace HELM_DOCS_VERSION=.* HELM_DOCS_VERSION="$(latest_version git norwoodj/helm-docs '^v')"
replace KUBEVAL_VERSION=.* KUBEVAL_VERSION="$(latest_version git instrumenta/kubeval)"
replace SHELLCHECK_VERSION=.* SHELLCHECK_VERSION="$(latest_version git koalaman/shellcheck)"
replace HADOLINT_VERSION=.* HADOLINT_VERSION="$(latest_version git hadolint/hadolint)"
