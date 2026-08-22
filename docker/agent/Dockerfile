# Hermes Agent ゲートウェイ (会社向け)
# - 本家 NousResearch/hermes-agent を取得(デフォルト)。フォークに切り替えたい場合は
#   docker compose の build.args.HERMES_AGENT_REPO を oversource-e のURLに変更。
# - Node.js を同梱し、npm系MCPサーバ(vikunja-mcp等)をエージェントから npx 実行できるようにする。
FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl git nodejs npm \
    && rm -rf /var/lib/apt/lists/*

ARG HERMES_AGENT_REPO=https://github.com/NousResearch/hermes-agent.git
ARG HERMES_AGENT_VERSION=main
RUN git clone "${HERMES_AGENT_REPO}" /app
WORKDIR /app
RUN if [ "${HERMES_AGENT_VERSION}" != "main" ]; then \
      git fetch origin && git checkout "v${HERMES_AGENT_VERSION}" || git checkout "${HERMES_AGENT_VERSION}"; \
    fi
RUN pip install --no-cache-dir -e .

# コンテナ外のVikunja(別のホスト/別コンテナ)へ繋ぐ場合の既定値は env_file / compose で上書き
ENV HOME=/root
EXPOSE 8642
CMD ["hermes", "gateway", "run"]