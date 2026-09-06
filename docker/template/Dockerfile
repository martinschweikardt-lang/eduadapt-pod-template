# ── eduadapt-pod-template v2: VOLLER Stack, kein Volume ─────────────────────
# Enthaelt: OS+CUDA, System-Pakete (postgres/redis/nginx/java), Python-venv,
# Keycloak, Node, Ollama + Modelle. KEIN Eduadapt-Code (kommt frisch von
# GitHub beim Podstart via Deploy-Key). Public-tauglich.
ARG BASE_IMAGE=runpod/base:1.1.0-cuda1290-ubuntu2404
FROM ${BASE_IMAGE}

ARG OLLAMA_VERSION=0.33.3
ARG KEYCLOAK_VERSION=24.0.5

ENV OLLAMA_MODELS=/opt/ollama/models \
    OLLAMA_HOST=0.0.0.0:11434 \
    VENV_DIR=/opt/venv \
    KC_HOME=/opt/keycloak \
    DEBIAN_FRONTEND=noninteractive

# ── Layer 1: System-Pakete (postgres, redis, nginx, java, python-libs) ──────
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates gnupg lsb-release jq git gettext-base zstd \
        postgresql postgresql-client \
        redis-server \
        openjdk-17-jdk-headless \
        libcairo2 libpango-1.0-0 libpangocairo-1.0-0 libgdk-pixbuf2.0-0 \
        libffi-dev shared-mime-info \
        python3-pip python3-venv \
        netcat-openbsd wireguard-tools restic nginx \
    && rm -rf /var/lib/apt/lists/*

# ── Layer 2: Node 22 (Frontend-Build) ───────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && node --version && npm --version

# ── Layer 3: Python-venv mit Backend-Dependencies (aus requirements.lock) ────
# Lock-Datei wird aus dem Eduadapt-Repo (backend/pyproject.toml) generiert;
# nur Paketnamen/-versionen -> public unkritisch. Code kommt separat.
COPY requirements.lock /tmp/requirements.lock
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/venv/bin/pip install --no-cache-dir -r /tmp/requirements.lock \
    && rm /tmp/requirements.lock

# ── Layer 4: Ollama-Runtime ──────────────────────────────────────────────────
RUN curl -fsSL -o /tmp/ollama.tar.zst \
        "https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-amd64.tar.zst" \
    && tar --zstd -C /usr/local -xf /tmp/ollama.tar.zst \
    && rm /tmp/ollama.tar.zst \
    && ollama --version

# ── Layer 5: Modelle einbacken (Hauptmodell + 2 Embedder) ────────────────────
RUN mkdir -p /opt/ollama/models \
    && (ollama serve >/tmp/ollama_build.log 2>&1 &) \
    && sleep 4 \
    && ollama pull qwen3.8:27b \
    && ollama pull bge-m3 \
    && ollama pull nomic-embed-text \
    && ollama list

# ── Layer 6: Keycloak ────────────────────────────────────────────────────────
RUN curl -fsSL -o /tmp/keycloak.tar.gz \
        "https://github.com/keycloak/keycloak/releases/download/${KEYCLOAK_VERSION}/keycloak-${KEYCLOAK_VERSION}.tar.gz" \
    && tar -xzf /tmp/keycloak.tar.gz -C /opt \
    && mv /opt/keycloak-${KEYCLOAK_VERSION} /opt/keycloak \
    && rm /tmp/keycloak.tar.gz \
    && /opt/keycloak/bin/kc.sh --version 2>&1 | tail -1

# ── Layer 7: Start-/Boot-Skripte ─────────────────────────────────────────────
COPY start.sh /start.sh
COPY boot.sh /boot.sh
RUN chmod +x /start.sh /boot.sh

# CMD bleibt /start.sh: sshd + ollama, dann boot.sh (Code-Pull + Stack)
CMD ["/start.sh"]
