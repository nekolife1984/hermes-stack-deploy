# Hermes Studio + Hermes Agent + Vikunja (会社向け新規環境)

会社で新しく立てるためのリファレンス一式。devcontainer / Docker Compose で
**Hermes Studio(Web UI)** と **Hermes Agent(ゲートウェイ)** を動かし、さらに
**Vikunja(タスク管理)** をエージェントから操作できるようにする。

> 元ネタ: [JPeetz/Hermes-Studio](https://github.com/JPeetz/Hermes-Studio)(本リポジトリのフォーク元)。本家の `docker-compose.yml` に **Vikunja サービスを追加**し、`.devcontainer` の**サービス名バグを修正**し、エージェントの Dockerfile に **Node.js を追加**(npm 系 MCP 対応)した。

## アーキテクチャ

```
ブラウザ ─► hermes-studio (:3000)  ─► hermes-agent HTTP API (:8642)
                                          │  vikunja-mcp (MCP, Node/npx)
                                          ▼
                                     vikunja (:3456)
```

- **hermes-agent**: Hermes Agent ゲートウェイ。モデルAPIキーは `.env` / OpenAI互換バックエンド。
- **hermes-studio**: React/TS の Web UI。cron管理・multi-agent crews・メモリグラフ・承認UIなどを提供。
- **vikunja**: タスク管理(Vikunja v2、SQLite)。エージェントが `vikunja-mcp` 経由でタスクをCRUD。

エージェントの `~/.hermes/config.yaml` はボリューム `hermes-home` で永続化。
Studio の「Settings → MCP Servers」から vikunja-mcp を登録する(手順は [mcp/vikunja-mcp.md](mcp/vikunja-mcp.md))。

## 起動

```bash
cp .env.example .env        # APIキー等を編集
docker compose up --build   # http://localhost:3000
```

- devcontainer で開くなら `.devcontainer/devcontainer.json` を使用(VS Code → "Reopen in Container")。
- Redis 永続化を使う場合: `.env` に `REDIS_URL=redis://redis:6379` を設定 → `docker compose --profile redis up`。

## 初期セットアップ

1. **Vikunja**: `http://localhost:3456` で初回ユーザー作成 → プロジェクト作成。
   → 「設定 → APIトークン」で**長期有効なAPIトークン**を発行し、`.env` の `VIKUNJA_API_TOKEN` に入れる。
2. **Hermes Studio**: `http://localhost:3000` でオンボード。
3. **MCP連携**: Studio の Settings → MCP Servers に `vikunja` を登録(詳細は [mcp/vikunja-mcp.md](mcp/vikunja-mcp.md))。
4. チャットで動作確認:「プロジェクトの一覧を出して」「Inbox にタスクを追加して」。

## 会社運用で確認すべき点

- **モデル/キー選定**: `ANTHROPIC_API_KEY` か、社内の OpenAI 互換バックエンド(`HERMES_URL`/`HERMES_MODEL`)を指定。
- **エージェント取得元**: デフォルトは本家 `NousResearch/hermes-agent`。Hermes Studio の拡張機能
  (承認・メモリグラフ等)が出ない場合は `HERMES_AGENT_REPO` を `outsourc-e` フォークに切り替え。
- **認証**: `HERMES_API_TOKEN` でエージェント↔UI 間を保護。Vikunja も外部公開なら auth を検討。
- **バージョンピン**: 再現性のため `HERMES_AGENT_VERSION=0.18.0` 等でピン止め推奨。
- **社内の既存Vikunjaを流用**する場合: compose の vikunja サービスを止め、
  `.env` の `VIKUNJA_URL` を既存インスタンスの `…/api/v1` にする。

## 構成

```
docker-compose.yml            # 3サービス(hermes-agent / hermes-studio / vikunja)+redis
docker/agent/Dockerfile      # Hermes Agent(本家取得+Node同梱)
docker/studio/Dockerfile     # Hermes Studio(本番ビルド)
.devcontainer/devcontainer.json  # devcontainer(サービス名バグ修正済み)
.env.example                 # 設定テンプレート
vikunja-config.yml           # Vikunja コンテナ設定
mcp/vikunja-mcp.md           # Vikunja 連携(MCP登録)手順
```