FROM decolua/9router:latest

USER root

ARG LITESTREAM_VERSION=0.5.16

# TARGETARCH é fornecido automaticamente pelo Docker Buildx/Koyeb.
ARG TARGETARCH=amd64

RUN set -eux; \
    apk add --no-cache ca-certificates wget tar su-exec; \
    case "${TARGETARCH}" in \
        amd64) ARCH="amd64" ;; \
        arm64) ARCH="arm64" ;; \
        *) echo "Arquitetura não suportada: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    echo "Baixando Litestream v${LITESTREAM_VERSION} para ${ARCH}..."; \
    wget -q -O /tmp/litestream.tar.gz https://github.com/benbjohnson/litestream/releases/download/v${LITESTREAM_VERSION}/litestream-${LITESTREAM_VERSION}-linux-${ARCH}.tar.gz; \
    mkdir -p /tmp/litestream; \
    tar -xzf /tmp/litestream.tar.gz -C /tmp/litestream; \
    install -m 0755 /tmp/litestream/litestream /usr/local/bin/litestream; \
    rm -rf /tmp/litestream /tmp/litestream.tar.gz; \
    litestream version

# Configuração
COPY litestream.yml /etc/litestream.yml

# Entrypoint personalizado
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

WORKDIR /app

ENTRYPOINT ["/entrypoint.sh"]

CMD ["node", "server.js"]
