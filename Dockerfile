FROM debian:buster-20210329-slim
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

# add flywheel user and common toolset
RUN apt-get update; \
    apt-get install -y --no-install-recommends \
        gosu=1.10-1+b23 \
        tini=0.18.0-1 \
    ; \
    rm -rf /var/lib/apt/lists/*

# set workdir, entrypoint and cmd
WORKDIR /src
COPY entrypoint.sh ./
ENTRYPOINT ["/src/entrypoint.sh"]
CMD ["/bin/bash", "-c", "echo hello $(id -un)"]
