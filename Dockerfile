FROM decolua/9router:latest

USER root

# Instala dependências mínimas
RUN apk add --no-cache \
    ca-certificates \
    wget \
    tar

# Baixa o Litestream v0.5.16 para Linux amd64
RUN wget -O /tmp/litestream.tar.gz \
    https://github.com/benbjohnson/litestream/releases/download/v0.5.16/litestream-0.5.16-linux-amd64.tar.gz \
    && mkdir -p /tmp/litestream \
    && tar -xzf /tmp/litestream.tar.gz -C /tmp/litestream \
    && install -m 0755 /tmp/litestream/litestream /usr/local/bin/litestream \
    && rm -rf /tmp/litestream /tmp/litestream.tar.gz \
    && /usr/local/bin/litestream version

# Configuração do Litestream
COPY litestream.yml /etc/litestream.yml

# Nosso entrypoint
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

WORKDIR /app

ENTRYPOINT ["/entrypoint.sh"]

CMD ["node", "server.js"]
