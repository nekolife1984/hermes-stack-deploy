# Hermes Studio (Web UI) — 会社向け
# JPeetz/Hermes-Studio のソースを git clone してビルドする(agentと同様の自己完結方式)。
# このリポジトリ自体はデプロイ用スキャフォールドのみで、アプリソースは同梱しない。
FROM node:22-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends git curl \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g pnpm

# 取得元とバージョン(リリースタグでピン止め推奨)
ARG STUDIO_REPO=https://github.com/JPeetz/Hermes-Studio.git
ARG STUDIO_VERSION=v1.18.1
RUN git clone --depth 1 --branch "${STUDIO_VERSION}" "${STUDIO_REPO}" /app \
    || git clone --depth 1 "${STUDIO_REPO}" /app
WORKDIR /app

ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
RUN pnpm install --no-frozen-lockfile
# 本番ビルド(server-entry.js が dist/ を serve)
RUN pnpm build

# 非root実行
RUN addgroup -S hermes && adduser -S hermes -G hermes && chown -R hermes:hermes /app
USER hermes

ENV NODE_ENV=production
EXPOSE 3000
CMD ["node", "server-entry.js"]