FROM decolua/9router:latest

USER root

# Versão do Litestream
ARG LITESTREAM_VERSION=0.5.16

# Instala dependências mínimas e o Litestream
RUN set -eux; \
    apk add --no-cache \
        ca-certificates \
        wget \
        tar \
        su-exec; \
    case "${TARGETARCH:-amd64}" in \
        amd64) ARCH="amd64" ;; \
        arm64) ARCH="arm64" ;; \
        *) \
            echo "Unsupported TARGETARCH: ${TARGETARCH:-amd64}" >&2; \
            exit 1 \
            ;; \
    esac; \
    wget -q \
        -O /tmp/litestream.tar.gz \
        "https://github.com/benbjohnson/litestream/releases/download/v${LITESTREAM_VERSION}/litestream-${LITESTREAM_VERSION}-linux-${ARCH}.tar.gz"; \
    mkdir -p /tmp/litestream; \
    tar -xzf /tmp/litestream.tar.gz -C /tmp/litestream; \
    install -m 0755 /tmp/litestream/litestream /usr/local/bin/litestream; \
    rm -rf /tmp/litestream /tmp/litestream.tar.gz; \
    litestream version

# Configuração do Litestream
COPY litestream.yml /etc/litestream.yml

# EntryPoint personalizado:
# 1. restaura o banco se necessário
# 2. inicia o Litestream
# 3. inicia o 9Router
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

# Mantém o diretório padrão da imagem original
WORKDIR /app

ENTRYPOINT ["/entrypoint.sh"]

# Comando original do 9Router
CMD ["node", "server.js"]
