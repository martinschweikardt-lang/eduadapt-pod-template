#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════════
# eduadapt-pod-template v2 – boot.sh (OHNE Volume)
#
# Holt den Eduadapt-Code frisch von GitHub (privates Repo, Deploy-Key aus
# Env GITHUB_DEPLOY_KEY), richtet /workspace per Symlinks auf die Image-Layer
# ein und startet den Stack über das Repo-start.sh --async-frontend.
#
# KEIN Eduadapt-Code in dieser Datei – nur generische Orchestrierung.
# ═════════════════════════════════════════════════════════════════════════════
set -uo pipefail

WS=/workspace
PROJECT=$WS/eduadapt
REPO_URL="git@github.com:martinschweikardt-lang/eduadapt.git"
LOG=/var/log/boot.log

log() { echo -e "\033[1;32m[BOOT]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err()  { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# ── 1. /workspace-Struktur + Symlinks auf Image-Layer ───────────────────────
log "Richte /workspace ein (Symlinks auf Image-Layer) ..."
mkdir -p "$WS"/{eduadapt,data/db_backup,data/dossiers,data/chroma,logs,run,cache}

# venv, Keycloak, Ollama-Models liegen im Image (/opt/...) → Symlinks an den
# vom Repo-start.sh erwarteten Pfaden (/workspace/cache/...)
[ ! -e "$WS/cache/venv" ]     && ln -s /opt/venv "$WS/cache/venv"
[ ! -e "$WS/cache/keycloak" ] && ln -s /opt/keycloak "$WS/cache/keycloak"
[ ! -e "$WS/cache/ollama" ]   && ln -s /opt/ollama/models "$WS/cache/ollama"

# ── 2. Deploy-Key fuer privates Repo einrichten ─────────────────────────────
# Key kommt als Env GITHUB_DEPLOY_KEY (RunPod-Template-Secret), NICHT im Image!
if [ -n "${GITHUB_DEPLOY_KEY:-}" ]; then
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  echo "$GITHUB_DEPLOY_KEY" > ~/.ssh/eduadapt_deploy
  chmod 600 ~/.ssh/eduadapt_deploy
  cat > ~/.ssh/config <<'SSHEOF'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/eduadapt_deploy
  StrictHostKeyChecking accept-new
SSHEOF
  chmod 600 ~/.ssh/config
  log "Deploy-Key eingerichtet (~/.ssh/eduadapt_deploy)"
else
  warn "GITHUB_DEPLOY_KEY fehlt – Code-Pull wird fehlschlagen!"
fi

# ── 3. Code frisch von GitHub ────────────────────────────────────────────────
if [ -d "$PROJECT/.git" ]; then
  log "Repo vorhanden – pull (frisch von GitHub) ..."
  git -C "$PROJECT" fetch origin main 2>&1 | tail -1
  git -C "$PROJECT" reset --hard origin/main 2>&1 | tail -1
else
  log "Klone eduadapt (frisch von GitHub) ..."
  GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new" \
    git clone --depth 1 --branch main "$REPO_URL" "$PROJECT" 2>&1 | tail -2
fi
cd "$PROJECT"
log "Code-Stand: $(git rev-parse --short HEAD) – $(git log -1 --format=%s | head -c 80)"

# ── 3b. pip-Delta: neue Backend-Deps aus frischem Code nachinstallieren ─────
# Image-venv enthaelt den Lock-Stand vom Build; wenn der Code neuere Deps
# verlangt, installiert pip hier nur die Differenz (idempotent, schnell).
if [ -f "$PROJECT/backend/requirements.lock" ]; then
  log "pip-Delta-Check (requirements.lock aus frischem Code) ..."
  /opt/venv/bin/pip install --quiet -r "$PROJECT/backend/requirements.lock" 2>&1 | tail -2 || warn "pip-Delta fehlgeschlagen"
fi

# ── 4. .env erzeugen (falls nicht vorhanden) ────────────────────────────────
# .env ist NICHT in Git. Basis: .env.example + Werte aus Template-Env.
# RunPod-Template-Env kann Werte ueberschreiben (POSTGRES_PASSWORD etc.).
if [ ! -f "$PROJECT/.env" ]; then
  log "Erzeuge .env aus .env.example + Template-Env ..."
  if [ -f "$PROJECT/.env.example" ]; then
    cp "$PROJECT/.env.example" "$PROJECT/.env"
    # Docker-Container-Namen aus .env.example auf localhost umstellen
    sed -i 's|@db:|@localhost:|g; s|@redis:|@localhost:|g; s|@chromadb:|@localhost:|g' "$PROJECT/.env"
    sed -i 's|^KEYCLOAK_URL=.*|KEYCLOAK_URL=http://localhost:9080|' "$PROJECT/.env"
    sed -i 's|^OLLAMA_HOST=.*|OLLAMA_HOST=http://localhost:11434|' "$PROJECT/.env"
    # Env-Uebersteuerung aus Template (nur gesetzte Variablen)
    for key in POSTGRES_PASSWORD SECRET_KEY KEYCLOAK_CLIENT_SECRET \
               POSTGRES_DB POSTGRES_USER OLLAMA_MODEL; do
      if [ -n "${!key:-}" ]; then
        sed -i "s|^${key}=.*|${key}=${!key}|" "$PROJECT/.env"
        log "  .env: ${key} aus Template-Env gesetzt"
      fi
    done
  else
    warn ".env.example fehlt im Repo!"
  fi
else
  log ".env vorhanden"
fi

# ── 5. DB-Dump von GitHub (falls im Repo) ───────────────────────────────────
# Dump liegt committet im Repo unter data/db_backup/eduadapt.sql
if [ -f "$PROJECT/data/db_backup/eduadapt.sql" ]; then
  log "DB-Dump aus Repo → /workspace/data/db_backup/ ..."
  cp "$PROJECT/data/db_backup/eduadapt.sql" "$WS/data/db_backup/eduadapt.sql"
elif [ -f "$WS/data/db_backup/eduadapt.sql" ]; then
  log "DB-Dump vorhanden: $WS/data/db_backup/eduadapt.sql"
else
  warn "Kein DB-Dump gefunden – start.sh wird leere DB seeden"
fi

# ── 6. Dossiers von GitHub (falls im Repo) ──────────────────────────────────
if [ -d "$PROJECT/data/dossiers" ]; then
  log "Dossiers aus Repo → /workspace/data/dossiers/ ..."
  cp -rn "$PROJECT/data/dossiers/." "$WS/data/dossiers/" 2>/dev/null || true
fi

# ── 7. Stack starten (Repo-start.sh, Frontend async) ────────────────────────
log "Starte Stack (start.sh --autostart --async-frontend) ..."
cd "$PROJECT"
# Postgres-Datenverzeichnis ist Container-lokal: Cluster ggf. initialisieren
if ! pg_lsclusters 2>/dev/null | grep -q online; then
  log "Initialisiere PostgreSQL-Cluster ..."
  PGVERSION=$(ls /usr/lib/postgresql/ 2>/dev/null | head -1)
  if [ -n "$PGVERSION" ] && [ ! -d "/var/lib/postgresql/$PGVERSION/main" ]; then
    mkdir -p "/var/lib/postgresql/$PGVERSION/main"
    chown -R postgres:postgres "/var/lib/postgresql/$PGVERSION"
    su postgres -c "/usr/lib/postgresql/$PGVERSION/bin/pg_ctl -D /var/lib/postgresql/$PGVERSION/main initdb" >/dev/null 2>&1 \
      && log "initdb OK" || warn "initdb fehlgeschlagen (start.sh versucht service start)"
  fi
fi

bash "$PROJECT/start.sh" --autostart --async-frontend \
  >> "$WS/logs/start_async.log" 2>&1 &
STACK_PID=$!
echo "$STACK_PID" > "$WS/run/start_async.pid"
log "start.sh läuft (PID $STACK_PID) – Log: $WS/logs/start_async.log"

# ── 8. Fortschritt melden (ohne zu blockieren) ──────────────────────────────
(
  # Backend-Check nach ~90s melden
  sleep 90
  if curl -sf -m 3 http://localhost:8000/health >/dev/null 2>&1; then
    log "✅ Backend bereit: http://localhost:8000/health (Frontend baut im Hintergrund)"
  else
    log "⏳ Backend noch nicht bereit – Log: $WS/logs/start_async.log (tail -f)"
  fi
  # Frontend-Check nach ~10 min (dist vorhanden → Nginx-Start prüfen)
  sleep 480
  if [ -f "$PROJECT/frontend/dist/index.html" ]; then
    log "✅ Frontend gebaut – Web-UI sollte über Port 8081 erreichbar sein"
  else
    log "⏳ Frontend baut noch – Fortschritt: tail -f $WS/logs/frontend_build.log"
  fi
) &
disown || true

log "── boot.sh Phase 1 fertig. Stack bootet im Hintergrund ──"
log "   Status: tail -f $WS/logs/start_async.log | grep -E 'START|✓|ERROR'"
