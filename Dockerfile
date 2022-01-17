FROM flywheel/python:main.d1938064
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]
WORKDIR /usr/local/bin

# add build-essential (make, gcc, etc.)
RUN apt-get update; \
    apt-get install -y --no-install-recommends build-essential=12.6; \
    rm -rf /var/lib/apt/lists/*

# add zstandard compression alg
ENV ZSTD_VERSION=1.5.1
RUN curl -fLSs https://github.com/facebook/zstd/releases/download/v$ZSTD_VERSION/zstd-$ZSTD_VERSION.tar.gz \
        | tar xz; \
    make -C zstd-$ZSTD_VERSION -j"$(nproc)"; \
    mv zstd-$ZSTD_VERSION/programs/zstd* ./; \
    rm -rf zstd-$ZSTD_VERSION

# shellcheck for shell script linting (for test:flywheel-lint)
ENV SHELLCHECK_VERSION=0.8.0
RUN curl -fLSs https://github.com/koalaman/shellcheck/releases/download/v$SHELLCHECK_VERSION/shellcheck-v$SHELLCHECK_VERSION.linux.x86_64.tar.xz \
        | tar xJ --strip-components=1 shellcheck-v$SHELLCHECK_VERSION/shellcheck

# hadolint for dockerfile linting (requires shellcheck - for test:flywheel-lint)
ENV HADOLINT_VERSION=2.6.0
RUN curl -fLSsO https://github.com/hadolint/hadolint/releases/download/v$HADOLINT_VERSION/hadolint-Linux-x86_64; \
    chmod +x hadolint-Linux-x86_64; \
    mv hadolint-Linux-x86_64 hadolint

# add nodejs to enable installing npm packages
ENV NODEJS_VERSION=14.17.1
RUN curl -fLSs https://nodejs.org/dist/v$NODEJS_VERSION/node-v$NODEJS_VERSION-linux-x64.tar.xz \
        | tar xJC /usr/local --strip-components=1 node-v$NODEJS_VERSION-linux-x64/{bin,include,lib,share}

# install npm packages (linters for test:flywheel-lint)
RUN npm install --global \
        jsonlint-newline-fork@1.6.8 \
        markdownlint-cli@0.30.0 \
        markdown-link-check@3.9.0 \
    ; \
    rm -rf ~/.config ~/.npm

# install npm packages (linters for test:flywheel-lint)
RUN pip install --no-cache-dir \
    black==21.12b0 \
    hadolintw==1.2.1 \
    pre-commit==2.16.0 \
    pydocstyle==6.1.1 \
    pyyaml==6.0 \
    safety==1.10.3 \
    yamllint==1.26.3

# docker client for dind usage (eg. publish:docker)
ENV DOCKER_VERSION=19.03.13
RUN curl -fLSs https://download.docker.com/linux/static/stable/x86_64/docker-$DOCKER_VERSION.tgz | \
    tar xz --strip-components=1 docker/docker

# compose for simple dind intergation environments
ENV DOCKER_COMPOSE_VERSION=1.29.2
RUN curl -fLSso docker-compose https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-Linux-x86_64; \
    chmod +x docker-compose;

# docker plugin for updating dockerhub image readmes
ENV PUSHRM_VERSION=1.8.0
RUN curl -fLSso docker-pushrm https://github.com/christian-korneck/docker-pushrm/releases/download/v$PUSHRM_VERSION/docker-pushrm_linux_amd64; \
    chmod +x docker-pushrm; \
    mkdir -p /root/.docker/cli-plugins; \
    mv docker-pushrm /root/.docker/cli-plugins

# helm, helm-docs and kubeval for test:helm-check
ENV KUBERNETES=1.15.7
ENV HELM_VERSION=3.3.4
RUN curl -fLSs https://get.helm.sh/helm-v$HELM_VERSION-linux-amd64.tar.gz | tar xz linux-amd64/helm; \
    mv linux-amd64/helm .; \
    rm -rf linux-amd64; \
    helm plugin install https://github.com/chartmuseum/helm-push.git

ENV HELM_DOCS_VERSION=1.5.0
RUN curl -fLSs https://github.com/norwoodj/helm-docs/releases/download/v$HELM_DOCS_VERSION/helm-docs_${HELM_DOCS_VERSION}_Linux_x86_64.tar.gz \
        | tar xz helm-docs

ENV KUBEVAL_VERSION=0.16.1
RUN curl -fLSs https://github.com/instrumenta/kubeval/releases/download/v$KUBEVAL_VERSION/kubeval-linux-amd64.tar.gz \
        | tar xz kubeval

ENV KUBEVAL_SCHEMA_DIR=/etc/kubeval
ENV KUBEVAL_SCHEMA_LOCATION=file://$KUBEVAL_SCHEMA_DIR
WORKDIR $KUBEVAL_SCHEMA_DIR
RUN pip install --no-cache-dir openapi2jsonschema==0.9.1; \
    openapi2jsonschema --expanded --kubernetes --stand-alone --strict \
        --output v$KUBERNETES-standalone-strict \
        https://github.com/kubernetes/kubernetes/raw/v$KUBERNETES/api/openapi-spec/swagger.json

WORKDIR /
COPY qa_ci/ /
ENTRYPOINT []
CMD ["/bin/bash"]
