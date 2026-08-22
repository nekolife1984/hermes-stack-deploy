#!/usr/bin/env bash
# =============================================================================
# setup.sh — one-shot initial setup for the Hermes Studio + Agent + Vikunja stack
#
# Automates what CAN be automated (secrets generation, .env creation, bring-up)
# and prints the remaining interactive steps as a checklist.
#
# Usage:
#   ./scripts/setup.sh            # prepare .env (idempotent) + print checklist
#   ./scripts/setup.sh up         # prepare .env, then docker compose up --build -d
#   ./scripts/setup.sh --check    # verify prerequisites + .env
#
# Idempotent: rerunning does NOT overwrite already-set values in .env.
# =============================================================================
set -euo pipefail

# ---- paths ----------------------------------------------------------------
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_TEMPLATE="$REPO_DIR/.env.example"
ENV_FILE="$REPO_DIR/.env"

# ---- is a var set (non-empty) in .env? -------------------------------------
env_get() { grep -E "^${1}=" "$ENV_FILE" 2>/dev/null | cut -d= -f2- | tr -d '"' || true; }
env_set() { python3 - "$ENV_FILE" "$1" "$2" <<'PY'
import sys, re
path, key, val = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    txt = open(path).read()
except FileNotFoundError:
    txt = ""
if re.search(rf"^{re.escape(key)}=", txt, re.M):
    txt = re.sub(rf"^{re.escape(key)}=.*$", f"{key}={val}", txt, flags=re.M)
else:
    txt += f"\n{key}={val}\n"
open(path, "w").write(txt)
print(f"  set {key}")
PY
}

# ---- checks ----------------------------------------------------------------
check_prereqs() {
  echo "== prerequisites =="
  command -v docker >/dev/null && echo "  docker: $(docker --version)" || { echo "  docker: MISSING"; return 1; }
  docker compose version >/dev/null 2>&1 && echo "  docker compose: $(docker compose version --short)" || { echo "  docker compose plugin: MISSING"; return 1; }
  command -v openssl >/dev/null && echo "  openssl: ok" || { echo "  openssl: MISSING"; return 1; }
  command -v python3 >/dev/null && echo "  python3: ok" || { echo "  python3: MISSING"; return 1; }
}

if [[ "${1:-}" == "--check" ]]; then
  check_prereqs
  [[ -f "$ENV_FILE" ]] && { echo ".env exists"; grep -qE '^API_SERVER_KEY=.+' "$ENV_FILE" && echo "  API_SERVER_KEY: set" || echo "  API_SERVER_KEY: EMPTY"; }
  exit 0
fi

# ---- build .env from template if missing -----------------------------------
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Creating $ENV_FILE from template..."
  cp "$ENV_TEMPLATE" "$ENV_FILE"
else
  echo "$ENV_FILE already exists (will not overwrite, only fill missing values)"
fi
chmod 600 "$ENV_FILE"

# ---- fill required secrets (idempotent) ------------------------------------
echo "== filling required secrets =="
[[ -z "$(env_get API_SERVER_KEY)" ]]     && env_set $ENV_FILE API_SERVER_KEY "$(openssl rand -hex 32)"
KEY="$(env_get API_SERVER_KEY)"
[[ -z "$(env_get HERMES_API_TOKEN)" ]]   && env_set $ENV_FILE HERMES_API_TOKEN "$KEY"
[[ -z "$(env_get VIKUNJA_SERVICE_SECRET)" ]] && env_set $ENV_FILE VIKUNJA_SERVICE_SECRET "$(openssl rand -base64 48)"

echo "== GitHub Copilot token (optional but recommended) =="
if [[ -z "$(env_get COPILOT_GITHUB_TOKEN)" ]]; then
  read -r -p "  COPILOT_GITHUB_TOKEN (gho_... or github_pat_...; Enter to skip, then do OAuth in-container): " copilot_token
  [[ -n "$copilot_token" ]] && env_set $ENV_FILE COPILOT_GITHUB_TOKEN "$copilot_token"
else
  echo "  COPILOT_GITHUB_TOKEN: already set (skipping)"
fi

# == validate ----------------------------------------------------------------
echo "== validate =="
docker compose -f "$REPO_DIR/docker-compose.yml" config --quiet && echo "  compose config: OK"

# == bring up ----------------------------------------------------------------
if [[ "${1:-}" == "up" ]]; then
  echo "== bring up (docker compose up --build -d) =="
  docker compose -f "$REPO_DIR/docker-compose.yml" up --build -d
fi

# == remaining manual steps --------------------------------------------------
cat <<'EOF'

===============================================================
 Setup complete for the automated parts.
 Remaining MANUAL steps (need a browser/UI or in-container OAuth):
===============================================================
 [1] Vikunja first user  -> http://localhost:3456
     - Temporarily enable registration: set VIKUNJA_SERVICE_ENABLEREGISTRATION=true
       in docker-compose.yml (or .env) then `docker compose up -d vikunja`.
     - Create the first user, then set it back to false and re-up.
 [2] Vikunja API token   -> UI: 設定 → APIトークン → new (scope: project/task read+create+update)
     - Put it in .env as VIKUNJA_API_TOKEN=<token>, then `docker compose up -d hermes-agent`.
 [3] Copilot provider    -> if you skipped the token above:
     - docker compose exec hermes-agent hermes model  → GitHub Copilot → Login with GitHub
     - (or use COPILOT_GITHUB_TOKEN you provided; ensure model.provider=copilot)
 [4] Hermes Studio onboard -> http://localhost:3000
 [5] MCP (vikunja)       -> Studio → Settings → MCP Servers → add vikunja  (see mcp/vikunja-mcp.md)
 [6] Verify              -> chat: "プロジェクトの一覧を出して" / "Inbox にタスクを追加して"
===============================================================
EOF
echo "Done."