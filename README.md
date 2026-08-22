# Hermes Studio + Hermes Agent + Vikunja (会社向け新規環境)

会社で新しく立てるためのリファレンス一式。devcontainer / Docker Compose で
**Hermes Studio(Web UI)** と **Hermes Agent(ゲートウェイ)** を動かし、さらに
**Vikunja(タスク管理)** をエージェントから操作できるようにする。

> 元ネタ: [JPeetz/Hermes-Studio](https://github.com/JPeetz/Hermes-Studio)。本リポジトリは
> デプロイ用スキャフォールド(**アプリソースは同梱しない**)。Hermes Studio 本体は
> `docker/studio/Dockerfile` 内で git clone してビルドする(agent と同様の自己完結方式)。

## アーキテクチャ

```
ブラウザ ─► hermes-studio (:3000)  ─► hermes-agent HTTP API (:8642) [Bearer: API_SERVER_KEY]
                                            │  vikunja-mcp (MCP, Node/npx)
                                            ▼
                                       vikunja (:3456)
```

- **hermes-agent**: Hermes Agent ゲートウェイ。モデルAPIキーは `.env` / OpenAI互換バックエンド。
- **hermes-studio**: React/TS の Web UI。cron管理・multi-agent crews・メモリグラフ・承認UIなどを提供。
- **vikunja**: タスク管理(Vikunja 2.5.0、SQLite)。エージェントが `vikunja-mcp` 経由でタスクをCRUD。

エージェントの `~/.hermes/config.yaml` はボリューム `hermes-home` で永続化。
Studio の「Settings → MCP Servers」から vikunja-mcp を登録する(手順は [mcp/vikunja-mcp.md](mcp/vikunja-mcp.md))。

## 起動

```bash
cp .env.example .env        # 編集: API_SERVER_KEY / VIKUNJA_SERVICE_SECRET は必須
docker compose up --build   # → http://localhost:3000
```

- devcontainer で開くなら `.devcontainer/devcontainer.json` を使用(VS Code → "Reopen in Container")。
- Redis 永続化を使う場合: `.env` に `REDIS_URL` と `REDIS_PASSWORD` を設定 → `docker compose --profile redis up`。

## 初期セットアップ

1. **Vikunja**: `http://localhost:3456` — 初期ユーザー作成用に一時的に
   registration を有効化する。compose の `VIKUNJA_SERVICE_ENABLEREGISTRATION` を `"true"` にして
   起動 → ユーザー作成後、すぐ `"false"` に戻して再起動。
   → 「設定 → APIトークン」で**長期有効なAPIトークン**を発行し、`.env` の `VIKUNJA_API_TOKEN` に入れる。
2. **Hermes Studio**: `http://localhost:3000` でオンボード(エージェントの `API_SERVER_KEY` と
   `HERMES_API_TOKEN` が一致していれば接続成功)。
3. **MCP連携**: Studio の Settings → MCP Servers に `vikunja` を登録(詳細は [mcp/vikunja-mcp.md](mcp/vikunja-mcp.md))。
4. チャットで動作確認:「プロジェクトの一覧を出して」「Inbox にタスクを追加して」。

## セキュリティ / 会社運用の要点

- **認証**: エージェントAPI(:8642)は `API_SERVER_KEY` で保護(Studioは `HERMES_API_TOKEN`=同値)。
  `.env` は `chmod 600`、**絶対にコミットしない**(`.gitignore` 済み)。
- **ポート**: 3サービスとも `127.0.0.1` に绑定。LAN/社外へ公開する場合は
  **TLSリバースプロキシ + 認証(SSO/basic auth)** を前段に置き、内部ネットワーク経由のみを通すこと。
- **Vikunja**: JWT秘密は `VIKUNJA_SERVICE_SECRET`(未設定なら起動しない)。登録は初期セットアップ時だけ有効に。
- **バックアップ**: `docker compose down -v` で全データを失う。volume の定期的バックアップを設ける
  (`hermes-home`=エージェントのメモリ/設定、`vikunja-db`=タスクDB、`studio-sessions`=会話)。
- **バージョンピン**: `HERMES_AGENT_VERSION` / `STUDIO_VERSION` はリリースタグでピン止め推奨(再現性)。
- **ベースイメージ**: 漂移を避けるならタグ+ダイジェストをピン。ビルドは `docker compose --pull build` で冒頭検証できる。

## バックアップ

`docker compose down -v` / `docker system prune -a --volumes` / ホスト故障で
**エージェントの記憶(hermes-home)やタスクDB(vikunja-db)が全損**する。定期的にvolumeを退避する:

```bash
./scripts/backup-volumes.sh --check           # どのvolumeがあるか確認
./scripts/backup-volumes.sh                   # ./backups/<日時>/ に tar.gz 出力
BACKUP_DIR=/mnt/backup ./scripts/backup-volumes.sh   # 場所を指定
```
復元例と注意はスクリプト内に記載。社内運用では `restic`/`rclone` で
オフサイト暗号化バックアップ＋週次実行(ボクのcronでも回せるよ)を推奨。

## CI / 検証

GitHub Actions(`.github/workflows/validate.yml`)がPR・main pushで自動実行:
compose config バリデーション → 3イメージのビルドスモーク(`docker compose build`) → gitleaks シークレットスキャン。

## 構成

```
docker-compose.yml            # 3サービス(hermes-agent / hermes-studio / vikunja)+redis
docker/agent/Dockerfile      # Hermes Agent(本家取得+Node22同梱)
docker/studio/Dockerfile     # Hermes Studio(JPeetz/Hermes-Studioをクローンしてビルド、非root)
.devcontainer/devcontainer.json  # devcontainer(サービス名バグ修正済み)
.env.example                 # 設定テンプレート(API_SERVER_KEY / VIKUNJA_SERVICE_SECRET 必須)
vikunja-config.yml           # Vikunja コンテナ設定(secretはenv注入)
mcp/vikunja-mcp.md           # Vikunja 連携(MCP登録)手順
.gitignore / .dockerignore   # シークレット・ビルドcontext漏れ防止
```