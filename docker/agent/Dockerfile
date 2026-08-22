# Hermes Agent ゲートウェイ (会社向け)
# - 本家 NousResearch/hermes-agent を取得(デフォルト)。フォークに切り替えたい場合は
#   docker compose の build.args.HERMES_AGENT_REPO を outsourc-e のURLに変更。
# - Node.js 22 LTS (nodesource) を同梱し、npm系MCPサーバ(vikunja-mcp等)を npx 実行可能にする。
#   ※ bookworm の apt 標準 nodejs は Node 18(EOL)のため利用しない。
FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl git ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

ARG HERMES_AGENT_REPO=https://github.com/NousResearch/hermes-agent.git
ARG HERMES_AGENT_VERSION=main
RUN git clone "${HERMES_AGENT_REPO}" /app
WORKDIR /app
RUN if [ "${HERMES_AGENT_VERSION}" != "main" ]; then \
      git fetch origin && git checkout "v${HERMES_AGENT_VERSION}" || git checkout "${HERMES_AGENT_VERSION}"; \
    fi
RUN pip install --no-cache-dir -e .

# uv (高速なPythonパッケージマネージャ) を同梱 — エージェント/スクリプトから呼び出せるように
RUN python3 -m pip install --no-cache-dir uv

# Python開発ツール(最低限) — ランタイム画像を軽く保つため必要最小限に
#   ruff(lint/format) / mypy(型) / pytest(テスト)
RUN python3 -m pip install --no-cache-dir \
    ruff mypy pytest

ENV HOME=/root
EXPOSE 8642
CMD ["hermes", "gateway", "run"]