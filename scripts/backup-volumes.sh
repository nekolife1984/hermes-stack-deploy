#!/usr/bin/env bash
# =============================================================================
# backup-volumes.sh — snapshot Hermes Studio / Hermes Agent / Vikunja named
# volume data into a host backup dir, using an ephemeral alpine container + tar.
#
# Volumes backed up (only those that exist on the host):
#   hermes-home       agent memory / config.yaml / MCP tokens / sessions
#   vikunja-db        Vikunja SQLite DB (tasks)
#   vikunja-files     Vikunja attachments
#   studio-sessions   Hermes Studio chat sessions (file store)
#
# Usage:
#   ./scripts/backup-volumes.sh                 # backup into ./backups/<date>/
#   BACKUP_DIR=/abs/path ./scripts/backup-volumes.sh
#   ./scripts/backup-volumes.sh --check         # list which volumes this host has
# =============================================================================
set -euo pipefail

# Named volumes managed by docker-compose.yml
VOLUMES=(hermes-home vikunja-db vikunja-files studio-sessions)

# Project name must match how `docker compose` names its volumes (dir basename -
# underscores). Override with COMPOSE_PROJECT_NAME if yours differs.
PROJECT="${COMPOSE_PROJECT_NAME:-$(basename "$(dirname "$0")/..")}"
BACKUP_DIR="${BACKUP_DIR:-$(pwd)/backups}"
DATE="$(date +%Y%m%d_%H%M%S)"
OUT="$BACKUP_DIR/$DATE"

if [[ "${1:-}" == "--check" ]]; then
  echo "Backup dir: $BACKUP_DIR"
  echo "Project prefix: $PROJECT"
  echo "Existing matching volumes:"
  for v in "${VOLUMES[@]}"; do
    docker volume inspect "${PROJECT}_${v}" >/dev/null 2>&1 \
      && echo "  - ${PROJECT}_${v} (present)" || echo "  - ${PROJECT}_${v} (absent)"
  done
  exit 0
fi

mkdir -p "$OUT"
echo "Backing up to: $OUT"

for v in "${VOLUMES[@]}"; do
  full="${PROJECT}_${v}"
  if ! docker volume inspect "$full" >/dev/null 2>&1; then
    echo "SKIP $full (volume not present)"
    continue
  fi
  echo "Backing up $full ..."
  # tar the mount as user 'root' (uid 0 inside alpine) into the host file
  docker run --rm \
    -v "$full":/data:ro \
    -v "$OUT":/backup \
    alpine:3.19 \
    tar czf "/backup/${v}.tar.gz" -C /data .
done

echo "Done. Backups in $OUT"
echo
echo "Restore (example):"
echo "  docker run --rm -v ${PROJECT}_vikunja-db:/data -v $OUT:/backup alpine:3.19 \\"
echo "    sh -c 'rm -rf /data/* && tar xzf /backup/vikunja-db.tar.gz -C /data'"
echo
echo "CAUTION: do NOT run 'docker compose down -v' or 'docker system prune -a --volumes'"
echo "as a habit — that deletes all named volumes above."