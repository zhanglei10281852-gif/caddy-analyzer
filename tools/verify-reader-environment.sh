#!/bin/sh
set -eu

image=${READER_IMAGE:-caddy-analyzer:reader-env}
compose=${READER_COMPOSE_FILE:-docker-compose.readers.yml}

docker build --build-arg VERSION=reader-env -t "$image" .
docker run --rm --entrypoint sh "$image" -c \
  'docker --version && kubectl version --client && journalctl --version | head -n 1'

if [ -n "${DOCKER_LOG_CONTAINER:-}" ]; then
  DOCKER_GID=${DOCKER_GID:-$(stat -c '%g' /var/run/docker.sock)} \
    docker compose -f "$compose" --profile docker-reader run --rm docker-reader
fi

if [ -n "${KUBE_POD:-}" ]; then
  : "${KUBECONFIG:?set KUBECONFIG to a real cluster configuration}"
  KUBE_NAMESPACE=${KUBE_NAMESPACE:-default} \
    docker compose -f "$compose" --profile kubernetes-reader run --rm kubernetes-reader
fi

if [ -n "${JOURNAL_UNIT:-}" ]; then
  JOURNAL_GID=${JOURNAL_GID:-$(getent group systemd-journal | cut -d: -f3)} \
    docker compose -f "$compose" --profile journal-reader run --rm journal-reader
fi

if [ -z "${DOCKER_LOG_CONTAINER:-}${KUBE_POD:-}${JOURNAL_UNIT:-}" ]; then
  echo "clients verified; set DOCKER_LOG_CONTAINER, KUBE_POD, or JOURNAL_UNIT to exercise a real reader" >&2
fi
