# Vikunja と Hermes Agent を MCP で連携させる

エージェントに **vikunja-mcp** を MCP サーバとして登録すると、
Hermes Studio のチャットや Hermes Agent から Vikunja のタスクを直接操作できる
(タスク追加・完了・一覧・ラベル・かんばんボックス移動など)。

## 前提

1. **Vikunja APIトークン(長期有効)を発行する** — ログイン用JWT(約24hで失効)ではなく、必ず**APIトークン**を使う。
   - 取得: Vikunja UI → 右上メニュー → **設定 → APIトークン → 新規**
   - 権限: プロジェクトとタスクの read/create/update で十分。deleteまで必要なら追加。
2. Vikunja UIで初期ユーザー/プロジェクトを作っておく。

## 使い方 (npm版 — 今回のコンテナ構成向け)

エージェントコンテナには Node.js が入っているので、npx でそのまま起動できる。
`.env` の `VIKUNJA_URL` は compose で `http://vikunja:3456/api/v1` に自動設定済み。

### Hermes Studio の UI から登録するのが一番簡単

1. Hermes Studio を開く → **Settings → MCP Servers → 追加**
2. この通り入力:
   - **Name**: `vikunja`
   - **Command**: `npx`
   - **Args**: `-y  @37bytes/vikunja-mcp`
   - **Env**:
     - `VIKUNJA_URL = http://vikunja:3456/api/v1`(外部なら `http://host.docker.internal:3456/api/v1` 等)
     - `VIKUNJA_API_TOKEN = <発行したAPIトークン>`
3. 保存→ ライブリロード。チャットで「Inboxに『定例MTG資料』を追加して」等と指示できる。

### config.yaml に直接書く場合

エージェントの `~/.hermes/config.yaml` に登録する(ボリューム `hermes-home` で永続化され、
Studioの「MCP Servers」UIと同一のもの):

```yaml
mcp_servers:
  vikunja:
    command: npx
    args:
      - -y
      - "@37bytes/vikunja-mcp"
    env:
      VIKUNJA_URL: http://vikunja:3456/api/v1
      VIKUNJA_API_TOKEN: <発行したAPIトークン>
    connect_timeout: 10
```

**注:** トークンを直接 YAML に埋め込むとコミット漏れのリスクがある。可能なら
`VIKUNJA_API_TOKEN` を `.env` に置き、`env:` には `${VIKUNJA_API_TOKEN}` を使って展開させる。

## 代替の MCP サーバ

- **`@epodivilov/vikunja-mcp`** — 軽量。ペイロードがタイトでトークン消費が少ない。読み書きがツール単位で分かれていて権限制御しやすい(企業のレビュー運用に向く)。
- **Go版(acidvegas/vikunja-mcp)** — 単一Goバイナリ。Streamable HTTP も話せるのでエージェントとは別の sidecar コンテナに立ててネットワーク越しに繋げる運用も可。

## 動作確認

```bash
# エージェントコンテナ内で、まずMCPが起動・ツール一覧が出るか確認
docker compose exec hermes-agent npx -y @37bytes/vikunja-mcp --help
# ツール名は vikunja_* 形式(一覧は --help / docs/tools.md で確認)
```

または Studio のチャットから:
> 「プロジェクトの一覧を出して」「Inbox に『週次レポート』タスクを追加して」

## トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| 認証エラー(401/403) | トークンがJWTだった / 権限不足 | 長期有効なAPIトークンを使い、プロジェクト・タスクのscopeを付与 |
| `VIKUNJA_URL` に接続できない | `host.docker.internal` 未指定で外部Vikunjaを指している | compose内なら `http://vikunja:3456/api/v1`、外部なら `host.docker.internal` |
| MCPサーバが毎回起動に失敗する | npxがネットワーク取得に失敗 | 試しに `docker compose exec hermes-agent npx -y @37bytes/vikunja-mcp --help` で事前取得 |