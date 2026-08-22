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
# uv を導入し、以降のPython依存はすべて uv で管理(依存解決・ビルドが高速)
RUN python3 -m pip install --no-cache-dir uv
ENV UV_NO_CACHE=1

# 本プロジェクト(Hermes Agent)を editable でインストール(uv, システムPythonへ)
RUN uv pip install --system -e .

# 開発用ツール(ruff/mypy/pytest等)はシステムPythonへは入れない。
# アプリ開発時は uv で作った開発用venvへ入れる: uv venv .venv && uv pip install ruff mypy pytest

ENV HOME=/root
EXPOSE 8642
CMD ["hermes", "gateway", "run"]