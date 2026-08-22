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

- **hermes-agent**: Hermes Agent ゲートウェイ。モデルプロバイダは **GitHub Copilot**(モデルAPIキー不要)。
- **hermes-studio**: React/TS の Web UI。cron管理・multi-agent crews・メモリグラフ・承認UIなどを提供。
- **vikunja**: タスク管理(Vikunja 2.5.0、SQLite)。エージェントが `vikunja-mcp` 経由でタスクをCRUD。

エージェントの `~/.hermes/config.yaml` はボリューム `hermes-home` で永続化。
Studio の「Settings → MCP Servers」から vikunja-mcp を登録する(手順は [mcp/vikunja-mcp.md](mcp/vikunja-mcp.md))。

## 初期セットアップ手順（起動前 → 起動後）

> 見分け方: **「コンテナ起動が成立するために要るか」**。`.env`の必須変数は起動前、
> サービス/ブラウザ/インタラクションが要るものは起動済みでないとできない。
>
> **自動化**: シークレット生成〜`.env`作成〜起動までを `./scripts/setup.sh` で自動化できる
> (冪等・対話式)。手動の要点は以下のとおり。

### Phase 0 — 起動「前」: `.env` を用意（これが無いと起動しない）

```bash
cp .env.example .env
# 必須4つを埋める(未設定だと docker compose up / devcontainer が `${VAR:?}` で失敗する):
#   API_SERVER_KEY      ※ openssl rand -hex 32
#   HERMES_API_TOKEN    = API_SERVER_KEY と同値
#   VIKUNJA_SERVICE_SECRET  ※ openssl rand -base64 48
#   COPILOT_GITHUB_TOKEN    ← 方式A(トークン)でCopilotを使うならここも起動前
chmod 600 .env
```

### Phase 1 — 起動

```bash
docker compose up --build        # → http://localhost:3000
```
- devcontainer を使う場合: VS Code → **「Reopen in Container」**。開いた瞬間にcomposeスタックが
  起動するので、`.env` は必ず「ここ」より前に置いておくこと。
- Redis 永続化: `.env` に `REDIS_URL` / `REDIS_PASSWORD` → `docker compose --profile redis up`。

### Phase 2 — 起動「後」: Vikunja初期化（1度だけ再起動が挟まる）

1. **Vikunja 初回ユーザー作成**(`http://localhost:3456`): 一時的に登録ONにするため
   compose の `VIKUNJA_SERVICE_ENABLEREGISTRATION` を `"true"` にして起動 → ユーザー作成。
2. **APIトークン発行**: Vikunja UI → 設定 → APIトークン → 新規(プロジェクト/タスク read+create+update権限)。
3. `.env` の `VIKUNJA_API_TOKEN` に追記(ホスト上の `.env` を編集)。
4. **登録OFFで再起動**: `VIKUNJA_SERVICE_ENABLEREGISTRATION` を `"false"` に戻し
   `docker compose up -d`(または devcontainer 再open)して反映。
   > これが唯一の「起動後→.env再編集→再起動」をまたぐ手順。最初の一度だけ。

### Phase 3 — モデル・Studio・MCP（起動済みで実施）

5. **モデルプロバイダ(GitHub Copilot)**: エージェントを Copilot で動かす(モデルAPIキー不要)。
   ```bash
   # 方式A: .env の COPILOT_GITHUB_TOKEN(gho_ / github_pat_)を利用(Phase0で設定済みなら不要)
   # 方式B: コンテナ内でOAuthデバイスコードを一度流す(トークンは hermes-home に永続化)
   docker compose exec hermes-agent hermes model   # → GitHub Copilot → Login with GitHub
   ```
   ※ classic PAT(`ghp_`)はCopilot APIで使えない点に注意。
6. **Hermes Studio オンボード**: `http://localhost:3000` — エージェントの `API_SERVER_KEY` と
   `HERMES_API_TOKEN` が一致していれば接続成功。
7. **MCP連携**: Studio → Settings → MCP Servers → `vikunja` を追加
   (詳細は [mcp/vikunja-mcp.md](mcp/vikunja-mcp.md))。
8. **動作確認**: チャットで「プロジェクトの一覧を出して」「Inbox にタスクを追加して」が通るか。

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
scripts/setup.sh             # 初期セットアップ自動化(シークレット/.env/起動)
scripts/backup-volumes.sh    # volumeのバックアップ
.gitignore / .dockerignore   # シークレット・ビルドcontext漏れ防止
```