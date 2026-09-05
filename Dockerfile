# syntax=docker/dockerfile:1

FROM alpine:3.22 AS litestream-downloader
ARG TARGETARCH
ARG LITESTREAM_VERSION=0.5.16
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
      amd64) ARCH=amd64 ;; \
      arm64) ARCH=arm64 ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    apk add --no-cache ca-certificates wget tar; \
    wget -q -O /tmp/litestream.tar.gz \
      "https://github.com/benbjohnson/litestream/releases/download/v${LITESTREAM_VERSION}/litestream-${LITESTREAM_VERSION}-linux-${ARCH}.tar.gz"; \
    mkdir -p /out; \
    tar -xzf /tmp/litestream.tar.gz -C /out; \
    test -x /out/litestream

FROM decolua/9router:latest

USER root

COPY --from=litestream-downloader /out/litestream /usr/local/bin/litestream
COPY entrypoint.sh /usr/local/bin/9router-entrypoint.sh
COPY litestream.yml /etc/litestream.yml

RUN chmod +x /usr/local/bin/litestream /usr/local/bin/9router-entrypoint.sh \
    && mkdir -p /app/data/db

ENV DATA_DIR=/app/data \
    PORT=20128 \
    HOSTNAME=0.0.0.0 \
    LITESTREAM_CONFIG=/etc/litestream.yml

EXPOSE 20128

ENTRYPOINT ["/usr/local/bin/9router-entrypoint.sh"]
