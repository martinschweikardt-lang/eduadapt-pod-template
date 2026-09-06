# ── eduadapt-pod-template: Ollama + qwen3.8:27b ─────────────────────────────
# Generisches RunPod-Pod-Template. KEIN Eduadapt-Code.
ARG BASE_IMAGE=runpod/base:1.1.0-cuda1290-ubuntu2404
FROM ${BASE_IMAGE}

ARG OLLAMA_VERSION=0.33.3
ARG MODEL=qwen3.8:27b

ENV OLLAMA_MODELS=/opt/ollama/models \
    OLLAMA_HOST=0.0.0.0:11434

# Layer: Tools
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates jq zstd \
    && rm -rf /var/lib/apt/lists/*

# Layer: Ollama-Binary (deterministisch aus GitHub-Release, .tar.zst)
RUN curl -fsSL -o /tmp/ollama.tar.zst \
        "https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-amd64.tar.zst" \
    && tar --zstd -C /usr/local -xf /tmp/ollama.tar.zst \
    && rm /tmp/ollama.tar.zst \
    && ollama --version

# Layer: Modell einbacken (ollama pull braucht laufenden Server im Build)
RUN (ollama serve >/tmp/ollama_build.log 2>&1 &) \
    && sleep 4 \
    && ollama pull ${MODEL} \
    && ollama list

# Layer: Start-Skript
COPY start.sh /start.sh
RUN chmod +x /start.sh
ENV PUBLIC_KEY=""
CMD ["/start.sh"]
