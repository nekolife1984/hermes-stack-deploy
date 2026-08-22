# Hermes Studio (Web UI) — 会社向け
# JPeetz/Hermes-Studio をビルドして本番サーバで起動する
FROM node:22-slim

RUN npm install -g pnpm

WORKDIR /app
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

COPY package.json pnpm-lock.yaml .npmrc ./
RUN pnpm install --no-frozen-lockfile
COPY . .

# 本番ビルド(server-entry.js で serve)
RUN pnpm build

ENV NODE_ENV=production
EXPOSE 3000
CMD ["node", "server-entry.js"]