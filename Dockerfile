# Build Stage
FROM golang:1.25-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s -X github.com/lenny-ts/caddy-analyzer/cmd.Version=${VERSION}" -o caddy-analyze ./cmd/caddy-analyze

# Production Stage. Docker and Kubernetes readers shell out to their
# respective clients, while the journal reader requires a real journalctl
# binary. Debian provides systemd's journal client; kubectl is pinned and
# checksum-verified below.
FROM debian:bookworm-slim@sha256:99c0b25c46d0214d5a2091092e7908907dcaecd6a962cde0ac700acee222b6f3

ARG TARGETARCH
ARG KUBECTL_VERSION=v1.31.2
ARG DOCKER_CLI_VERSION=29.1.3
RUN apt-get update && \
    apt-get install --yes --no-install-recommends ca-certificates curl systemd util-linux && \
    case "${TARGETARCH:-amd64}" in \
      amd64) \
        KUBECTL_SHA256=399e9d1995da80b64d2ef3606c1a239018660d8b35209fba3f7b0bc11c631c68; \
        DOCKER_ARCH=x86_64; \
        DOCKER_SHA256=c019c608ba2bb009dd673f3230e4d743f36a78d36166c6c2444c05d0aa9ff0d9 \
        ;; \
      arm64) \
        KUBECTL_SHA256=bb9fd6e5a92c2e2378954a2f1a8b4ccb2e8ba5a3635f870c3f306a53b359f971; \
        DOCKER_ARCH=aarch64; \
        DOCKER_SHA256=2219f3ac48727d8c5546b13d5d271a58856188ecb8ff1f71f9e2f9aefde3ea76 \
        ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    curl --fail --location --output /tmp/docker.tgz \
      "https://download.docker.com/linux/static/stable/${DOCKER_ARCH}/docker-${DOCKER_CLI_VERSION}.tgz" && \
    echo "${DOCKER_SHA256}  /tmp/docker.tgz" | sha256sum --check --strict && \
    tar --extract --gzip --file /tmp/docker.tgz --strip-components=1 \
      --directory /usr/local/bin docker/docker && \
    curl --fail --location --output /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH:-amd64}/kubectl" && \
    echo "${KUBECTL_SHA256}  /usr/local/bin/kubectl" | sha256sum --check --strict && \
    chmod 0755 /usr/local/bin/kubectl && \
    docker --version && \
    kubectl version --client && \
    journalctl --version && \
    rm -rf /var/lib/apt/lists/* /tmp/docker.tgz

RUN groupadd --system caddy && useradd --system --gid caddy --create-home caddy

WORKDIR /app

COPY --from=builder /app/caddy-analyze /usr/local/bin/caddy-analyze

USER caddy

ENTRYPOINT ["caddy-analyze"]
CMD ["--help"]
