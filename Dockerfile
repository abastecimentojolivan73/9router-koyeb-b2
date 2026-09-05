# syntax=docker/dockerfile:1

# ============================================================
# Stage 1 - Litestream oficial
# ============================================================
FROM litestream/litestream:latest AS litestream

# ============================================================
# Stage 2 - 9Router
# ============================================================
FROM decolua/9router:latest

USER root

# O Litestream é um binário estático.
# A imagem oficial disponibiliza o binário neste caminho.
COPY --from=litestream /usr/local/bin/litestream /usr/local/bin/litestream

# Verificação durante o build.
RUN chmod +x /usr/local/bin/litestream \
    && /usr/local/bin/litestream version

# ============================================================
# Arquivos da nossa integração
# ============================================================

COPY litestream.yml /etc/litestream.yml
COPY entrypoint.sh /entrypoint-b2.sh

RUN chmod +x /entrypoint-b2.sh

# ============================================================
# Configuração padrão do 9Router
# ============================================================

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=20128
ENV HOSTNAME=0.0.0.0
ENV DATA_DIR=/app/data
ENV NEXT_TELEMETRY_DISABLED=1

EXPOSE 20128

# ============================================================
# IMPORTANTE:
#
# O entrypoint-b2.sh fará:
#
# 1. Preparação do diretório
# 2. Verificação do SQLite
# 3. Restore do B2, se necessário
# 4. Somente depois inicia Litestream + 9Router
#
# Assim o restore NÃO concorre com o 9Router em memória.
# ============================================================

ENTRYPOINT ["/entrypoint-b2.sh"]

CMD ["node", "server.js"]
