# Reproducible external reader environment

The production image contains all three clients used by non-file readers:
`docker`, `kubectl` v1.31.2, and `journalctl`. The clients still need an
explicit connection to the corresponding Linux service.

Build the image and verify the installed clients:

```sh
docker build -t caddy-analyzer:reader-env .
docker run --rm --entrypoint sh caddy-analyzer:reader-env -c \
  'docker --version && kubectl version --client && journalctl --version'
```

`docker-compose.readers.yml` provides opt-in profiles for each real reader.
The default compose file remains the least-privileged local-file demo.

Docker reader (Linux Docker socket):

```sh
DOCKER_GID=$(stat -c '%g' /var/run/docker.sock) \
DOCKER_LOG_CONTAINER=caddy \
docker compose -f docker-compose.readers.yml --profile docker-reader run --rm docker-reader
```

Kubernetes reader (current kubeconfig and a real pod):

```sh
KUBECONFIG=$HOME/.kube/config KUBE_NAMESPACE=default KUBE_POD=caddy-0 \
docker compose -f docker-compose.readers.yml --profile kubernetes-reader run --rm kubernetes-reader
```

Journal reader (Linux host journal):

```sh
JOURNAL_GID=$(getent group systemd-journal | cut -d: -f3) \
JOURNAL_UNIT=caddy.service \
docker compose -f docker-compose.readers.yml --profile journal-reader run --rm journal-reader
```

The journal profile must run on a Linux host whose persistent or runtime
journal directories exist. If those files are not group-readable through
`systemd-journal` (for example an exported journal used in CI), set
`JOURNAL_USER=0` explicitly. Kubernetes requires a kubeconfig that can read
`pods/log`. Docker requires read access to the mounted daemon socket.
