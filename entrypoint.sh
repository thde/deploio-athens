#!/bin/sh
# Prepares the environment Deploio provides for athens-proxy, then starts it.
set -eu

log() {
  echo "entrypoint: $*" >&2
}

# Kubernetes injects ATHENS_PORT=tcp://<ip>:<port> when the app is named "athens",
# which athens would read as its port setting.
case ${ATHENS_PORT:-} in
tcp://*) unset ATHENS_PORT ;;
esac

# Deploio routes traffic to $PORT.
export ATHENS_PORT="${ATHENS_PORT:-${PORT:-3000}}"

# Memory available to the container in bytes, or nothing if it is unlimited or unknown.
memory_limit() {
  for f in /sys/fs/cgroup/memory.max /sys/fs/cgroup/memory/memory.limit_in_bytes; do
    [ -r "$f" ] || continue
    limit=$(cat "$f")
    case $limit in
    '' | max | *[!0-9]*) return ;;
    esac
    # cgroup v1 reports a huge number instead of "max" when unlimited.
    [ "${#limit}" -lt 19 ] && echo "$limit"
    return
  done
}

# Each background fetch runs one "go mod download" and buffers its upload to S3.
# Size the worker pool to the memory limit, unless ATHENS_GOGET_WORKERS is set.
if [ -z "${ATHENS_GOGET_WORKERS:-}" ]; then
  limit=$(memory_limit)
  if [ -n "$limit" ]; then
    mib=$((limit / 1048576))
    workers=$(((mib - GOGET_RESERVED_MIB) / GOGET_WORKER_MIB))
    [ "$workers" -lt 1 ] && workers=1
    [ "$workers" -gt "$GOGET_MAX_WORKERS" ] && workers=$GOGET_MAX_WORKERS
    export ATHENS_GOGET_WORKERS="$workers"
    log "memory limit ${mib}MiB, using ATHENS_GOGET_WORKERS=$workers"
  fi
fi

exec /bin/athens-proxy "$@"
