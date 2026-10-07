# renovate: datasource=docker depName=gomods/athens
ARG ATHENS_VERSION=v0.19.2

FROM gomods/athens:${ATHENS_VERSION}

ENV GO_ENV=production \
    ATHENS_LOG_LEVEL=info \
    ATHENS_LOG_FORMAT=json \
    ATHENS_STORAGE_TYPE=s3 \
    AWS_REGION=us-east-1 \
    AWS_FORCE_PATH_STYLE=true \
    ATHENS_DOWNLOAD_MODE=async_redirect \
    ATHENS_DOWNLOAD_URL=https://proxy.golang.org \
    ATHENS_GO_BINARY_ENV_VARS=GOPROXY=https://proxy.golang.org \
    ATHENS_NETWORK_MODE=fallback \
    ATHENS_SINGLE_FLIGHT_TYPE=memory \
    ATHENS_STATS_EXPORTER=""

# Used by entrypoint.sh to size ATHENS_GOGET_WORKERS to the memory limit.
ENV GOGET_RESERVED_MIB=128 \
    GOGET_WORKER_MIB=64 \
    GOGET_MAX_WORKERS=10

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

# The upstream image creates this user but runs as root.
USER 1000

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["-config_file=/config/config.toml"]
